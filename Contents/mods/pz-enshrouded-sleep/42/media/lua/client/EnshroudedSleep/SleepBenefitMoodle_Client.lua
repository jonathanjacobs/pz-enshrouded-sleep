-- Enshrouded Sleep - self-contained Rested / Well Rested client Moodle UI
-- Release Candidate v1.0.0 for Project Zomboid Build 42.20+
--
-- This renderer is intentionally narrow: it draws one non-stacking positive
-- sleep-benefit status using Enshrouded Sleep artwork and installed vanilla Moodle
-- UI resources. It does not register a custom vanilla MoodleType and does not
-- depend on Moodle Framework or Lifestyle. Lifestyle was reviewed as implementation
-- prior art only; no third-party code or artwork is redistributed here.
--
-- Presentation is fail-isolated. Any unexpected renderer/UI bridge exception
-- circuit-breaks this Moodle for the current client session rather than throwing
-- once per frame or affecting the XP/Endurance/sleep systems.

if not isClient() then return {} end

require "ISUI/ISUIElement"

local UI = {}
local PREFIX = "[EnshroudedSleepBenefits][MOODLE]"
local BENEFIT_NONE = "none"
local BENEFIT_RESTED = "rested"
local BENEFIT_WELL_RESTED = "well-rested"
local ICON_RESTED = "media/ui/Moodle_EnshroudedRested.png"
local ICON_WELL_RESTED = "media/ui/Moodle_EnshroudedWellRested.png"
local TOP_OFFSET = 120
local RIGHT_OFFSET = 10
local SLOT_GAP = 10

-- Mirrors the B42.20 base MoodleType registry so the Enshrouded Sleep slot can be
-- placed immediately below visible vanilla moodles without patching MoodlesUI.
-- Third-party custom Moodle renderers remain a compatibility-test boundary; the
-- Lifestyle special case below is read-only because that mod is present on the
-- target server and exposes enough runtime state to avoid overlap safely.
local VANILLA_MOODLES = {
    "ENDURANCE", "TIRED", "HUNGRY", "PANIC", "SICK", "BORED", "UNHAPPY",
    "BLEEDING", "WET", "HAS_A_COLD", "ANGRY", "STRESS", "THIRST", "INJURED",
    "PAIN", "HEAVY_LOAD", "DRUNK", "DEAD", "ZOMBIE", "HYPERTHERMIA",
    "HYPOTHERMIA", "WINDCHILL", "CANT_SPRINT", "UNCOMFORTABLE",
    "NOXIOUS_SMELL", "FOOD_EATEN",
}

local state = {
    benefitType = BENEFIT_NONE,
    expiresAtWorldHour = -1,
    xpBonusPercent = 0,
    enduranceRecoveryBonusPercent = 0,
}

local instance = nil
local lastError = nil
local loggedLifestyleCompatibility = false
local uiCapabilityDisabled = false

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

local function disableUI(element, reason)
    if uiCapabilityDisabled then return end
    uiCapabilityDisabled = true
    logErrorOnce("UI_DISABLED | " .. tostring(reason))
    if element then pcall(function() element:setVisible(false) end) end
end

local function currentWorldAgeHours()
    if type(getGameTime) ~= "function" then return nil end
    local ok, gt = pcall(getGameTime)
    if not ok or not gt then return nil end
    return tonumber(safeMethod(gt, "getWorldAgeHours"))
end

local function isActive()
    if state.benefitType ~= BENEFIT_RESTED and state.benefitType ~= BENEFIT_WELL_RESTED then
        return false
    end
    local expires = tonumber(state.expiresAtWorldHour)
    local now = currentWorldAgeHours()
    if expires ~= nil and expires >= 0 and now ~= nil and now >= expires then
        return false
    end
    return true
end

