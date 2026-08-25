-- Enshrouded Sleep - SPIKE-006 diagnostics-only awake-player protection prototype
-- Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Test whether server-authoritative post-update normalization can remove the
-- extra world-time progression imposed on an awake player by MinutesPerDay
-- compression without changing the global simulation multiplier.
--
-- SAFETY BOUNDARY
-- ---------------
-- This file is a development spike, not production behavior. It mutates player
-- state ONLY when all of the following are true:
--   * DiagnosticsEnabled=true
--   * DiagnosticAwakeProtectionPrototype=true
--   * DiagnosticForcedCompressionFactor>1
--   * exactly one living multiplayer-server player exists
--   * that player is awake
--   * a native baseline MinutesPerDay was observed first at forced factor 1
--
-- The prototype never modifies sleeping players, GameTime, world objects, or
-- vanilla simulation speed. If any required binding/read/write is unavailable,
-- it fails open and leaves vanilla progression untouched.
--
-- IMPLEMENTATION NOTE
-- -------------------
-- B42.20.3 drives awake hunger/thirst/fatigue from getDeltaMinutesPerDay(), and
-- Nutrition from getGameWorldSecondsSinceLastUpdate(). Ordinary Workshop Lua
-- cannot directly write the Java ZomboidGlobals static fields used by the
-- character update. This spike therefore measures a post-update correction path.
--
-- The first dedicated-server SPIKE-006 run showed that Events.OnPlayerUpdate
-- did not fire for this server-side module. This revision uses Events.OnTick,
-- a callback already demonstrated to run on the dedicated server by the other
-- Enshrouded Sleep diagnostics. Successive tick snapshots bracket vanilla
-- changes even if this callback runs before the Java character update in a
-- particular frame.
--
-- The second controlled run demonstrated approximately 1x passive awake-player
-- progression while world/calendar time ran at approximately 20x. This version
-- keeps the same correction algorithm but narrows the per-tick read path to the
-- eight protected fields instead of collecting the full SurvivalStatProbe
-- snapshot (24 CharacterStats, Moodles, BodyDamage, and auxiliary telemetry).
--
-- The correction is deliberately directional:
--   hunger/thirst/fatigue: scale only increases (worsening)
--   calories/macros:       scale only decreases (passive depletion)
--   weight:                scale either direction
--
-- Opposite-direction changes are accepted in full so eating/drinking can be
-- exercised in later validation. This is still not source-specific enough for
-- production until active-effect regressions are tested.

if isClient() then return end

local Probe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepAwakeProtect][SERVER]"
local EPSILON = 0.0000001
local LOG_INTERVAL_SECONDS = 1
local HEARTBEAT_INTERVAL_SECONDS = 30

local baselineMinutesPerDay = nil
local previousByPlayer = {}
local lastLogAt = -1
local lastHeartbeatAt = -1
local lastStatus = nil
local tickCalls = 0

-- Resolve only the three CharacterStat objects used by the correction loop.
-- Resolution is lazy because Java/Kahlua class exposure is runtime-dependent.
local protectedCharacterStats = {
    Hunger = { key = "HUNGER", id = "Hunger", stat = nil },
    Thirst = { key = "THIRST", id = "Thirst", stat = nil },
    Fatigue = { key = "FATIGUE", id = "Fatigue", stat = nil },
}

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function logStatusOnce(status)
    if status == lastStatus then return end
    lastStatus = status
    log("STATUS | " .. tostring(status))
end

local function getConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return {
        diagnosticsEnabled = vars ~= nil and vars.DiagnosticsEnabled == true,
        prototypeEnabled = vars ~= nil and vars.DiagnosticAwakeProtectionPrototype == true,
        forcedFactor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0,
    }
end

local function safeCall(obj, methodName, ...)
    if not obj then return false, nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return false, nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return false, nil end
    return true, value
end

