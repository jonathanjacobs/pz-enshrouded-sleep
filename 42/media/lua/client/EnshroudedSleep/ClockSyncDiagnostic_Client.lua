-- Enshrouded Sleep - client clock synchronization diagnostic
-- v0.0.5 diagnostic instrumentation for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- This file records the multiplayer client's view of GameTime once per real
-- second. It exists to diagnose the clock-display snapping observed during the
-- first successful two-player v0.0.4 partial-sleep test.
--
-- IMPORTANT: this diagnostic is observational only. It never changes
-- MinutesPerDay, TimeOfDay, the GameTime multiplier, sleep state, or clock sync.

-- This file is intended for multiplayer clients only.
if not isClient() then return end

local PREFIX = "[EnshroudedSleepDiag][CLIENT]"
local SAMPLE_INTERVAL_SECONDS = 1
local lastSampleAt = -1
local lastError = nil

---Write one namespaced diagnostic message to the client log.
---@param message any Value to stringify.
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Format a number while allowing missing/unavailable diagnostic values.
---@param value any Value to format.
---@param decimals integer|nil Decimal places; defaults to 4.
---@return string formattedValue
local function formatNumber(value, decimals)
    if type(value) ~= "number" then return tostring(value or "N/A") end
    return string.format("%." .. tostring(decimals or 4) .. "f", value)
end

---Safely call a Java/Lua method without allowing a diagnostic API mismatch to
---break the client. Missing values are logged as N/A instead.
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

---Safely read a public Java field exposed through Kahlua.
---@param obj any Java/Lua object.
---@param fieldName string Public field name.
---@return any|nil value
local function safeField(obj, fieldName)
    if not obj then return nil end

    local ok, value = pcall(function() return obj[fieldName] end)
    if not ok then return nil end

    return value
end

---Read the local player's current sleep/death state for correlation with the
---clock sample. Failure to resolve a player is valid during loading.
---@return string playerName
---@return any asleep
---@return any dead
local function readPlayerState()
    if type(getPlayer) ~= "function" then return "N/A", nil, nil end

    local ok, player = pcall(getPlayer)
    if not ok or not player then return "N/A", nil, nil end

    local username = safeMethod(player, "getUsername")
        or safeMethod(player, "getDisplayName")
        or "N/A"

    return tostring(username), safeMethod(player, "isAsleep"), safeMethod(player, "isDead")
end

---Capture one real-time client clock sample.
---
---The most important comparison is whether client MinutesPerDay follows the
---server's 90 -> 4.5 transition during two-player partial sleep. We also record
---local TimeOfDay plus GameTime's public ServerTimeOfDay/ServerLastTimeOfDay
---fields to distinguish a replicated-day-length problem from coarse time sync
---or UI-only interpolation behavior.
---@return nil
local function sampleClock()
    local now = os.time()

    -- OnTickEvenPaused executes many times per second; sample only once per wall second.
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then
        return
    end
    lastSampleAt = now

    local gt = getGameTime()

    -- A missing GameTime object is unusual but should never destabilize the client.
    if not gt then
        if lastError ~= "getGameTime() unavailable" then
            lastError = "getGameTime() unavailable"
            log("ERROR | " .. lastError)
        end
        return
    end

    lastError = nil

    local playerName, asleep, dead = readPlayerState()

    local minutesPerDay = tonumber(safeMethod(gt, "getMinutesPerDay"))
    local timeOfDay = tonumber(safeMethod(gt, "getTimeOfDay"))
    local worldAgeHours = tonumber(safeMethod(gt, "getWorldAgeHours"))
    local multiplier = tonumber(safeMethod(gt, "getMultiplier"))
    local trueMultiplier = tonumber(safeMethod(gt, "getTrueMultiplier"))
    local serverMultiplier = tonumber(safeMethod(gt, "getServerMultiplier"))
    local deltaMinutesPerDay = tonumber(safeMethod(gt, "getDeltaMinutesPerDay"))

    -- These are public GameTime fields in the B42 Java API. They are diagnostic
    -- only because Kahlua field exposure can vary; unavailable fields print N/A.
    local serverTimeOfDay = tonumber(safeField(gt, "ServerTimeOfDay"))
    local serverLastTimeOfDay = tonumber(safeField(gt, "ServerLastTimeOfDay"))
    local rawTimeOfDay = tonumber(safeField(gt, "TimeOfDay"))

    log(string.format(
        "SAMPLE | epoch=%d | player=%s | asleep=%s | dead=%s | MinutesPerDay=%s | TimeOfDay=%s | RawTimeOfDay=%s | ServerTimeOfDay=%s | ServerLastTimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | Multiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s",
        now,
        playerName,
        tostring(asleep),
        tostring(dead),
        formatNumber(minutesPerDay, 4),
        formatNumber(timeOfDay, 6),
        formatNumber(rawTimeOfDay, 6),
        formatNumber(serverTimeOfDay, 6),
        formatNumber(serverLastTimeOfDay, 6),
        formatNumber(worldAgeHours, 6),
        formatNumber(deltaMinutesPerDay, 6),
        formatNumber(multiplier, 4),
        formatNumber(trueMultiplier, 4),
        formatNumber(serverMultiplier, 4)
    ))
end

-- Prefer the same event used by the authoritative controller so samples continue
-- through local paused/sleep-screen states. Fall back to OnTick if unavailable.
if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleClock)
else
    Events.OnTick.Add(sampleClock)
end

log("Loaded v0.0.5 read-only client clock synchronization diagnostic.")
