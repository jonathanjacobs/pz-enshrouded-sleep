-- Enshrouded Sleep - optional multiplayer sleep-status notifications
-- Public Beta v0.1.1 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Broadcast concise sleep-state/time-compression notifications to connected
-- clients when the server administrator enables SleepNotificationsEnabled.
--
-- DESIGN BOUNDARY
-- ---------------
-- This module is observational. It never changes GameTime, player state, sleep
-- policy, or awake-player protection. The authoritative controller still owns
-- MinutesPerDay. Notifications are derived from settled authoritative
-- MinutesPerDay so chat cannot become a second policy engine.

if isClient() then return end

local PREFIX = "[EnshroudedSleepNotify][SERVER]"
local MODULE = "EnshroudedSleep"
local COMMAND = "SleepNotification"
local PROTOCOL_VERSION = 1
local BUILD_VERSION = "0.1.1"
local EPSILON = 0.0001

local baselineMinutesPerDay = nil
local lastPopulationSignature = nil
local lastNotificationSignature = nil
local hadSleepingState = false
local lastError = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function logErrorOnce(message)
    message = tostring(message)
    if message == lastError then return end
    lastError = message
    log("ERROR | " .. message)
end

local function clearError()
    lastError = nil
end

local function getConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local forcedFactor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    return {
        modEnabled = vars == nil or vars.Enabled ~= false,
        notificationsEnabled = vars ~= nil and vars.SleepNotificationsEnabled == true,
        diagnosticForced = vars ~= nil
            and vars.DiagnosticsEnabled == true
            and forcedFactor > 1.0 + EPSILON,
    }
end

local function collectPopulation()
    if type(getOnlinePlayers) ~= "function" then return nil, nil end
    local players = getOnlinePlayers()
    if not players then return 0, 0 end

    local size = tonumber(safeMethod(players, "size"))
    if size == nil then return nil, nil end

    local living = 0
    local sleeping = 0
    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if player and safeMethod(player, "isDead") ~= true then
            living = living + 1
            if safeMethod(player, "isAsleep") == true then sleeping = sleeping + 1 end
        end
    end

    return living, sleeping
end

local function formatFactor(value)
    if not value or value <= 1.0 + EPSILON then return "1x" end
    local roundedInteger = math.floor(value + 0.5)
    if math.abs(value - roundedInteger) < 0.05 then
        return tostring(roundedInteger) .. "x"
    end
    return string.format("%.1fx", value)
end

local function broadcast(message, living, sleeping, compression)
    if type(sendServerCommand) ~= "function" then
        logErrorOnce("sendServerCommand() unavailable; sleep notification not sent")
        return false
    end

    local args = {
        protocolVersion = PROTOCOL_VERSION,
        buildVersion = BUILD_VERSION,
        message = message,
        living = living,
        sleeping = sleeping,
        calendarCompressionFactor = compression,
        serverEpoch = os.time(),
    }

    local ok, err = pcall(sendServerCommand, MODULE, COMMAND, args)
    if not ok then
        logErrorOnce("sendServerCommand failed: " .. tostring(err))
        return false
    end

    clearError()
    log("BROADCAST | " .. message)
    return true
end

local function resetNotificationState()
    lastPopulationSignature = nil
    lastNotificationSignature = nil
    hadSleepingState = false
end

local function update()
    local config = getConfig()
    if not config.modEnabled or not config.notificationsEnabled or config.diagnosticForced then
        resetNotificationState()
        return
    end

    local gt = type(getGameTime) == "function" and getGameTime() or nil
    if not gt then return end

    local minutesPerDay = tonumber(safeMethod(gt, "getMinutesPerDay"))
    if not minutesPerDay or minutesPerDay <= 0 then return end

    if baselineMinutesPerDay == nil or minutesPerDay > baselineMinutesPerDay then
        baselineMinutesPerDay = minutesPerDay
    end

    local living, sleeping = collectPopulation()
    if living == nil or sleeping == nil then return end
    if living <= 0 then
        resetNotificationState()
        return
    end

    local mode
    if sleeping <= 0 then
        mode = "baseline"
    elseif sleeping >= living then
        mode = "vanilla-full-sleep"
    else
        mode = "partial"
    end

    local populationSignature = table.concat({ mode, tostring(living), tostring(sleeping) }, "|")

    if populationSignature ~= lastPopulationSignature then
        lastPopulationSignature = populationSignature
        return
    end

    local compression = 1.0
    if baselineMinutesPerDay and baselineMinutesPerDay > 0 then
        compression = math.max(1.0, baselineMinutesPerDay / minutesPerDay)
    end

    local notificationSignature = table.concat({
        populationSignature,
        string.format("%.4f", compression),
    }, "|")
    if notificationSignature == lastNotificationSignature then return end

    if sleeping <= 0 then
        if hadSleepingState then
            local message = "[Enshrouded Sleep] All living players are awake. Time is normal."
            if broadcast(message, living, sleeping, 1.0) then
                hadSleepingState = false
                lastNotificationSignature = notificationSignature
            end
        else
            lastNotificationSignature = notificationSignature
        end
        return
    end

    hadSleepingState = true

    local message
    if sleeping >= living then
        message = string.format(
            "[Enshrouded Sleep] All %d living player%s sleeping. Vanilla fast-forward active.",
            living,
            living == 1 and " is" or "s are"
        )
    else
        local percent = math.floor(((sleeping / living) * 100.0) + 0.5)
        if compression <= 1.0 + EPSILON then
            message = string.format(
                "[Enshrouded Sleep] %d/%d living players sleeping (%d%%). Time is normal.",
                sleeping,
                living,
                percent
            )
        else
            message = string.format(
                "[Enshrouded Sleep] %d/%d living players sleeping (%d%%). Time is %s faster.",
                sleeping,
                living,
                percent,
                formatFactor(compression)
            )
        end
    end

    if broadcast(message, living, sleeping, compression) then
        lastNotificationSignature = notificationSignature
    end
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(update)
else
    Events.OnTick.Add(update)
end

log("Loaded Public Beta v0.1.1 optional sleep-status broadcaster; server-admin controlled and disabled unless SleepNotificationsEnabled=true.")
