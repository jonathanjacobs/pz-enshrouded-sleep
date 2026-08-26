-- Enshrouded Sleep - client sleep-status notification display
-- Public Beta v0.1.0 for Project Zomboid Build 42.20+
--
-- Receives server-authored sleep-state notifications and displays them through
-- Project Zomboid's client ServerChat path. This module is UI-only and never
-- changes GameTime or player state. Whether notifications are emitted is owned
-- entirely by the server administrator through SleepNotificationsEnabled.

if not isClient() then return end

local PREFIX = "[EnshroudedSleepNotify][CLIENT]"
local MODULE = "EnshroudedSleep"
local COMMAND = "SleepNotification"
local PROTOCOL_VERSION = 1

local pendingMessage = nil
local chatCapabilityDisabled = false
local lastError = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
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

local function disableChatCapability(reason)
    if chatCapabilityDisabled then return end
    chatCapabilityDisabled = true
    pendingMessage = nil
    logErrorOnce("chat display disabled for this session: " .. tostring(reason))
end

local function getChatManagerSafely()
    if chatCapabilityDisabled then return nil end
    if ChatManager == nil then
        disableChatCapability("ChatManager is not exposed to Lua")
        return nil
    end

    local okMethod, getInstance = pcall(function() return ChatManager.getInstance end)
    if not okMethod or not getInstance then
        disableChatCapability("ChatManager.getInstance unavailable")
        return nil
    end

    local ok, manager = pcall(getInstance)
    if not ok or not manager then
        disableChatCapability("ChatManager.getInstance failed")
        return nil
    end

    return manager
end

local function managerIsReady(manager)
    local okMethod, method = pcall(function() return manager.isWorking end)
    if not okMethod or not method then
        -- Older/exposed bindings may not provide isWorking; attempt delivery.
        return true
    end

    local ok, value = pcall(method, manager)
    if not ok then return true end
    return value == true
end

local function deliverPending()
    if not pendingMessage or chatCapabilityDisabled then return end

    local manager = getChatManagerSafely()
    if not manager or not managerIsReady(manager) then return end

    local okMethod, method = pcall(function() return manager.showServerChatMessage end)
    if not okMethod or not method then
        disableChatCapability("ChatManager.showServerChatMessage unavailable")
        return
    end

    local message = pendingMessage
    local ok, err = pcall(method, manager, message)
    if not ok then
        -- Circuit-break the UI bridge after one failure so a Kahlua exposure
        -- mismatch cannot repeat every tick or affect gameplay.
        disableChatCapability("showServerChatMessage failed: " .. tostring(err))
        return
    end

    pendingMessage = nil
    clearError()
    log("DISPLAY | " .. message)
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= COMMAND then return end
    if chatCapabilityDisabled then return end

    if not args then
        logErrorOnce("SleepNotification packet missing arguments")
        return
    end

    if tonumber(args.protocolVersion) ~= PROTOCOL_VERSION then
        logErrorOnce("unsupported SleepNotification protocolVersion=" .. tostring(args.protocolVersion))
        return
    end

    local message = tostring(args.message or "")
    if message == "" then
        logErrorOnce("SleepNotification packet missing message")
        return
    end

    -- Keep only the newest state if chat initialization briefly lags the packet.
    pendingMessage = message
    deliverPending()
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
else
    disableChatCapability("Events.OnServerCommand unavailable")
end

if Events.OnTick then
    Events.OnTick.Add(deliverPending)
end

log("Loaded Public Beta v0.1.0 optional sleep-status client display; messages are server-authored and server-admin controlled.")
