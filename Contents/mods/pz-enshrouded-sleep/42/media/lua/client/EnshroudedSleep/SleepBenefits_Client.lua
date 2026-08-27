-- Enshrouded Sleep - owning-client Rested / Well Rested behavior
-- Development candidate based on Public Beta v0.1.1 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Receive server-authoritative sleep-benefit state, apply the configured XP bonus
-- to positive AddXP events, and optionally display Rested / Well Rested through
-- Tchernobill's Moodle Framework when that framework is installed.
--
-- SAFETY
-- ------
-- * The client does not decide whether sleep qualified for a benefit.
-- * XP bonus percentages come only from server SleepBenefitState packets.
-- * Bonus XP uses addXpNoMultiplier() and a recursion guard so the additional XP
--   is not multiplied again or recursively awarded.
-- * Moodle Framework is a soft integration. If it is absent or its API fails,
--   the gameplay benefit remains active and only the custom Moodle UI is lost.
-- * No third-party Moodle Framework code or assets are redistributed here.

if not isClient() then return end

local PREFIX = "[EnshroudedSleepBenefits][CLIENT]"
local MODULE = "EnshroudedSleep"
local COMMAND = "SleepBenefitState"
local PROTOCOL_VERSION = 1
local BENEFIT_NONE = "none"
local BENEFIT_RESTED = "rested"
local BENEFIT_WELL_RESTED = "well-rested"
local MOODLE_RESTED = "EnshroudedRested"
local MOODLE_WELL_RESTED = "EnshroudedWellRested"
local EPSILON = 0.0000001

local state = {
    benefitType = BENEFIT_NONE,
    expiresAtWorldHour = -1,
    xpBonusPercent = 0,
    enduranceRecoveryBonusPercent = 0,
    lastQualifyingSleepHours = 0,
    diagnosticsEnabled = false,
}

local applyingBonusXP = false
local xpCapabilityDisabled = false
local moodleFrameworkAvailable = false
local moodleCapabilityDisabled = false
local moodlesCreated = false
local lastMoodleDescriptionSignature = nil
local lastStateSignature = nil
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

local function currentWorldAgeHours()
    if type(getGameTime) ~= "function" then return nil end
    local ok, gt = pcall(getGameTime)
    if not ok or not gt then return nil end
    local okMethod, method = pcall(function() return gt.getWorldAgeHours end)
    if not okMethod or not method then return nil end
    local okValue, value = pcall(method, gt)
    if not okValue then return nil end
    return tonumber(value)
end

local function stateIsActive()
    if state.benefitType ~= BENEFIT_RESTED and state.benefitType ~= BENEFIT_WELL_RESTED then
        return false
    end
    local now = currentWorldAgeHours()
    if now ~= nil and tonumber(state.expiresAtWorldHour) and now >= tonumber(state.expiresAtWorldHour) then
        return false
    end
    return true
end

local function findPlayerNumForOnlineID(onlineID)
    local wanted = tonumber(onlineID)
    for playerNum = 0, 3 do
        local player = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
        if player then
            local okMethod, method = pcall(function() return player.getOnlineID end)
            if okMethod and method then
                local ok, value = pcall(method, player)
                if ok and (wanted == nil or tonumber(value) == wanted) then
                    return playerNum, player
                end
            elseif playerNum == 0 then
                return 0, player
            end
        end
    end
    return 0, getPlayer and getPlayer() or nil
end

local function initializeMoodleFramework()
    if moodlesCreated or moodleCapabilityDisabled then return end

    local okRequire, err = pcall(require, "MF_ISMoodle")
    if not okRequire then
        moodleFrameworkAvailable = false
        moodleCapabilityDisabled = true
        log("MOODLES | optional Moodle Framework not installed; benefits remain active without custom moodles")
        return
    end

    if type(MF) ~= "table" or type(MF.createMoodle) ~= "function" or type(MF.getMoodle) ~= "function" then
        moodleFrameworkAvailable = false
        moodleCapabilityDisabled = true
        logErrorOnce("Moodle Framework loaded without expected MF API; custom moodles disabled")
        return
    end

    local okRested, errRested = pcall(MF.createMoodle, MOODLE_RESTED)
    local okWell, errWell = pcall(MF.createMoodle, MOODLE_WELL_RESTED)
    if not okRested or not okWell then
        moodleFrameworkAvailable = false
        moodleCapabilityDisabled = true
        logErrorOnce("MF.createMoodle failed: " .. tostring(errRested or errWell))
        return
    end

    moodleFrameworkAvailable = true
    moodlesCreated = true
    clearError()
    log("MOODLES | optional Moodle Framework integration active")
