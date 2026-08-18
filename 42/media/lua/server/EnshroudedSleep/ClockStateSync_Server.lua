-- Enshrouded Sleep - server-to-client MinutesPerDay replication
-- v0.0.7 synchronization cleanup for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Project Zomboid's normal multiplayer clock synchronization keeps client
-- TimeOfDay near the authoritative server, but v0.0.5 testing demonstrated that
-- runtime server changes to GameTime MinutesPerDay are not automatically copied
-- to clients. Clients therefore continued advancing a 90-minute day while the
-- server was running a 4.5-minute day, then periodically snapped forward.
--
-- v0.0.6 proved that broadcasting the effective server MinutesPerDay and
-- mirroring it on clients removes the large clock corrections and produces
-- visually smooth sleeping/HUD clocks while active gameplay remains normal-speed.
--
-- v0.0.7 preserves that architecture and adds a one-tick settling guard when the
-- observed player/sleep population changes. The sync observer and authoritative
-- controller are separate OnTick listeners; without the guard, the observer can
-- sometimes see a new sleep-state label one fraction of a tick before the
-- controller has applied the corresponding MinutesPerDay, causing a harmless
-- stale transition packet (for example partial mode paired briefly with 90).
--
-- This module broadcasts the effective authoritative MinutesPerDay to clients.
-- It does not decide the compression policy and never changes GameTime itself;
-- EnshroudedSleep_Server.lua remains the sole authoritative controller.

if isClient() then return end

local PREFIX = "[EnshroudedSleepSync][SERVER]"
local MODULE = "EnshroudedSleep"
local COMMAND = "ClockState"
local PROTOCOL_VERSION = 1
local HEARTBEAT_SECONDS = 2

local baselineMinutesPerDay = nil
local lastSentSignature = nil
local lastSentAt = -1
local lastError = nil
local lastObservedPopulationSignature = nil

---Write one namespaced synchronization message to the dedicated-server log.
---@param message any Value to stringify.
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Safely call a Java/Lua method without allowing an unavailable API to stop the
---server synchronization loop.
---@param obj any Object expected to expose methodName.
---@param methodName string Method name.
---@param ... any Method arguments.
---@return any|nil value
local function safeMethod(obj, methodName, ...)
    if not obj then return nil end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end

    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end

    return value
end

---Log a synchronization error once per distinct failure episode.
---@param message any Error description.
---@return nil
local function logErrorOnce(message)
    message = tostring(message)
    if message == lastError then return end
    lastError = message
    log("ERROR | " .. message)
end

---Clear the remembered synchronization error after a successful send/read pass.
---@return nil
local function clearError()
    lastError = nil
end

---Capture the native runtime MinutesPerDay before any partial-sleep value is
---needed. On a dedicated server this module begins running with no living
---players, so the first valid GameTime value is the native baseline.
---@param current number Current server MinutesPerDay.
---@return nil
local function ensureBaseline(current)
    if baselineMinutesPerDay ~= nil then return end
    if type(current) == "number" and current > 0 then
        baselineMinutesPerDay = current
        log(string.format("CONFIG | captured baselineMinutesPerDay=%.4f", current))
    end
end

---Count currently instantiated living and sleeping players for state labeling.
---The counts are included only as diagnostics; the authoritative controller owns
---the actual compression decision.
---@return integer|nil living
---@return integer|nil sleeping
local function countPlayers()
    if type(getOnlinePlayers) ~= "function" then return nil, nil end

    local players = getOnlinePlayers()
    if not players then return 0, 0 end

    local size = tonumber(safeMethod(players, "size"))
    if size == nil then return nil, nil end

    local living = 0
    local sleeping = 0

    -- Inspect all currently instantiated player characters without mutating them.
    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if not player then return nil, nil end

        local dead = safeMethod(player, "isDead")
        if dead == nil then return nil, nil end

        -- Match the controller's living-player denominator for readable state labels.
        if dead ~= true then
            living = living + 1
            local asleep = safeMethod(player, "isAsleep")
            if asleep == nil then return nil, nil end
            if asleep == true then sleeping = sleeping + 1 end
        end
    end

    return living, sleeping
end