-- B42.20 supports 32/48/64/80/96/128 Moodle sizes. Option 7 follows the
-- configured real-font-size index; this mirrors vanilla MoodlesUI sizing.
local function getMoodleSize()
    local core = type(getCore) == "function" and getCore() or nil
    if not core then return 32 end

    local sizes = { 32, 48, 64, 80, 96, 128 }
    local option = tonumber(safeMethod(core, "getOptionMoodleSize")) or 1
    if option >= 1 and option <= #sizes then
        return sizes[option]
    end

    if option == 7 then
        local fontOption = tonumber(safeMethod(core, "getOptionFontSizeReal")) or 1
        if fontOption >= 1 and fontOption <= #sizes then
            return sizes[fontOption]
        end
    end

    return 32
end

local function getLocalPlayer()
    if type(getSpecificPlayer) == "function" then
        local player = getSpecificPlayer(0)
        if player then return 0, player end
    end
    return 0, type(getPlayer) == "function" and getPlayer() or nil
end

local function countVisibleVanillaMoodles(player)
    if not player then return 0 end
    local moodles = safeMethod(player, "getMoodles")
    if not moodles then return 0 end

    local count = 0
    for _, key in ipairs(VANILLA_MOODLES) do
        local okType, moodleType = pcall(function() return MoodleType and MoodleType[key] end)
        if okType and moodleType then
            local level = tonumber(safeMethod(moodles, "getMoodleLevel", moodleType)) or 0
            local visible = level > 0
            -- Vanilla hides FOOD_EATEN until the highest positive level.
            if key == "FOOD_EATEN" and level < 3 then visible = false end
            if visible then count = count + 1 end
        end
    end
    return count
end

-- Lifestyle uses its own ISUIElement moodles and exposes their active levels in
-- player ModData. When it is already loaded, reserve those active slots so the
-- Enshrouded Sleep icon does not overlap them. This is read-only and optional.
local function countVisibleLifestyleMoodles(player)
    local okManager, manager = pcall(function() return LSMoodleManager end)
    if not okManager or type(manager) ~= "table" then return 0 end

    local data = safeMethod(player, "getModData")
    local moodles = type(data) == "table" and data.LSMoodles or nil
    if type(moodles) ~= "table" then return 0 end

    local count = 0
    for _, entry in pairs(moodles) do
        if type(entry) == "table" and (tonumber(entry.Level) or 0) > 0 then
            count = count + 1
        end
    end

    if not loggedLifestyleCompatibility then
        loggedLifestyleCompatibility = true
        log("COMPAT | Lifestyle custom-moodle stack detected; reserving active Lifestyle slots")
    end

    return count
end

local function positionForPlayer(playerNum, player, size)
    local core = type(getCore) == "function" and getCore() or nil
    local screenLeft = 0
    local screenTop = 0
    local screenWidth = core and tonumber(safeMethod(core, "getScreenWidth")) or 0

    if type(getPlayerScreenLeft) == "function" then
        local ok, value = pcall(getPlayerScreenLeft, playerNum)
        if ok and tonumber(value) then screenLeft = tonumber(value) end
    end
    if type(getPlayerScreenTop) == "function" then
        local ok, value = pcall(getPlayerScreenTop, playerNum)
        if ok and tonumber(value) then screenTop = tonumber(value) end
    end
    if type(getPlayerScreenWidth) == "function" then
        local ok, value = pcall(getPlayerScreenWidth, playerNum)
        if ok and tonumber(value) then screenWidth = tonumber(value) end
    end

    local occupied = countVisibleVanillaMoodles(player) + countVisibleLifestyleMoodles(player)
    local x = screenLeft + screenWidth - RIGHT_OFFSET - size
    local y = screenTop + TOP_OFFSET + occupied * (size + SLOT_GAP)
    return x, y
end

local function formatPercent(value)
    local numeric = tonumber(value) or 0
    local rounded = math.floor(numeric + 0.5)
    if math.abs(numeric - rounded) < 0.01 then return tostring(rounded) .. "%" end
    return string.format("%.1f%%", numeric)
end

