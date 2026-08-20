-- Enshrouded Sleep - shared survival-stat diagnostic probe
-- Public Alpha v0.0.10 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Provide one guarded, read-only access layer for current Build 42 survival state
-- used by both the server and owning-client focused diagnostics.
--
-- API MODEL
-- ---------
-- Build 42.20.3 exposes important continuous survival values through registered
-- CharacterStat objects, for example:
--
--     player:getStats():get(CharacterStat.HUNGER)
--
-- Moodles are keyed by MoodleType objects, for example:
--
--     player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
--
-- The probe resolves those class globals defensively because Java/Javadoc
-- existence does not by itself guarantee identical Kahlua exposure in every
-- server/client context.
--
-- MUTATION BOUNDARY
-- -----------------
-- All Java/Kahlua bridge calls are guarded with pcall. This module never mutates
-- Stats, CharacterStats, Moodles, Nutrition, BodyDamage, player state, sleep
-- state, or world time. Missing bindings become nil/N/A diagnostic values.

local Probe = {}

-- Ordered descriptors keep server/client log schemas identical and make post-run
-- rate analysis deterministic. `id` is retained as the guarded getById fallback
-- where static CharacterStat field access is unavailable.
Probe.CharacterStats = {
    { output = "Hunger", key = "HUNGER", id = "Hunger" },
    { output = "Thirst", key = "THIRST", id = "Thirst" },
    { output = "Fatigue", key = "FATIGUE", id = "Fatigue" },
    { output = "Endurance", key = "ENDURANCE", id = "Endurance" },
    { output = "Fitness", key = "FITNESS", id = "Fitness" },
    { output = "Intoxication", key = "INTOXICATION", id = "Intoxication" },
    { output = "Anger", key = "ANGER", id = "Anger" },
    { output = "Pain", key = "PAIN", id = "Pain" },
    { output = "Panic", key = "PANIC", id = "Panic" },
    { output = "Morale", key = "MORALE", id = "Morale" },
    { output = "Stress", key = "STRESS", id = "Stress" },
    { output = "NicotineWithdrawal", key = "NICOTINE_WITHDRAWAL", id = "NicotineWithdrawal" },
    { output = "Boredom", key = "BOREDOM", id = "Boredom" },
    { output = "Idleness", key = "IDLENESS", id = "Idleness" },
    { output = "Unhappiness", key = "UNHAPPINESS", id = "Unhappiness" },
    { output = "Sanity", key = "SANITY", id = "Sanity" },
    { output = "Discomfort", key = "DISCOMFORT", id = "Discomfort" },
    { output = "WetnessStat", key = "WETNESS", id = "Wetness" },
    { output = "TemperatureStat", key = "TEMPERATURE", id = "Temperature" },
    { output = "Sickness", key = "SICKNESS", id = "Sickness" },
    { output = "ZombieInfectionStat", key = "ZOMBIE_INFECTION", id = "ZombieInfection" },
    { output = "ZombieFever", key = "ZOMBIE_FEVER", id = "ZombieFever" },
    { output = "FoodSicknessStat", key = "FOOD_SICKNESS", id = "FoodSickness" },
    { output = "PoisonStat", key = "POISON", id = "Poison" },
}

-- Moodle levels are ordinal corroboration, not substitutes for continuous
-- CharacterStat values. Names match the Build 42.20.3 MoodleType constants used
-- by the validated diagnostic run.
Probe.Moodles = {
    { output = "MoodleEndurance", key = "ENDURANCE" },
    { output = "MoodleTired", key = "TIRED" },
    { output = "MoodleHungry", key = "HUNGRY" },
    { output = "MoodlePanic", key = "PANIC" },
    { output = "MoodleSick", key = "SICK" },
    { output = "MoodleBored", key = "BORED" },
    { output = "MoodleUnhappy", key = "UNHAPPY" },
    { output = "MoodleBleeding", key = "BLEEDING" },
    { output = "MoodleWet", key = "WET" },
    { output = "MoodleHasACold", key = "HAS_A_COLD" },
    { output = "MoodleAngry", key = "ANGRY" },
    { output = "MoodleStress", key = "STRESS" },
    { output = "MoodleThirst", key = "THIRST" },
    { output = "MoodleInjured", key = "INJURED" },
    { output = "MoodlePain", key = "PAIN" },
    { output = "MoodleHeavyLoad", key = "HEAVY_LOAD" },
    { output = "MoodleDrunk", key = "DRUNK" },
    { output = "MoodleZombie", key = "ZOMBIE" },
    { output = "MoodleHyperthermia", key = "HYPERTHERMIA" },
    { output = "MoodleHypothermia", key = "HYPOTHERMIA" },
    { output = "MoodleWindchill", key = "WINDCHILL" },
    { output = "MoodleCantSprint", key = "CANT_SPRINT" },
    { output = "MoodleUncomfortable", key = "UNCOMFORTABLE" },
    { output = "MoodleNoxiousSmell", key = "NOXIOUS_SMELL" },
    { output = "MoodleFoodEaten", key = "FOOD_EATEN" },
}

