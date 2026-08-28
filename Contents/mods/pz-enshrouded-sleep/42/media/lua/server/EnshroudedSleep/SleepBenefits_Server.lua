-- Enshrouded Sleep - optional Rested / Well Rested sleep benefits
-- Development candidate based on Public Beta v0.1.1 for Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Reward meaningful voluntary sleep without making sleep mandatory. The server
-- measures actual game-world hours spent asleep, persists the resulting benefit
-- expiry in player ModData, applies the Well Rested endurance-recovery bonus, and
-- publishes authoritative benefit state to the owning client.
--
-- DEFAULT TIERS
-- -------------
-- < 6 game hours: no new benefit
-- 6 to < 9 hours: Rested      (+5% XP, 12 game hours)
-- >= 9 hours:     Well Rested (+5% XP, +10% endurance recovery, 24 game hours)
--
-- All thresholds, durations, and bonus percentages are server sandbox options.
-- A qualifying sleep replaces the previous tier; a short sleep below the Rested
-- threshold does not cancel an otherwise active benefit. Benefits do not stack.
--
-- AUTHORITY / SAFETY
-- ------------------
-- * Sleep qualification and benefit expiry are server-authoritative.
-- * Benefit duration is measured in game-world hours via getWorldAgeHours().
-- * Death or disabling SleepBenefitsEnabled clears active benefits.
-- * Disconnecting/restarting while currently asleep does not preserve the
--   in-progress sleep attempt; this avoids rewarding offline elapsed world time.
-- * Well Rested endurance recovery is directional: only observed positive
--   Endurance deltas receive the configured percentage bonus. Depletion is never
--   reduced by this module.
-- * XP is awarded by the owning client through the standard AddXP event because
--   Build 42 exposes that event client-side; the server supplies the percentage.
-- * The self-contained Moodle renderer is client/UI-only and is not required by
--   this authoritative server controller.

if isClient() then return end

local Probe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepBenefits][SERVER]"
local MODULE = "EnshroudedSleep"
local COMMAND = "SleepBenefitState"
local PROTOCOL_VERSION = 1
local HEARTBEAT_SECONDS = 15
local EPSILON = 0.0000001

local BENEFIT_NONE = "none"
local BENEFIT_RESTED = "rested"
local BENEFIT_WELL_RESTED = "well-rested"

local KEY_TYPE = "EnshroudedSleepBenefitType"
local KEY_EXPIRES = "EnshroudedSleepBenefitExpiresAtWorldHour"
local KEY_LAST_SLEEP = "EnshroudedSleepBenefitLastQualifyingSleepHours"

local sleepStartByPlayer = {}
local previousAsleepByPlayer = {}
local previousEnduranceByPlayer = {}
local lastSentSignatureByPlayer = {}
local lastSentAtByPlayer = {}
local enduranceStat = nil
local enduranceCapabilityDisabled = false
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

local function clamp(value, minimum, maximum)
    value = tonumber(value)
    if value == nil then return minimum end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function getConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil

    local restedMin = clamp(vars and vars.RestedMinimumSleepHours or 6.0, 0.0, 24.0)
    local wellMin = clamp(vars and vars.WellRestedMinimumSleepHours or 9.0, 0.0, 24.0)
    if wellMin < restedMin then wellMin = restedMin end

    return {
        enabled = vars ~= nil and vars.SleepBenefitsEnabled == true,
        restedMinHours = restedMin,
        restedDurationHours = clamp(vars and vars.RestedDurationHours or 12.0, 0.0, 168.0),
        restedXPPercent = clamp(vars and vars.RestedXPBonusPercent or 5.0, 0.0, 100.0),
        wellMinHours = wellMin,
        wellDurationHours = clamp(vars and vars.WellRestedDurationHours or 24.0, 0.0, 168.0),
        wellXPPercent = clamp(vars and vars.WellRestedXPBonusPercent or 5.0, 0.0, 100.0),
        wellEndurancePercent = clamp(vars and vars.WellRestedEnduranceRecoveryBonusPercent or 10.0, 0.0, 100.0),
        diagnosticsEnabled = vars ~= nil and vars.DiagnosticsEnabled == true,
    }
end

