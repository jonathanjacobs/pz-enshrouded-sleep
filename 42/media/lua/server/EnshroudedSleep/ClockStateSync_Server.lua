-- Enshrouded Sleep - server-to-client MinutesPerDay replication
-- v0.0.10 package; normal synchronization behavior remains the validated v0.0.7 design
--
-- Runtime server changes to GameTime MinutesPerDay are not automatically copied
-- to clients in the tested multiplayer path. This module publishes the settled
-- authoritative MinutesPerDay so clients can pace their local clocks coherently.
-- It does not calculate normal proportional sleep policy.

if isClient() then return end

local PREFIX = "[EnshroudedSleepSync][SERVER]"
local MODULE = "EnshroudedSleep"
local COMMAND = "ClockState"
local PROTOCOL_VERSION = 1
local HEARTBEAT_SECONDS = 2
local EPSILON = 0.0001

local baselineMinutesPerDay = nil
local lastSentSignature = nil
local lastSentAt = -1
local lastError = nil
local lastObservedPopulationSignature = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function logErrorOnce(message)
    message = tostring(message)
    if message == lastError then return end
    lastError = message
    log("ERROR | " .. message)
end

local function clearError()
    lastError = nil
end

local function ensureBaseline(current)
    if baselineMinutesPerDay ~= nil then return end
    if type(current) == "number" and current > 0 then
        baselineMinutesPerDay = current
        log(string.format("CONFIG | captured baselineMinutesPerDay=%.4f", current))
    end
end

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

local function diagnosticOverrideConfigured()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local factor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    return vars ~= nil
        and vars.DiagnosticsEnabled == true
        and factor > 1.0 + EPSILON
end

local function deriveMode(living, sleeping, currentMinutesPerDay)
    if living == nil or sleeping == nil then return "unknown" end

    -- In hosted multiplayer, preserve the diagnostic test override rather than
    -- misclassifying an awake/no-sleeper compressed clock as baseline and
    -- broadcasting baseline back to clients.
    if diagnosticOverrideConfigured()
        and sleeping <= 0
        and baselineMinutesPerDay ~= nil
        and currentMinutesPerDay < baselineMinutesPerDay - EPSILON then
        return "diagnostic-forced"
    end

    if living <= 0 or sleeping <= 0 then return "baseline" end
    if sleeping >= living then return "vanilla-full-sleep" end
    return "partial"
end

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
        clearError()
        lastObservedPopulationSignature = nil
        return
    end

    local mode = deriveMode(living, sleeping, currentMinutesPerDay)
    local populationSignature = table.concat({mode, tostring(living), tostring(sleeping)}, "|")

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

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(synchronizeClients)
else
    Events.OnTick.Add(synchronizeClients)
end

log("Loaded v0.0.10 authoritative MinutesPerDay replication; diagnostic-forced mode is preserved when configured.")
