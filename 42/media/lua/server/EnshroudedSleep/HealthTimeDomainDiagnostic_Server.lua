-- Enshrouded Sleep - server health/time-domain diagnostic
-- v0.0.8 pre-Public-Alpha instrumentation for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Sample a broad set of player health, survival-stat, nutrition, sleep, and
-- injury variables once per real second so controlled tests can determine which
-- systems follow compressed world/calendar time and which remain tied to active
-- simulation/real time.
--
-- This module is READ-ONLY. It does not heal, injure, feed, fatigue, infect,
-- wake, sleep, or otherwise mutate a player. It is dormant unless the server
-- administrator explicitly sets EnshroudedSleep.DiagnosticsEnabled=true.

if isClient() then return end

local PREFIX = "[EnshroudedSleepHealthDiag][SERVER]"
local SAMPLE_INTERVAL_SECONDS = 1
local EPSILON = 0.0001
local lastSampleAt = -1
local observedBaselineMinutesPerDay = nil

---Return whether verbose support/experiment telemetry is enabled.
---@return boolean enabled
local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

---Write one namespaced diagnostic line.
---@param message any
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Safely invoke a Java/Lua method. Missing/unexposed APIs become nil rather than
---breaking the diagnostic or the game session.
---@param obj any
---@param methodName string
---@param ... any
---@return any|nil value
local function safeMethod(obj, methodName, ...)
    if not obj then return nil end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end

    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end

    return value
end

---Read and numerically convert exactly the first safeMethod return value.
---Keeping conversion separate avoids the Kahlua multi-return tonumber overload
---problem discovered during v0.0.6 testing.
---@param obj any
---@param methodName string
---@param ... any
---@return number|nil value
local function safeNumber(obj, methodName, ...)
    local value = safeMethod(obj, methodName, ...)
    return tonumber(value)
end

---Format values in stable key=value diagnostic output.
---@param value any
---@param decimals integer|nil
---@return string formattedValue
local function formatValue(value, decimals)
    if value == nil then return "N/A" end
    if type(value) == "number" then
        return string.format("%." .. tostring(decimals or 6) .. "f", value)
    end
    return tostring(value)
end

---Replace the log delimiter in free-text values so lines remain machine-parseable.
---@param value any
---@return string sanitized
local function sanitize(value)
    local text = tostring(value or "N/A")
    return string.gsub(text, "|", "/")
end

---Observe the largest valid MinutesPerDay value seen by this diagnostic as the
---native baseline. Enshrouded Sleep only shortens the day during partial sleep,
---so the largest observed value is a safe observational baseline estimate.
---@param current number|nil
---@return number|nil baseline
local function observeBaseline(current)
    if current and current > 0 then
        if not observedBaselineMinutesPerDay or current > observedBaselineMinutesPerDay then
            observedBaselineMinutesPerDay = current
        end
    end
    return observedBaselineMinutesPerDay
end

