-- Enshrouded Sleep - server-to-client MinutesPerDay replication
-- Public Alpha v0.0.10 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Publish the settled, server-authoritative MinutesPerDay to connected clients
-- so their local clocks pace coherently between vanilla multiplayer world-time
-- corrections. This module observes controller output; it does not calculate the
-- normal proportional-sleep target itself.
--
-- DESIGN BOUNDARY
-- ---------------
-- EnshroudedSleep_Server.lua owns server policy and the authoritative
-- GameTime:setMinutesPerDay() mutation. This module only observes that settled
-- value and sends protocol-1 EnshroudedSleep/ClockState packets. The client sync
-- module mirrors the resulting target locally.
--
-- A one-observer-pass settling guard is retained from the validated v0.0.7
-- regression so a population/sleep transition is not broadcast before the
-- controller has had a chance to apply its new MinutesPerDay.

if isClient() then return end

local PREFIX = "[EnshroudedSleepSync][SERVER]"
local MODULE = "EnshroudedSleep"
local COMMAND = "ClockState"
local PROTOCOL_VERSION = 1
local HEARTBEAT_SECONDS = 2
local EPSILON = 0.0001

-- The synchronization layer captures its own observational baseline from the
-- first valid authoritative value. It never writes this baseline to the server.
local baselineMinutesPerDay = nil
local lastSentSignature = nil
local lastSentAt = -1
local lastError = nil
local lastObservedPopulationSignature = nil

---Write one namespaced server synchronization message.
---@param message any Value to stringify.
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Best-effort Java/Lua bridge call used only by this observer.
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

---Log one distinct synchronization error once until a successful cycle clears it.
---@param message any Error description.
---@return nil
local function logErrorOnce(message)
    message = tostring(message)
    if message == lastError then return end
    lastError = message
    log("ERROR | " .. message)
end

---Clear the remembered synchronization error after successful observation/send.
---@return nil
local function clearError()
    lastError = nil
end

---Capture the first valid authoritative MinutesPerDay as the observer's baseline.
---@param current number Current server MinutesPerDay.
---@return nil
local function ensureBaseline(current)
    if baselineMinutesPerDay ~= nil then return end
    if type(current) == "number" and current > 0 then
        baselineMinutesPerDay = current
        log(string.format("CONFIG | captured baselineMinutesPerDay=%.4f", current))
    end
end

---Count instantiated living and sleeping players using the same vanilla-visible
---population semantics as the authoritative controller.
---@return integer|nil living
---@return integer|nil sleeping
local function countPlayers()
    if type(getOnlinePlayers) ~= "function" then return nil, nil end
    local players = getOnlinePlayers()
    if not players then return 0, 0 end

    local sizeValue = safeMethod(players, "size")
    local size = tonumber(sizeValue)
    if size == nil then return nil, nil end

    local living = 0
    local sleeping = 0
    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if not player then return nil, nil end
        local dead = safeMethod(player, "isDead")
        if dead == nil then return nil, nil end
        if dead ~= true then
            living = living + 1
            local asleep = safeMethod(player, "isAsleep")
            if asleep == nil then return nil, nil end
            if asleep == true then sleeping = sleeping + 1 end
        end
    end

    return living, sleeping
end

---Return whether the diagnostics-only forced-compression mode is currently armed.
---@return boolean configured
local function diagnosticOverrideConfigured()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local factor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    return vars ~= nil
        and vars.DiagnosticsEnabled == true
        and factor > 1.0 + EPSILON
end

---Derive a semantic mode for packet/log metadata from observed population and
---authoritative MinutesPerDay. This does not alter controller policy.
---@param living integer|nil
---@param sleeping integer|nil
---@param currentMinutesPerDay number
---@return string mode
local function deriveMode(living, sleeping, currentMinutesPerDay)
    if living == nil or sleeping == nil then return "unknown" end

    -- Diagnostic-forced is valid only for the intentionally isolated SPIKE/support
    -- state: one living connected server player, awake, and an authoritative
    -- MinutesPerDay below the captured baseline.
    if diagnosticOverrideConfigured()
        and living == 1
        and sleeping == 0
        and baselineMinutesPerDay ~= nil
        and currentMinutesPerDay < baselineMinutesPerDay - EPSILON then
        return "diagnostic-forced"
    end

    if living <= 0 or sleeping <= 0 then return "baseline" end
    if sleeping >= living then return "vanilla-full-sleep" end
    return "partial"
end

---Observe the settled server clock and publish it when state changes or the
---low-frequency convergence heartbeat becomes due.
---@return nil
local function synchronizeClients()
    local now = os.time()
    local gt = getGameTime()
    if not gt then
        logErrorOnce("getGameTime() unavailable")
        return
    end

    local currentValue = safeMethod(gt, "getMinutesPerDay")
    local currentMinutesPerDay = tonumber(currentValue)
    if currentMinutesPerDay == nil or currentMinutesPerDay <= 0 then
        logErrorOnce("invalid authoritative MinutesPerDay: " .. tostring(currentMinutesPerDay))
        return
    end

    ensureBaseline(currentMinutesPerDay)

    local living, sleeping = countPlayers()
    if living == 0 then
        -- No client needs a ClockState packet. Clear the transition guard so the
        -- next connected population is allowed one settling pass.
        clearError()
        lastObservedPopulationSignature = nil
        return
    end

    local mode = deriveMode(living, sleeping, currentMinutesPerDay)
    local populationSignature = table.concat({mode, tostring(living), tostring(sleeping)}, "|")

    -- One-pass settling guard: on the first observation of a new population/mode,
    -- return without sending. The next tick sees controller output after its own
    -- update and is therefore the value safe to publish.
    if populationSignature ~= lastObservedPopulationSignature then
        lastObservedPopulationSignature = populationSignature
        return
    end

    local targetMinutesPerDay = currentMinutesPerDay
    if mode ~= "partial" and mode ~= "diagnostic-forced" and baselineMinutesPerDay ~= nil then
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
    if not stateChanged and not heartbeatDue then return end

    if type(sendServerCommand) ~= "function" then
        logErrorOnce("sendServerCommand() unavailable")
        return
    end

    -- Packet schema is deliberately small and versioned. living/sleeping are
    -- diagnostic/context fields; clients must use minutesPerDay rather than
    -- independently recalculating a target from those counts.
    local args = {
        protocolVersion = PROTOCOL_VERSION,
        buildVersion = "0.0.10",
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

    -- Heartbeats are intentionally quiet; only semantic transitions are logged.
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

-- Continue synchronization through paused/sleep transitions where supported.
if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(synchronizeClients)
else
    Events.OnTick.Add(synchronizeClients)
end

log("Loaded Public Alpha v0.0.10 authoritative MinutesPerDay replication.")
