-- Enshrouded Sleep - owning-client Rested / Well Rested behavior
-- Development candidate based on Public Beta v0.1.1 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Receive server-authoritative sleep-benefit state, apply the configured XP bonus
-- to positive AddXP events, and drive Enshrouded Sleep's self-contained custom
-- Rested / Well Rested Moodle UI.
--
-- SAFETY
-- ------
-- * The client does not decide whether sleep qualified for a benefit.
-- * XP bonus percentages come only from server SleepBenefitState packets.
-- * Bonus XP uses addXpNoMultiplier() and a recursion guard so the additional XP
--   is not multiplied again or recursively awarded.
-- * The custom Moodle renderer is presentation-only. A UI failure must not alter
--   XP, Endurance, sleep qualification, or proportional time behavior.
-- * No third-party Moodle framework or Lifestyle code/assets are redistributed.

if not isClient() then return end

local MoodleUI = require "EnshroudedSleep/SleepBenefitMoodle_Client"

local PREFIX = "[EnshroudedSleepBenefits][CLIENT]"
local MODULE = "EnshroudedSleep"
local COMMAND = "SleepBenefitState"
local PROTOCOL_VERSION = 1
local BENEFIT_NONE = "none"
local BENEFIT_RESTED = "rested"
local BENEFIT_WELL_RESTED = "well-rested"
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

local function pushMoodleState()
    local ok, err = pcall(MoodleUI.setState, state)
    if not ok then
        logErrorOnce("self-contained Moodle UI update failed; gameplay benefit remains active: " .. tostring(err))
    end
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

    pushMoodleState()
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
    if stateIsActive() then return end
    if state.benefitType == BENEFIT_NONE then return end

    state.benefitType = BENEFIT_NONE
    state.xpBonusPercent = 0
    state.enduranceRecoveryBonusPercent = 0
    pushMoodleState()
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
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(function() pcall(MoodleUI.refresh) end) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(function() pcall(MoodleUI.hide) end) end

pcall(MoodleUI.refresh)
log("Loaded Rested / Well Rested owning-client benefit handler with self-contained Moodle UI.")
