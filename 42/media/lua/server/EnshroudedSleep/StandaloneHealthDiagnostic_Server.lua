-- Enshrouded Sleep - standalone/single-player health diagnostic bridge
-- v0.0.10 pre-Public-Alpha instrumentation for Project Zomboid Build 42.20+
--
-- The normal server diagnostic prefers getOnlinePlayers(). In standalone play
-- that collection may be absent/empty even though getPlayer() exposes the local
-- IsoPlayer. This bridge runs ONLY in that fallback case and emits the injury/
-- health fields needed for SPIKE-004. It is strictly read-only.

if isClient() then return end

local Probe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepStandaloneHealthDiag][SERVER]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local observedBaselineMinutesPerDay = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function enabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

local function forcedConfigured()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local factor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    return vars ~= nil and vars.DiagnosticsEnabled == true and factor > 1.0 + EPSILON
end

local function onlinePopulationExists()
    if type(getOnlinePlayers) ~= "function" then return false end
    local players = getOnlinePlayers()
    local size = Probe.safeNumber(players, "size")
    return size ~= nil and size > 0
end

local function getLocalLivingPlayer()
    if type(getPlayer) ~= "function" then return nil end
    local ok, player = pcall(getPlayer)
    if not ok or not player then return nil end
    if Probe.safeMethod(player, "isDead") == true then return nil end
    return player
end

local function bodyPartInteresting(part)
    if not part then return false end
    local health = Probe.safeNumber(part, "getHealth")
    if health and health < 99.999 then return true end
    if Probe.safeMethod(part, "HasInjury") == true then return true end
    if Probe.safeMethod(part, "bleeding") == true then return true end
    if Probe.safeMethod(part, "scratched") == true then return true end
    if Probe.safeMethod(part, "isCut") == true then return true end
    if Probe.safeMethod(part, "bitten") == true then return true end
    if Probe.safeMethod(part, "isDeepWounded") == true then return true end
    if Probe.safeMethod(part, "isBurnt") == true then return true end
    local fracture = Probe.safeNumber(part, "getFractureTime")
    return fracture ~= nil and fracture > 0
end

local function logBodyParts(playerName, onlineID, bodyDamage, epoch)
    local parts = Probe.safeMethod(bodyDamage, "getBodyParts")
    local size = Probe.safeNumber(parts, "size")
    if not size then return end

    for i = 0, size - 1 do
        local part = Probe.safeMethod(parts, "get", i)
        if bodyPartInteresting(part) then
            local partName = Probe.safeMethod(bodyDamage, "getBodyPartName", i)
                or Probe.safeMethod(part, "getType")
                or tostring(i)

            log(string.format(
                "BODY | epoch=%d | player=%s | onlineID=%s | part=%s | Health=%s | Bleeding=%s | BleedingTime=%s | Pain=%s | AdditionalPain=%s | Bandaged=%s | BandageLife=%s | Cut=%s | CutTime=%s | Scratched=%s | ScratchTime=%s | Bitten=%s | BiteTime=%s | DeepWound=%s | DeepWoundTime=%s | FractureTime=%s | Burnt=%s | BurnTime=%s | InfectedWound=%s | WoundInfectionLevel=%s",
                epoch,
                Probe.sanitize(playerName),
                Probe.formatValue(onlineID, 0),
                Probe.sanitize(partName),
                Probe.formatValue(Probe.safeNumber(part, "getHealth")),
                Probe.formatValue(Probe.safeMethod(part, "bleeding")),
                Probe.formatValue(Probe.safeNumber(part, "getBleedingTime")),
                Probe.formatValue(Probe.safeNumber(part, "getPain")),
                Probe.formatValue(Probe.safeNumber(part, "getAdditionalPain")),
                Probe.formatValue(Probe.safeMethod(part, "bandaged")),
                Probe.formatValue(Probe.safeNumber(part, "getBandageLife")),
                Probe.formatValue(Probe.safeMethod(part, "isCut")),
                Probe.formatValue(Probe.safeNumber(part, "getCutTime")),
                Probe.formatValue(Probe.safeMethod(part, "scratched")),
                Probe.formatValue(Probe.safeNumber(part, "getScratchTime")),
                Probe.formatValue(Probe.safeMethod(part, "bitten")),
                Probe.formatValue(Probe.safeNumber(part, "getBiteTime")),
                Probe.formatValue(Probe.safeMethod(part, "isDeepWounded")),
                Probe.formatValue(Probe.safeNumber(part, "getDeepWoundTime")),
                Probe.formatValue(Probe.safeNumber(part, "getFractureTime")),
                Probe.formatValue(Probe.safeMethod(part, "isBurnt")),
                Probe.formatValue(Probe.safeNumber(part, "getBurnTime")),
                Probe.formatValue(Probe.safeMethod(part, "isInfectedWound")),
                Probe.formatValue(Probe.safeNumber(part, "getWoundInfectionLevel"))
            ))
        end
    end
