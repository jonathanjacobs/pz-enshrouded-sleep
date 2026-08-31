-- Enshrouded Sleep - authoritative proportional calendar/world-time controller
-- Release Candidate v1.0.0 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Provide proportional multiplayer sleeping without globally fast-forwarding
-- active simulation. During normal partial sleep, the server changes only
-- GameTime:MinutesPerDay. Movement, combat, zombies, vehicles, animations,
-- physics, and ordinary timed actions therefore remain on the normal active
-- simulation path while world/calendar time advances faster.
--
-- NORMAL POLICY
-- -------------
-- LivingPlayers  = instantiated getOnlinePlayers() entries where isDead()==false
-- SleepingPlayers = LivingPlayers where isAsleep()==true
--
-- 0 sleepers:
--     restore/carry native baseline MinutesPerDay
-- some but not all living players asleep:
--     SleepFraction = SleepingPlayers / LivingPlayers
--     EffectivePartialSleepCap = FastForwardMultiplier * PartialSleepSpeedScale
--     CalendarCompressionFactor = max(1, EffectivePartialSleepCap * SleepFraction)
--     EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
-- all living players asleep:
--     restore native baseline MinutesPerDay and let vanilla full-sleep
--     fast-forward own the state
--
-- DIAGNOSTIC OVERRIDE
-- -------------------
-- DiagnosticForcedCompressionFactor is a deliberately narrow support/test path.
-- It is active only when DiagnosticsEnabled=true, the factor is >1, exactly one
-- living player is connected to the multiplayer server, and that player is
-- awake. Sleeping, a second living player joining, or zero connected living
-- players causes/retains baseline instead of mixing test compression with normal
-- sleep policy. The override never calls GameTime:setMultiplier().
--
-- FAIL-SAFE PRINCIPLE
-- -------------------
-- Capture the authoritative runtime baseline once and fail toward that baseline.
-- A recoverable read/write/configuration error must never intentionally leave the
-- server at a stale compressed day length.

if isClient() then return end

local PREFIX = "[EnshroudedSleep]"
local EPSILON = 0.0001
local MAX_DIAGNOSTIC_COMPRESSION_FACTOR = 20.0

local baselineMinutesPerDay = nil
local cachedNativeConfig = nil
local lastConfigRefreshAt = -1
local lastStateSignature = nil
local lastError = nil
local startupConfigLogged = false

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function formatNumber(value, decimals)
    if type(value) ~= "number" then return tostring(value) end
    return string.format("%." .. tostring(decimals or 3) .. "f", value)
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil, "nil object" end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil, methodName .. " unavailable" end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil, tostring(value) end
    return value, nil
end

local function logErrorOnce(message)
    if message ~= lastError then
        lastError = message
        log("ERROR | " .. tostring(message) .. " | restoring native baseline where possible")
    end
end

local function clearError()
    lastError = nil
end

local function getModConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local scale = tonumber(vars and vars.PartialSleepSpeedScale) or 1.0
    local diagnosticFactor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0

    if scale < 0 then scale = 0 end
    if diagnosticFactor < 1.0 then diagnosticFactor = 1.0 end
    if diagnosticFactor > MAX_DIAGNOSTIC_COMPRESSION_FACTOR then
        diagnosticFactor = MAX_DIAGNOSTIC_COMPRESSION_FACTOR
    end

    return {
        enabled = vars == nil or vars.Enabled ~= false,
        partialSleepSpeedScale = scale,
        diagnosticsEnabled = vars ~= nil and vars.DiagnosticsEnabled == true,
        diagnosticForcedCompressionFactor = diagnosticFactor,
    }
end

local function readNativeConfig(force)
    local now = os.time()
    if cachedNativeConfig and not force and now == lastConfigRefreshAt then
        return cachedNativeConfig
    end

    lastConfigRefreshAt = now

    if type(getServerOptions) ~= "function" then
        cachedNativeConfig = nil
        return nil, "getServerOptions() unavailable"
    end

    local okOptions, options = pcall(getServerOptions)
    if not okOptions or not options then
        cachedNativeConfig = nil
        return nil, "could not read native ServerOptions"
    end

    local sleepAllowed, errAllowed = safeMethod(options, "getBoolean", "SleepAllowed")
    local sleepNeeded, errNeeded = safeMethod(options, "getBoolean", "SleepNeeded")
    local nativeFastForward, errFastForward = safeMethod(options, "getDouble", "FastForwardMultiplier")
    nativeFastForward = tonumber(nativeFastForward)

    if sleepAllowed == nil then
        cachedNativeConfig = nil
        return nil, "could not read SleepAllowed: " .. tostring(errAllowed)
    end

    if nativeFastForward == nil then
        cachedNativeConfig = nil
        return nil, "could not read FastForwardMultiplier: " .. tostring(errFastForward)
    end

    local sandboxDayLengthMinutes = nil
    if type(getSandboxOptions) == "function" then
        local okSandbox, sandboxOptions = pcall(getSandboxOptions)
        if okSandbox and sandboxOptions then
            sandboxDayLengthMinutes = safeMethod(sandboxOptions, "getDayLengthMinutes")
            sandboxDayLengthMinutes = tonumber(sandboxDayLengthMinutes)
        end
    end

    cachedNativeConfig = {
        sleepAllowed = sleepAllowed == true,
        sleepNeeded = sleepNeeded,
        sleepNeededError = errNeeded,
        nativeFastForward = math.max(0.0, nativeFastForward),
        sandboxDayLengthMinutes = sandboxDayLengthMinutes,
    }

    return cachedNativeConfig, nil
