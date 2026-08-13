if isClient() then return end

-- Enshrouded Sleep - proportional calendar/world-time compression
-- v0.0.3 functional prototype for Project Zomboid Build 42.20+
--
-- Vanilla Project Zomboid owns sleep eligibility, sleep/wake state, death,
-- respawn, joins/disconnects, and the all-living-players-asleep fast-forward.
--
-- This mod only changes GameTime MinutesPerDay while SOME, but not all,
-- currently instantiated living players are asleep. It never calls
-- GameTime:setMultiplier().

local PREFIX = "[EnshroudedSleep]"
local EPSILON = 0.0001

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
    local vars = SandboxVars and SandboxVars.EnshroudedSleepClockSpike or nil
    local scale = tonumber(vars and vars.PartialSleepSpeedScale) or 1.0
    if scale < 0 then scale = 0 end

    return {
        enabled = vars == nil or vars.Enabled ~= false,
        partialSleepSpeedScale = scale,
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
    if not gt then
        return false, "getGameTime() unavailable"
    end

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

    local current, readErr = safeMethod(gt, "getMinutesPerDay")
    current = tonumber(current)
    if current == nil then return false, "could not read MinutesPerDay: " .. tostring(readErr) end

    if math.abs(current - target) <= EPSILON then
        return true, nil
    end

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

    local size, sizeErr = safeMethod(players, "size")
    size = tonumber(size)
    if size == nil then return nil, nil, "could not read online-player count: " .. tostring(sizeErr) end

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

    -- Full sleep belongs to vanilla. The theoretical target is logged only so
    -- admins can see what the continuous MinutesPerDay model would have been;
    -- we do NOT apply it because vanilla also engages its own fast-forward.
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

local function maybeLogStartupConfig(nativeConfig, modConfig)
    if startupConfigLogged or baselineMinutesPerDay == nil then return end
    startupConfigLogged = true

    log(string.format(
        "CONFIG | BaselineMinutesPerDay=%s | SandboxDayLengthMinutes=%s | SleepAllowed=%s | SleepNeeded=%s | NativeFastForward=%s | PartialSleepSpeedScale=%s | EffectivePartialSleepCap=%s",
        formatNumber(baselineMinutesPerDay, 3),
        nativeConfig.sandboxDayLengthMinutes and formatNumber(nativeConfig.sandboxDayLengthMinutes, 3) or "N/A",
        tostring(nativeConfig.sleepAllowed),
        nativeConfig.sleepNeeded ~= nil and tostring(nativeConfig.sleepNeeded) or "N/A",
        formatNumber(nativeConfig.nativeFastForward, 3),
        formatNumber(modConfig.partialSleepSpeedScale, 3),
        formatNumber(nativeConfig.nativeFastForward * modConfig.partialSleepSpeedScale, 3)
    ))

    if nativeConfig.sandboxDayLengthMinutes
        and math.abs(nativeConfig.sandboxDayLengthMinutes - baselineMinutesPerDay) > EPSILON then
        log(string.format(
            "NOTICE | runtime MinutesPerDay (%s) differs from sandbox day-length minutes (%s); runtime value remains authoritative",
            formatNumber(baselineMinutesPerDay, 3),
            formatNumber(nativeConfig.sandboxDayLengthMinutes, 3)
        ))
    end
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

    if not nativeConfig.sleepAllowed then
        local restored, restoreErr = restoreBaseline()
        if not restored then logErrorOnce(restoreErr) else clearError() end
        logStateIfChanged("native-sleep-disabled", 0, 0, nil, "SleepAllowed=false")
        return
    end

    local living, sleeping, playerErr = countLivingAndSleepingPlayers()
    if living == nil then
        restoreBaseline()
        logErrorOnce(playerErr)
        logStateIfChanged("fail-safe", 0, 0, nil, playerErr)
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

-- Every tick is intentional: changing MinutesPerDay is cheap, and the actual
-- setter only runs when the target changes. Per-tick observation minimizes the
-- window in which partial compression could overlap vanilla full-sleep FF when
-- the final awake player falls asleep.
Events.OnTickEvenPaused.Add(update)

log("Loaded v0.0.3 proportional calendar-compression prototype.")
log("Partial sleep changes MinutesPerDay only; global simulation multiplier is never modified.")
log("At 100% living players asleep, native MinutesPerDay is restored and vanilla sleep fast-forward takes over.")
