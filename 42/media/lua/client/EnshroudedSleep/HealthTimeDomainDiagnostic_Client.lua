-- Enshrouded Sleep - client health/time-domain diagnostic
-- v0.0.8 pre-Public-Alpha instrumentation for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Sample the local player's health, survival-stat, nutrition, sleep, and injury
-- state once per real second while diagnostics are enabled. This complements the
-- all-player server sampler because prior sleep testing showed that some useful
-- player timing values are more meaningful on the owning client.
--
-- This module is READ-ONLY and dormant unless the server administrator enables
-- EnshroudedSleep.DiagnosticsEnabled.

if not isClient() then return end

local PREFIX = "[EnshroudedSleepHealthDiag][CLIENT]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local observedBaselineMinutesPerDay = nil

local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
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

local function safeNumber(obj, methodName, ...)
    local value = safeMethod(obj, methodName, ...)
    return tonumber(value)
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
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then
        return
    end
    lastSampleAt = now

    if type(getPlayer) ~= "function" then return end
    local okPlayer, player = pcall(getPlayer)
    if not okPlayer or not player then return end

    local gt = getGameTime()
    if not gt then return end

    local minutesPerDay = safeNumber(gt, "getMinutesPerDay")
    local baseline = observeBaseline(minutesPerDay)
    local compression = nil
    if baseline and minutesPerDay and minutesPerDay > EPSILON then
        compression = baseline / minutesPerDay
    end

    local phase = "baseline-or-vanilla"
    if baseline and minutesPerDay and minutesPerDay < baseline - EPSILON then
        phase = "partial"
    end

    local playerName = safeMethod(player, "getUsername") or safeMethod(player, "getDisplayName") or "N/A"
    local onlineID = safeNumber(player, "getOnlineID")
    local stats = safeMethod(player, "getStats")
    local bodyDamage = safeMethod(player, "getBodyDamage")
    local nutrition = safeMethod(player, "getNutrition")

    log(string.format(
        "PLAYER | epoch=%d | phase=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | player=%s | onlineID=%s | asleep=%s | AsleepTime=%s | ForceWakeUpTime=%s | SleepingPillsTaken=%s | Health=%s | OverallBodyHealth=%s | HasInjury=%s | NumBleeding=%s | NumScratched=%s | NumBitten=%s | Hunger=%s | Thirst=%s | Fatigue=%s | Endurance=%s | Stress=%s | Panic=%s | Pain=%s | Boredom=%s | Unhappiness=%s | Sickness=%s | Drunkenness=%s | Fear=%s | Sanity=%s | FoodSickness=%s | Poison=%s | InfectionLevel=%s | ApparentInfectionLevel=%s | FakeInfectionLevel=%s | Infected=%s | Temperature=%s | Wetness=%s | CatchACold=%s | ColdStrength=%s | ColdDamageStage=%s | Weight=%s | Calories=%s | Carbohydrates=%s | Proteins=%s | Lipids=%s",
        now,
        phase,
        formatValue(minutesPerDay),
        formatValue(baseline),
        formatValue(compression),
        formatValue(safeNumber(gt, "getTimeOfDay")),
        formatValue(safeNumber(gt, "getWorldAgeHours")),
        sanitize(playerName),
        formatValue(onlineID, 0),
        formatValue(safeMethod(player, "isAsleep")),
        formatValue(safeNumber(player, "getAsleepTime")),
        formatValue(safeNumber(player, "getForceWakeUpTime")),
        formatValue(safeNumber(player, "getSleepingPillsTaken"), 0),
        formatValue(safeNumber(bodyDamage, "getHealth")),
        formatValue(safeNumber(bodyDamage, "getOverallBodyHealth")),
        formatValue(safeMethod(bodyDamage, "HasInjury")),
        formatValue(safeNumber(bodyDamage, "getNumPartsBleeding"), 0),
        formatValue(safeNumber(bodyDamage, "getNumPartsScratched"), 0),
        formatValue(safeNumber(bodyDamage, "getNumPartsBitten"), 0),
        formatValue(safeNumber(stats, "getHunger")),
        formatValue(safeNumber(stats, "getThirst")),
        formatValue(safeNumber(stats, "getFatigue")),
        formatValue(safeNumber(stats, "getEndurance")),
        formatValue(safeNumber(stats, "getStress")),
        formatValue(safeNumber(stats, "getPanic")),
        formatValue(safeNumber(stats, "getPain")),
        formatValue(safeNumber(stats, "getBoredom")),
        formatValue(safeNumber(bodyDamage, "getUnhappynessLevel")),
        formatValue(safeNumber(stats, "getSickness")),
        formatValue(safeNumber(stats, "getDrunkenness")),
        formatValue(safeNumber(stats, "getFear")),
        formatValue(safeNumber(stats, "getSanity")),
        formatValue(safeNumber(bodyDamage, "getFoodSicknessLevel")),
        formatValue(safeNumber(bodyDamage, "getPoisonLevel")),
        formatValue(safeNumber(bodyDamage, "getInfectionLevel")),
        formatValue(safeNumber(bodyDamage, "getApparentInfectionLevel")),
        formatValue(safeNumber(bodyDamage, "getFakeInfectionLevel")),
        formatValue(safeMethod(bodyDamage, "isInfected")),
        formatValue(safeNumber(bodyDamage, "getTemperature")),
        formatValue(safeNumber(bodyDamage, "getWetness")),
        formatValue(safeNumber(bodyDamage, "getCatchACold")),
        formatValue(safeNumber(bodyDamage, "getColdStrength")),
        formatValue(safeNumber(bodyDamage, "getColdDamageStage")),
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

log("Loaded v0.0.8 client health/time-domain diagnostic; telemetry is disabled unless DiagnosticsEnabled=true.")
