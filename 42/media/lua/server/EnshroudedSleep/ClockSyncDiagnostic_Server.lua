-- Enshrouded Sleep - server clock and sleep synchronization diagnostic
-- v0.0.7 verification instrumentation for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record the authoritative server GameTime state once per real second and, when
-- at least one player is asleep, record each living player's vanilla sleep
-- counters. v0.0.6 established that explicit client MinutesPerDay replication
-- fixes the visible clock drift and that client-side sleep counters track
-- compressed world time sensibly.
--
-- v0.0.7 retains this instrumentation for one clean regression after fixing the
-- client post-apply logging exception. Server-side AsleepTime/ForceWakeUpTime
-- values may remain unavailable or non-authoritative; the local sleeping-client
-- values are the useful sleep-duration evidence.
--
-- IMPORTANT: this file is observational only. It never changes GameTime,
-- player state, sleep state, fatigue, pills, or native synchronization behavior.

if isClient() then return end

local PREFIX = "[EnshroudedSleepDiag][SERVER]"
local SAMPLE_INTERVAL_SECONDS = 1
local lastSampleAt = -1
local lastError = nil

---Write one namespaced diagnostic message to the dedicated-server log.
---@param message any Value to stringify.
---@return nil
local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

---Format a number while allowing missing/unavailable diagnostic values.
---@param value any Value to format.
---@param decimals integer|nil Decimal places; defaults to 4.
---@return string formattedValue
local function formatNumber(value, decimals)
    if type(value) ~= "number" then return tostring(value or "N/A") end
    return string.format("%." .. tostring(decimals or 4) .. "f", value)
end

---Safely call a Java/Lua method for diagnostics.
---@param obj any Object expected to expose methodName.
---@param methodName string Method name.
---@param ... any Method arguments.
---@return any|nil value
local function safeMethod(obj, methodName, ...)
    if not obj then return nil end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end

    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end

    return value
end

---Collect instantiated living players and aggregate sleep counts without mutating
---their state. Player objects are returned for per-player sleep telemetry.
---@return integer|nil living
---@return integer|nil sleeping
---@return table playerStates
local function collectPlayers()
    local playerStates = {}
    if type(getOnlinePlayers) ~= "function" then return nil, nil, playerStates end

    local players = getOnlinePlayers()
    if not players then return 0, 0, playerStates end

    local size = tonumber(safeMethod(players, "size"))
    if size == nil then return nil, nil, playerStates end

    local living = 0
    local sleeping = 0

    -- Inspect each currently instantiated IsoPlayer without changing it.
    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if not player then return nil, nil, {} end

        local dead = safeMethod(player, "isDead")
        if dead == nil then return nil, nil, {} end

        if dead ~= true then
            living = living + 1

            local asleep = safeMethod(player, "isAsleep")
            if asleep == nil then return nil, nil, {} end
            if asleep == true then sleeping = sleeping + 1 end

            local stats = safeMethod(player, "getStats")

            playerStates[#playerStates + 1] = {
                playerName = tostring(
                    safeMethod(player, "getUsername")
                    or safeMethod(player, "getDisplayName")
                    or "N/A"
                ),
                onlineID = tonumber(safeMethod(player, "getOnlineID")),
                asleep = asleep,
                dead = dead,
                asleepTime = tonumber(safeMethod(player, "getAsleepTime")),
                forceWakeUpTime = tonumber(safeMethod(player, "getForceWakeUpTime")),
                fatigue = tonumber(safeMethod(stats, "getFatigue")),
                sleepingPillsTaken = tonumber(safeMethod(player, "getSleepingPillsTaken")),
            }
        end
    end

    return living, sleeping, playerStates
end

---Derive a descriptive state from the observed population only.
---This is diagnostic labeling, not a second source of authoritative behavior.
---@param living integer|nil
---@param sleeping integer|nil
---@return string mode
local function deriveMode(living, sleeping)
    if living == nil or sleeping == nil then return "unknown" end
    if living <= 0 or sleeping <= 0 then return "baseline" end
    if sleeping >= living then return "vanilla-full-sleep" end
    return "partial"
end

---Capture one authoritative server clock/sleep sample per real second.
---@return nil
local function sampleClock()
    local now = os.time()

    -- The event fires many times per second; wall-clock gating keeps logs readable.
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then
        return
    end
    lastSampleAt = now

    local gt = getGameTime()

    if not gt then
        if lastError ~= "getGameTime() unavailable" then
            lastError = "getGameTime() unavailable"
            log("ERROR | " .. lastError)
        end
        return
    end

    local living, sleeping, playerStates = collectPlayers()

    -- Suppress idle-server samples; startup still emits the loaded message below.
    if living == 0 then
        lastError = nil
        return
    end

    lastError = nil

    local minutesPerDay = tonumber(safeMethod(gt, "getMinutesPerDay"))
    local timeOfDay = tonumber(safeMethod(gt, "getTimeOfDay"))
    local worldAgeHours = tonumber(safeMethod(gt, "getWorldAgeHours"))
    local multiplier = tonumber(safeMethod(gt, "getMultiplier"))
    local trueMultiplier = tonumber(safeMethod(gt, "getTrueMultiplier"))
    local serverMultiplier = tonumber(safeMethod(gt, "getServerMultiplier"))
    local deltaMinutesPerDay = tonumber(safeMethod(gt, "getDeltaMinutesPerDay"))

    log(string.format(
        "SAMPLE | epoch=%d | mode=%s | living=%s | sleeping=%s | MinutesPerDay=%s | TimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | Multiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s",
        now,
        deriveMode(living, sleeping),
        tostring(living or "N/A"),
        tostring(sleeping or "N/A"),
        formatNumber(minutesPerDay, 4),
        formatNumber(timeOfDay, 6),
        formatNumber(worldAgeHours, 6),
        formatNumber(deltaMinutesPerDay, 6),
        formatNumber(multiplier, 4),
        formatNumber(trueMultiplier, 4),
        formatNumber(serverMultiplier, 4)
    ))

    -- Keep server-side sleep values for correlation even though the v0.0.6 run
    -- showed that local client sleep counters provide the meaningful wake data.
    if sleeping and sleeping > 0 then
        for _, state in ipairs(playerStates) do
            log(string.format(
                "PLAYER | epoch=%d | player=%s | onlineID=%s | asleep=%s | AsleepTime=%s | ForceWakeUpTime=%s | Fatigue=%s | SleepingPillsTaken=%s",
                now,
                state.playerName,
                tostring(state.onlineID or "N/A"),
                tostring(state.asleep),
                formatNumber(state.asleepTime, 6),
                formatNumber(state.forceWakeUpTime, 6),
                formatNumber(state.fatigue, 6),
                tostring(state.sleepingPillsTaken or "N/A")
            ))
        end
    end
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleClock)
else
    Events.OnTick.Add(sampleClock)
end

log("Loaded v0.0.7 server clock/sleep diagnostic.")