local function collectLivingPlayers()
    local result = {}
    local sleeping = 0

    if type(getOnlinePlayers) ~= "function" then
        return result, 0, 0
    end

    local players = getOnlinePlayers()
    local size = Probe.safeNumber(players, "size")
    if not size then return result, 0, 0 end

    for i = 0, size - 1 do
        local player = Probe.safeMethod(players, "get", i)
        if player and Probe.safeMethod(player, "isDead") ~= true then
            result[#result + 1] = player
            if Probe.safeMethod(player, "isAsleep") == true then
                sleeping = sleeping + 1
            end
        end
    end

    return result, #result, sleeping
end

local function playerKey(player)
    local onlineID = Probe.safeNumber(player, "getOnlineID")
    if onlineID ~= nil then return "id:" .. tostring(onlineID) end

    local username = Probe.safeMethod(player, "getUsername")
    if username ~= nil then return "user:" .. tostring(username) end

    return tostring(player)
end

local function captureBaselineIfSafe(config, minutesPerDay)
    if not minutesPerDay or minutesPerDay <= 0 then return end

    -- A forced factor of 1 is the controlled/native phase. Only that phase may
    -- establish the first baseline, preventing a module loaded during forced
    -- compression from mistaking a compressed day length for native time.
    if config.forcedFactor <= 1.0 + EPSILON then
        if baselineMinutesPerDay == nil or minutesPerDay > baselineMinutesPerDay then
            baselineMinutesPerDay = minutesPerDay
            log("BASELINE | MinutesPerDay=" .. Probe.formatValue(baselineMinutesPerDay))
        end
    end
end

local function resolveProtectedCharacterStat(name)
    local descriptor = protectedCharacterStats[name]
    if not descriptor then return nil end
    if descriptor.stat == nil then
        descriptor.stat = Probe.resolveCharacterStat(descriptor.key, descriptor.id)
    end
    return descriptor.stat
end

-- Hot-path reader: intentionally reads only the eight values SPIKE-006 may
-- correct. Do not call Probe.collect() here; its broad diagnostic snapshot is
-- useful once per second but unnecessarily expensive at server tick cadence.
local function readProtectedState(player)
    local stats = Probe.safeMethod(player, "getStats")
    local nutrition = Probe.safeMethod(player, "getNutrition")

    local function readStat(name)
        local stat = resolveProtectedCharacterStat(name)
        if not stats or not stat then return nil end
        return Probe.toNumber(Probe.safeMethod(stats, "get", stat))
    end

    return {
        Hunger = readStat("Hunger"),
        Thirst = readStat("Thirst"),
        Fatigue = readStat("Fatigue"),
        Calories = Probe.safeNumber(nutrition, "getCalories"),
        Carbohydrates = Probe.safeNumber(nutrition, "getCarbohydrates"),
        Proteins = Probe.safeNumber(nutrition, "getProteins"),
        Lipids = Probe.safeNumber(nutrition, "getLipids"),
        Weight = Probe.safeNumber(nutrition, "getWeight"),
    }
end

local function writeCharacterStat(player, name, value)
    if value == nil then return false end
    local stats = Probe.safeMethod(player, "getStats")
    local stat = resolveProtectedCharacterStat(name)
    if not stats or not stat then return false end
    local ok = safeCall(stats, "set", stat, value)
    return ok == true
end

local function writeNutrition(player, methodName, value)
    if value == nil then return false end
    local nutrition = Probe.safeMethod(player, "getNutrition")
    if not nutrition then return false end
    local ok = safeCall(nutrition, methodName, value)
    return ok == true
end

local function retainFraction(previous, current, compression, direction)
    if previous == nil or current == nil then
        return current, false
    end

    local delta = current - previous
    if direction == "positive" then
        if delta <= EPSILON then return current, false end
    elseif direction == "negative" then
        if delta >= -EPSILON then return current, false end
    elseif direction == "either" then
        if math.abs(delta) <= EPSILON then return current, false end
    else
        return current, false
    end

    return previous + (delta / compression), true
end

local function applyCorrection(player, previous, before, compression)
    local corrected = {}
    local changed = false
    local writeFailure = false

    corrected.Hunger, changed = retainFraction(previous.Hunger, before.Hunger, compression, "positive")
    if changed and not writeCharacterStat(player, "Hunger", corrected.Hunger) then
        writeFailure = true
    end

    corrected.Thirst, changed = retainFraction(previous.Thirst, before.Thirst, compression, "positive")
    if changed and not writeCharacterStat(player, "Thirst", corrected.Thirst) then
        writeFailure = true
    end

    corrected.Fatigue, changed = retainFraction(previous.Fatigue, before.Fatigue, compression, "positive")
    if changed and not writeCharacterStat(player, "Fatigue", corrected.Fatigue) then
        writeFailure = true
    end

    corrected.Calories, changed = retainFraction(previous.Calories, before.Calories, compression, "negative")
    if changed and not writeNutrition(player, "setCalories", corrected.Calories) then
        writeFailure = true
    end

    corrected.Carbohydrates, changed = retainFraction(previous.Carbohydrates, before.Carbohydrates, compression, "negative")
    if changed and not writeNutrition(player, "setCarbohydrates", corrected.Carbohydrates) then
        writeFailure = true
    end

    corrected.Proteins, changed = retainFraction(previous.Proteins, before.Proteins, compression, "negative")
    if changed and not writeNutrition(player, "setProteins", corrected.Proteins) then
        writeFailure = true
    end

    corrected.Lipids, changed = retainFraction(previous.Lipids, before.Lipids, compression, "negative")
    if changed and not writeNutrition(player, "setLipids", corrected.Lipids) then
        writeFailure = true
    end

    corrected.Weight, changed = retainFraction(previous.Weight, before.Weight, compression, "either")
    if changed and not writeNutrition(player, "setWeight", corrected.Weight) then
        writeFailure = true
    end

    if writeFailure then
        return false
    end
    return true
end

local function formatState(prefix, state)
    if not state then return prefix .. "=N/A" end
    local fields = {
        "Hunger", "Thirst", "Fatigue",
        "Calories", "Carbohydrates", "Proteins", "Lipids", "Weight",
    }
    local parts = {}
    for _, field in ipairs(fields) do
        parts[#parts + 1] = prefix .. field .. "=" .. Probe.formatValue(state[field], field == "Weight" and 8 or 6)
    end
    return table.concat(parts, " | ")
end

local function clearPrototypeState(reason)
    previousByPlayer = {}
    if reason then logStatusOnce(reason) end
end

local function maybeHeartbeat(config, minutesPerDay, living, sleeping)
    if not config.diagnosticsEnabled then return end

    local now = os.time()
    if lastHeartbeatAt >= 0 and now - lastHeartbeatAt < HEARTBEAT_INTERVAL_SECONDS then
        return
    end
    lastHeartbeatAt = now

    log(
        "HEARTBEAT | epoch=" .. tostring(now)
        .. " | tickCalls=" .. tostring(tickCalls)
        .. " | prototypeEnabled=" .. tostring(config.prototypeEnabled)
        .. " | forcedFactor=" .. Probe.formatValue(config.forcedFactor)
        .. " | living=" .. tostring(living)
        .. " | sleeping=" .. tostring(sleeping)
        .. " | MinutesPerDay=" .. Probe.formatValue(minutesPerDay)
        .. " | BaselineMinutesPerDay=" .. Probe.formatValue(baselineMinutesPerDay)
    )
end

local function onTick()
    tickCalls = tickCalls + 1

    local config = getConfig()
    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    local minutesPerDay = Probe.safeNumber(gameTime, "getMinutesPerDay")
    local players, living, sleeping = collectLivingPlayers()

    captureBaselineIfSafe(config, minutesPerDay)
    maybeHeartbeat(config, minutesPerDay, living, sleeping)

    if not config.diagnosticsEnabled or not config.prototypeEnabled then
        clearPrototypeState("prototype-inactive")
        return
    end

    if config.forcedFactor <= 1.0 + EPSILON then
        if living == 1 and sleeping == 0 and #players == 1 then
            local player = players[1]
            previousByPlayer[playerKey(player)] = readProtectedState(player)
            logStatusOnce("prototype-armed-at-baseline")
        else
            clearPrototypeState(
                "awaiting-baseline-player living=" .. tostring(living)
                .. " sleeping=" .. tostring(sleeping)
            )
        end
        return
    end

    if baselineMinutesPerDay == nil then
        clearPrototypeState("awaiting-baseline-factor-1-phase")
        return
    end

    if living ~= 1 or sleeping ~= 0 or #players ~= 1 then
        clearPrototypeState("suspended-population living=" .. tostring(living) .. " sleeping=" .. tostring(sleeping))
        return
    end

    local player = players[1]
    if Probe.safeMethod(player, "isAsleep") == true or Probe.safeMethod(player, "isDead") == true then
        clearPrototypeState("suspended-player-state")
        return
    end

    if not minutesPerDay or minutesPerDay <= 0 then
        clearPrototypeState("suspended-invalid-MinutesPerDay")
        return
    end

    local compression = baselineMinutesPerDay / minutesPerDay
    if compression <= 1.0 + EPSILON then
        previousByPlayer[playerKey(player)] = readProtectedState(player)
        logStatusOnce("waiting-for-compressed-MinutesPerDay")
        return
    end

    -- Guard against accidentally normalizing an unrelated time change. The
    -- observed compression should approximately match the explicitly armed
    -- diagnostic forced factor.
    local tolerance = math.max(0.05, config.forcedFactor * 0.02)
    if math.abs(compression - config.forcedFactor) > tolerance then
        clearPrototypeState(
            "suspended-factor-mismatch observed=" .. Probe.formatValue(compression)
            .. " configured=" .. Probe.formatValue(config.forcedFactor)
        )
        return
    end

    local key = playerKey(player)
    local before = readProtectedState(player)
    local previous = previousByPlayer[key]

    if not previous then
        previousByPlayer[key] = before
        logStatusOnce("prototype-active-initializing-snapshot")
        return
    end

    local ok = applyCorrection(player, previous, before, compression)
    if not ok then
        -- Fail open. Clear the previous reference so a transient bridge failure
        -- does not cause a large catch-up correction on a later tick.
        previousByPlayer[key] = nil
        logStatusOnce("write-failure-fail-open")
        return
    end

    local after = readProtectedState(player)
    previousByPlayer[key] = after
    logStatusOnce("prototype-active")

    local now = os.time()
    if lastLogAt < 0 or now - lastLogAt >= LOG_INTERVAL_SECONDS then
        lastLogAt = now
        local name = Probe.safeMethod(player, "getUsername") or "N/A"
        log(
            "CORRECTION | epoch=" .. tostring(now)
            .. " | player=" .. Probe.sanitize(name)
            .. " | configuredFactor=" .. Probe.formatValue(config.forcedFactor)
            .. " | observedFactor=" .. Probe.formatValue(compression)
            .. " | MinutesPerDay=" .. Probe.formatValue(minutesPerDay)
            .. " | BaselineMinutesPerDay=" .. Probe.formatValue(baselineMinutesPerDay)
            .. " | TickCalls=" .. tostring(tickCalls)
            .. " | " .. formatState("before.", before)
            .. " | " .. formatState("after.", after)
        )
    end
end

Events.OnTick.Add(onTick)

log("Loaded SPIKE-006 diagnostics-only awake-player protection prototype.")
log("Correction loop uses dedicated-server Events.OnTick and iterates getOnlinePlayers().")
log("Protected-state hot path reads only Hunger/Thirst/Fatigue and Nutrition fields targeted by SPIKE-006.")
log("No mutation occurs unless DiagnosticsEnabled=true, DiagnosticAwakeProtectionPrototype=true, and the one-player forced-compression test path is active.")