---Derive a human-readable state label from the observed population.
---@param living integer|nil
---@param sleeping integer|nil
---@return string mode
local function deriveMode(living, sleeping)
    if living == nil or sleeping == nil then return "unknown" end
    if living <= 0 or sleeping <= 0 then return "baseline" end
    if sleeping >= living then return "vanilla-full-sleep" end
    return "partial"
end

---Broadcast effective authoritative MinutesPerDay when state changes or the
---heartbeat expires. The heartbeat ensures a client that finishes loading after
---an earlier state-change packet still converges to the current server value.
---@return nil
local function synchronizeClients()
    local now = os.time()
    local gt = getGameTime()

    if not gt then
        logErrorOnce("getGameTime() unavailable")
        return
    end

    local currentMinutesPerDay = tonumber(safeMethod(gt, "getMinutesPerDay"))
    if currentMinutesPerDay == nil or currentMinutesPerDay <= 0 then
        logErrorOnce("invalid authoritative MinutesPerDay: " .. tostring(currentMinutesPerDay))
        return
    end

    ensureBaseline(currentMinutesPerDay)

    local living, sleeping = countPlayers()

    -- No instantiated players means there is nobody useful to notify yet. Do not
    -- update lastSentSignature so the first player appearance forces a later send.
    if living == 0 then
        clearError()
        lastObservedPopulationSignature = nil
        return
    end

    local mode = deriveMode(living, sleeping)
    local populationSignature = table.concat({
        mode,
        tostring(living),
        tostring(sleeping),
    }, "|")

    -- The authoritative controller and this observer are independent tick
    -- listeners. When vanilla-visible sleep/population changes, defer exactly one
    -- observer pass so the controller can apply the matching MinutesPerDay before
    -- this module publishes a state packet. This avoids stale transition pairs
    -- such as mode=partial with the previous baseline value.
    if populationSignature ~= lastObservedPopulationSignature then
        lastObservedPopulationSignature = populationSignature
        return
    end

    -- Baseline and full-sleep states must always tell clients to use the native
    -- baseline. Partial mode mirrors the already-settled controller output.
    local targetMinutesPerDay = currentMinutesPerDay
    if mode ~= "partial" and baselineMinutesPerDay ~= nil then
        targetMinutesPerDay = baselineMinutesPerDay
    end

    local signature = table.concat({
        mode,
        tostring(living),
        tostring(sleeping),
        string.format("%.6f", targetMinutesPerDay),
    }, "|")

    local stateChanged = signature ~= lastSentSignature
    local heartbeatDue = lastSentAt < 0 or (now - lastSentAt) >= HEARTBEAT_SECONDS

    -- Avoid a packet every tick; state changes are prompt after the one-pass
    -- settling guard and stable states receive only a two-second heartbeat.
    if not stateChanged and not heartbeatDue then return end

    if type(sendServerCommand) ~= "function" then
        logErrorOnce("sendServerCommand() unavailable")
        return
    end

    local args = {
        protocolVersion = PROTOCOL_VERSION,
        buildVersion = "0.0.7",
        mode = mode,
        minutesPerDay = targetMinutesPerDay,
        baselineMinutesPerDay = baselineMinutesPerDay or targetMinutesPerDay,
        living = living or -1,
        sleeping = sleeping or -1,
        serverEpoch = now,
    }

    local ok, err = pcall(sendServerCommand, MODULE, COMMAND, args)
    if not ok then
        logErrorOnce("sendServerCommand failed: " .. tostring(err))
        return
    end

    clearError()
    lastSentSignature = signature
    lastSentAt = now

    -- State-change packets are logged; routine heartbeat packets stay quiet.
    if stateChanged then
        log(string.format(
            "STATE | mode=%s | living=%s | sleeping=%s | currentServerMinutesPerDay=%.4f | broadcastMinutesPerDay=%.4f | broadcast ClockState",
            mode,
            tostring(living or "N/A"),
            tostring(sleeping or "N/A"),
            currentMinutesPerDay,
            targetMinutesPerDay
        ))
    end
end

-- Observe every tick so server clock transitions are replicated promptly; the
-- function rate-limits stable-state heartbeats and defers population transitions
-- by one observer pass to let the authoritative controller settle first.
if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(synchronizeClients)
else
    Events.OnTick.Add(synchronizeClients)
end

log("Loaded v0.0.7 authoritative MinutesPerDay replication.")
