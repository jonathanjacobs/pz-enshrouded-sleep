-- Enshrouded Sleep - client MinutesPerDay synchronization
-- v0.0.6 experimental synchronization for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- v0.0.5 diagnostics established that clients retain their native
-- MinutesPerDay (90 on the test server) while the server applies partial-sleep
-- compression (4.5 in the 2-player / 1-sleeper test). Vanilla multiplayer then
-- corrects TimeOfDay periodically, producing visible ~51-minute clock jumps.
--
-- This client module listens for the server's EnshroudedSleep/ClockState command
-- and mirrors only the authoritative MinutesPerDay value locally. The server
-- remains authoritative for actual world time and sleep state.

if not isClient() then return end

local PREFIX = "[EnshroudedSleepSync][CLIENT]"
local MODULE = "EnshroudedSleep"
local COMMAND = "ClockState"
local PROTOCOL_VERSION = 1
local EPSILON = 0.0001
local MIN_VALID_MINUTES_PER_DAY = 0.01
local MAX_VALID_MINUTES_PER_DAY = 1440.0

local lastStateSignature = nil
local lastError = nil

---Write one namespaced synchronization message to the client log.
---@param message any Value to stringify.
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Safely call a Java/Lua method and convert bridge failures into ordinary
---client-side synchronization errors.
---@param obj any Object expected to expose methodName.
---@param methodName string Method name.
---@param ... any Method arguments.
---@return any|nil value
---@return string|nil errorMessage
local function safeMethod(obj, methodName, ...)
    if not obj then return nil, "nil object" end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil, methodName .. " unavailable" end

    local ok, value = pcall(method, obj, ...)
    if not ok then return nil, tostring(value) end

    return value, nil
end

---Log a client synchronization error once per distinct failure episode.
---@param message any Error description.
---@return nil
local function logErrorOnce(message)
    message = tostring(message)
    if message == lastError then return end
    lastError = message
    log("ERROR | " .. message)
end

---Clear the remembered synchronization error after a successful packet.
---@return nil
local function clearError()
    lastError = nil
end

---Validate and apply one authoritative ClockState packet.
---@param module string Server-command module name.
---@param command string Server-command command name.
---@param args table|nil Command arguments.
---@return nil
local function onServerCommand(module, command, args)
    -- Ignore all unrelated server commands; this listener is deliberately narrow.
    if module ~= MODULE or command ~= COMMAND then return end

    if type(args) ~= "table" then
        logErrorOnce("ClockState packet missing argument table")
        return
    end

    local protocolVersion = tonumber(args.protocolVersion)
    if protocolVersion ~= PROTOCOL_VERSION then
        logErrorOnce("unsupported ClockState protocolVersion=" .. tostring(args.protocolVersion))
        return
    end

    local target = tonumber(args.minutesPerDay)
    if target == nil or target < MIN_VALID_MINUTES_PER_DAY or target > MAX_VALID_MINUTES_PER_DAY then
        logErrorOnce("invalid ClockState minutesPerDay=" .. tostring(args.minutesPerDay))
        return
    end

    local gt = getGameTime()
    if not gt then
        logErrorOnce("getGameTime() unavailable while applying ClockState")
        return
    end

    local current, readErr = safeMethod(gt, "getMinutesPerDay")
    current = tonumber(current)
    if current == nil then
        logErrorOnce("could not read local MinutesPerDay: " .. tostring(readErr))
        return
    end

    local changed = math.abs(current - target) > EPSILON

    -- Mirror only the server's day-length pacing value. Do not set TimeOfDay or
    -- any multiplier; normal PZ multiplayer synchronization remains authoritative.
    if changed then
        local _, setErr = safeMethod(gt, "setMinutesPerDay", target)
        if setErr then
            logErrorOnce("setMinutesPerDay failed: " .. tostring(setErr))
            return
        end
    end

    local after = tonumber(safeMethod(gt, "getMinutesPerDay")) or target
    local mode = tostring(args.mode or "unknown")
    local signature = table.concat({
        mode,
        string.format("%.6f", target),
        tostring(args.living or "N/A"),
        tostring(args.sleeping or "N/A"),
    }, "|")

    clearError()

    -- Log state changes and any actual local correction. Routine heartbeat
    -- packets that find the client already synchronized remain silent.
    if changed or signature ~= lastStateSignature then
        log(string.format(
            "APPLY | mode=%s | living=%s | sleeping=%s | beforeMinutesPerDay=%.4f | targetMinutesPerDay=%.4f | afterMinutesPerDay=%.4f | serverEpoch=%s",
            mode,
            tostring(args.living or "N/A"),
            tostring(args.sleeping or "N/A"),
            current,
            target,
            after,
            tostring(args.serverEpoch or "N/A")
        ))
    end

    lastStateSignature = signature
end

-- OnServerCommand is the normal Lua event for server-to-client mod commands.
-- Guard registration so an API mismatch is visible in the client log rather
-- than preventing the rest of the mod from loading.
if Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
    log("Loaded v0.0.6 client MinutesPerDay synchronization experiment.")
else
    log("ERROR | Events.OnServerCommand unavailable; client clock replication disabled")
end