local function worldAgeHours()
    if type(getGameTime) ~= "function" then return nil end
    local gt = getGameTime()
    return Probe.safeNumber(gt, "getWorldAgeHours")
end

local function playerKey(player)
    local onlineID = Probe.safeNumber(player, "getOnlineID")
    if onlineID ~= nil then return "id:" .. tostring(onlineID) end
    local username = Probe.safeMethod(player, "getUsername")
    if username ~= nil then return "user:" .. tostring(username) end
    return tostring(player)
end

local function playerName(player)
    return Probe.sanitize(Probe.safeMethod(player, "getUsername") or playerKey(player))
end

local function getModData(player)
    local data = Probe.safeMethod(player, "getModData")
    if type(data) ~= "table" then return nil end
    return data
end

local function readBenefit(player, nowWorldHour)
    local data = getModData(player)
    if not data then return BENEFIT_NONE, nil, 0 end

    local benefitType = tostring(data[KEY_TYPE] or BENEFIT_NONE)
    if benefitType ~= BENEFIT_RESTED and benefitType ~= BENEFIT_WELL_RESTED then
        benefitType = BENEFIT_NONE
    end

    local expires = tonumber(data[KEY_EXPIRES])
    local lastSleep = tonumber(data[KEY_LAST_SLEEP]) or 0

    if benefitType ~= BENEFIT_NONE and (expires == nil or expires <= (nowWorldHour or -math.huge)) then
        return BENEFIT_NONE, expires, lastSleep
    end

    return benefitType, expires, lastSleep
end

local function writeBenefit(player, benefitType, expiresAtWorldHour, sleepHours)
    local data = getModData(player)
    if not data then return false end

    data[KEY_TYPE] = benefitType or BENEFIT_NONE
    data[KEY_EXPIRES] = expiresAtWorldHour
    data[KEY_LAST_SLEEP] = sleepHours or 0
    return true
end

local function clearBenefit(player, reason, nowWorldHour)
    local current = readBenefit(player, nowWorldHour)
    if current == BENEFIT_NONE then
        local data = getModData(player)
        if data then
            data[KEY_TYPE] = BENEFIT_NONE
            data[KEY_EXPIRES] = nil
            data[KEY_LAST_SLEEP] = 0
        end
        return false
    end

    if writeBenefit(player, BENEFIT_NONE, nil, 0) then
        log("CLEAR | player=" .. playerName(player) .. " | reason=" .. tostring(reason))
        return true
    end
    return false
end

local function classifySleep(config, sleepHours)
    if sleepHours >= config.wellMinHours then
        return BENEFIT_WELL_RESTED, config.wellDurationHours
    end
    if sleepHours >= config.restedMinHours then
        return BENEFIT_RESTED, config.restedDurationHours
    end
    return BENEFIT_NONE, 0
end

local function grantForSleep(player, config, sleepHours, nowWorldHour)
    local benefitType, durationHours = classifySleep(config, sleepHours)
    if benefitType == BENEFIT_NONE then
        log(string.format(
            "NO_REWARD | player=%s | sleepHours=%.3f | RestedMinimum=%.3f",
            playerName(player), sleepHours, config.restedMinHours
        ))
        return false
    end

    local expires = nowWorldHour + math.max(0.0, durationHours)
    if not writeBenefit(player, benefitType, expires, sleepHours) then
        logErrorOnce("could not write benefit ModData for player=" .. playerName(player))
        return false
    end

    clearError()
    log(string.format(
        "GRANT | player=%s | sleepHours=%.3f | benefit=%s | durationHours=%.3f | expiresAtWorldHour=%.3f",
        playerName(player), sleepHours, benefitType, durationHours, expires
    ))
    return true
end

local function resolveEnduranceStat()
    if enduranceCapabilityDisabled then return nil end
    if enduranceStat ~= nil then return enduranceStat end

    local stat, source = Probe.resolveCharacterStat("ENDURANCE", "Endurance")
    if stat == nil then
        enduranceCapabilityDisabled = true
        logErrorOnce("CharacterStat.ENDURANCE unavailable; Well Rested endurance bonus disabled for this server session")
        return nil
    end

    enduranceStat = stat
    log("CAPABILITY | Endurance stat resolved via " .. tostring(source))
    return enduranceStat