local function formatRemaining()
    local now = currentWorldAgeHours()
    local expires = tonumber(state.expiresAtWorldHour)
    if now == nil or expires == nil or expires < 0 then return nil end

    local remaining = math.max(0, expires - now)
    local hours = math.floor(remaining)
    local minutes = math.floor((remaining - hours) * 60 + 0.5)
    if minutes >= 60 then
        hours = hours + 1
        minutes = 0
    end
    if hours > 0 then return string.format("%dh %02dm remaining", hours, minutes) end
    return string.format("%dm remaining", minutes)
end

local function translated(key, fallback)
    if type(getText) ~= "function" then return fallback end
    local ok, value = pcall(getText, key)
    if not ok or value == nil or tostring(value) == key then return fallback end
    return tostring(value)
end

local SleepBenefitMoodle = ISUIElement:derive("EnshroudedSleepBenefitMoodle")

function SleepBenefitMoodle:initialise()
    ISUIElement.initialise(self)
end

function SleepBenefitMoodle:new(playerNum, player)
    local size = getMoodleSize()
    local x, y = positionForPlayer(playerNum, player, size)
    local o = ISUIElement:new(x, y, size, size)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.player = player
    o.keepOnScreen = false
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

function SleepBenefitMoodle:updatePlacement()
    local playerNum, player = getLocalPlayer()
    if not player then
        self:setVisible(false)
        return
    end

    self.playerNum = playerNum
    self.player = player

    local size = getMoodleSize()
    if self:getWidth() ~= size then self:setWidth(size) end
    if self:getHeight() ~= size then self:setHeight(size) end

    local x, y = positionForPlayer(playerNum, player, size)
    if self:getX() ~= x then self:setX(x) end
    if self:getY() ~= y then self:setY(y) end
end

