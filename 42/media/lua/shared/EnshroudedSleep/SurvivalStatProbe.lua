-- Enshrouded Sleep - shared survival-stat diagnostic probe
-- v0.0.10 pre-Public-Alpha instrumentation for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Provide one read-only, guarded access layer for Build 42 survival state used by
-- both the server and owning-client diagnostics.
--
-- Build 42.20.3 no longer exposes the important survival values as the legacy
-- Stats getters/fields used by earlier diagnostic builds. Current vanilla Lua
-- reads them through:
--
--     player:getStats():get(CharacterStat.HUNGER)
--
-- Moodles are likewise keyed by MoodleType objects and are read through:
--
--     player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
--
-- All Java/Kahlua bridge calls remain inside pcall. This module never mutates
-- Stats, Moodles, Nutrition, BodyDamage, player state, or world time.

local Probe = {}

-- Ordered descriptors keep server/client log schemas identical and make post-run
-- rate analysis deterministic.
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

-- These names match the Build 42.20.3 MoodleType static constants. Moodles are
-- intentionally kept as ordinal corroboration rather than treated as continuous
-- replacements for CharacterStat values.
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

-- Safely invoke an instance method. Returns nil when the object, method, or bridge
-- invocation is unavailable. Callers deliberately treat nil as N/A.
function Probe.safeMethod(obj, methodName, ...)
    if not obj then return nil end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end

    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

-- Convert a previously captured bridge result to a Lua number. Keeping the bridge
-- call and tonumber() in separate expressions avoids the Kahlua multi-return bug
-- that affected the v0.0.6 diagnostics.
function Probe.toNumber(value)
    if value == nil then return nil end

    local direct = tonumber(value)
    if direct ~= nil then return direct end

    local okText, text = pcall(tostring, value)
    if not okText then return nil end
    return tonumber(text)
end

function Probe.safeNumber(obj, methodName, ...)
    local value = Probe.safeMethod(obj, methodName, ...)
    return Probe.toNumber(value)
end

-- Read the Java class globals defensively. The decompiled 42.20.3 classes are
-- marked @UsedFromLua, but this diagnostic verifies actual runtime exposure rather
-- than assuming every server/client Kahlua context behaves identically.
local function getCharacterStatClass()
    local ok, value = pcall(function() return CharacterStat end)
    if not ok then return nil end
    return value
end

local function getMoodleTypeClass()
    local ok, value = pcall(function() return MoodleType end)
    if not ok then return nil end
    return value
end

-- Resolve a CharacterStat constant. Static-field access is the primary path used
-- by current vanilla Lua; getById() is a guarded secondary path for resilience.
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

function Probe.resolveMoodleType(key)
    local class = getMoodleTypeClass()
    if not class then return nil, "MoodleType-global-unavailable" end

    local okMember, member = pcall(function() return class[key] end)
    if okMember and member ~= nil then return member, "static:" .. tostring(key) end

    return nil, "MoodleType-member-unavailable:" .. tostring(key)
end

function Probe.readCharacterStats(player)
    local result = {}
    local stats = Probe.safeMethod(player, "getStats")

    for _, descriptor in ipairs(Probe.CharacterStats) do
        local stat = Probe.resolveCharacterStat(descriptor.key, descriptor.id)
        local value = stat and Probe.safeMethod(stats, "get", stat) or nil
        result[descriptor.output] = Probe.toNumber(value)
    end

    -- Extra Stats state that is not represented by CharacterStat itself.
    result.NicotineStress = Probe.safeNumber(stats, "getNicotineStress")
    result.LastEndurance = Probe.safeNumber(stats, "getLastEndurance")
    result.EnduranceWarning = Probe.safeNumber(stats, "getEnduranceWarning")
    result.EnduranceDangerWarning = Probe.safeNumber(stats, "getEnduranceDangerWarning")
    result.EnduranceRecharging = Probe.safeMethod(stats, "isEnduranceRecharging")

    return result
end

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

function Probe.readAuxiliary(player)
    local result = {}
    local bodyDamage = Probe.safeMethod(player, "getBodyDamage")

    -- Vanilla's current Stats/Body debug panel accesses this BodyDamage timer
    -- directly. It is useful when relating food intake to general-health effects.
    result.HealthFromFoodTimer = Probe.safeNumber(bodyDamage, "getHealthFromFoodTimer")
    result.OverallBodyHealth = Probe.safeNumber(bodyDamage, "getOverallBodyHealth")
    result.BodyDamageWetness = Probe.safeNumber(bodyDamage, "getWetness")
    result.ColdStrength = Probe.safeNumber(bodyDamage, "getColdStrength")
    result.ColdDamageStage = Probe.safeNumber(bodyDamage, "getColdDamageStage")
    result.Infected = Probe.safeMethod(bodyDamage, "IsInfected")
    result.FakeInfected = Probe.safeMethod(bodyDamage, "IsFakeInfected")

    return result
end

function Probe.collect(player)
    return {
        characterStats = Probe.readCharacterStats(player),
        moodles = Probe.readMoodles(player),
        nutrition = Probe.readNutrition(player),
        auxiliary = Probe.readAuxiliary(player),
    }
end

function Probe.formatValue(value, decimals)
    if value == nil then return "N/A" end
    if type(value) == "number" then
        return string.format("%." .. tostring(decimals or 6) .. "f", value)
    end
    return tostring(value)
end

function Probe.sanitize(value)
    local text = tostring(value or "N/A")
    return string.gsub(text, "|", "/")
end

local function appendDescriptorFields(parts, values, descriptors)
    for _, descriptor in ipairs(descriptors) do
        parts[#parts + 1] = descriptor.output .. "=" .. Probe.formatValue(values[descriptor.output])
    end
end

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

-- Return a compact capability record for the first live player observed by each
-- diagnostic side. This makes an N/A result actionable: the next log will show
-- whether class globals, enum members, get() calls, Moodles, or Nutrition failed.
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