end

local function readEndurance(player)
    local stat = resolveEnduranceStat()
    if not stat then return nil, nil end
    local stats = Probe.safeMethod(player, "getStats")
    if not stats then return nil, nil end
    return Probe.toNumber(Probe.safeMethod(stats, "get", stat)), stats
end

local function applyEnduranceRecoveryBonus(player, key, config, benefitType, asleep)
    local current, stats = readEndurance(player)
    if current == nil or not stats then
        previousEnduranceByPlayer[key] = nil
        return
    end

    local previous = previousEnduranceByPlayer[key]

    if asleep == true or benefitType ~= BENEFIT_WELL_RESTED or config.wellEndurancePercent <= EPSILON then
        previousEnduranceByPlayer[key] = current
        return
    end

    if previous ~= nil and current > previous + EPSILON then
        local vanillaRecovery = current - previous
        local extra = vanillaRecovery * (config.wellEndurancePercent / 100.0)
        local target = math.min(1.0, current + extra)
        local okMethod, setMethod = pcall(function() return stats.set end)
        if okMethod and setMethod then
            local ok = pcall(setMethod, stats, enduranceStat, target)
            if ok then
                current = Probe.toNumber(Probe.safeMethod(stats, "get", enduranceStat)) or target
                if config.diagnosticsEnabled then
                    log(string.format(
                        "ENDURANCE_BONUS | player=%s | vanillaRecovery=%.8f | bonusPercent=%.3f | extra=%.8f | after=%.8f",
                        playerName(player), vanillaRecovery, config.wellEndurancePercent, extra, current
                    ))
                end
            else
                previousEnduranceByPlayer[key] = nil
                logErrorOnce("Stats:set(Endurance) failed; skipping current recovery correction")
                return
            end
        else
            previousEnduranceByPlayer[key] = nil
            enduranceCapabilityDisabled = true
            logErrorOnce("Stats:set unavailable; Well Rested endurance bonus disabled for this server session")
            return
        end
    end

    previousEnduranceByPlayer[key] = current
end

local function stateForClient(player, config, nowWorldHour)
    local benefitType, expires, lastSleep = readBenefit(player, nowWorldHour)
    local xpPercent = 0.0
    local endurancePercent = 0.0

    if benefitType == BENEFIT_RESTED then
        xpPercent = config.restedXPPercent
    elseif benefitType == BENEFIT_WELL_RESTED then
        xpPercent = config.wellXPPercent
        endurancePercent = config.wellEndurancePercent
    end

    return {
        protocolVersion = PROTOCOL_VERSION,
        buildVersion = "0.1.1+sleep-benefits-dev",
        benefitType = benefitType,
        expiresAtWorldHour = expires or -1,
        lastQualifyingSleepHours = lastSleep or 0,
        xpBonusPercent = xpPercent,
        enduranceRecoveryBonusPercent = endurancePercent,
        serverWorldAgeHours = nowWorldHour or -1,
        diagnosticsEnabled = config.diagnosticsEnabled,
    }
end

local function sendState(player, key, config, nowWorldHour, force)
    if type(sendServerCommand) ~= "function" then
        logErrorOnce("sendServerCommand() unavailable; sleep-benefit client state not sent")
        return
    end

    local args = stateForClient(player, config, nowWorldHour)
    local signature = table.concat({
        tostring(args.benefitType),
        string.format("%.4f", tonumber(args.expiresAtWorldHour) or -1),
        string.format("%.4f", tonumber(args.xpBonusPercent) or 0),
        string.format("%.4f", tonumber(args.enduranceRecoveryBonusPercent) or 0),
    }, "|")

    local nowReal = os.time()
    local heartbeatDue = (lastSentAtByPlayer[key] == nil) or (nowReal - lastSentAtByPlayer[key] >= HEARTBEAT_SECONDS)
    if not force and signature == lastSentSignatureByPlayer[key] and not heartbeatDue then return end

    local ok, err = pcall(sendServerCommand, player, MODULE, COMMAND, args)
    if not ok then
        logErrorOnce("sendServerCommand(player, SleepBenefitState) failed: " .. tostring(err))
        return
    end

    clearError()
    if signature ~= lastSentSignatureByPlayer[key] then
        log(string.format(
            "STATE | player=%s | benefit=%s | expiresAtWorldHour=%.3f | xpBonus=%.3f%% | enduranceRecoveryBonus=%.3f%%",
            playerName(player), args.benefitType, tonumber(args.expiresAtWorldHour) or -1,
            tonumber(args.xpBonusPercent) or 0, tonumber(args.enduranceRecoveryBonusPercent) or 0
        ))
    end

    lastSentSignatureByPlayer[key] = signature
    lastSentAtByPlayer[key] = nowReal
