-- Enshrouded Sleep - client sleep-status notification display
-- Development candidate based on Public Beta v0.1.1 for Project Zomboid Build 42.20+
--
-- Receives server-authored sleep-state notifications and displays them through a
-- small self-contained ISUIElement banner. The live B42.20.4 Kahlua environment
-- does not expose ChatManager, so this module deliberately avoids that bridge.
-- This module is presentation-only and never changes GameTime or player state.

if not isClient() then return end

require "ISUI/ISUIElement"

local PREFIX = "[EnshroudedSleepNotify][CLIENT]"
local MODULE = "EnshroudedSleep"
local COMMAND = "SleepNotification"
local PROTOCOL_VERSION = 1
local BUILD_VERSION = "0.1.1+sleep-benefits-server-xp-dev"
local DISPLAY_SECONDS = 7

local banner = nil
local uiCapabilityDisabled = false
local lastError = nil
local lastServerBuild = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function logErrorOnce(message)
    message = tostring(message)
    if message == lastError then return end
    lastError = message
    log("ERROR | " .. message)
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function disableUI(reason)
    if uiCapabilityDisabled then return end
    uiCapabilityDisabled = true
    if banner then pcall(function() banner:setVisible(false) end) end
    logErrorOnce("UI_DISABLED | " .. tostring(reason))
end

local SleepNotificationBanner = ISUIElement:derive("EnshroudedSleepNotificationBanner")

function SleepNotificationBanner:initialise()
    ISUIElement.initialise(self)
end

function SleepNotificationBanner:new()
    local o = ISUIElement:new(0, 0, 640, 38)
    setmetatable(o, self)
    self.__index = self
    o.message = ""
    o.hideAtEpoch = 0
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.keepOnScreen = false
    return o
end

function SleepNotificationBanner:updatePlacement()
    local core = type(getCore) == "function" and getCore() or nil
    if not core then return end
    local width = tonumber(safeMethod(core, "getScreenWidth")) or 0
    if width <= 0 then return end
    self:setX(math.floor((width - self:getWidth()) / 2))
    self:setY(48)
end

function SleepNotificationBanner:showMessage(message)
    self.message = tostring(message or "")
    self.hideAtEpoch = os.time() + DISPLAY_SECONDS
    self:updatePlacement()
    self:setVisible(self.message ~= "")
end

function SleepNotificationBanner:updateUnsafe()
    ISUIElement.update(self)
    if not self:getIsVisible() then return end
    if os.time() >= (tonumber(self.hideAtEpoch) or 0) then
        self:setVisible(false)
        return
    end
    self:updatePlacement()
end

function SleepNotificationBanner:update()
    if uiCapabilityDisabled then return end
    local ok, err = pcall(self.updateUnsafe, self)
    if not ok then disableUI("notification banner update failed: " .. tostring(err)) end
end

function SleepNotificationBanner:renderUnsafe()
    if not self:getIsVisible() or self.message == "" then return end

    local font = UIFont and UIFont.Medium or nil
    local textManager = type(getTextManager) == "function" and getTextManager() or nil
    local textWidth = 0
    if textManager and font then
        textWidth = tonumber(safeMethod(textManager, "MeasureStringX", font, self.message)) or 0
    end

    local wantedWidth = math.max(360, math.min(900, textWidth + 36))
    if self:getWidth() ~= wantedWidth then
        self:setWidth(wantedWidth)
        self:updatePlacement()
    end

    self:drawRect(0, 0, self:getWidth(), self:getHeight(), 0.78, 0.03, 0.03, 0.03)
    self:drawRectBorder(0, 0, self:getWidth(), self:getHeight(), 0.82, 0.72, 0.86, 0.72)

    local x = 18
    if textWidth > 0 then x = math.max(18, math.floor((self:getWidth() - textWidth) / 2)) end
    self:drawText(self.message, x, 9, 0.92, 1.0, 0.92, 1, font)

    ISUIElement.render(self)
end

function SleepNotificationBanner:render()
    if uiCapabilityDisabled then return end
    local ok, err = pcall(self.renderUnsafe, self)
    if not ok then disableUI("notification banner render failed: " .. tostring(err)) end
end

local function ensureBanner()
    if uiCapabilityDisabled then return nil end
    if banner then return banner end

    local ok, created = pcall(function()
        local ui = SleepNotificationBanner:new()
        ui:initialise()
        ui:addToUIManager()
        ui:setVisible(false)
        return ui
    end)

    if not ok or not created then
        disableUI("could not create notification banner: " .. tostring(created))
        return nil
    end

    banner = created
    return banner
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= COMMAND then return end
    if uiCapabilityDisabled then return end

    if not args then
        logErrorOnce("SleepNotification packet missing arguments")
        return
    end

    if tonumber(args.protocolVersion) ~= PROTOCOL_VERSION then
        logErrorOnce("unsupported SleepNotification protocolVersion=" .. tostring(args.protocolVersion))
        return
    end

    local serverBuild = tostring(args.buildVersion or "unknown")
    if serverBuild ~= lastServerBuild then
        lastServerBuild = serverBuild
        log("SERVER_BUILD | " .. serverBuild)
    end
    if serverBuild ~= BUILD_VERSION then
        logErrorOnce("BUILD_MISMATCH | client=" .. BUILD_VERSION .. " | server=" .. serverBuild)
    end

    local message = tostring(args.message or "")
    if message == "" then
        logErrorOnce("SleepNotification packet missing message")
        return
    end

    local ui = ensureBanner()
    if not ui then return end

    local ok, err = pcall(ui.showMessage, ui, message)
    if not ok then
        disableUI("notification display failed: " .. tostring(err))
        return
    end

    log("DISPLAY | " .. message)
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
else
    disableUI("Events.OnServerCommand unavailable")
end

log("Loaded sleep-status banner | build=" .. BUILD_VERSION .. " | server-authored, server-admin controlled.")