end

local function ensureBaseline()
    if baselineMinutesPerDay ~= nil then return true end

    local gt = getGameTime()
    if not gt then return false, "getGameTime() unavailable" end

    local value, err = safeMethod(gt, "getMinutesPerDay")
    value = tonumber(value)
    if value == nil or value <= 0 then
        return false, "invalid runtime MinutesPerDay: " .. tostring(value or err)
    end

    baselineMinutesPerDay = value
    return true, nil
end

local function setMinutesPerDay(target)
    if type(target) ~= "number" or target <= 0 then
        return false, "invalid target MinutesPerDay: " .. tostring(target)
    end

    local gt = getGameTime()
    if not gt then return false, "getGameTime() unavailable" end

    local currentValue, readErr = safeMethod(gt, "getMinutesPerDay")
    local current = tonumber(currentValue)
    if current == nil then
        return false, "could not read MinutesPerDay: " .. tostring(readErr)
    end

    if math.abs(current - target) <= EPSILON then return true, nil end

    local _, setErr = safeMethod(gt, "setMinutesPerDay", target)
    if setErr then return false, "setMinutesPerDay failed: " .. tostring(setErr) end
    return true, nil
end

local function restoreBaseline()
    if baselineMinutesPerDay == nil then return true, nil end
    return setMinutesPerDay(baselineMinutesPerDay)
end

local function countLivingAndSleepingPlayers()
    if type(getOnlinePlayers) ~= "function" then
        return nil, nil, "getOnlinePlayers() unavailable"
    end

    local players = getOnlinePlayers()
    if not players then return 0, 0, nil end

    local sizeValue, sizeErr = safeMethod(players, "size")
    local size = tonumber(sizeValue)
    if size == nil then
        return nil, nil, "could not read online-player count: " .. tostring(sizeErr)
    end

    local living = 0
    local sleeping = 0

    for i = 0, size - 1 do
        local player, getErr = safeMethod(players, "get", i)
        if not player then
            return nil, nil, "could not read player index " .. tostring(i) .. ": " .. tostring(getErr)
        end

        local dead, deadErr = safeMethod(player, "isDead")
        if dead == nil then
            return nil, nil, "could not read isDead() for player index " .. tostring(i) .. ": " .. tostring(deadErr)
        end

        if dead ~= true then
            living = living + 1
            local asleep, sleepErr = safeMethod(player, "isAsleep")
            if asleep == nil then
                return nil, nil, "could not read isAsleep() for player index " .. tostring(i) .. ": " .. tostring(sleepErr)
            end
            if asleep == true then sleeping = sleeping + 1 end
        end
    end

    return living, sleeping, nil
end

local function calculateDecision(nativeConfig, modConfig, living, sleeping)
    local nativeFF = nativeConfig.nativeFastForward
    local scale = modConfig.partialSleepSpeedScale
    local effectivePartialSleepCap = nativeFF * scale

    if living <= 0 or sleeping <= 0 then
        return {
            mode = "baseline",
            sleepFraction = 0.0,
            calendarCompressionFactor = 1.0,
            realTimeCompensationFactor = 1.0,
            effectivePartialSleepCap = effectivePartialSleepCap,
            targetMinutesPerDay = baselineMinutesPerDay,
        }
    end

    local sleepFraction = math.min(1.0, sleeping / living)

    if sleeping >= living then
        local theoreticalFactor = math.max(1.0, effectivePartialSleepCap)
        return {
            mode = "vanilla",
            sleepFraction = 1.0,
            calendarCompressionFactor = 1.0,
            realTimeCompensationFactor = 1.0,
            effectivePartialSleepCap = effectivePartialSleepCap,
            targetMinutesPerDay = baselineMinutesPerDay,
            theoreticalFullSleepMinutesPerDay = baselineMinutesPerDay / theoreticalFactor,
        }
    end

    local compression = math.max(1.0, effectivePartialSleepCap * sleepFraction)
    return {
        mode = "partial",
        sleepFraction = sleepFraction,
        calendarCompressionFactor = compression,
        realTimeCompensationFactor = 1.0 / compression,
        effectivePartialSleepCap = effectivePartialSleepCap,
        targetMinutesPerDay = baselineMinutesPerDay / compression,
    }
