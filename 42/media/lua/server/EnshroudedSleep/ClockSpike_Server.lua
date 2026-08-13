if isClient() then return end

-- Enshrouded Sleep - Clock Spike
-- v0.0.1 diagnostic technical spike for Project Zomboid Build 42.20+
--
-- Purpose:
--   Verify that changing GameTime MinutesPerDay accelerates world/calendar
--   time without changing the normal simulation multiplier.
--
-- This intentionally DOES NOT implement sleep logic yet.

local ES = {}
local PREFIX = "[EnshroudedSleep:Spike]"

local state = {
    phase = "WAITING_FOR_PLAYER",
    baselineMinutesPerDay = nil,
    temporaryMinutesPerDay = nil,
    playerSeenAt = nil,
    accelerationStartedAt = nil,
    lastStatusLogAt = 0,
    complete = false,
}

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function now()
    return os.time()
end

local function getConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleepClockSpike or nil

    return {
        enabled = vars == nil or vars.Enabled ~= false,
        acceleration = math.max(1, tonumber(vars and vars.Acceleration) or 20),
        warmupSeconds = math.max(5, tonumber(vars and vars.WarmupSeconds) or 10),
        testSeconds = math.max(10, tonumber(vars and vars.TestSeconds) or 60),
    }
end

local function safeCall(obj, methodName)
    if not obj then return "nil" end

    local method = obj[methodName]
    if not method then return "N/A" end

    local ok, value = pcall(method, obj)
    if not ok then
        return "ERROR"
    end

    return value
end

local function getPlayerCount()
    local players = getOnlinePlayers()
    if not players then return 0 end
    return players:size()
end

local function formatClock(gameTime)
    local hour = safeCall(gameTime, "getHour")
    local minute = safeCall(gameTime, "getMinutes")

    if type(hour) == "number" and type(minute) == "number" then
        return string.format("%02d:%02d", hour, minute)
    end

    return tostring(safeCall(gameTime, "getTimeOfDay"))
end

local function logTimeState(label)
    local gt = getGameTime()
    if not gt then
        log(label .. " | getGameTime() returned nil")
        return
    end

    log(string.format(
        "%s | clock=%s | players=%d | MinutesPerDay=%s | Multiplier=%s | ServerMultiplier=%s | TrueMultiplier=%s | WorldAgeHours=%s",
        label,
        formatClock(gt),
        getPlayerCount(),
        tostring(safeCall(gt, "getMinutesPerDay")),
        tostring(safeCall(gt, "getMultiplier")),
        tostring(safeCall(gt, "getServerMultiplier")),
        tostring(safeCall(gt, "getTrueMultiplier")),
        tostring(safeCall(gt, "getWorldAgeHours"))
    ))
end

local function captureBaseline()
    if state.baselineMinutesPerDay ~= nil then return true end

    local gt = getGameTime()
    if not gt then return false end

    local value = safeCall(gt, "getMinutesPerDay")
    if type(value) ~= "number" or value <= 0 then
        log("ERROR: could not read a valid baseline MinutesPerDay.")
        return false
    end

    state.baselineMinutesPerDay = value
    log("Captured baseline MinutesPerDay=" .. tostring(value))
    return true
end

local function restoreBaseline(reason)
    if state.baselineMinutesPerDay == nil then return end

    local gt = getGameTime()
    if not gt then return end

    local current = safeCall(gt, "getMinutesPerDay")
    if type(current) == "number" and math.abs(current - state.baselineMinutesPerDay) < 0.0001 then
        return
    end

    local ok, err = pcall(gt.setMinutesPerDay, gt, state.baselineMinutesPerDay)
    if ok then
        log("Restored baseline MinutesPerDay=" .. tostring(state.baselineMinutesPerDay)
            .. " | reason=" .. tostring(reason))
        logTimeState("AFTER RESTORE")
    else
        log("ERROR restoring baseline MinutesPerDay: " .. tostring(err))
    end
end

local function beginAcceleration(config)
    if not captureBaseline() then return false end

    local gt = getGameTime()
    if not gt then return false end

    state.temporaryMinutesPerDay = state.baselineMinutesPerDay / config.acceleration

    logTimeState("BEFORE ACCELERATION")
    log(string.format(
        "Applying %.2fx CLOCK acceleration: MinutesPerDay %.4f -> %.4f",
        config.acceleration,
        state.baselineMinutesPerDay,
        state.temporaryMinutesPerDay
    ))

    local ok, err = pcall(gt.setMinutesPerDay, gt, state.temporaryMinutesPerDay)

    if not ok then
        log("ERROR applying setMinutesPerDay: " .. tostring(err))
        restoreBaseline("setMinutesPerDay failure")
        state.phase = "FAILED"
        state.complete = true
        return false
    end

    state.accelerationStartedAt = now()
    state.phase = "ACCELERATED"
    state.lastStatusLogAt = 0
    logTimeState("AFTER ACCELERATION")
    return true
end

local function finishTest()
    restoreBaseline("diagnostic test complete")
    state.phase = "COMPLETE"
    state.complete = true
    log("Diagnostic cycle COMPLETE. The mod will not run another spike until the server/Lua is restarted.")
end

local function update()
    local config = getConfig()

    if not config.enabled then
        if state.phase == "ACCELERATED" then
            restoreBaseline("diagnostic disabled")
        end
        return
    end

    if state.complete then return end

    local gt = getGameTime()
    if not gt then return end

    if not captureBaseline() then return end

    local playerCount = getPlayerCount()

    if state.phase == "WAITING_FOR_PLAYER" then
        if playerCount > 0 then
            state.playerSeenAt = now()
            state.phase = "WARMUP"
            log("First instantiated in-world player detected.")
            log("Warm-up started for " .. tostring(config.warmupSeconds) .. " real seconds.")
            logTimeState("WARMUP START")
        end
        return
    end

    if state.phase == "WARMUP" then
        if playerCount == 0 then
            state.phase = "WAITING_FOR_PLAYER"
            state.playerSeenAt = nil
            log("All players left during warm-up; returning to WAITING_FOR_PLAYER.")
            return
        end

        if now() - state.playerSeenAt >= config.warmupSeconds then
            beginAcceleration(config)
        end
        return
    end

    if state.phase == "ACCELERATED" then
        if playerCount == 0 then
            restoreBaseline("all players disconnected")
            state.phase = "WAITING_FOR_PLAYER"
            state.playerSeenAt = nil
            state.accelerationStartedAt = nil
            log("All players disconnected; spike cancelled and reset.")
            return
        end

        local elapsed = now() - state.accelerationStartedAt

        if state.lastStatusLogAt == 0 or now() - state.lastStatusLogAt >= 10 then
            state.lastStatusLogAt = now()
            logTimeState(string.format("ACCELERATED +%ds real", elapsed))
        end

        if elapsed >= config.testSeconds then
            finishTest()
        end
    end
end

Events.OnTickEvenPaused.Add(update)

log("Loaded v0.0.1 diagnostic clock spike.")
log("Waiting for the first instantiated in-world player.")