end

local function safeMoodle(name, playerNum)
    if not moodleFrameworkAvailable or moodleCapabilityDisabled or type(MF) ~= "table" then return nil end
    local ok, moodle = pcall(MF.getMoodle, name, playerNum)
    if not ok then
        moodleCapabilityDisabled = true
        logErrorOnce("MF.getMoodle failed; custom moodles disabled for this session")
        return nil
    end
    return moodle
end

local function callMoodle(moodle, methodName, ...)
    if not moodle or moodleCapabilityDisabled then return false end
    local okMethod, method = pcall(function() return moodle[methodName] end)
    if not okMethod or not method then return false end
    local ok, err = pcall(method, moodle, ...)
    if not ok then
        moodleCapabilityDisabled = true
        logErrorOnce("Moodle Framework " .. tostring(methodName) .. " failed: " .. tostring(err))
        return false
    end
    return true
end

local function formatPercent(value)
    local numeric = tonumber(value) or 0
    if math.abs(numeric - math.floor(numeric + 0.5)) < 0.01 then
        return tostring(math.floor(numeric + 0.5)) .. "%"
    end
    return string.format("%.1f%%", numeric)
end

local function formatRemainingHours()
    local now = currentWorldAgeHours()
    local expires = tonumber(state.expiresAtWorldHour)
    if now == nil or expires == nil or expires < 0 then return "" end
    local remaining = math.max(0, expires - now)
    if remaining >= 1 then return string.format("%.1f game hours remaining", remaining) end
    return string.format("%d game minutes remaining", math.max(0, math.floor(remaining * 60 + 0.5)))
end

local function updateMoodles()
    initializeMoodleFramework()
    if not moodleFrameworkAvailable or moodleCapabilityDisabled then return end

    local playerNum = findPlayerNumForOnlineID(state.onlineID)
    local rested = safeMoodle(MOODLE_RESTED, playerNum)
    local wellRested = safeMoodle(MOODLE_WELL_RESTED, playerNum)
    if not rested or not wellRested then return end

    local active = stateIsActive()
    local restedActive = active and state.benefitType == BENEFIT_RESTED
    local wellActive = active and state.benefitType == BENEFIT_WELL_RESTED

    -- Moodle Framework's default hidden band includes 0.5; 1.0 renders Good lvl4.
    callMoodle(rested, "setValue", restedActive and 1.0 or 0.5)
    callMoodle(wellRested, "setValue", wellActive and 1.0 or 0.5)

    local remainingText = formatRemainingHours()
    local signature = table.concat({
        tostring(state.benefitType),
        tostring(state.xpBonusPercent),
        tostring(state.enduranceRecoveryBonusPercent),
        remainingText,
    }, "|")
    if signature == lastMoodleDescriptionSignature then return end
    lastMoodleDescriptionSignature = signature

    local restedDesc = "After a solid sleep: +" .. formatPercent(state.xpBonusPercent) .. " XP gain."
    if remainingText ~= "" then restedDesc = restedDesc .. " " .. remainingText .. "." end

    local wellDesc = "After a long, restorative sleep: +" .. formatPercent(state.xpBonusPercent)
        .. " XP gain and +" .. formatPercent(state.enduranceRecoveryBonusPercent) .. " endurance recovery."
    if remainingText ~= "" then wellDesc = wellDesc .. " " .. remainingText .. "." end

    -- The current Moodle Framework exposes dynamic title/description overrides.
    -- These calls are optional so a future framework API change degrades to the
    -- static translation text rather than affecting gameplay.
    callMoodle(rested, "setTitle", 1, 4, "Rested")
    callMoodle(rested, "setDescription", 1, 4, restedDesc)
    callMoodle(wellRested, "setTitle", 1, 4, "Well Rested")
    callMoodle(wellRested, "setDescription", 1, 4, wellDesc)
