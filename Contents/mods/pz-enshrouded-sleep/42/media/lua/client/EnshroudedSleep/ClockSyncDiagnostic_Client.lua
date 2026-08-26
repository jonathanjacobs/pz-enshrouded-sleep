-- Enshrouded Sleep - client clock/sleep diagnostic
-- Public Alpha v0.0.10 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record the connected client's view of GameTime and local sleep state once per
-- real second while verbose diagnostics are explicitly enabled. This is support
-- instrumentation only; normal Public Alpha gameplay leaves it dormant.
--
-- This sampler preserves the clock/sleep observability first used to diagnose
-- the historical client MinutesPerDay mismatch. It complements the newer health
-- and CharacterStat diagnostics without participating in clock policy.
--
-- MUTATION BOUNDARY
-- -----------------
-- Read-only. ClockStateSync_Client.lua is the only client component that
-- intentionally mutates local MinutesPerDay.

if not isClient() then return end

local PREFIX = "[EnshroudedSleepDiag][CLIENT]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local lastError = nil
local observedBaselineMinutesPerDay = nil

---Return whether development/support telemetry is explicitly enabled.
---@return boolean enabled
local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

---Return whether the diagnostics-only forced compression control is armed.
---This is descriptive only; the client never owns the test mutation.
---@return boolean configured
local function diagnosticForcedConfigured()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local factor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    return vars ~= nil and vars.DiagnosticsEnabled == true and factor > 1.0 + EPSILON
end

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

---Resolve the owning client player and read sleep/recovery values relevant to
---clock/sleep support diagnostics. This function never mutates the player.
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

    -- This legacy broad diagnostic keeps the historical fatigue getter probe for
    -- continuity. Current Build 42 survival-state analysis uses the dedicated
    -- SurvivalStatProbe/CharacterStat path instead, so N/A here is acceptable.
    local stats = safeMethod(player, "getStats")
    state.fatigue = tonumber(safeMethod(stats, "getFatigue"))

    return state
end

---Derive a descriptive client phase from local sleep state and observed day length.
---@param playerState table
---@param minutesPerDay number|nil
---@param baseline number|nil
---@return string phase
local function derivePhase(playerState, minutesPerDay, baseline)
    if playerState.dead == true then return "dead" end

    if playerState.asleep == true then
        if diagnosticForcedConfigured() then return "diagnostic-forced-suspended-sleep" end
        if minutesPerDay and baseline and math.abs(minutesPerDay - baseline) < EPSILON then
            return "sleeping-at-baseline"
        end
        return "sleeping"
    end

    if diagnosticForcedConfigured() then
        if baseline and minutesPerDay and minutesPerDay < baseline - EPSILON then
            return "diagnostic-forced"
        end
        return "diagnostic-forced-armed"
    end

    if minutesPerDay and baseline and minutesPerDay < baseline - EPSILON then return "partial" end
    return "baseline"
end

---Capture one wall-clock-gated client clock/sleep sample when verbose
---diagnostics are explicitly enabled.
---@return nil
local function sampleClock()
    if not diagnosticsEnabled() then return end

    local now = os.time()

    -- os.time() is intentionally used as a real-time gate. A game-world-time
    -- event would itself accelerate under calendar compression and distort the
    -- diagnostic sampling rate.
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
    if minutesPerDay and minutesPerDay > 0 then
        if not observedBaselineMinutesPerDay or minutesPerDay > observedBaselineMinutesPerDay then
            observedBaselineMinutesPerDay = minutesPerDay
        end
    end

    local baseline = observedBaselineMinutesPerDay
    local compression = nil
    if minutesPerDay and minutesPerDay > 0 and baseline and baseline > 0 then
        compression = baseline / minutesPerDay
    end

    local timeOfDay = tonumber(safeMethod(gt, "getTimeOfDay"))
    local worldAgeHours = tonumber(safeMethod(gt, "getWorldAgeHours"))
    local multiplier = tonumber(safeMethod(gt, "getMultiplier"))
    local trueMultiplier = tonumber(safeMethod(gt, "getTrueMultiplier"))
    local serverMultiplier = tonumber(safeMethod(gt, "getServerMultiplier"))
    local deltaMinutesPerDay = tonumber(safeMethod(gt, "getDeltaMinutesPerDay"))

    log(string.format(
        "SAMPLE | epoch=%d | phase=%s | player=%s | onlineID=%s | asleep=%s | dead=%s | AsleepTime=%s | ForceWakeUpTime=%s | Fatigue=%s | SleepingPillsTaken=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | Multiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s",
        now,
        derivePhase(playerState, minutesPerDay, baseline),
        playerState.playerName,
        tostring(playerState.onlineID or "N/A"),
        tostring(playerState.asleep),
        tostring(playerState.dead),
        formatNumber(playerState.asleepTime, 6),
        formatNumber(playerState.forceWakeUpTime, 6),
        formatNumber(playerState.fatigue, 6),
        tostring(playerState.sleepingPillsTaken or "N/A"),
        formatNumber(minutesPerDay, 4),
        formatNumber(baseline, 4),
        formatNumber(compression, 4),
        formatNumber(timeOfDay, 6),
        formatNumber(worldAgeHours, 6),
        formatNumber(deltaMinutesPerDay, 6),
        formatNumber(multiplier, 4),
        formatNumber(trueMultiplier, 4),
        formatNumber(serverMultiplier, 4)
    ))
end

-- Prefer the even-while-paused hook so support telemetry can continue through
-- sleep/pause transitions; fall back to OnTick on builds where it is unavailable.
if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleClock)
else
    Events.OnTick.Add(sampleClock)
end

log("Loaded Public Alpha v0.0.10 client clock/sleep diagnostic; telemetry is disabled unless DiagnosticsEnabled=true.")
