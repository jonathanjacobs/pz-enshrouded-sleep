-- Enshrouded Sleep - broad client health/time-domain diagnostic
-- Public Beta v0.1.1 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Sample the owning client's health, legacy survival probes, nutrition, sleep,
-- and detailed injured-body-part state once per real second while diagnostics are
-- enabled. This broad stream is retained because its BodyDamage/body-part
-- telemetry proved useful during SPIKE-004 and remains valuable for support.
--
-- v0.0.10 also includes SurvivalStatProbe.lua plus focused server/client
-- SurvivalStatDiagnostic modules. Those focused modules are the authoritative
-- current-Build-42 path for CharacterStat and Moodle values. Some legacy probes
-- in this broad sampler may legitimately remain N/A.
--
-- MUTATION BOUNDARY
-- -----------------
-- Read-only. Missing Java/Kahlua exposure is converted to N/A; diagnostic API
-- mismatches must never break or mutate the gameplay session.

if not isClient() then return end

local PREFIX = "[EnshroudedSleepHealthDiag][CLIENT]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local observedBaselineMinutesPerDay = nil

local TRACKED_MOODLES = {
    Hungry = true,
    Thirst = true,
    Tired = true,
    Endurance = true,
    Stress = true,
    Panic = true,
    Pain = true,
    Bored = true,
    Unhappy = true,
    Sick = true,
    Drunk = true,
    Bleeding = true,
    Injured = true,
    Wet = true,
    HasACold = true,
    Hyperthermia = true,
    Hypothermia = true,
    Zombie = true,
}

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

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function safeField(obj, fieldName)
    if not obj then return nil end
    local ok, value = pcall(function() return obj[fieldName] end)
    if not ok then return nil end
    return value
end

local function safeNumber(obj, methodName, ...)
    local value = safeMethod(obj, methodName, ...)
    return tonumber(value)
end

local function safeNumberProbe(obj, methodName, fieldNames)
    local value = safeNumber(obj, methodName)
    if value ~= nil then return value end
    if not fieldNames then return nil end
    for _, fieldName in ipairs(fieldNames) do
        local fieldValue = safeField(obj, fieldName)
        local numberValue = tonumber(fieldValue)
        if numberValue ~= nil then return numberValue end
    end
    return nil
end

local function safeValueProbe(obj, methodName, fieldNames)
    local value = safeMethod(obj, methodName)
    if value ~= nil then return value end
    if not fieldNames then return nil end
    for _, fieldName in ipairs(fieldNames) do
        local fieldValue = safeField(obj, fieldName)
        if fieldValue ~= nil then return fieldValue end
    end
    return nil
end

local function formatValue(value, decimals)
    if value == nil then return "N/A" end
    if type(value) == "number" then
        return string.format("%." .. tostring(decimals or 6) .. "f", value)
    end
    return tostring(value)
end

local function sanitize(value)
    local text = tostring(value or "N/A")
    return string.gsub(text, "|", "/")
end

local function observeBaseline(current)
    if current and current > 0 then
        if not observedBaselineMinutesPerDay or current > observedBaselineMinutesPerDay then
            observedBaselineMinutesPerDay = current
        end
    end
    return observedBaselineMinutesPerDay
end

local function canonicalMoodleName(moodleType)
    if not moodleType then return nil end
    local name = safeMethod(moodleType, "name")
    if name == nil then name = tostring(moodleType) end
    if name == nil then return nil end
    name = tostring(name)
    local tail = string.match(name, "([%w_]+)$")
    return tail or name
end

