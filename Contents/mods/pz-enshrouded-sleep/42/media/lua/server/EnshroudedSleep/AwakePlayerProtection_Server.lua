-- Enshrouded Sleep - awake-player survival protection
-- Public Beta v0.1.0 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- During normal partial sleep, Enshrouded Sleep compresses world/calendar time
-- by reducing MinutesPerDay while leaving active simulation at normal speed.
-- Build 42 drives several awake-player survival systems from that compressed
-- world-time delta. This module normalizes the supported awake-player fields
-- back toward the rate expected at the captured native MinutesPerDay.
--
-- PROTECTED FIELDS
-- ----------------
-- Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, Weight.
--
-- SAFETY BOUNDARY
-- ---------------
-- * Server authoritative; never runs as a client mutation path.
-- * Never corrects sleeping or dead players.
-- * Normal gameplay correction runs only while some-but-not-all living players
--   are asleep and MinutesPerDay is actually below the captured baseline.
-- * The one-player DiagnosticForcedCompressionFactor path remains available for
--   controlled support/regression tests when DiagnosticsEnabled=true.
-- * Direct favorable changes (eating/drinking) are accepted in full. The tested
--   directional normalizer removes only worsening/depleting deltas for the
--   supported fields, with Weight corrected in either direction.
-- * Any read/write failure fails open for that player and clears its reference
--   snapshot so no later catch-up correction is attempted.
--
-- BETA NOTE
-- ---------
-- SPIKE-006 passed controlled passive and active-effect tests at 20x. Public Beta
-- broadens validation to real multiplayer populations and mod stacks. Admins can
-- disable AwakePlayerProtectionEnabled independently if a compatibility problem
-- is suspected; the proportional sleep/calendar controller continues to operate.

if isClient() then return end

local Probe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepAwakeProtect][SERVER]"
local EPSILON = 0.0000001
local LOG_INTERVAL_SECONDS = 1
local HEARTBEAT_INTERVAL_SECONDS = 30

local baselineMinutesPerDay = nil
local previousByPlayer = {}
local lastCorrectionLogAtByPlayer = {}
local lastHeartbeatAt = -1
local lastStatus = nil
local tickCalls = 0