end

local function applyState(args)
    local benefitType = tostring(args.benefitType or BENEFIT_NONE)
    if benefitType ~= BENEFIT_RESTED and benefitType ~= BENEFIT_WELL_RESTED then
        benefitType = BENEFIT_NONE
    end

    state.benefitType = benefitType
    state.expiresAtWorldHour = tonumber(args.expiresAtWorldHour) or -1
    state.xpBonusPercent = math.max(0, tonumber(args.xpBonusPercent) or 0)
    state.enduranceRecoveryBonusPercent = math.max(0, tonumber(args.enduranceRecoveryBonusPercent) or 0)
    state.lastQualifyingSleepHours = math.max(0, tonumber(args.lastQualifyingSleepHours) or 0)
    state.diagnosticsEnabled = args.diagnosticsEnabled == true
    state.onlineID = tonumber(args.onlineID)

    local signature = table.concat({
        state.benefitType,
        string.format("%.4f", state.expiresAtWorldHour),
        string.format("%.4f", state.xpBonusPercent),
        string.format("%.4f", state.enduranceRecoveryBonusPercent),
    }, "|")

    if signature ~= lastStateSignature then
        lastStateSignature = signature
        log(string.format(
            "STATE | benefit=%s | expiresAtWorldHour=%.3f | xpBonus=%.3f%% | enduranceRecoveryBonus=%.3f%% | lastSleepHours=%.3f",
            state.benefitType, state.expiresAtWorldHour, state.xpBonusPercent,
            state.enduranceRecoveryBonusPercent, state.lastQualifyingSleepHours
        ))
    end

    updateMoodles()
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= COMMAND then return end
    if not args then
        logErrorOnce("SleepBenefitState packet missing arguments")
        return
    end
    if tonumber(args.protocolVersion) ~= PROTOCOL_VERSION then
        logErrorOnce("unsupported SleepBenefitState protocolVersion=" .. tostring(args.protocolVersion))
        return
    end
    clearError()
    applyState(args)
end

local function onAddXP(character, perk, amount)
    if applyingBonusXP or xpCapabilityDisabled then return end
    if not stateIsActive() then return end

    local player = getPlayer and getPlayer() or nil
    if not player or character ~= player then return end

    local numericAmount = tonumber(amount)
    if numericAmount == nil or numericAmount <= EPSILON then return end

    local percent = tonumber(state.xpBonusPercent) or 0
    if percent <= EPSILON then return end

    local bonus = numericAmount * (percent / 100.0)
    if bonus <= EPSILON then return end

    if type(addXpNoMultiplier) ~= "function" then
        xpCapabilityDisabled = true
        logErrorOnce("addXpNoMultiplier() unavailable; Rested XP bonus disabled for this client session")
        return
    end

    applyingBonusXP = true
    local ok, err = pcall(addXpNoMultiplier, player, perk, bonus)
    applyingBonusXP = false

    if not ok then
        xpCapabilityDisabled = true
        logErrorOnce("addXpNoMultiplier failed; Rested XP bonus disabled for this client session: " .. tostring(err))
        return
    end

    if state.diagnosticsEnabled then
        log(string.format("XP_BONUS | base=%.6f | percent=%.3f | bonus=%.6f | perk=%s", numericAmount, percent, bonus, tostring(perk)))
    end
end

local function onPlayerUpdate(player)
    if not player then return end
    if stateIsActive() then
        updateMoodles()
    elseif state.benefitType ~= BENEFIT_NONE then
        state.benefitType = BENEFIT_NONE
        state.xpBonusPercent = 0
        state.enduranceRecoveryBonusPercent = 0
        updateMoodles()
    end
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
else
    logErrorOnce("Events.OnServerCommand unavailable; sleep-benefit client state disabled")
end

if Events.AddXP then
    Events.AddXP.Add(onAddXP)
else
    xpCapabilityDisabled = true
    logErrorOnce("Events.AddXP unavailable; Rested XP bonus disabled")
end

if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(onPlayerUpdate) end
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(function() updateMoodles() end) end

initializeMoodleFramework()
log("Loaded Rested / Well Rested owning-client benefit handler.")
