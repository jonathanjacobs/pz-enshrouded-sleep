-- Enshrouded Sleep - proportional calendar/world-time compression
-- v0.0.6 functional prototype for Project Zomboid Build 42.20+
--
-- DESIGN SUMMARY
-- --------------
-- Vanilla Project Zomboid owns sleep eligibility, sleep/wake state, death,
-- respawn, joins/disconnects, and the all-living-players-asleep fast-forward.
--
-- This mod adds one behavior only: while SOME, but not all, currently
-- instantiated living players are asleep, it shortens GameTime MinutesPerDay
-- according to the sleeping fraction. This compresses world/calendar time
-- without calling GameTime:setMultiplier() or otherwise globally accelerating
-- the active simulation.
--
-- IMPORTANT INVARIANTS
-- --------------------
-- 1. baselineMinutesPerDay is captured once from the live GameTime value and is
--    the exact value restored whenever partial-sleep compression is not active.
-- 2. The mod never applies a compressed MinutesPerDay when all living players
--    are asleep; vanilla fast-forward owns that state.
-- 3. Any recoverable error fails toward the captured native baseline rather
--    than leaving the world clock accelerated.
-- 4. Only instantiated, non-dead players returned by getOnlinePlayers() are
--    included in the proportional population.

-- This file is server-only. If it is ever loaded in a client Lua context,
-- return before registering events or touching authoritative GameTime state.
if isClient() then return end

local PREFIX = "[EnshroudedSleep]"

-- Floating-point comparison tolerance used when deciding whether an existing
-- MinutesPerDay value is already close enough to the requested target.
local EPSILON = 0.0001

-- Captured native runtime day length. This must remain unchanged after capture
-- so every exit path can restore exactly the value that existed before the mod
-- began applying partial-sleep compression.
local baselineMinutesPerDay = nil

-- Native server settings are cached for the current wall-clock second. The
-- controller runs every tick, so this avoids repeatedly querying ServerOptions
-- dozens of times per second while still reacting quickly to configuration
-- changes made at runtime.
local cachedNativeConfig = nil
local lastConfigRefreshAt = -1

-- State-transition logging is deduplicated by signature so the per-tick
-- controller does not flood the dedicated-server log with identical messages.
local lastStateSignature = nil
local lastError = nil
local startupConfigLogged = false

---Write a namespaced informational message to the dedicated-server log.
---@param message any Value to stringify and append after the log prefix.
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Format numeric values consistently for human-readable diagnostics.
---Non-numeric inputs are stringified unchanged so callers can safely pass
---optional values such as "N/A" without adding their own type branches.
---@param value any Number or fallback value to format.
---@param decimals integer|nil Number of decimal places; defaults to 3.
---@return string formattedValue
local function formatNumber(value, decimals)
    -- Preserve non-numeric diagnostic values instead of raising a format error.
    if type(value) ~= "number" then return tostring(value) end

    return string.format("%." .. tostring(decimals or 3) .. "f", value)
end

---Safely invoke a method on a Project Zomboid Java/Lua object.
---Project Zomboid's Lua bridge can expose methods differently between builds;
---pcall prevents a missing method or Java-side exception from aborting the
---controller and leaving a compressed day length active.
---@param obj any Object expected to provide methodName.
---@param methodName string Method to resolve and invoke.
---@param ... any Arguments passed to the resolved method.
---@return any|nil value First return value on success; nil on failure or for void methods.
---@return string|nil errorMessage Nil on success, descriptive text on failure.
local function safeMethod(obj, methodName, ...)
    -- A nil object cannot provide a callable method; report it as a recoverable failure.
    if not obj then return nil, "nil object" end

    local okMethod, method = pcall(function() return obj[methodName] end)

    -- Treat a failed lookup or absent method as an API-availability error.
    if not okMethod or not method then
        return nil, methodName .. " unavailable"
    end

    local ok, value = pcall(method, obj, ...)

    -- Convert Java/Lua invocation exceptions into ordinary controller errors.
    if not ok then return nil, tostring(value) end

    return value, nil
end