local protectedCharacterStats = {
    Hunger = { key = "HUNGER", id = "Hunger", stat = nil },
    Thirst = { key = "THIRST", id = "Thirst", stat = nil },
    Fatigue = { key = "FATIGUE", id = "Fatigue", stat = nil },
}

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function getConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return {
        modEnabled = vars == nil or vars.Enabled ~= false,
        protectionEnabled = vars == nil or vars.AwakePlayerProtectionEnabled ~= false,
        diagnosticsEnabled = vars ~= nil and vars.DiagnosticsEnabled == true,
        forcedFactor = math.max(1.0, tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0),
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

local function captureBaselineIfSafe(config, minutesPerDay, living, sleeping)
    if not minutesPerDay or minutesPerDay <= 0 then return end

    local diagnosticForced = config.diagnosticsEnabled
        and config.forcedFactor > 1.0 + EPSILON
        and living == 1
        and sleeping == 0

    local baselineState = living == 0
        or sleeping >= living
        or (sleeping == 0 and not diagnosticForced)

    if baselineState and (baselineMinutesPerDay == nil or minutesPerDay > baselineMinutesPerDay) then
        baselineMinutesPerDay = minutesPerDay
        log("BASELINE | MinutesPerDay=" .. Probe.formatValue(baselineMinutesPerDay))
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
    if previous == nil or current == nil then return current, false end

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
    if changed and not writeCharacterStat(player, "Hunger", corrected.Hunger) then writeFailure = true end

    corrected.Thirst, changed = retainFraction(previous.Thirst, before.Thirst, compression, "positive")
    if changed and not writeCharacterStat(player, "Thirst", corrected.Thirst) then writeFailure = true end

    corrected.Fatigue, changed = retainFraction(previous.Fatigue, before.Fatigue, compression, "positive")
    if changed and not writeCharacterStat(player, "Fatigue", corrected.Fatigue) then writeFailure = true end

    corrected.Calories, changed = retainFraction(previous.Calories, before.Calories, compression, "negative")
    if changed and not writeNutrition(player, "setCalories", corrected.Calories) then writeFailure = true end

    corrected.Carbohydrates, changed = retainFraction(previous.Carbohydrates, before.Carbohydrates, compression, "negative")
    if changed and not writeNutrition(player, "setCarbohydrates", corrected.Carbohydrates) then writeFailure = true end

    corrected.Proteins, changed = retainFraction(previous.Proteins, before.Proteins, compression, "negative")
    if changed and not writeNutrition(player, "setProteins", corrected.Proteins) then writeFailure = true end

    corrected.Lipids, changed = retainFraction(previous.Lipids, before.Lipids, compression, "negative")
    if changed and not writeNutrition(player, "setLipids", corrected.Lipids) then writeFailure = true end

    corrected.Weight, changed = retainFraction(previous.Weight, before.Weight, compression, "either")
    if changed and not writeNutrition(player, "setWeight", corrected.Weight) then writeFailure = true end

    return not writeFailure
end

local function formatState(prefix, state)
    if not state then return prefix .. "=N/A" end
    local fields = { "Hunger", "Thirst", "Fatigue", "Calories", "Carbohydrates", "Proteins", "Lipids", "Weight" }
    local parts = {}
    for _, field in ipairs(fields) do
        parts[#parts + 1] = prefix .. field .. "=" .. Probe.formatValue(state[field], field == "Weight" and 8 or 6)
    end
    return table.concat(parts, " | ")
end

local function setStatus(mode, living, sleeping, awakeCount, compression)
    local status = table.concat({
        "mode=" .. tostring(mode),
        "living=" .. tostring(living),
        "sleeping=" .. tostring(sleeping),
        "awake=" .. tostring(awakeCount),
        "factor=" .. Probe.formatValue(compression),
    }, " | ")
    if status ~= lastStatus then
        lastStatus = status
        log("STATUS | " .. status)
    end
end

local function snapshotAwakePlayers(players)
    local seen = {}
    for _, player in ipairs(players) do
        local key = playerKey(player)
        seen[key] = true
        if Probe.safeMethod(player, "isAsleep") ~= true then
            previousByPlayer[key] = readProtectedState(player)
        else
            previousByPlayer[key] = nil
        end
    end
    for key, _ in pairs(previousByPlayer) do
        if not seen[key] then previousByPlayer[key] = nil end
    end
end

local function maybeHeartbeat(config, mode, minutesPerDay, living, sleeping, awakeCount, compression)
    if not config.diagnosticsEnabled then return end
    local now = os.time()
    if lastHeartbeatAt >= 0 and now - lastHeartbeatAt < HEARTBEAT_INTERVAL_SECONDS then return end
    lastHeartbeatAt = now

    log(
        "HEARTBEAT | epoch=" .. tostring(now)
        .. " | tickCalls=" .. tostring(tickCalls)
        .. " | mode=" .. tostring(mode)
        .. " | protectionEnabled=" .. tostring(config.protectionEnabled)
        .. " | living=" .. tostring(living)
        .. " | sleeping=" .. tostring(sleeping)
        .. " | awake=" .. tostring(awakeCount)
        .. " | MinutesPerDay=" .. Probe.formatValue(minutesPerDay)
        .. " | BaselineMinutesPerDay=" .. Probe.formatValue(baselineMinutesPerDay)
        .. " | compression=" .. Probe.formatValue(compression)
    )
end

local function onTick()
    tickCalls = tickCalls + 1

    local config = getConfig()
    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    local minutesPerDay = Probe.safeNumber(gameTime, "getMinutesPerDay")
    local players, living, sleeping = collectLivingPlayers()
    local awakeCount = math.max(0, living - sleeping)

    captureBaselineIfSafe(config, minutesPerDay, living, sleeping)

    if not config.protectionEnabled or not config.modEnabled then
        snapshotAwakePlayers(players)
        setStatus(config.protectionEnabled and "controller-disabled" or "protection-disabled", living, sleeping, awakeCount, 1.0)
        maybeHeartbeat(config, "inactive", minutesPerDay, living, sleeping, awakeCount, 1.0)
        return
    end

    if baselineMinutesPerDay == nil or not minutesPerDay or minutesPerDay <= 0 then
        previousByPlayer = {}
        setStatus("awaiting-baseline", living, sleeping, awakeCount, 1.0)
        maybeHeartbeat(config, "awaiting-baseline", minutesPerDay, living, sleeping, awakeCount, 1.0)
        return
    end

    local compression = baselineMinutesPerDay / minutesPerDay
    local normalPartial = living > 0 and sleeping > 0 and sleeping < living and compression > 1.0 + EPSILON
    local diagnosticForced = config.diagnosticsEnabled
        and config.forcedFactor > 1.0 + EPSILON
        and living == 1
        and sleeping == 0
        and compression > 1.0 + EPSILON

    local mode = normalPartial and "partial" or (diagnosticForced and "diagnostic-forced" or "baseline")

    if diagnosticForced then
        local tolerance = math.max(0.05, config.forcedFactor * 0.02)
        if math.abs(compression - config.forcedFactor) > tolerance then
            snapshotAwakePlayers(players)
            setStatus("diagnostic-factor-mismatch", living, sleeping, awakeCount, compression)
            maybeHeartbeat(config, "diagnostic-factor-mismatch", minutesPerDay, living, sleeping, awakeCount, compression)
            return
        end
    end

    if not normalPartial and not diagnosticForced then
        snapshotAwakePlayers(players)
        setStatus("baseline-or-vanilla", living, sleeping, awakeCount, compression)
        maybeHeartbeat(config, "baseline-or-vanilla", minutesPerDay, living, sleeping, awakeCount, compression)
        return
    end

    local seen = {}
    local correctedPlayers = 0

    for _, player in ipairs(players) do
        local key = playerKey(player)
        seen[key] = true

        if Probe.safeMethod(player, "isAsleep") == true or Probe.safeMethod(player, "isDead") == true then
            previousByPlayer[key] = nil
        else
            local before = readProtectedState(player)
            local previous = previousByPlayer[key]

            if previous == nil then
                previousByPlayer[key] = before
            else
                local ok = applyCorrection(player, previous, before, compression)
                if not ok then
                    previousByPlayer[key] = nil
                    log("WRITE_FAILURE_FAIL_OPEN | epoch=" .. tostring(os.time()) .. " | player=" .. Probe.sanitize(Probe.safeMethod(player, "getUsername") or key))
                else
                    local after = readProtectedState(player)
                    previousByPlayer[key] = after
                    correctedPlayers = correctedPlayers + 1

                    if config.diagnosticsEnabled then
                        local now = os.time()
                        local last = lastCorrectionLogAtByPlayer[key] or -1
                        if last < 0 or now - last >= LOG_INTERVAL_SECONDS then
                            lastCorrectionLogAtByPlayer[key] = now
                            log(
                                "CORRECTION | epoch=" .. tostring(now)
                                .. " | mode=" .. tostring(mode)
                                .. " | player=" .. Probe.sanitize(Probe.safeMethod(player, "getUsername") or key)
                                .. " | factor=" .. Probe.formatValue(compression)
                                .. " | MinutesPerDay=" .. Probe.formatValue(minutesPerDay)
                                .. " | BaselineMinutesPerDay=" .. Probe.formatValue(baselineMinutesPerDay)
                                .. " | TickCalls=" .. tostring(tickCalls)
                                .. " | " .. formatState("Before", before)
                                .. " | " .. formatState("After", after)
                            )
                        end
                    end
                end
            end
        end
    end

    for key, _ in pairs(previousByPlayer) do
        if not seen[key] then
            previousByPlayer[key] = nil
            lastCorrectionLogAtByPlayer[key] = nil
        end
    end

    setStatus(mode .. "-protection-active", living, sleeping, awakeCount, compression)
    maybeHeartbeat(config, mode, minutesPerDay, living, sleeping, awakeCount, compression)
end

Events.OnTick.Add(onTick)

log("Loaded Public Beta v0.1.0 awake-player survival protection.")
log("Normal partial sleep protects all awake living players; sleeping players remain vanilla-authoritative.")
log("Supported fields: Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, Weight.")
