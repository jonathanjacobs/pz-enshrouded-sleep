-- Enshrouded Sleep - server clock/sleep diagnostic
-- Release Candidate v1.0.0 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record authoritative server GameTime state once per real second and, when at
-- least one living player is asleep, record each living player's vanilla sleep
-- counters. This diagnostic is retained for support/regression work after the
-- Public Alpha clock-synchronization and sleep-duration investigations.
--
-- Verbose diagnostics are opt-in through
-- SandboxVars.EnshroudedSleep.DiagnosticsEnabled and are disabled by default.
-- Low-volume controller/synchronization transition logs remain active
-- independently of this module.
--
-- MUTATION BOUNDARY
-- -----------------
-- Read-only. This file never changes GameTime, player state, sleep state,
-- fatigue, medication state, or native synchronization behavior.

if isClient() then return end

local PREFIX = "[EnshroudedSleepDiag][SERVER]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local lastError = nil
local observedBaselineMinutesPerDay = nil

local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

local function diagnosticForcedConfigured()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local factor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    return vars ~= nil and vars.DiagnosticsEnabled == true and factor > 1.0 + EPSILON
end

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function formatNumber(value, decimals)
    if type(value) ~= "number" then return tostring(value or "N/A") end
    return string.format("%." .. tostring(decimals or 4) .. "f", value)
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function collectPlayers()
    local playerStates = {}
    if type(getOnlinePlayers) ~= "function" then return nil, nil, playerStates end

    local players = getOnlinePlayers()
    if not players then return 0, 0, playerStates end

    local size = tonumber(safeMethod(players, "size"))
    if size == nil then return nil, nil, playerStates end

    local living = 0
    local sleeping = 0

    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if not player then return nil, nil, {} end

        local dead = safeMethod(player, "isDead")
        if dead == nil then return nil, nil, {} end

        if dead ~= true then
            living = living + 1
            local asleep = safeMethod(player, "isAsleep")
            if asleep == nil then return nil, nil, {} end
            if asleep == true then sleeping = sleeping + 1 end

            local stats = safeMethod(player, "getStats")
            playerStates[#playerStates + 1] = {
                playerName = tostring(safeMethod(player, "getUsername") or safeMethod(player, "getDisplayName") or "N/A"),
                onlineID = tonumber(safeMethod(player, "getOnlineID")),
                asleep = asleep,
                dead = dead,
                asleepTime = tonumber(safeMethod(player, "getAsleepTime")),
                forceWakeUpTime = tonumber(safeMethod(player, "getForceWakeUpTime")),
                fatigue = tonumber(safeMethod(stats, "getFatigue")),
                sleepingPillsTaken = tonumber(safeMethod(player, "getSleepingPillsTaken")),
            }
        end
    end

    return living, sleeping, playerStates
end

local function deriveMode(living, sleeping, minutesPerDay, baseline)
    if living == nil or sleeping == nil then return "unknown" end
    if diagnosticForcedConfigured() then
        if sleeping > 0 then return "diagnostic-forced-suspended-sleep" end
        if living <= 0 then return "diagnostic-forced-awaiting-player" end
        if living ~= 1 then return "diagnostic-forced-suspended-player-count" end
        if baseline and minutesPerDay and minutesPerDay < baseline - EPSILON then return "diagnostic-forced" end
        return "diagnostic-forced-armed"
    end
    if living <= 0 or sleeping <= 0 then return "baseline" end
    if sleeping >= living then return "vanilla-full-sleep" end
    return "partial"
end

local function sampleClock()
    if not diagnosticsEnabled() then return end

    local now = os.time()
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then return end
    lastSampleAt = now

    local gt = getGameTime()
    if not gt then
        if lastError ~= "getGameTime() unavailable" then
            lastError = "getGameTime() unavailable"
            log("ERROR | " .. lastError)
        end
        return
    end

    local living, sleeping, playerStates = collectPlayers()
    if living == 0 then
        lastError = nil
        return
    end
    lastError = nil

    local minutesPerDay = tonumber(safeMethod(gt, "getMinutesPerDay"))
    if minutesPerDay and minutesPerDay > 0 then
        if not observedBaselineMinutesPerDay or minutesPerDay > observedBaselineMinutesPerDay then
            observedBaselineMinutesPerDay = minutesPerDay
        end
    end

    local baseline = observedBaselineMinutesPerDay
    local compression = nil
    if minutesPerDay and minutesPerDay > 0 and baseline and baseline > 0 then compression = baseline / minutesPerDay end

    local timeOfDay = tonumber(safeMethod(gt, "getTimeOfDay"))
    local worldAgeHours = tonumber(safeMethod(gt, "getWorldAgeHours"))
    local multiplier = tonumber(safeMethod(gt, "getMultiplier"))
    local trueMultiplier = tonumber(safeMethod(gt, "getTrueMultiplier"))
    local serverMultiplier = tonumber(safeMethod(gt, "getServerMultiplier"))
    local deltaMinutesPerDay = tonumber(safeMethod(gt, "getDeltaMinutesPerDay"))

    log(string.format(
        "SAMPLE | epoch=%d | mode=%s | living=%s | sleeping=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | Multiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s",
        now,
        deriveMode(living, sleeping, minutesPerDay, baseline),
        tostring(living or "N/A"),
        tostring(sleeping or "N/A"),
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

    if sleeping and sleeping > 0 then
        for _, state in ipairs(playerStates) do
            log(string.format(
                "PLAYER | epoch=%d | player=%s | onlineID=%s | asleep=%s | AsleepTime=%s | ForceWakeUpTime=%s | Fatigue=%s | SleepingPillsTaken=%s",
                now,
                state.playerName,
                tostring(state.onlineID or "N/A"),
                tostring(state.asleep),
                formatNumber(state.asleepTime, 6),
                formatNumber(state.forceWakeUpTime, 6),
                formatNumber(state.fatigue, 6),
                tostring(state.sleepingPillsTaken or "N/A")
            ))
        end
    end
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleClock)
else
    Events.OnTick.Add(sampleClock)
end

log("Loaded Release Candidate v1.0.0 server clock/sleep diagnostic; telemetry is disabled unless DiagnosticsEnabled=true.")
