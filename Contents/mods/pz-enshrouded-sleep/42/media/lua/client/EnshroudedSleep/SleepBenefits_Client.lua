-- Enshrouded Sleep - owning-client Rested / Well Rested behavior
-- Development candidate based on Public Beta v0.1.1 for Project Zomboid Build 42.20+

if not isClient() then return end

local MoodleUI = require "EnshroudedSleep/SleepBenefitMoodle_Client"

local PREFIX = "[EnshroudedSleepBenefits][CLIENT]"
local MODULE = "EnshroudedSleep"
local COMMAND = "SleepBenefitState"
local PROTOCOL_VERSION = 1
local BUILD_VERSION = "0.1.1+sleep-benefits-server-xp-dev"
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

local lastStateSignature = nil
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

local function clearError()
    lastError = nil
end

local function localPlayer()
    return type(getPlayer) == "function" and getPlayer() or nil
end

local function localPlayerIsDead()
    local player = localPlayer()
    if not player then return false end
    local ok, dead = pcall(function() return player:isDead() end)
    return ok and dead == true
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
    if localPlayerIsDead() then return false end
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

local function clearLocalBenefit(reason)
    local wasActive = state.benefitType ~= BENEFIT_NONE
        or (tonumber(state.xpBonusPercent) or 0) > EPSILON
        or (tonumber(state.enduranceRecoveryBonusPercent) or 0) > EPSILON

    state.benefitType = BENEFIT_NONE
    state.expiresAtWorldHour = -1
    state.xpBonusPercent = 0
    state.enduranceRecoveryBonusPercent = 0
    state.lastQualifyingSleepHours = 0

    pushMoodleState()
    pcall(MoodleUI.hide)

    if wasActive and reason then
        log("LOCAL_CLEAR | reason=" .. tostring(reason))
    end
end

local function applyState(args)
    local benefitType = tostring(args.benefitType or BENEFIT_NONE)
    if benefitType ~= BENEFIT_RESTED and benefitType ~= BENEFIT_WELL_RESTED then
        benefitType = BENEFIT_NONE
    end

    local expiresAtWorldHour = tonumber(args.expiresAtWorldHour) or -1
    local xpBonusPercent = math.max(0, tonumber(args.xpBonusPercent) or 0)
    local enduranceRecoveryBonusPercent = math.max(0, tonumber(args.enduranceRecoveryBonusPercent) or 0)
    local lastQualifyingSleepHours = math.max(0, tonumber(args.lastQualifyingSleepHours) or 0)

    if localPlayerIsDead() then
        benefitType = BENEFIT_NONE
        expiresAtWorldHour = -1
        xpBonusPercent = 0
        enduranceRecoveryBonusPercent = 0
        lastQualifyingSleepHours = 0
    end

    state.benefitType = benefitType
    state.expiresAtWorldHour = expiresAtWorldHour
    state.xpBonusPercent = xpBonusPercent
    state.enduranceRecoveryBonusPercent = enduranceRecoveryBonusPercent
    state.lastQualifyingSleepHours = lastQualifyingSleepHours
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

    local serverBuild = tostring(args.buildVersion or "unknown")
    if serverBuild ~= lastServerBuild then
        lastServerBuild = serverBuild
        log("SERVER_BUILD | " .. serverBuild)
    end
    if serverBuild ~= BUILD_VERSION then
        logErrorOnce("BUILD_MISMATCH | client=" .. BUILD_VERSION .. " | server=" .. serverBuild)
    else
        clearError()
    end

    applyState(args)
end

local function onPlayerUpdate(player)
    if not player then return end
    if localPlayerIsDead() then
        if state.benefitType ~= BENEFIT_NONE then clearLocalBenefit("death-observed") end
        return
    end
    if stateIsActive() then return end
    if state.benefitType == BENEFIT_NONE then return end

    clearLocalBenefit("expired-locally")
end

local function onPlayerDeath(player)
    local ownPlayer = localPlayer()
    if player and ownPlayer and player ~= ownPlayer then return end
    clearLocalBenefit("death-event")
end

if Events.OnServerCommand then
    Events.OnServerCommand.Add(onServerCommand)
else
    logErrorOnce("Events.OnServerCommand unavailable; sleep-benefit client state disabled")
end

if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(onPlayerUpdate) end
if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(function() pcall(MoodleUI.refresh) end) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(onPlayerDeath) end

pcall(MoodleUI.refresh)
log("Loaded Rested / Well Rested client | build=" .. BUILD_VERSION .. " | self-contained Moodle UI.")