end

local function calculateDiagnosticDecision(modConfig, living, sleeping)
    local factor = modConfig.diagnosticForcedCompressionFactor

    if sleeping and sleeping > 0 then
        return {
            mode = "diagnostic-forced-suspended-sleep",
            sleepFraction = living > 0 and math.min(1.0, sleeping / living) or 0.0,
            calendarCompressionFactor = 1.0,
            realTimeCompensationFactor = 1.0,
            targetMinutesPerDay = baselineMinutesPerDay,
            diagnosticForcedCompressionFactor = factor,
        }
    end

    if living <= 0 then
        return {
            mode = "diagnostic-forced-awaiting-player",
            sleepFraction = 0.0,
            calendarCompressionFactor = 1.0,
            realTimeCompensationFactor = 1.0,
            targetMinutesPerDay = baselineMinutesPerDay,
            diagnosticForcedCompressionFactor = factor,
        }
    end

    if living ~= 1 then
        return {
            mode = "diagnostic-forced-suspended-player-count",
            sleepFraction = 0.0,
            calendarCompressionFactor = 1.0,
            realTimeCompensationFactor = 1.0,
            targetMinutesPerDay = baselineMinutesPerDay,
            diagnosticForcedCompressionFactor = factor,
        }
    end

    return {
        mode = "diagnostic-forced",
        sleepFraction = 0.0,
        calendarCompressionFactor = factor,
        realTimeCompensationFactor = 1.0 / factor,
        targetMinutesPerDay = baselineMinutesPerDay / factor,
        diagnosticForcedCompressionFactor = factor,
    }
end

local function maybeLogStartupConfig(nativeConfig, modConfig)
    if startupConfigLogged or baselineMinutesPerDay == nil then return end
    startupConfigLogged = true

    log(string.format(
        "CONFIG | BaselineMinutesPerDay=%s | SandboxDayLengthMinutes=%s | SleepAllowed=%s | SleepNeeded=%s | NativeFastForward=%s | PartialSleepSpeedScale=%s | EffectivePartialSleepCap=%s | DiagnosticsEnabled=%s | DiagnosticForcedCompressionFactor=%s",
        formatNumber(baselineMinutesPerDay, 3),
        nativeConfig.sandboxDayLengthMinutes and formatNumber(nativeConfig.sandboxDayLengthMinutes, 3) or "N/A",
        tostring(nativeConfig.sleepAllowed),
        nativeConfig.sleepNeeded ~= nil and tostring(nativeConfig.sleepNeeded) or "N/A",
        formatNumber(nativeConfig.nativeFastForward, 3),
        formatNumber(modConfig.partialSleepSpeedScale, 3),
        formatNumber(nativeConfig.nativeFastForward * modConfig.partialSleepSpeedScale, 3),
        tostring(modConfig.diagnosticsEnabled),
        formatNumber(modConfig.diagnosticForcedCompressionFactor, 3)
    ))
end