end

local function collectPlayers()
    local result = {}
    if type(getOnlinePlayers) ~= "function" then return result end
    local players = getOnlinePlayers()
    local size = Probe.safeNumber(players, "size")
    if not size then return result end

    for i = 0, size - 1 do
        local player = Probe.safeMethod(players, "get", i)
        if player then result[#result + 1] = player end
    end
    return result
end

local function update()
    local config = getConfig()
    local nowWorldHour = worldAgeHours()
    if nowWorldHour == nil then
        logErrorOnce("GameTime:getWorldAgeHours() unavailable; sleep benefits suspended")
        return
    end

    local seen = {}

    for _, player in ipairs(collectPlayers()) do
        local key = playerKey(player)
        seen[key] = true

        local dead = Probe.safeMethod(player, "isDead") == true
        local asleep = Probe.safeMethod(player, "isAsleep") == true
        local wasAsleep = previousAsleepByPlayer[key] == true

        if dead then
            sleepStartByPlayer[key] = nil
            previousAsleepByPlayer[key] = false
            previousEnduranceByPlayer[key] = nil
            clearBenefit(player, "death", nowWorldHour)
            -- Do not force a packet every tick while a dead IsoPlayer remains in
            -- the online roster. Signature/heartbeat deduplication sends the clear
            -- transition once and then only the low-frequency authoritative state.
            sendState(player, key, config, nowWorldHour, false)
        elseif not config.enabled then
            sleepStartByPlayer[key] = nil
            previousAsleepByPlayer[key] = asleep
            previousEnduranceByPlayer[key] = nil
            clearBenefit(player, "SleepBenefitsEnabled=false", nowWorldHour)
            sendState(player, key, config, nowWorldHour, false)
        else
            local benefitType, expires = readBenefit(player, nowWorldHour)
            if benefitType == BENEFIT_NONE and expires ~= nil and expires <= nowWorldHour then
                clearBenefit(player, "expired", nowWorldHour)
                benefitType = BENEFIT_NONE
            end

            if asleep and not wasAsleep then
                sleepStartByPlayer[key] = nowWorldHour
                previousEnduranceByPlayer[key] = nil
                log(string.format("SLEEP_START | player=%s | worldHour=%.3f", playerName(player), nowWorldHour))
            elseif not asleep and wasAsleep then
                local started = sleepStartByPlayer[key]
                sleepStartByPlayer[key] = nil
                previousEnduranceByPlayer[key] = nil
                if started ~= nil and nowWorldHour >= started then
                    local sleepHours = nowWorldHour - started
                    grantForSleep(player, config, sleepHours, nowWorldHour)
                    benefitType = readBenefit(player, nowWorldHour)
                end
            end

            previousAsleepByPlayer[key] = asleep
            benefitType = readBenefit(player, nowWorldHour)
            applyEnduranceRecoveryBonus(player, key, config, benefitType, asleep)
            sendState(player, key, config, nowWorldHour, false)
        end
    end

    -- In-progress sleep attempts are intentionally session-scoped. If a player
    -- leaves, discard the attempt so offline world-time advancement cannot count.
    for key, _ in pairs(previousAsleepByPlayer) do
        if not seen[key] then
            sleepStartByPlayer[key] = nil
            previousAsleepByPlayer[key] = nil
            previousEnduranceByPlayer[key] = nil
            lastSentSignatureByPlayer[key] = nil
            lastSentAtByPlayer[key] = nil
        end
    end
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(update)
else
    Events.OnTick.Add(update)
end

log("Loaded optional Rested / Well Rested server benefit controller; disabled unless SleepBenefitsEnabled=true.")