---Log a controller error only when the error text changes.
---This keeps a recurring per-tick failure visible without spamming the log.
---@param message any Error description.
---@return nil
local function logErrorOnce(message)
    -- Emit only a newly observed error; repeated identical failures stay quiet.
    if message ~= lastError then
        lastError = message
        log("ERROR | " .. tostring(message) .. " | restoring native baseline where possible")
    end
end

---Clear the remembered error after a successful controller pass.
---The next failure, even if textually identical to an earlier one, will then be
---logged again because it represents a new failure episode.
---@return nil
local function clearError()
    lastError = nil
end

---Read Enshrouded Sleep's own sandbox configuration.
---Missing values intentionally fall back to safe defaults so upgrading from a
---diagnostic build with older SandboxVars does not prevent the server loading.
---@return table config Table with boolean `enabled` and numeric `partialSleepSpeedScale`.
local function getModConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local scale = tonumber(vars and vars.PartialSleepSpeedScale) or 1.0

    -- Manual config edits can bypass sandbox-option bounds; clamp negative values
    -- so the compression formula can never request a negative time scale.
    if scale < 0 then scale = 0 end

    return {
        enabled = vars == nil or vars.Enabled ~= false,
        partialSleepSpeedScale = scale,
    }
end

---Read native Project Zomboid sleep/time policy from ServerOptions.
---The result is cached for the current wall-clock second because update() runs
---every server tick. A new second forces a fresh read, allowing runtime option
---changes to propagate without expensive per-tick option lookups.
---@param force boolean|nil When true, bypass the one-second cache.
---@return table|nil nativeConfig Native values on success; nil on failure.
---@return string|nil errorMessage Nil on success, descriptive text on failure.
local function readNativeConfig(force)
    local now = os.time()

    -- Reuse the same snapshot for all controller ticks occurring in this second.
    if cachedNativeConfig and not force and now == lastConfigRefreshAt then
        return cachedNativeConfig
    end

    lastConfigRefreshAt = now

    -- getServerOptions() is the Lua-safe source of native multiplayer settings.
    if type(getServerOptions) ~= "function" then
        cachedNativeConfig = nil
        return nil, "getServerOptions() unavailable"
    end

    local okOptions, options = pcall(getServerOptions)

    -- Failure to obtain ServerOptions means compression cannot be calculated safely.
    if not okOptions or not options then
        cachedNativeConfig = nil
        return nil, "could not read native ServerOptions"
    end

    local sleepAllowed, errAllowed = safeMethod(options, "getBoolean", "SleepAllowed")
    local sleepNeeded, errNeeded = safeMethod(options, "getBoolean", "SleepNeeded")
    local nativeFastForward, errFastForward = safeMethod(options, "getDouble", "FastForwardMultiplier")

    nativeFastForward = tonumber(nativeFastForward)

    -- SleepAllowed is mandatory because the mod must never bypass native sleep policy.
    if sleepAllowed == nil then
        cachedNativeConfig = nil
        return nil, "could not read SleepAllowed: " .. tostring(errAllowed)
    end

    -- FastForwardMultiplier is mandatory because it defines the partial-sleep policy cap.
    if nativeFastForward == nil then
        cachedNativeConfig = nil
        return nil, "could not read FastForwardMultiplier: " .. tostring(errFastForward)
    end

    -- Sandbox day-length minutes are optional and diagnostic only. The live
    -- GameTime MinutesPerDay value remains authoritative for actual behavior.
    local sandboxDayLengthMinutes = nil

    if type(getSandboxOptions) == "function" then
        local okSandbox, sandboxOptions = pcall(getSandboxOptions)

        -- Failure here is non-fatal because this value is only used for logging.
        if okSandbox and sandboxOptions then
            sandboxDayLengthMinutes = safeMethod(sandboxOptions, "getDayLengthMinutes")
            sandboxDayLengthMinutes = tonumber(sandboxDayLengthMinutes)
        end
    end

    -- Clamp an invalid negative native fast-forward value defensively. Normal PZ
    -- validation should prevent this, but the controller should remain safe even
    -- if a manually edited server configuration contains an unexpected number.
    cachedNativeConfig = {
        sleepAllowed = sleepAllowed == true,
        sleepNeeded = sleepNeeded,
        sleepNeededError = errNeeded,
        nativeFastForward = math.max(0.0, nativeFastForward),
        sandboxDayLengthMinutes = sandboxDayLengthMinutes,
    }

    return cachedNativeConfig, nil