local function logStateIfChanged(mode, living, sleeping, decision, extra)
    local signature = table.concat({
        tostring(mode),
        tostring(living),
        tostring(sleeping),
        formatNumber(decision and decision.sleepFraction or 0, 6),
        formatNumber(decision and decision.calendarCompressionFactor or 1, 6),
        formatNumber(decision and decision.targetMinutesPerDay or baselineMinutesPerDay or 0, 6),
        tostring(extra or ""),
    }, "|")

    if signature == lastStateSignature then return end
    lastStateSignature = signature

    if mode == "partial" then
        log(string.format(
            "STATE | mode=partial | living=%d | sleeping=%d | sleepFraction=%s | CalendarCompressionFactor=%s | EffectiveMinutesPerDay=%s | RealTimeCompensationFactor=%s",
            living,
            sleeping,
            formatNumber(decision.sleepFraction, 4),
            formatNumber(decision.calendarCompressionFactor, 3),
            formatNumber(decision.targetMinutesPerDay, 3),
            formatNumber(decision.realTimeCompensationFactor, 5)
        ))
    elseif mode == "vanilla" then
        log(string.format(
            "STATE | mode=vanilla-full-sleep | living=%d | sleeping=%d | restoredMinutesPerDay=%s | theoreticalCompressedMinutesPerDay=%s | vanilla fast-forward owns full sleep",
            living,
            sleeping,
            formatNumber(baselineMinutesPerDay, 3),
            formatNumber(decision.theoreticalFullSleepMinutesPerDay, 3)
        ))
    elseif mode == "diagnostic-forced" then
        log(string.format(
            "TEST OVERRIDE ACTIVE | mode=diagnostic-forced | living=1 | sleeping=0 | DiagnosticForcedCompressionFactor=%s | EffectiveMinutesPerDay=%s | one connected server player must remain awake | NOT FOR NORMAL GAMEPLAY",
            formatNumber(decision.diagnosticForcedCompressionFactor, 3),
            formatNumber(decision.targetMinutesPerDay, 3)
        ))
    elseif mode == "diagnostic-forced-suspended-sleep" then
        log(string.format(
            "TEST OVERRIDE SUSPENDED | reason=sleeping-player | living=%d | sleeping=%d | restoredMinutesPerDay=%s",
            living or 0,
            sleeping or 0,
            formatNumber(baselineMinutesPerDay, 3)
        ))
    elseif mode == "diagnostic-forced-suspended-player-count" then
        log(string.format(
            "TEST OVERRIDE SUSPENDED | reason=requires-exactly-one-living-connected-player | living=%d | sleeping=%d | restoredMinutesPerDay=%s",
            living or 0,
            sleeping or 0,
            formatNumber(baselineMinutesPerDay, 3)
        ))
    elseif mode == "diagnostic-forced-awaiting-player" then
        log("TEST OVERRIDE ARMED | living=0 | baseline retained until exactly one awake living player is connected")
    else
        log(string.format(
            "STATE | mode=%s | living=%d | sleeping=%d | MinutesPerDay=%s%s",
            tostring(mode),
            living or 0,
            sleeping or 0,
            baselineMinutesPerDay and formatNumber(baselineMinutesPerDay, 3) or "N/A",
            extra and (" | " .. tostring(extra)) or ""
        ))
    end
end

local function update()
    local baselineOK, baselineErr = ensureBaseline()
    if not baselineOK then
        logErrorOnce(baselineErr)
        return
    end

    local modConfig = getModConfig()

    if not modConfig.enabled then
        local restored, restoreErr = restoreBaseline()
        if not restored then logErrorOnce(restoreErr) else clearError() end
        logStateIfChanged("disabled", 0, 0, nil, "mod disabled")
        return
    end

    local nativeConfig, nativeErr = readNativeConfig(false)
    if not nativeConfig then
        restoreBaseline()
        logErrorOnce(nativeErr)
        logStateIfChanged("fail-safe", 0, 0, nil, nativeErr)
        return
    end

    maybeLogStartupConfig(nativeConfig, modConfig)

    local living, sleeping, playerErr = countLivingAndSleepingPlayers()
    if living == nil then
        restoreBaseline()
        logErrorOnce(playerErr)
        logStateIfChanged("fail-safe", 0, 0, nil, playerErr)
        return
    end

    if modConfig.diagnosticsEnabled
        and modConfig.diagnosticForcedCompressionFactor > 1.0 + EPSILON then
        local decision = calculateDiagnosticDecision(modConfig, living, sleeping)
        local applied, applyErr = setMinutesPerDay(decision.targetMinutesPerDay)
        if not applied then
            restoreBaseline()
            logErrorOnce(applyErr)
            logStateIfChanged("fail-safe", living, sleeping, decision, applyErr)
            return
        end

        clearError()
        logStateIfChanged(decision.mode, living, sleeping, decision, nil)
        return
    end

    if not nativeConfig.sleepAllowed then
        local restored, restoreErr = restoreBaseline()
        if not restored then logErrorOnce(restoreErr) else clearError() end
        logStateIfChanged("native-sleep-disabled", living, sleeping, nil, "SleepAllowed=false")
        return
    end

    local decision = calculateDecision(nativeConfig, modConfig, living, sleeping)
    local applied, applyErr = setMinutesPerDay(decision.targetMinutesPerDay)
    if not applied then
        restoreBaseline()
        logErrorOnce(applyErr)
        logStateIfChanged("fail-safe", living, sleeping, decision, applyErr)
        return
    end

    clearError()
    logStateIfChanged(decision.mode, living, sleeping, decision, nil)
end

Events.OnTickEvenPaused.Add(update)

log("Loaded Release Candidate v1.0.0 multiplayer-server calendar-compression controller.")
log("Normal partial sleep changes MinutesPerDay only; global simulation multiplier is never modified.")
log("Diagnostic forced compression is SERVER TEST ONLY and requires exactly one awake living player connected to the multiplayer server.")
log("If that player sleeps or another living player connects, the diagnostic override restores native MinutesPerDay.")
