-- Enshrouded Sleep - client clock and sleep synchronization diagnostic
-- v0.0.6 diagnostic instrumentation for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record the multiplayer client's view of GameTime and local sleep state once
-- per real second. v0.0.5 established that runtime server MinutesPerDay changes
-- were not automatically replicated to clients. v0.0.6 keeps this diagnostic
-- active while the ClockState synchronization experiment is tested and adds
-- sleep-duration telemetry for the long-sleep investigation.
--
-- This file is observational only. The separate ClockStateSync_Client.lua file
-- is the only v0.0.6 client component that mutates local MinutesPerDay.

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

---Resolve the local player and read sleep/recovery values relevant to issue #3.
---@return table state
local function readPlayerState()
    local state = {
        playerName = "N/A",
        onlineID = nil,
        asleep = nil,
        dead = nil,
        asleepTime = nil,
        forceWakeUpTime = nil,
        fatigue = nil,
        sleepingPillsTaken = nil,
    }

    if type(getPlayer) ~= "function" then return state end

    local ok, player = pcall(getPlayer)
    if not ok or not player then return state end

    state.playerName = tostring(
        safeMethod(player, "getUsername")
        or safeMethod(player, "getDisplayName")
        or "N/A"
    )
    state.onlineID = tonumber(safeMethod(player, "getOnlineID"))
    state.asleep = safeMethod(player, "isAsleep")
    state.dead = safeMethod(player, "isDead")
    state.asleepTime = tonumber(safeMethod(player, "getAsleepTime"))
    state.forceWakeUpTime = tonumber(safeMethod(player, "getForceWakeUpTime"))
    state.sleepingPillsTaken = tonumber(safeMethod(player, "getSleepingPillsTaken"))

    local stats = safeMethod(player, "getStats")
    state.fatigue = tonumber(safeMethod(stats, "getFatigue"))

    return state
end

---Capture one real-time client clock/sleep sample.
---The key v0.0.6 clock test is whether local MinutesPerDay now follows the
---server's 90 -> 4.5 -> 90 state transitions and eliminates large TimeOfDay
---corrections. Sleep fields diagnose whether vanilla wake/recovery counters use
---a different time domain than compressed world/calendar time.
---@return nil
local function sampleClock()
    local now = os.time()

    -- OnTickEvenPaused executes many times per second; sample once per wall second.
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then
        return
    end
    lastSampleAt = now

    local gt = getGameTime()

    if not gt then
        if lastError ~= "getGameTime() unavailable" then
            lastError = "getGameTime() unavailable"
            log("ERROR | " .. lastError)
        end
        return
    end

    lastError = nil

    local playerState = readPlayerState()
    local minutesPerDay = tonumber(safeMethod(gt, "getMinutesPerDay"))
    local timeOfDay = tonumber(safeMethod(gt, "getTimeOfDay"))
    local worldAgeHours = tonumber(safeMethod(gt, "getWorldAgeHours"))
    local multiplier = tonumber(safeMethod(gt, "getMultiplier"))
    local trueMultiplier = tonumber(safeMethod(gt, "getTrueMultiplier"))
    local serverMultiplier = tonumber(safeMethod(gt, "getServerMultiplier"))
    local deltaMinutesPerDay = tonumber(safeMethod(gt, "getDeltaMinutesPerDay"))

    log(string.format(
        "SAMPLE | epoch=%d | player=%s | onlineID=%s | asleep=%s | dead=%s | AsleepTime=%s | ForceWakeUpTime=%s | Fatigue=%s | SleepingPillsTaken=%s | MinutesPerDay=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | Multiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s",
        now,
        playerState.playerName,
        tostring(playerState.onlineID or "N/A"),
        tostring(playerState.asleep),
        tostring(playerState.dead),
        formatNumber(playerState.asleepTime, 6),
        formatNumber(playerState.forceWakeUpTime, 6),
        formatNumber(playerState.fatigue, 6),
        tostring(playerState.sleepingPillsTaken or "N/A"),
        formatNumber(minutesPerDay, 4),
        formatNumber(timeOfDay, 6),
        formatNumber(worldAgeHours, 6),
        formatNumber(deltaMinutesPerDay, 6),
        formatNumber(multiplier, 4),
        formatNumber(trueMultiplier, 4),
        formatNumber(serverMultiplier, 4)
    ))
end

-- Use the same event family as the authoritative controller so diagnostics
-- continue through the sleeping black-screen state.
if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleClock)
else
    Events.OnTick.Add(sampleClock)
end

log("Loaded v0.0.6 client clock/sleep diagnostic.")