---Collect the instantiated living-player population and current vanilla sleep count.
---@return table players Lua array of living IsoPlayer objects.
---@return integer living
---@return integer sleeping
local function collectLivingPlayers()
    local result = {}
    if type(getOnlinePlayers) ~= "function" then return result, 0, 0 end

    local players = getOnlinePlayers()
    if not players then return result, 0, 0 end

    local size = safeNumber(players, "size")
    if not size then return result, 0, 0 end

    local sleeping = 0

    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if player then
            local dead = safeMethod(player, "isDead")
            if dead ~= true then
                result[#result + 1] = player
                if safeMethod(player, "isAsleep") == true then
                    sleeping = sleeping + 1
                end
            end
        end
    end

    return result, #result, sleeping
end

---Derive a descriptive experiment phase from the currently observed population.
---@param living integer
---@param sleeping integer
---@return string phase
local function derivePhase(living, sleeping)
    if living <= 0 or sleeping <= 0 then return "baseline" end
    if sleeping >= living then return "vanilla-full-sleep" end
    return "partial"
end

---Return true when a body part contains any injury/treatment state worth logging.
---Aggregate body temperature/wetness are already present in the PLAYER line, so
---BODY lines focus on injury/healing variables rather than every pristine limb.
---@param part any
---@return boolean interesting
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

---Log detailed injury/healing state for all non-pristine body parts.
---@param playerName string
---@param onlineID any
---@param bodyDamage any
---@param epoch integer
---@return nil
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
            if not partName then
                partName = safeMethod(part, "getType")
            end

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

---Log one broad health/survival snapshot for a living player.
---@param player any IsoPlayer
---@param epoch integer
---@param phase string
---@param living integer
---@param sleeping integer
---@param minutesPerDay number|nil
---@param baseline number|nil
---@param compression number|nil
---@param timeOfDay number|nil
---@param worldAgeHours number|nil
---@return nil
local function logPlayer(player, epoch, phase, living, sleeping, minutesPerDay, baseline, compression, timeOfDay, worldAgeHours)
    local playerName = safeMethod(player, "getUsername") or safeMethod(player, "getDisplayName") or "N/A"
    local onlineID = safeNumber(player, "getOnlineID")
    local stats = safeMethod(player, "getStats")
    local bodyDamage = safeMethod(player, "getBodyDamage")
    local nutrition = safeMethod(player, "getNutrition")
    local sleepFraction = living > 0 and (sleeping / living) or 0

    log(string.format(
        "PLAYER | epoch=%d | phase=%s | living=%d | sleeping=%d | SleepFraction=%s | MinutesPerDay=%s | BaselineMinutesPerDay=%s | CalendarCompressionFactor=%s | TimeOfDay=%s | WorldAgeHours=%s | player=%s | onlineID=%s | asleep=%s | AsleepTime=%s | ForceWakeUpTime=%s | SleepingPillsTaken=%s | Health=%s | OverallBodyHealth=%s | HasInjury=%s | NumBleeding=%s | NumScratched=%s | NumBitten=%s | Hunger=%s | Thirst=%s | Fatigue=%s | Endurance=%s | Stress=%s | Panic=%s | Pain=%s | Boredom=%s | Unhappiness=%s | Sickness=%s | Drunkenness=%s | Fear=%s | Sanity=%s | FoodSickness=%s | Poison=%s | InfectionLevel=%s | ApparentInfectionLevel=%s | FakeInfectionLevel=%s | Infected=%s | Temperature=%s | Wetness=%s | CatchACold=%s | ColdStrength=%s | ColdDamageStage=%s | Weight=%s | Calories=%s | Carbohydrates=%s | Proteins=%s | Lipids=%s",
        epoch,
        phase,
        living,
        sleeping,
        formatValue(sleepFraction),
        formatValue(minutesPerDay),
        formatValue(baseline),
        formatValue(compression),
        formatValue(timeOfDay),
        formatValue(worldAgeHours),
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

    logBodyParts(tostring(playerName), onlineID, bodyDamage, epoch)
end

---Sample all living players once per wall-clock second.
---@return nil
local function sampleHealthTimeDomains()
    if not diagnosticsEnabled() then return end

    local now = os.time()
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then
        return
    end
    lastSampleAt = now

    local gt = getGameTime()
    if not gt then return end

    local players, living, sleeping = collectLivingPlayers()
    if living <= 0 then return end

    local minutesPerDay = safeNumber(gt, "getMinutesPerDay")
    local baseline = observeBaseline(minutesPerDay)
    local compression = nil
    if baseline and minutesPerDay and minutesPerDay > EPSILON then
        compression = baseline / minutesPerDay
    end

    local phase = derivePhase(living, sleeping)
    local timeOfDay = safeNumber(gt, "getTimeOfDay")
    local worldAgeHours = safeNumber(gt, "getWorldAgeHours")

    for _, player in ipairs(players) do
        logPlayer(player, now, phase, living, sleeping, minutesPerDay, baseline, compression, timeOfDay, worldAgeHours)
    end
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleHealthTimeDomains)
else
    Events.OnTick.Add(sampleHealthTimeDomains)
end

log("Loaded v0.0.8 health/time-domain diagnostic; telemetry is disabled unless DiagnosticsEnabled=true.")
