-- Enshrouded Sleep - server clock synchronization diagnostic
-- v0.0.5 diagnostic instrumentation for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record the authoritative server's GameTime state once per real second so it
-- can be correlated with the v0.0.5 client clock diagnostic. This is intended
-- to identify whether visual clock snapping originates in MinutesPerDay
-- replication, multiplayer clock synchronization, or the client UI layer.
--
-- IMPORTANT: this file is observational only. It never changes GameTime,
-- player state, sleep state, or native synchronization behavior.

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

---Safely read a public Java field exposed through Kahlua.
---@param obj any Java/Lua object.
---@param fieldName string Public field name.
---@return any|nil value
local function safeField(obj, fieldName)
    if not obj then return nil end

    local ok, value = pcall(function() return obj[fieldName] end)
    if not ok then return nil end

    return value
end

---Count instantiated living and sleeping players for diagnostic correlation.
---Unlike the authoritative controller, a failed read does not alter GameTime;
---the sample simply reports N/A counts.
---@return integer|nil living
---@return integer|nil sleeping
local function countPlayers()
    if type(getOnlinePlayers) ~= "function" then return nil, nil end

    local players = getOnlinePlayers()
    if not players then return 0, 0 end

    local size = tonumber(safeMethod(players, "size"))
    if size == nil then return nil, nil end

    local living = 0
    local sleeping = 0

    -- Inspect each currently instantiated IsoPlayer without mutating it.
    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if not player then return nil, nil end

        local dead = safeMethod(player, "isDead")
        if dead == nil then return nil, nil end

        -- Mirror the controller's population semantics for useful log correlation.
        if dead ~= true then
            living = living + 1
            local asleep = safeMethod(player, "isAsleep")
            if asleep == nil then return nil, nil end
            if asleep == true then sleeping = sleeping + 1 end
        end
    end

    return living, sleeping
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

---Capture one authoritative server clock sample per real second.
---@return nil
local function sampleClock()
    local now = os.time()

    -- The event fires many times per second; wall-clock gating keeps logs readable.
    if now == lastSampleAt or (lastSampleAt >= 0 and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS) then
        return
    end
    lastSampleAt = now

    local gt = getGameTime()

    -- Diagnostics must never turn a missing GameTime object into a server failure.
    if not gt then
        if lastError ~= "getGameTime() unavailable" then
            lastError = "getGameTime() unavailable"
            log("ERROR | " .. lastError)
        end
        return
    end

    local living, sleeping = countPlayers()

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
    local serverTimeOfDay = tonumber(safeField(gt, "ServerTimeOfDay"))
    local serverLastTimeOfDay = tonumber(safeField(gt, "ServerLastTimeOfDay"))
    local rawTimeOfDay = tonumber(safeField(gt, "TimeOfDay"))

    log(string.format(
        "SAMPLE | epoch=%d | mode=%s | living=%s | sleeping=%s | MinutesPerDay=%s | TimeOfDay=%s | RawTimeOfDay=%s | ServerTimeOfDay=%s | ServerLastTimeOfDay=%s | WorldAgeHours=%s | DeltaMinutesPerDay=%s | Multiplier=%s | TrueMultiplier=%s | ServerMultiplier=%s",
        now,
        deriveMode(living, sleeping),
        tostring(living or "N/A"),
        tostring(sleeping or "N/A"),
        formatNumber(minutesPerDay, 4),
        formatNumber(timeOfDay, 6),
        formatNumber(rawTimeOfDay, 6),
        formatNumber(serverTimeOfDay, 6),
        formatNumber(serverLastTimeOfDay, 6),
        formatNumber(worldAgeHours, 6),
        formatNumber(deltaMinutesPerDay, 6),
        formatNumber(multiplier, 4),
        formatNumber(trueMultiplier, 4),
        formatNumber(serverMultiplier, 4)
    ))
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(sampleClock)
else
    Events.OnTick.Add(sampleClock)
end

log("Loaded v0.0.5 read-only server clock synchronization diagnostic.")