-- Nutrition descriptors deliberately include both continuous stores and boolean
-- weight/fitness state so a single focused log record can be analyzed later.
Probe.Nutrition = {
    { output = "Weight", method = "getWeight", numeric = true },
    { output = "Calories", method = "getCalories", numeric = true },
    { output = "Carbohydrates", method = "getCarbohydrates", numeric = true },
    { output = "Proteins", method = "getProteins", numeric = true },
    { output = "Lipids", method = "getLipids", numeric = true },
    { output = "IncWeight", method = "isIncWeight", numeric = false },
    { output = "IncWeightLot", method = "isIncWeightLot", numeric = false },
    { output = "DecWeight", method = "isDecWeight", numeric = false },
    { output = "WeightTrouble", method = "characterHaveWeightTrouble", numeric = false },
    { output = "CanAddFitnessXp", method = "canAddFitnessXp", numeric = false },
}

---Safely invoke an instance method. Missing objects/methods/bridge calls return nil
---so callers can emit N/A rather than breaking a gameplay session.
---@param obj any
---@param methodName string
---@param ... any
---@return any|nil value
function Probe.safeMethod(obj, methodName, ...)
    if not obj then return nil end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end

    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

---Convert an already captured bridge result to a Lua number.
---Keeping bridge invocation and tonumber() in separate expressions preserves the
---fix for the Kahlua multi-return argument-propagation failure found in v0.0.6.
---@param value any
---@return number|nil numberValue
function Probe.toNumber(value)
    if value == nil then return nil end

    local direct = tonumber(value)
    if direct ~= nil then return direct end

    local okText, text = pcall(tostring, value)
    if not okText then return nil end
    return tonumber(text)
end

---Safely invoke a method and normalize its first returned value to number.
---@param obj any
---@param methodName string
---@param ... any
---@return number|nil value
function Probe.safeNumber(obj, methodName, ...)
    local value = Probe.safeMethod(obj, methodName, ...)
    return Probe.toNumber(value)
end

---Resolve the Java CharacterStat global defensively in the current Lua context.
---@return any|nil class
local function getCharacterStatClass()
    local ok, value = pcall(function() return CharacterStat end)
    if not ok then return nil end
    return value
end

---Resolve the Java MoodleType global defensively in the current Lua context.
---@return any|nil class
local function getMoodleTypeClass()
    local ok, value = pcall(function() return MoodleType end)
    if not ok then return nil end
    return value
end

---Resolve a CharacterStat constant. Static-field access is the primary path used
---by current vanilla Lua; getById() is a guarded secondary path for resilience.
---@param key string
---@param id string|nil
---@return any|nil stat
---@return string resolution
function Probe.resolveCharacterStat(key, id)
    local class = getCharacterStatClass()
    if not class then return nil, "CharacterStat-global-unavailable" end

    local okMember, member = pcall(function() return class[key] end)
    if okMember and member ~= nil then return member, "static:" .. tostring(key) end

    local okGetter, getter = pcall(function() return class.getById end)
    if okGetter and getter and id then
        local okValue, value = pcall(getter, id)
        if okValue and value ~= nil then return value, "getById:" .. tostring(id) end
    end

    return nil, "CharacterStat-member-unavailable:" .. tostring(key)
end

---Resolve a MoodleType constant from the current Lua-visible Java class.
---@param key string
---@return any|nil moodleType
---@return string resolution
function Probe.resolveMoodleType(key)
    local class = getMoodleTypeClass()
    if not class then return nil, "MoodleType-global-unavailable" end

    local okMember, member = pcall(function() return class[key] end)
    if okMember and member ~= nil then return member, "static:" .. tostring(key) end

    return nil, "MoodleType-member-unavailable:" .. tostring(key)
end

