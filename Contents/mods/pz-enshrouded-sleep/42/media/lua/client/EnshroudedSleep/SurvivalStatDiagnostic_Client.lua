-- Enshrouded Sleep - focused owning-client survival-stat diagnostic
-- Release Candidate v1.0.0 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record the connected player's current Build 42 CharacterStat, MoodleType,
-- Nutrition, and related health values once per real second while verbose
-- diagnostics are enabled. This is the focused survival-state stream validated
-- during SPIKE-004.
--
-- MUTATION BOUNDARY
-- -----------------
-- Read-only. This module never changes CharacterStats, Moodles, Nutrition,
-- health, sleep state, or GameTime. DiagnosticForcedCompressionFactor is owned
-- by the authoritative server controller, not by this sampler.

if not isClient() then return end

local SurvivalStatProbe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepSurvivalDiag][CLIENT]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local observedBaselineMinutesPerDay = nil
local capabilityLogged = false

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

local function derivePhase(player, minutesPerDay, baseline)
    if not player then return "no-player" end

    local asleep = SurvivalStatProbe.safeMethod(player, "isAsleep") == true
    if asleep and minutesPerDay and baseline and math.abs(minutesPerDay - baseline) < EPSILON then
        return "sleeping-at-baseline"
    end

    if not asleep
        and diagnosticForcedConfigured()
        and minutesPerDay and baseline
        and minutesPerDay < baseline - EPSILON then
        return "diagnostic-forced"
    end

    if minutesPerDay and baseline and minutesPerDay < baseline - EPSILON then return "partial" end
    return "baseline"
end

local function sample()
    if not diagnosticsEnabled() then return end

    local epoch = os.time()
    if lastSampleAt >= 0 and (epoch - lastSampleAt) < SAMPLE_INTERVAL_SECONDS then return end
    lastSampleAt = epoch

    local player = type(getPlayer) == "function" and getPlayer() or nil
    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    if not player or not gameTime then return end
    if SurvivalStatProbe.safeMethod(player, "isDead") == true then return end

    local minutesPerDay = SurvivalStatProbe.safeNumber(gameTime, "getMinutesPerDay")
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

    local playerName = SurvivalStatProbe.safeMethod(player, "getUsername")
        or SurvivalStatProbe.safeMethod(player, "getDisplayName")
        or "N/A"
    local onlineID = SurvivalStatProbe.safeNumber(player, "getOnlineID")

    if not capabilityLogged then
        capabilityLogged = true
        log("CAPABILITIES | player=" .. SurvivalStatProbe.sanitize(playerName)
            .. " | onlineID=" .. SurvivalStatProbe.formatValue(onlineID, 0)
            .. " | " .. SurvivalStatProbe.capabilitySummary(player))
    end

    local snapshot = SurvivalStatProbe.collect(player)
    local phase = derivePhase(player, minutesPerDay, baseline)

    log(string.format(
        "SURVIVAL | epoch=%d | phase=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | GameMultiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s | player=%s | onlineID=%s | asleep=%s | %s",
        epoch,
        phase,
        SurvivalStatProbe.formatValue(minutesPerDay),
        SurvivalStatProbe.formatValue(baseline),
        SurvivalStatProbe.formatValue(compression),
        SurvivalStatProbe.formatValue(SurvivalStatProbe.safeNumber(gameTime, "getTimeOfDay")),
        SurvivalStatProbe.formatValue(SurvivalStatProbe.safeNumber(gameTime, "getWorldAgeHours")),
        SurvivalStatProbe.formatValue(SurvivalStatProbe.safeNumber(gameTime, "getDeltaMinutesPerDay")),
        SurvivalStatProbe.formatValue(SurvivalStatProbe.safeNumber(gameTime, "getMultiplier")),
        SurvivalStatProbe.formatValue(SurvivalStatProbe.safeNumber(gameTime, "getTrueMultiplier")),
        SurvivalStatProbe.formatValue(SurvivalStatProbe.safeNumber(gameTime, "getServerMultiplier")),
        SurvivalStatProbe.sanitize(playerName),
        SurvivalStatProbe.formatValue(onlineID, 0),
        SurvivalStatProbe.formatValue(SurvivalStatProbe.safeMethod(player, "isAsleep")),
        SurvivalStatProbe.formatSnapshot(snapshot)
    ))
end

Events.OnTick.Add(sample)

log("Loaded Release Candidate v1.0.0 owning-client survival-stat diagnostic; telemetry is disabled unless DiagnosticsEnabled=true.")
