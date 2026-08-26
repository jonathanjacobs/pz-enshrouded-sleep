-- Enshrouded Sleep - client MinutesPerDay synchronization
-- Public Beta v0.1.1 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Mirror the server-authoritative MinutesPerDay value onto each connected client
-- so HUD/watch/sleep clocks pace smoothly between vanilla multiplayer world-time
-- corrections. The server remains authoritative for world time, player
-- population, sleep state, and proportional-compression policy.
--
-- DESIGN HISTORY
-- --------------
-- v0.0.5 established that server-side MinutesPerDay changes were not sufficient:
-- clients retained their native day length and visibly snapped when vanilla
-- corrected TimeOfDay. v0.0.6 introduced explicit ClockState replication, and
-- v0.0.7 fixed a Kahlua multi-return conversion bug. That synchronization model
-- remains the validated design used by Public Beta v0.1.1.
--
-- MUTATION BOUNDARY
-- -----------------
-- This is the only client component that intentionally calls
-- GameTime:setMinutesPerDay(). It never calculates compression independently and
-- never changes TimeOfDay, the global GameTime multiplier, sleep state, health,
-- or any player simulation state.

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
local cachedBaselineMinutesPerDay = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil, "nil object" end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil, methodName .. " unavailable" end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil, tostring(value) end
    return value, nil
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

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= COMMAND then return end

    if not args then
        logErrorOnce("ClockState packet missing arguments")
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

    local baseline = tonumber(args.baselineMinutesPerDay)
    if baseline and baseline >= MIN_VALID_MINUTES_PER_DAY and baseline <= MAX_VALID_MINUTES_PER_DAY then
        cachedBaselineMinutesPerDay = baseline
    end

    local gt = getGameTime()
    if not gt then
        logErrorOnce("getGameTime() unavailable while applying ClockState")
        return
    end

    local currentValue, readErr = safeMethod(gt, "getMinutesPerDay")
    local current = tonumber(currentValue)
    if current == nil then
        logErrorOnce("could not read local MinutesPerDay: " .. tostring(readErr))
        return
    end

    local changed = math.abs(current - target) > EPSILON
    if changed then
        local _, setErr = safeMethod(gt, "setMinutesPerDay", target)
        if setErr then
            logErrorOnce("setMinutesPerDay failed: " .. tostring(setErr))
            return
        end
    end

    local afterValue, afterReadErr = safeMethod(gt, "getMinutesPerDay")
    local after = tonumber(afterValue)
    if after == nil then
        logErrorOnce("could not verify local MinutesPerDay after apply: " .. tostring(afterReadErr))
        return
    end

    local mode = tostring(args.mode or "unknown")
    local signature = table.concat({
        mode,
        string.format("%.6f", target),
        tostring(args.living or "N/A"),
        tostring(args.sleeping or "N/A"),
    }, "|")

    clearError()

    if changed or signature ~= lastStateSignature then
        log(string.format(
            "APPLY | mode=%s | living=%s | sleeping=%s | beforeMinutesPerDay=%.4f | targetMinutesPerDay=%.4f | afterMinutesPerDay=%.4f | baselineMinutesPerDay=%s | serverEpoch=%s",
            mode,
            tostring(args.living or "N/A"),
            tostring(args.sleeping or "N/A"),
            current,
            target,
            after,
            cachedBaselineMinutesPerDay and string.format("%.4f", cachedBaselineMinutesPerDay) or "N/A",
            tostring(args.serverEpoch or "N/A")
        ))
    end

    lastStateSignature = signature
end

local function onDisconnect()
    if not cachedBaselineMinutesPerDay then return end
    local gt = getGameTime()
    if not gt then return end

    local currentValue = safeMethod(gt, "getMinutesPerDay")
    local current = tonumber(currentValue)
    if current and math.abs(current - cachedBaselineMinutesPerDay) <= EPSILON then return end

    local _, err = safeMethod(gt, "setMinutesPerDay", cachedBaselineMinutesPerDay)
    if not err then
        log(string.format("RESTORE | disconnect | MinutesPerDay=%.4f", cachedBaselineMinutesPerDay))
    end
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
    log("Loaded Public Beta v0.1.1 client MinutesPerDay synchronization.")
else
    log("ERROR | Events.OnServerCommand unavailable; client clock replication disabled")
end

if Events.OnDisconnect then
    Events.OnDisconnect.Add(onDisconnect)
end