end

---Capture the exact live MinutesPerDay baseline once.
---The function is intentionally idempotent: after a successful capture, later
---calls do not re-read GameTime because a re-read during active compression
---would incorrectly redefine the compressed value as the new native baseline.
---@return boolean success True when a valid baseline is available.
---@return string|nil errorMessage Nil on success, descriptive text on failure.
local function ensureBaseline()
    -- Once captured, the baseline is immutable for the lifetime of this Lua state.
    if baselineMinutesPerDay ~= nil then return true end

    local gt = getGameTime()

    -- GameTime is required for both reading and restoring the native day length.
    if not gt then
        return false, "getGameTime() unavailable"
    end

    local value, err = safeMethod(gt, "getMinutesPerDay")
    value = tonumber(value)

    -- Reject nil, non-numeric, zero, or negative values before storing the invariant.
    if value == nil or value <= 0 then
        return false, "invalid runtime MinutesPerDay: " .. tostring(value or err)
    end

    baselineMinutesPerDay = value
    return true, nil
end

---Set GameTime MinutesPerDay only when the requested value differs materially
---from the current value. This avoids an unnecessary Java/Lua bridge write on
---every server tick while preserving prompt state transitions.
---@param target number Positive real-world minutes representing one 24-hour PZ day.
---@return boolean success True when current/target values match or the write succeeds.
---@return string|nil errorMessage Nil on success, descriptive text on failure.
local function setMinutesPerDay(target)
    -- Invalid targets are rejected before touching GameTime.
    if type(target) ~= "number" or target <= 0 then
        return false, "invalid target MinutesPerDay: " .. tostring(target)
    end

    local gt = getGameTime()

    -- Without GameTime the controller cannot safely inspect or change day length.
    if not gt then return false, "getGameTime() unavailable" end

    local current, readErr = safeMethod(gt, "getMinutesPerDay")
    current = tonumber(current)

    -- Refuse to write blindly if the existing value cannot be read first.
    if current == nil then
        return false, "could not read MinutesPerDay: " .. tostring(readErr)
    end

    -- Avoid redundant setter calls when the current value already matches the target.
    if math.abs(current - target) <= EPSILON then
        return true, nil
    end

    local _, setErr = safeMethod(gt, "setMinutesPerDay", target)

    -- A setter failure is propagated so update() can execute its fail-safe path.
    if setErr then
        return false, "setMinutesPerDay failed: " .. tostring(setErr)
    end

    return true, nil
end

---Restore the exact captured native day length.
---Calling before baseline capture is treated as a no-op success because there is
---no authoritative value available to restore yet.
---@return boolean success True if no restore is needed or the restore succeeds.
---@return string|nil errorMessage Nil on success, descriptive text on failure.
local function restoreBaseline()
    -- No baseline means there is nothing safe to write back yet.
    if baselineMinutesPerDay == nil then return true, nil end

    return setMinutesPerDay(baselineMinutesPerDay)
end