---Read all configured CharacterStat values plus selected non-CharacterStat Stats
---state from one player.
---@param player any
---@return table values
function Probe.readCharacterStats(player)
    local result = {}
    local stats = Probe.safeMethod(player, "getStats")

    for _, descriptor in ipairs(Probe.CharacterStats) do
        local stat = Probe.resolveCharacterStat(descriptor.key, descriptor.id)
        local value = stat and Probe.safeMethod(stats, "get", stat) or nil
        result[descriptor.output] = Probe.toNumber(value)
    end

    result.NicotineStress = Probe.safeNumber(stats, "getNicotineStress")
    result.LastEndurance = Probe.safeNumber(stats, "getLastEndurance")
    result.EnduranceWarning = Probe.safeNumber(stats, "getEnduranceWarning")
    result.EnduranceDangerWarning = Probe.safeNumber(stats, "getEnduranceDangerWarning")
    result.EnduranceRecharging = Probe.safeMethod(stats, "isEnduranceRecharging")

    return result
end

---Read all configured Moodle levels from one player.
---@param player any
---@return table values
function Probe.readMoodles(player)
    local result = {}
    local moodles = Probe.safeMethod(player, "getMoodles")

    for _, descriptor in ipairs(Probe.Moodles) do
        local moodleType = Probe.resolveMoodleType(descriptor.key)
        local value = moodleType and Probe.safeMethod(moodles, "getMoodleLevel", moodleType) or nil
        result[descriptor.output] = Probe.toNumber(value)
    end

    return result
end

---Read all configured Nutrition values from one player.
---@param player any
---@return table values
function Probe.readNutrition(player)
    local result = {}
    local nutrition = Probe.safeMethod(player, "getNutrition")

    for _, descriptor in ipairs(Probe.Nutrition) do
        local value = Probe.safeMethod(nutrition, descriptor.method)
        if descriptor.numeric then value = Probe.toNumber(value) end
        result[descriptor.output] = value
    end

    return result
end

---Read selected BodyDamage/auxiliary values useful when interpreting survival
---state alongside CharacterStats and Nutrition.
---@param player any
---@return table values
function Probe.readAuxiliary(player)
    local result = {}
    local bodyDamage = Probe.safeMethod(player, "getBodyDamage")

    result.HealthFromFoodTimer = Probe.safeNumber(bodyDamage, "getHealthFromFoodTimer")
    result.OverallBodyHealth = Probe.safeNumber(bodyDamage, "getOverallBodyHealth")
    result.BodyDamageWetness = Probe.safeNumber(bodyDamage, "getWetness")
    result.ColdStrength = Probe.safeNumber(bodyDamage, "getColdStrength")
    result.ColdDamageStage = Probe.safeNumber(bodyDamage, "getColdDamageStage")
    result.Infected = Probe.safeMethod(bodyDamage, "IsInfected")
    result.FakeInfected = Probe.safeMethod(bodyDamage, "IsFakeInfected")

    return result
end

---Collect one complete focused survival snapshot for a player.
---@param player any
---@return table snapshot
function Probe.collect(player)
    return {
        characterStats = Probe.readCharacterStats(player),
        moodles = Probe.readMoodles(player),
        nutrition = Probe.readNutrition(player),
        auxiliary = Probe.readAuxiliary(player),
    }
end

---Format a diagnostic value, preserving booleans/strings and rendering nil as N/A.
---@param value any
---@param decimals integer|nil
---@return string formatted
function Probe.formatValue(value, decimals)
    if value == nil then return "N/A" end
    if type(value) == "number" then
        return string.format("%." .. tostring(decimals or 6) .. "f", value)
    end
    return tostring(value)
end

---Remove the log field delimiter from arbitrary display values.
---@param value any
---@return string sanitized
function Probe.sanitize(value)
    local text = tostring(value or "N/A")
    return string.gsub(text, "|", "/")
end