end

local function sample()
    if not enabled() then return end
    if onlinePopulationExists() then return end

    local epoch = os.time()
    if lastSampleAt >= 0 and (epoch - lastSampleAt) < SAMPLE_INTERVAL_SECONDS then return end
    lastSampleAt = epoch

    local player = getLocalLivingPlayer()
    if not player then return end

    local gt = type(getGameTime) == "function" and getGameTime() or nil
    if not gt then return end

    local minutesPerDay = Probe.safeNumber(gt, "getMinutesPerDay")
    if minutesPerDay and minutesPerDay > 0 then
        if not observedBaselineMinutesPerDay or minutesPerDay > observedBaselineMinutesPerDay then
            observedBaselineMinutesPerDay = minutesPerDay
        end
    end

    local baseline = observedBaselineMinutesPerDay
    local compression = baseline and minutesPerDay and minutesPerDay > 0 and (baseline / minutesPerDay) or nil
    local asleep = Probe.safeMethod(player, "isAsleep") == true
    local phase = "baseline"
    if asleep then
        phase = "vanilla-full-sleep"
    elseif forcedConfigured() and compression and compression > 1.0 + EPSILON then
        phase = "diagnostic-forced"
    end

    local bodyDamage = Probe.safeMethod(player, "getBodyDamage")
    local playerName = Probe.safeMethod(player, "getUsername")
        or Probe.safeMethod(player, "getDisplayName")
        or "N/A"
    local onlineID = Probe.safeNumber(player, "getOnlineID")

    log(string.format(
        "PLAYER | epoch=%d | phase=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | GameMultiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s | player=%s | onlineID=%s | asleep=%s | Health=%s | OverallBodyHealth=%s | HasInjury=%s | NumBleeding=%s | NumScratched=%s | NumBitten=%s",
        epoch,
        phase,
        Probe.formatValue(minutesPerDay),
        Probe.formatValue(baseline),
        Probe.formatValue(compression),
        Probe.formatValue(Probe.safeNumber(gt, "getTimeOfDay")),
        Probe.formatValue(Probe.safeNumber(gt, "getWorldAgeHours")),
        Probe.formatValue(Probe.safeNumber(gt, "getDeltaMinutesPerDay")),
        Probe.formatValue(Probe.safeNumber(gt, "getMultiplier")),
        Probe.formatValue(Probe.safeNumber(gt, "getTrueMultiplier")),
        Probe.formatValue(Probe.safeNumber(gt, "getServerMultiplier")),
        Probe.sanitize(playerName),
        Probe.formatValue(onlineID, 0),
        Probe.formatValue(asleep),
        Probe.formatValue(Probe.safeNumber(bodyDamage, "getHealth")),
        Probe.formatValue(Probe.safeNumber(bodyDamage, "getOverallBodyHealth")),
        Probe.formatValue(Probe.safeMethod(bodyDamage, "HasInjury")),
        Probe.formatValue(Probe.safeNumber(bodyDamage, "getNumPartsBleeding"), 0),
        Probe.formatValue(Probe.safeNumber(bodyDamage, "getNumPartsScratched"), 0),
        Probe.formatValue(Probe.safeNumber(bodyDamage, "getNumPartsBitten"), 0)
    ))

    logBodyParts(playerName, onlineID, bodyDamage, epoch)
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sample)
else
    Events.OnTick.Add(sample)
end

log("Loaded v0.0.10 standalone health diagnostic bridge; active only when DiagnosticsEnabled=true and no online-player collection is populated.")