---Count the currently instantiated living and sleeping player characters.
---Population semantics intentionally mirror vanilla-visible IsoPlayer state:
---dead characters are excluded, while loading clients without an IsoPlayer do
---not exist in the denominator yet.
---@return integer|nil living Count of non-dead instantiated players, or nil on failure.
---@return integer|nil sleeping Count of living players with isAsleep()==true, or nil on failure.
---@return string|nil errorMessage Nil on success, descriptive text on failure.
local function countLivingAndSleepingPlayers()
    -- The global player accessor is required for the proportional denominator.
    if type(getOnlinePlayers) ~= "function" then
        return nil, nil, "getOnlinePlayers() unavailable"
    end

    local players = getOnlinePlayers()

    -- A nil collection is treated as an empty server rather than an error.
    if not players then return 0, 0, nil end

    local size, sizeErr = safeMethod(players, "size")
    size = tonumber(size)

    -- If collection size cannot be trusted, fail safe rather than using a partial count.
    if size == nil then
        return nil, nil, "could not read online-player count: " .. tostring(sizeErr)
    end

    local living = 0
    local sleeping = 0

    -- Inspect every instantiated IsoPlayer currently exposed by the server.
    for i = 0, size - 1 do
        local player, getErr = safeMethod(players, "get", i)

        -- A missing element makes the population snapshot unreliable; abort the pass.
        if not player then
            return nil, nil, "could not read player index " .. tostring(i) .. ": " .. tostring(getErr)
        end

        local dead, deadErr = safeMethod(player, "isDead")

        -- Unknown death state is unsafe because dead players must not enter the denominator.
        if dead == nil then
            return nil, nil, "could not read isDead() for player index " .. tostring(i) .. ": " .. tostring(deadErr)
        end

        -- Only living instantiated characters participate in proportional sleep math.
        if dead ~= true then
            living = living + 1

            local asleep, sleepErr = safeMethod(player, "isAsleep")

            -- Unknown sleep state would make the compression fraction ambiguous.
            if asleep == nil then
                return nil, nil, "could not read isAsleep() for player index " .. tostring(i) .. ": " .. tostring(sleepErr)
            end

            -- Count only actual vanilla sleep state; the mod never invents sleep intent.
            if asleep == true then
                sleeping = sleeping + 1
            end
        end
    end

    return living, sleeping, nil
end

---Convert the current native settings and player state into a pure clock decision.
---This function does not call any PZ mutation API; it only calculates the mode,
---compression factor, compensation factor, and target MinutesPerDay.
---@param nativeConfig table Output from readNativeConfig().
---@param modConfig table Output from getModConfig().
---@param living integer Number of living instantiated players.
---@param sleeping integer Number of those living players currently asleep.
---@return table decision Calculated mode and target values.
local function calculateDecision(nativeConfig, modConfig, living, sleeping)
    local nativeFF = nativeConfig.nativeFastForward
    local scale = modConfig.partialSleepSpeedScale
    local effectivePartialSleepCap = nativeFF * scale

    -- Empty server or zero sleepers means exact native baseline behavior.
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

    -- Defensive min() keeps malformed counts from creating a fraction above 1.0.
    local sleepFraction = math.min(1.0, sleeping / living)

    -- All living players asleep belongs entirely to vanilla. The theoretical
    -- compressed value is retained for diagnostics only; applying it here would
    -- stack MinutesPerDay compression with vanilla's own full-sleep fast-forward.
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

    -- Partial sleep scales the server's native fast-forward policy by the
    -- fraction of living players asleep. max(1.0, ...) guarantees the mod never
    -- lengthens the configured day or slows world time below native baseline.
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

---Log the inherited/native configuration once after baseline capture succeeds.
---This creates an administrator-visible audit record of the actual inputs used
---by the controller rather than relying on assumed/default server values.
---@param nativeConfig table Output from readNativeConfig().
---@param modConfig table Output from getModConfig().
---@return nil
local function maybeLogStartupConfig(nativeConfig, modConfig)
    -- Startup configuration should be logged once, and only after a baseline exists.
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

    -- A mismatch is noteworthy but not fatal: live GameTime is deliberately the
    -- operational source of truth, while the sandbox value is validation only.
    if nativeConfig.sandboxDayLengthMinutes
        and math.abs(nativeConfig.sandboxDayLengthMinutes - baselineMinutesPerDay) > EPSILON then
        log(string.format(
            "NOTICE | runtime MinutesPerDay (%s) differs from sandbox day-length minutes (%s); runtime value remains authoritative",
            formatNumber(baselineMinutesPerDay, 3),
            formatNumber(nativeConfig.sandboxDayLengthMinutes, 3)
        ))
    end
end