---Append ordered descriptor values to a log-field array.
---@param parts table
---@param values table
---@param descriptors table
---@return nil
local function appendDescriptorFields(parts, values, descriptors)
    for _, descriptor in ipairs(descriptors) do
        parts[#parts + 1] = descriptor.output .. "=" .. Probe.formatValue(values[descriptor.output])
    end
end

---Serialize a focused snapshot into deterministic `key=value | ...` fields.
---@param snapshot table
---@return string formattedSnapshot
function Probe.formatSnapshot(snapshot)
    local parts = {}

    appendDescriptorFields(parts, snapshot.characterStats, Probe.CharacterStats)
    parts[#parts + 1] = "NicotineStress=" .. Probe.formatValue(snapshot.characterStats.NicotineStress)
    parts[#parts + 1] = "LastEndurance=" .. Probe.formatValue(snapshot.characterStats.LastEndurance)
    parts[#parts + 1] = "EnduranceWarning=" .. Probe.formatValue(snapshot.characterStats.EnduranceWarning)
    parts[#parts + 1] = "EnduranceDangerWarning=" .. Probe.formatValue(snapshot.characterStats.EnduranceDangerWarning)
    parts[#parts + 1] = "EnduranceRecharging=" .. Probe.formatValue(snapshot.characterStats.EnduranceRecharging)

    appendDescriptorFields(parts, snapshot.moodles, Probe.Moodles)
    appendDescriptorFields(parts, snapshot.nutrition, Probe.Nutrition)

    parts[#parts + 1] = "HealthFromFoodTimer=" .. Probe.formatValue(snapshot.auxiliary.HealthFromFoodTimer)
    parts[#parts + 1] = "OverallBodyHealth=" .. Probe.formatValue(snapshot.auxiliary.OverallBodyHealth)
    parts[#parts + 1] = "BodyDamageWetness=" .. Probe.formatValue(snapshot.auxiliary.BodyDamageWetness)
    parts[#parts + 1] = "ColdStrength=" .. Probe.formatValue(snapshot.auxiliary.ColdStrength)
    parts[#parts + 1] = "ColdDamageStage=" .. Probe.formatValue(snapshot.auxiliary.ColdDamageStage)
    parts[#parts + 1] = "Infected=" .. Probe.formatValue(snapshot.auxiliary.Infected)
    parts[#parts + 1] = "FakeInfected=" .. Probe.formatValue(snapshot.auxiliary.FakeInfected)

    return table.concat(parts, " | ")
end

---Return a compact one-time capability record for a live player. This makes N/A
---values actionable by showing whether class globals, enum members, Stats:get(),
---Moodles, or Nutrition are actually readable in the current Lua context.
---@param player any
---@return string summary
function Probe.capabilitySummary(player)
    local parts = {}
    local stats = Probe.safeMethod(player, "getStats")
    local moodles = Probe.safeMethod(player, "getMoodles")
    local nutrition = Probe.safeMethod(player, "getNutrition")

    local characterStatClass = getCharacterStatClass()
    local moodleTypeClass = getMoodleTypeClass()

    parts[#parts + 1] = "CharacterStatGlobal=" .. tostring(characterStatClass ~= nil)
    parts[#parts + 1] = "StatsObject=" .. tostring(stats ~= nil)

    local resolvedStats = 0
    local readableStats = 0
    for _, descriptor in ipairs(Probe.CharacterStats) do
        local stat = Probe.resolveCharacterStat(descriptor.key, descriptor.id)
        if stat then
            resolvedStats = resolvedStats + 1
            if Probe.toNumber(Probe.safeMethod(stats, "get", stat)) ~= nil then
                readableStats = readableStats + 1
            end
        end
    end
    parts[#parts + 1] = string.format("CharacterStatsResolved=%d/%d", resolvedStats, #Probe.CharacterStats)
    parts[#parts + 1] = string.format("CharacterStatsReadable=%d/%d", readableStats, #Probe.CharacterStats)

    parts[#parts + 1] = "MoodleTypeGlobal=" .. tostring(moodleTypeClass ~= nil)
    parts[#parts + 1] = "MoodlesObject=" .. tostring(moodles ~= nil)

    local resolvedMoodles = 0
    local readableMoodles = 0
    for _, descriptor in ipairs(Probe.Moodles) do
        local moodleType = Probe.resolveMoodleType(descriptor.key)
        if moodleType then
            resolvedMoodles = resolvedMoodles + 1
            if Probe.toNumber(Probe.safeMethod(moodles, "getMoodleLevel", moodleType)) ~= nil then
                readableMoodles = readableMoodles + 1
            end
        end
    end
    parts[#parts + 1] = string.format("MoodlesResolved=%d/%d", resolvedMoodles, #Probe.Moodles)
    parts[#parts + 1] = string.format("MoodlesReadable=%d/%d", readableMoodles, #Probe.Moodles)

    parts[#parts + 1] = "NutritionObject=" .. tostring(nutrition ~= nil)
    local readableNutrition = 0
    for _, descriptor in ipairs(Probe.Nutrition) do
        local value = Probe.safeMethod(nutrition, descriptor.method)
        if descriptor.numeric then value = Probe.toNumber(value) end
        if value ~= nil then readableNutrition = readableNutrition + 1 end
    end
    parts[#parts + 1] = string.format("NutritionReadable=%d/%d", readableNutrition, #Probe.Nutrition)

    return table.concat(parts, " | ")
end

return Probe
