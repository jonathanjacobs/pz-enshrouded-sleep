-- Enshrouded Sleep - focused owning-client survival-stat diagnostic
-- Public Alpha v0.0.10 for Project Zomboid Build 42.20+
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

---Return whether verbose support diagnostics are explicitly enabled.
---@return boolean enabled
local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

---Return whether the diagnostics-only forced compression control is armed.
---This is used only to label telemetry; the client never applies test policy.
---@return boolean configured
local function diagnosticForcedConfigured()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local factor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    return vars ~= nil and vars.DiagnosticsEnabled == true and factor > 1.0 + EPSILON
end

---Write one namespaced focused-survival diagnostic line.
---@param message any
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Derive a diagnostic phase label from local sleep state and observed day length.
---The label is descriptive only; it does not drive clock or sleep behavior.
---@param player any
---@param minutesPerDay number|nil
---@param baseline number|nil
---@return string phase
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

---Capture one wall-clock-gated local survival-state sample.
---@return nil
local function sample()
    if not diagnosticsEnabled() then return end

    local epoch = os.time()
    -- Use real wall-clock seconds so calendar compression cannot accelerate the
    -- diagnostic sampling cadence itself.
    if lastSampleAt >= 0 and (epoch - lastSampleAt) < SAMPLE_INTERVAL_SECONDS then return end
    lastSampleAt = epoch

    local player = type(getPlayer) == "function" and getPlayer() or nil
    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    if not player or not gameTime then return end
    if SurvivalStatProbe.safeMethod(player, "isDead") == true then return end

    -- The highest valid local MinutesPerDay seen by this sampler is retained as
    -- its observational baseline. This value is never written back to GameTime.
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

    -- Emit capability information once per client session so unavailable Build 42
    -- bindings can be distinguished from a metric that simply did not change.
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

log("Loaded Public Alpha v0.0.10 owning-client survival-stat diagnostic; telemetry is disabled unless DiagnosticsEnabled=true.")