function SleepBenefitMoodle:drawTooltip()
    if not self:isMouseOver() then return end

    local title
    local description
    local lines = {}
    if state.benefitType == BENEFIT_WELL_RESTED then
        title = translated("Moodles_EnshroudedWellRested", "Well Rested")
        description = translated(
            "Moodles_EnshroudedWellRested_desc",
            "You feel exceptionally refreshed after a long, restorative sleep."
        )
        lines[#lines + 1] = "+" .. formatPercent(state.xpBonusPercent) .. " Experience Gain"
        lines[#lines + 1] = "+" .. formatPercent(state.enduranceRecoveryBonusPercent) .. " Endurance Recovery"
    else
        title = translated("Moodles_EnshroudedRested", "Rested")
        description = translated(
            "Moodles_EnshroudedRested_desc",
            "You feel refreshed after a solid sleep."
        )
        lines[#lines + 1] = "+" .. formatPercent(state.xpBonusPercent) .. " Experience Gain"
    end

    local remaining = formatRemaining()
    if remaining then lines[#lines + 1] = remaining end

    local font = UIFont and UIFont.Small or nil
    local fontHeight = 14
    local textManager = type(getTextManager) == "function" and getTextManager() or nil
    if textManager and font then
        fontHeight = tonumber(safeMethod(textManager, "getFontHeight", font)) or fontHeight
    end

    local allLines = { title, description }
    for _, line in ipairs(lines) do allLines[#allLines + 1] = line end

    local width = 180
    if textManager and font then
        for _, line in ipairs(allLines) do
            local measured = tonumber(safeMethod(textManager, "MeasureStringX", font, line))
            if measured and measured + 18 > width then width = measured + 18 end
        end
    end

    local height = #allLines * fontHeight + 12
    local left = -width - 10
    self:drawRect(left, 0, width, height, 0.78, 0, 0, 0)

    local y = 5
    self:drawTextRight(title, -16, y, 1, 1, 1, 1, font)
    y = y + fontHeight
    self:drawTextRight(description, -16, y, 0.82, 0.82, 0.82, 1, font)
    y = y + fontHeight

    for _, line in ipairs(lines) do
        self:drawTextRight(line, -16, y, 0.45, 1.0, 0.55, 1, font)
        y = y + fontHeight
    end
end

function SleepBenefitMoodle:renderUnsafe()
    if not isActive() then
        self:setVisible(false)
        return
    end

    self:updatePlacement()
    if not self:getIsVisible() then return end

    local size = self:getWidth()
    local background = type(getTexture) == "function" and getTexture(
        "media/ui/Moodles/" .. tostring(size) .. "/_Moodles_BGsolid.png"
    ) or nil
    local border = type(getTexture) == "function" and getTexture(
        "media/ui/Moodles/" .. tostring(size) .. "/_Moodles_BGoutline.png"
    ) or nil
    local iconPath = state.benefitType == BENEFIT_WELL_RESTED and ICON_WELL_RESTED or ICON_RESTED
    local icon = type(getTexture) == "function" and getTexture(iconPath) or nil

    if background then
        -- Positive Moodle tint; the original icon art carries the tier-specific color.
        self:drawTextureScaled(background, 0, 0, size, size, 1, 0.45, 0.85, 0.48)
    end
    if border then self:drawTextureScaled(border, 0, 0, size, size, 1, 1, 1, 1) end
    if icon then
        self:drawTextureScaled(icon, 0, 0, size, size, 1, 1, 1, 1)
    else
        logErrorOnce("custom Rested/Well Rested icon texture unavailable")
    end

    self:drawTooltip()
    ISUIElement.render(self)
end

function SleepBenefitMoodle:render()
    if uiCapabilityDisabled then return end
    local ok, err = pcall(self.renderUnsafe, self)
    if not ok then disableUI(self, "render failed: " .. tostring(err)) end
end

function SleepBenefitMoodle:updateUnsafe()
    ISUIElement.update(self)
    if not isActive() then
        self:setVisible(false)
        return
    end
    self:setVisible(true)
    self:updatePlacement()
end

function SleepBenefitMoodle:update()
    if uiCapabilityDisabled then return end
    local ok, err = pcall(self.updateUnsafe, self)
    if not ok then disableUI(self, "update failed: " .. tostring(err)) end
end

local function ensureInstance()
    if uiCapabilityDisabled then return nil end

    local playerNum, player = getLocalPlayer()
    if not player then return nil end
    if instance then
        instance.playerNum = playerNum
        instance.player = player
        return instance
    end

    local ok, created = pcall(function()
        local ui = SleepBenefitMoodle:new(playerNum, player)
        ui:initialise()
        ui:addToUIManager()
        ui:setVisible(isActive())
        return ui
    end)

    if not ok or not created then
        disableUI(nil, "could not create self-contained Moodle UI: " .. tostring(created))
        return nil
    end

    instance = created
    log("Loaded self-contained Rested / Well Rested Moodle UI.")
    return instance
end

local function applyVisibility()
    if uiCapabilityDisabled then return false end
    local ui = ensureInstance()
    if not ui then return false end
    ui:setVisible(isActive())
    if isActive() then ui:updatePlacement() end
    return true
end

function UI.setState(newState)
    if type(newState) == "table" then
        state.benefitType = tostring(newState.benefitType or BENEFIT_NONE)
        state.expiresAtWorldHour = tonumber(newState.expiresAtWorldHour) or -1
        state.xpBonusPercent = math.max(0, tonumber(newState.xpBonusPercent) or 0)
        state.enduranceRecoveryBonusPercent = math.max(0, tonumber(newState.enduranceRecoveryBonusPercent) or 0)
    else
        state.benefitType = BENEFIT_NONE
        state.expiresAtWorldHour = -1
        state.xpBonusPercent = 0
        state.enduranceRecoveryBonusPercent = 0
    end

    if uiCapabilityDisabled then return false end
    local ok, result = pcall(applyVisibility)
    if not ok then
        disableUI(instance, "state update failed: " .. tostring(result))
        return false
    end
    return result == true
end

function UI.refresh()
    if uiCapabilityDisabled then return false end
    local ok, result = pcall(applyVisibility)
    if not ok then
        disableUI(instance, "refresh failed: " .. tostring(result))
        return false
    end
    return result == true
end

function UI.hide()
    if instance then pcall(function() instance:setVisible(false) end) end
end

function UI.isDisabled()
    return uiCapabilityDisabled
end

return UI