---Log a state transition only when its effective state signature changes.
---The signature includes population, sleep fraction, compression, target day
---length, and optional context so meaningful transitions remain visible while
---stable per-tick operation stays quiet.
---@param mode string Controller mode such as baseline, partial, vanilla, disabled, or fail-safe.
---@param living integer|nil Living-player count for this pass.
---@param sleeping integer|nil Sleeping-player count for this pass.
---@param decision table|nil Decision returned by calculateDecision().
---@param extra string|nil Additional diagnostic context.
---@return nil
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

    -- Identical state has already been logged; suppress duplicate per-tick output.
    if signature == lastStateSignature then return end

    lastStateSignature = signature

    -- Partial mode logs the values most useful for validating the proportional math.
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

    -- Vanilla mode explicitly records that the baseline was restored before handoff.
    elseif mode == "vanilla" then
        log(string.format(
            "STATE | mode=vanilla-full-sleep | living=%d | sleeping=%d | restoredMinutesPerDay=%s | theoreticalCompressedMinutesPerDay=%s | vanilla fast-forward owns full sleep",
            living,
            sleeping,
            formatNumber(baselineMinutesPerDay, 3),
            formatNumber(decision.theoreticalFullSleepMinutesPerDay, 3)
        ))

    -- Baseline, disabled, native-disabled, and fail-safe states share a concise format.
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

---Main server controller, invoked every tick (including paused ticks).
---The function follows a fail-safe pipeline:
---  1. ensure a native baseline exists;
---  2. honor the mod Enabled flag;
---  3. read native sleep/time policy;
---  4. honor native SleepAllowed;
---  5. count living/sleeping players;
---  6. calculate the desired clock state;
---  7. apply only the requested MinutesPerDay target.
---Any failure after baseline capture attempts to restore the exact native value.
---@return nil
local function update()
    local baselineOK, baselineErr = ensureBaseline()

    -- Without a trustworthy baseline we deliberately make no GameTime mutation.
    if not baselineOK then
        logErrorOnce(baselineErr)
        return
    end

    local modConfig = getModConfig()

    -- Disabling the mod must immediately return the server to its captured day length.
    if not modConfig.enabled then
        local restored, restoreErr = restoreBaseline()

        -- A restore failure remains visible and keeps retrying on subsequent ticks.
        if not restored then
            logErrorOnce(restoreErr)
        else
            clearError()
        end

        logStateIfChanged("disabled", 0, 0, nil, "mod disabled")
        return
    end

    local nativeConfig, nativeErr = readNativeConfig(false)

    -- Native policy is required for safe compression math; failure means baseline only.
    if not nativeConfig then
        restoreBaseline()
        logErrorOnce(nativeErr)
        logStateIfChanged("fail-safe", 0, 0, nil, nativeErr)
        return
    end

    maybeLogStartupConfig(nativeConfig, modConfig)

    -- Never use the mod to create partial sleep behavior when vanilla sleep is disabled.
    if not nativeConfig.sleepAllowed then
        local restored, restoreErr = restoreBaseline()

        -- Report a failure to restore, otherwise clear any earlier transient error.
        if not restored then
            logErrorOnce(restoreErr)
        else
            clearError()
        end

        logStateIfChanged("native-sleep-disabled", 0, 0, nil, "SleepAllowed=false")
        return
    end

    local living, sleeping, playerErr = countLivingAndSleepingPlayers()

    -- An unreliable player snapshot cannot safely drive a proportional denominator.
    if living == nil then
        restoreBaseline()
        logErrorOnce(playerErr)
        logStateIfChanged("fail-safe", 0, 0, nil, playerErr)
        return
    end

    local decision = calculateDecision(nativeConfig, modConfig, living, sleeping)
    local applied, applyErr = setMinutesPerDay(decision.targetMinutesPerDay)

    -- Any write failure immediately falls back toward the captured native baseline.
    if not applied then
        restoreBaseline()
        logErrorOnce(applyErr)
        logStateIfChanged("fail-safe", living, sleeping, decision, applyErr)
        return
    end

    -- Successful application closes any previous error episode and records only
    -- a genuine state transition, not every controller tick.
    clearError()
    logStateIfChanged(decision.mode, living, sleeping, decision, nil)
end

-- Every tick is intentional. The setter itself is deduplicated by comparing the
-- current and target MinutesPerDay values, while per-tick observation minimizes
-- the interval in which partial compression could overlap vanilla full-sleep
-- fast-forward when the final awake living player falls asleep.
Events.OnTickEvenPaused.Add(update)

log("Loaded v0.0.6 proportional calendar-compression prototype.")
log("Partial sleep changes MinutesPerDay only; global simulation multiplier is never modified.")
log("At 100% living players asleep, native MinutesPerDay is restored and vanilla sleep fast-forward takes over.")
