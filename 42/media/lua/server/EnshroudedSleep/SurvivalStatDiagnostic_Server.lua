-- Enshrouded Sleep - focused server survival-stat diagnostic
-- v0.0.10 pre-Public-Alpha instrumentation for Project Zomboid Build 42.20+
--
-- Samples Build 42 CharacterStat, MoodleType, Nutrition, and related health
-- values needed to finish SPIKE-004. This diagnostic is server-side/read-only
-- and observes only instantiated players returned by getOnlinePlayers().

if isClient() then return end

local SurvivalStatProbe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepSurvivalDiag][SERVER]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local observedBaselineMinutesPerDay = nil
local capabilitiesLoggedFor = {}

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

local function addLivingPlayer(result, player)
    if not player then return 0 end
    if SurvivalStatProbe.safeMethod(player, "isDead") == true then return 0 end
    result[#result + 1] = player
    return SurvivalStatProbe.safeMethod(player, "isAsleep") == true and 1 or 0
end

local function collectLivingPlayers()
    local result = {}
    if type(getOnlinePlayers) ~= "function" then return result, 0, 0 end

    local players = getOnlinePlayers()
    local size = SurvivalStatProbe.safeNumber(players, "size")
    if not size then return result, 0, 0 end

    local sleeping = 0
    for i = 0, size - 1 do
        local player = SurvivalStatProbe.safeMethod(players, "get", i)
        sleeping = sleeping + addLivingPlayer(result, player)
    end

    return result, #result, sleeping
end

local function derivePhase(living, sleeping, minutesPerDay, baseline)
    if sleeping and sleeping > 0 then
        if living > 0 and sleeping >= living then return "vanilla-full-sleep" end
        return "partial"
    end

    if diagnosticForcedConfigured()
        and living == 1
        and sleeping == 0
        and baseline and minutesPerDay
        and minutesPerDay < baseline - EPSILON then
        return "diagnostic-forced"
    end

    return "baseline"
end

local function sample()
    if not diagnosticsEnabled() then return end

    local epoch = os.time()
    if lastSampleAt >= 0 and (epoch - lastSampleAt) < SAMPLE_INTERVAL_SECONDS then return end
    lastSampleAt = epoch

    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    if not gameTime then return end

    local minutesPerDay = SurvivalStatProbe.safeNumber(gameTime, "getMinutesPerDay")
    if minutesPerDay and minutesPerDay > 0 then
        if not observedBaselineMinutesPerDay or minutesPerDay > observedBaselineMinutesPerDay then
            observedBaselineMinutesPerDay = minutesPerDay
        end
    end

    local players, living, sleeping = collectLivingPlayers()
    if living <= 0 then return end

    local baseline = observedBaselineMinutesPerDay
    local compression = nil
    if minutesPerDay and minutesPerDay > 0 and baseline and baseline > 0 then
        compression = baseline / minutesPerDay
    end
    local phase = derivePhase(living, sleeping, minutesPerDay, baseline)

    local timeOfDay = SurvivalStatProbe.safeNumber(gameTime, "getTimeOfDay")
    local worldAgeHours = SurvivalStatProbe.safeNumber(gameTime, "getWorldAgeHours")
    local deltaMinutesPerDay = SurvivalStatProbe.safeNumber(gameTime, "getDeltaMinutesPerDay")
    local gameMultiplier = SurvivalStatProbe.safeNumber(gameTime, "getMultiplier")
    local trueMultiplier = SurvivalStatProbe.safeNumber(gameTime, "getTrueMultiplier")
    local serverMultiplier = SurvivalStatProbe.safeNumber(gameTime, "getServerMultiplier")

    for _, player in ipairs(players) do
        local playerName = SurvivalStatProbe.safeMethod(player, "getUsername")
            or SurvivalStatProbe.safeMethod(player, "getDisplayName")
            or "N/A"
        local onlineID = SurvivalStatProbe.safeNumber(player, "getOnlineID")
        local capabilityKey = tostring(onlineID or playerName)

        if not capabilitiesLoggedFor[capabilityKey] then
            capabilitiesLoggedFor[capabilityKey] = true
            log("CAPABILITIES | player=" .. SurvivalStatProbe.sanitize(playerName)
                .. " | onlineID=" .. SurvivalStatProbe.formatValue(onlineID, 0)
                .. " | " .. SurvivalStatProbe.capabilitySummary(player))
        end

        local snapshot = SurvivalStatProbe.collect(player)
        local sleepFraction = living > 0 and (sleeping / living) or 0

        log(string.format(
            "SURVIVAL | epoch=%d | phase=%s | living=%d | sleeping=%d | SleepFraction=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | GameMultiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s | player=%s | onlineID=%s | asleep=%s | %s",
            epoch,
            phase,
            living,
            sleeping,
            SurvivalStatProbe.formatValue(sleepFraction),
            SurvivalStatProbe.formatValue(minutesPerDay),
            SurvivalStatProbe.formatValue(baseline),
            SurvivalStatProbe.formatValue(compression),
            SurvivalStatProbe.formatValue(timeOfDay),
            SurvivalStatProbe.formatValue(worldAgeHours),
            SurvivalStatProbe.formatValue(deltaMinutesPerDay),
            SurvivalStatProbe.formatValue(gameMultiplier),
            SurvivalStatProbe.formatValue(trueMultiplier),
            SurvivalStatProbe.formatValue(serverMultiplier),
            SurvivalStatProbe.sanitize(playerName),
            SurvivalStatProbe.formatValue(onlineID, 0),
            SurvivalStatProbe.formatValue(SurvivalStatProbe.safeMethod(player, "isAsleep")),
            SurvivalStatProbe.formatSnapshot(snapshot)
        ))
    end
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sample)
else
    Events.OnTick.Add(sample)
end

log("Loaded v0.0.10 server survival-stat diagnostic; online server players only, dormant unless DiagnosticsEnabled=true.")