local function readMoodles(player)
    local tracked = {}
    local compact = {}
    local moodles = safeMethod(player, "getMoodles")
    if not moodles then return tracked, "N/A" end

    local count = safeNumber(moodles, "getNumMoodles")
    if count == nil then return tracked, "N/A" end

    for i = 0, count - 1 do
        local moodleType = safeMethod(moodles, "getMoodleType", i)
        local level = safeNumber(moodles, "getMoodleLevel", i)
        local name = canonicalMoodleName(moodleType)
        if name and level ~= nil then
            compact[#compact + 1] = sanitize(name) .. ":" .. formatValue(level, 0)
            if TRACKED_MOODLES[name] then tracked[name] = level end
        end
    end

    table.sort(compact)
    if #compact <= 0 then return tracked, "N/A" end
    return tracked, table.concat(compact, ",")
end

local function bodyPartIsInteresting(part)
    if not part then return false end
    local health = safeNumber(part, "getHealth")
    if health and health < 99.999 then return true end
    if safeMethod(part, "HasInjury") == true then return true end
    if safeMethod(part, "bleeding") == true then return true end
    if safeMethod(part, "scratched") == true then return true end
    if safeMethod(part, "isCut") == true then return true end
    if safeMethod(part, "bitten") == true then return true end
    if safeMethod(part, "isDeepWounded") == true then return true end
    if safeMethod(part, "stitched") == true then return true end
    if safeMethod(part, "isBurnt") == true then return true end
    if safeMethod(part, "isInfectedWound") == true then return true end
    if safeMethod(part, "haveGlass") == true then return true end
    if safeMethod(part, "haveBullet") == true then return true end
    local fractureTime = safeNumber(part, "getFractureTime")
    local woundInfection = safeNumber(part, "getWoundInfectionLevel")
    return (fractureTime and fractureTime > 0) or (woundInfection and woundInfection > 0) or false
end

local function logBodyParts(playerName, onlineID, bodyDamage, epoch)
    if not bodyDamage then return end
    local parts = safeMethod(bodyDamage, "getBodyParts")
    if not parts then return end
    local size = safeNumber(parts, "size")
    if not size then return end

    for i = 0, size - 1 do
        local part = safeMethod(parts, "get", i)
        if bodyPartIsInteresting(part) then
            local partName = safeMethod(bodyDamage, "getBodyPartName", i)
            if not partName then partName = safeMethod(part, "getType") end
            log(string.format(
                "BODY | epoch=%d | player=%s | onlineID=%s | part=%s | Health=%s | Pain=%s | AdditionalPain=%s | Bleeding=%s | BleedingTime=%s | BleedingStemmed=%s | Bandaged=%s | BandageLife=%s | BandageDirty=%s | Cut=%s | CutTime=%s | Scratched=%s | ScratchTime=%s | Bitten=%s | BiteTime=%s | DeepWound=%s | DeepWoundTime=%s | Stitched=%s | StitchTime=%s | FractureTime=%s | Splint=%s | SplintFactor=%s | Burnt=%s | BurnTime=%s | InfectedWound=%s | WoundInfectionLevel=%s | Glass=%s | Bullet=%s | Wetness=%s | SkinTemperature=%s | InnerTemperature=%s | Stiffness=%s",
                epoch,
                sanitize(playerName),
                formatValue(onlineID, 0),
                sanitize(partName),
                formatValue(safeNumber(part, "getHealth")),
                formatValue(safeNumber(part, "getPain")),
                formatValue(safeNumber(part, "getAdditionalPain")),
                formatValue(safeMethod(part, "bleeding")),
                formatValue(safeNumber(part, "getBleedingTime")),
                formatValue(safeMethod(part, "IsBleedingStemmed")),
                formatValue(safeMethod(part, "bandaged")),
                formatValue(safeNumber(part, "getBandageLife")),
                formatValue(safeMethod(part, "isBandageDirty")),
                formatValue(safeMethod(part, "isCut")),
                formatValue(safeNumber(part, "getCutTime")),
                formatValue(safeMethod(part, "scratched")),
                formatValue(safeNumber(part, "getScratchTime")),
                formatValue(safeMethod(part, "bitten")),
                formatValue(safeNumber(part, "getBiteTime")),
                formatValue(safeMethod(part, "isDeepWounded")),
                formatValue(safeNumber(part, "getDeepWoundTime")),
                formatValue(safeMethod(part, "stitched")),
                formatValue(safeNumber(part, "getStitchTime")),
                formatValue(safeNumber(part, "getFractureTime")),
                formatValue(safeMethod(part, "isSplint")),
                formatValue(safeNumber(part, "getSplintFactor")),
                formatValue(safeMethod(part, "isBurnt")),
                formatValue(safeNumber(part, "getBurnTime")),
                formatValue(safeMethod(part, "isInfectedWound")),
                formatValue(safeNumber(part, "getWoundInfectionLevel")),
                formatValue(safeMethod(part, "haveGlass")),
                formatValue(safeMethod(part, "haveBullet")),
                formatValue(safeNumber(part, "getWetness")),
                formatValue(safeNumber(part, "getSkinTemperature")),
                formatValue(safeNumber(part, "getInnerTemperature")),
                formatValue(safeNumber(part, "getStiffness"))
            ))
        end
    end
end

local function sampleHealthTimeDomains()
    if not diagnosticsEnabled() then return end
    local now = os.time()
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then return end
    lastSampleAt = now

    if type(getPlayer) ~= "function" then return end
    local okPlayer, player = pcall(getPlayer)
    if not okPlayer or not player then return end

    local gt = getGameTime()
    if not gt then return end

    local minutesPerDay = safeNumber(gt, "getMinutesPerDay")
    local baseline = observeBaseline(minutesPerDay)
    local compression = nil
    if baseline and minutesPerDay and minutesPerDay > EPSILON then compression = baseline / minutesPerDay end

    local asleep = safeMethod(player, "isAsleep")
    local phase = "baseline"
    if diagnosticForcedConfigured() then
        if asleep == true then
            phase = "diagnostic-forced-suspended-sleep"
        elseif baseline and minutesPerDay and minutesPerDay < baseline - EPSILON then
            phase = "diagnostic-forced"
        else
            phase = "diagnostic-forced-armed"
        end
    elseif baseline and minutesPerDay and minutesPerDay < baseline - EPSILON then
        phase = "partial"
    elseif asleep == true then
        phase = "vanilla-full-sleep-local"
    end

    local playerName = safeMethod(player, "getUsername") or safeMethod(player, "getDisplayName") or "N/A"
    local onlineID = safeNumber(player, "getOnlineID")
    local stats = safeMethod(player, "getStats")
    local bodyDamage = safeMethod(player, "getBodyDamage")
    local nutrition = safeMethod(player, "getNutrition")
    local moodles, moodleSummary = readMoodles(player)

    local hunger = safeNumberProbe(stats, "getHunger", { "hunger" })
    local thirst = safeNumberProbe(stats, "getThirst", { "thirst" })
    local fatigue = safeNumberProbe(stats, "getFatigue", { "fatigue" })
    local endurance = safeNumberProbe(stats, "getEndurance", { "endurance" })
    local stress = safeNumberProbe(stats, "getStress", { "stress" })
    local panic = safeNumberProbe(stats, "getPanic", { "Panic" })
    local pain = safeNumberProbe(stats, "getPain", { "Pain" })
    local boredom = safeNumberProbe(stats, "getBoredom", { "boredom", "Boredom" })
    if boredom == nil then boredom = safeNumberProbe(bodyDamage, "getBoredomLevel", { "BoredomLevel" }) end
    local sickness = safeNumberProbe(stats, "getSickness", { "Sickness" })
    local drunkenness = safeNumberProbe(stats, "getDrunkenness", { "Drunkenness" })
    local fear = safeNumberProbe(stats, "getFear", { "Fear" })
    local sanity = safeNumberProbe(stats, "getSanity", { "Sanity" })

    log(string.format(
        "PLAYER | epoch=%d | phase=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | GameMultiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s | player=%s | onlineID=%s | asleep=%s | AsleepTime=%s | ForceWakeUpTime=%s | SleepingPillsTaken=%s | Health=%s | OverallBodyHealth=%s | HasInjury=%s | NumBleeding=%s | NumScratched=%s | NumBitten=%s | Hunger=%s | Thirst=%s | Fatigue=%s | Endurance=%s | Stress=%s | Panic=%s | Pain=%s | Boredom=%s | Unhappiness=%s | Sickness=%s | Drunkenness=%s | Fear=%s | Sanity=%s | FoodSickness=%s | Poison=%s | InfectionLevel=%s | ApparentInfectionLevel=%s | FakeInfectionLevel=%s | Infected=%s | Temperature=%s | Wetness=%s | CatchACold=%s | ColdStrength=%s | ColdDamageStage=%s | MoodleHungry=%s | MoodleThirst=%s | MoodleTired=%s | MoodleEndurance=%s | MoodleStress=%s | MoodlePanic=%s | MoodlePain=%s | MoodleBored=%s | MoodleUnhappy=%s | MoodleSick=%s | MoodleDrunk=%s | MoodleBleeding=%s | MoodleInjured=%s | MoodleWet=%s | MoodleHasACold=%s | MoodleHyperthermia=%s | MoodleHypothermia=%s | MoodleZombie=%s | Moodles=%s | Weight=%s | Calories=%s | Carbohydrates=%s | Proteins=%s | Lipids=%s",
        now,
        phase,
        formatValue(minutesPerDay),
        formatValue(baseline),
        formatValue(compression),
        formatValue(safeNumber(gt, "getTimeOfDay")),
        formatValue(safeNumber(gt, "getWorldAgeHours")),
        formatValue(safeNumber(gt, "getDeltaMinutesPerDay")),
        formatValue(safeNumber(gt, "getMultiplier")),
        formatValue(safeNumber(gt, "getTrueMultiplier")),
        formatValue(safeNumber(gt, "getServerMultiplier")),
        sanitize(playerName),
        formatValue(onlineID, 0),
        formatValue(asleep),
        formatValue(safeNumber(player, "getAsleepTime")),
        formatValue(safeNumber(player, "getForceWakeUpTime")),
        formatValue(safeNumber(player, "getSleepingPillsTaken"), 0),
        formatValue(safeNumberProbe(bodyDamage, "getHealth", { "OverallBodyHealth" })),
        formatValue(safeNumberProbe(bodyDamage, "getOverallBodyHealth", { "OverallBodyHealth" })),
        formatValue(safeMethod(bodyDamage, "HasInjury")),
        formatValue(safeNumber(bodyDamage, "getNumPartsBleeding"), 0),
        formatValue(safeNumber(bodyDamage, "getNumPartsScratched"), 0),
        formatValue(safeNumber(bodyDamage, "getNumPartsBitten"), 0),
        formatValue(hunger),
        formatValue(thirst),
        formatValue(fatigue),
        formatValue(endurance),
        formatValue(stress),
        formatValue(panic),
        formatValue(pain),
        formatValue(boredom),
        formatValue(safeNumberProbe(bodyDamage, "getUnhappynessLevel", { "UnhappynessLevel" })),
        formatValue(sickness),
        formatValue(drunkenness),
        formatValue(fear),
        formatValue(sanity),
        formatValue(safeNumber(bodyDamage, "getFoodSicknessLevel")),
        formatValue(safeNumber(bodyDamage, "getPoisonLevel")),
        formatValue(safeNumberProbe(bodyDamage, "getInfectionLevel", { "InfectionLevel" })),
        formatValue(safeNumber(bodyDamage, "getApparentInfectionLevel")),
        formatValue(safeNumberProbe(bodyDamage, "getFakeInfectionLevel", { "FakeInfectionLevel" })),
        formatValue(safeValueProbe(bodyDamage, "isInfected", { "IsInfected" })),
        formatValue(safeNumber(bodyDamage, "getTemperature")),
        formatValue(safeNumberProbe(bodyDamage, "getWetness", { "Wetness" })),
        formatValue(safeNumberProbe(bodyDamage, "getCatchACold", { "CatchACold" })),
        formatValue(safeNumberProbe(bodyDamage, "getColdStrength", { "ColdStrength" })),
        formatValue(safeNumberProbe(bodyDamage, "getColdDamageStage", { "ColdDamageStage" })),
        formatValue(moodles.Hungry, 0),
        formatValue(moodles.Thirst, 0),
        formatValue(moodles.Tired, 0),
        formatValue(moodles.Endurance, 0),
        formatValue(moodles.Stress, 0),
        formatValue(moodles.Panic, 0),
        formatValue(moodles.Pain, 0),
        formatValue(moodles.Bored, 0),
        formatValue(moodles.Unhappy, 0),
        formatValue(moodles.Sick, 0),
        formatValue(moodles.Drunk, 0),
        formatValue(moodles.Bleeding, 0),
        formatValue(moodles.Injured, 0),
        formatValue(moodles.Wet, 0),
        formatValue(moodles.HasACold, 0),
        formatValue(moodles.Hyperthermia, 0),
        formatValue(moodles.Hypothermia, 0),
        formatValue(moodles.Zombie, 0),
        sanitize(moodleSummary),
        formatValue(safeNumber(nutrition, "getWeight")),
        formatValue(safeNumber(nutrition, "getCalories")),
        formatValue(safeNumber(nutrition, "getCarbohydrates")),
        formatValue(safeNumber(nutrition, "getProteins")),
        formatValue(safeNumber(nutrition, "getLipids"))
    ))

    logBodyParts(tostring(playerName), onlineID, bodyDamage, now)
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleHealthTimeDomains)
else
    Events.OnTick.Add(sampleHealthTimeDomains)
end

log("Loaded Public Beta v0.1.1 broad client health/time-domain diagnostic; telemetry is disabled unless DiagnosticsEnabled=true.")
