-- Enshrouded Sleep - SPIKE-006 owning-client action/activity transition diagnostic
-- Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record low-volume local activity/timed-action transitions so active-effects
-- tests can be correlated directly with survival telemetry without handwritten
-- timestamps. The owning client is particularly useful for LuaTimedActionNew
-- metadata because ordinary eating/drinking actions originate from client-side
-- timed-action queues before their effects synchronize with the server.
--
-- IMPORTANT: NetworkCharacterAI.getPerformingAction() exists in Java but the
-- NetworkPlayerAI bridge object returned at runtime is not safely indexable from
-- Kahlua. Do not probe it here; doing so can emit a Lua exception every tick.
--
-- MUTATION BOUNDARY
-- -----------------
-- Read-only. This file never changes actions, player state, GameTime, or network
-- state. It is dormant unless DiagnosticsEnabled=true.

if not isClient() then return end

local Probe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepActionDiag][CLIENT]"
local lastSignature = nil
local hadPlayer = false
local optionalCapabilities = {}
local optionalCapabilityWarnings = {}

local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

-- Optional Java/Lua bridge capabilities are circuit-broken. If a method lookup
-- or invocation is not exposed by the runtime, probe it once, log one compact
-- CAPABILITY_DISABLED record, and never touch that bridge method again for the
-- rest of the session. This prevents diagnostic failures from becoming a
-- per-tick error flood.
local function optionalMethod(capability, obj, methodName, ...)
    if optionalCapabilities[capability] == false or obj == nil then return nil end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then
        optionalCapabilities[capability] = false
        if not optionalCapabilityWarnings[capability] then
            log("CAPABILITY_DISABLED | capability=" .. tostring(capability)
                .. " | method=" .. tostring(methodName)
                .. " | reason=lookup-failed")
            optionalCapabilityWarnings[capability] = true
        end
        return nil
    end

    local okCall, value = pcall(method, obj, ...)
    if not okCall then
        optionalCapabilities[capability] = false
        if not optionalCapabilityWarnings[capability] then
            log("CAPABILITY_DISABLED | capability=" .. tostring(capability)
                .. " | method=" .. tostring(methodName)
                .. " | reason=call-failed")
            optionalCapabilityWarnings[capability] = true
        end
        return nil
    end

    optionalCapabilities[capability] = true
    return value
end

local function itemLabel(value)
    if value == nil then return nil end
    if type(value) == "string" or type(value) == "number" then return tostring(value) end

    local fullType = optionalMethod("item-getFullType", value, "getFullType")
    if fullType ~= nil then return tostring(fullType) end

    local itemType = optionalMethod("item-getType", value, "getType")
    if itemType ~= nil then return tostring(itemType) end
    return nil
end

local function readTimedAction(player)
    local actions = optionalMethod("character-actions", player, "getCharacterActions")
    if not actions then return nil, nil, nil end

    local size = optionalMethod("character-actions-size", actions, "size")
    if not size or size <= 0 then return nil, nil, nil end

    local action = optionalMethod("character-actions-get", actions, "get", 0)
    if not action then return nil, nil, nil end

    local metaType = optionalMethod("timed-action-meta-type", action, "getMetaType")
    local tableValue = optionalMethod("timed-action-table", action, "getTable")
    local rawType = tableValue and optionalMethod("timed-action-table-rawget", tableValue, "rawget", "Type") or nil

    local actionItem = nil
    if tableValue and optionalCapabilities["timed-action-table-rawget"] ~= false then
        local keys = { "item", "food", "waterSource", "primaryItem", "item1", "item2" }
        for _, key in ipairs(keys) do
            local value = optionalMethod("timed-action-table-rawget", tableValue, "rawget", key)
            local label = itemLabel(value)
            if label ~= nil then
                actionItem = tostring(key) .. ":" .. label
                break
            end
        end
    end

    return metaType and tostring(metaType) or nil,
        rawType and tostring(rawType) or nil,
        actionItem
end

local function classifyActivity(state)
    if state.asleep then return "sleeping" end
    if state.sprinting then return "sprinting" end
    if state.running then return "running" end
    if state.moving then return "walking" end
    if state.resting then return "resting" end
    if state.sitGround or state.sitFurniture then return "sitting" end

    local text = string.lower(table.concat({
        tostring(state.actionMetaType or ""),
        tostring(state.actionType or ""),
    }, " "))

    if string.find(text, "drink", 1, true) then return "drink-action" end
    if string.find(text, "eat", 1, true) or string.find(text, "food", 1, true) then return "eat-action" end
    if state.performingActionFlag or state.actionMetaType or state.actionType then
        return "timed-action"
    end
    return "idle"
end

local function readState(player)
    local actionMetaType, actionType, actionItem = readTimedAction(player)

    local state = {
        asleep = Probe.safeMethod(player, "isAsleep") == true,
        moving = Probe.safeMethod(player, "isPlayerMoving") == true,
        running = Probe.safeMethod(player, "isRunning") == true,
        sprinting = Probe.safeMethod(player, "isSprinting") == true,
        sitGround = Probe.safeMethod(player, "isSitOnGround") == true,
        sitFurniture = Probe.safeMethod(player, "isSittingOnFurniture") == true,
        resting = Probe.safeMethod(player, "isResting") == true,
        performingActionFlag = Probe.safeMethod(player, "isPerformingAnAction") == true,
        actionMetaType = actionMetaType,
        actionType = actionType,
        actionItem = actionItem,
    }
    state.activity = classifyActivity(state)
    return state
end

local function signature(state)
    return table.concat({
        tostring(state.activity),
        tostring(state.asleep),
        tostring(state.moving),
        tostring(state.running),
        tostring(state.sprinting),
        tostring(state.sitGround),
        tostring(state.sitFurniture),
        tostring(state.resting),
        tostring(state.performingActionFlag),
        tostring(state.actionMetaType or ""),
        tostring(state.actionType or ""),
        tostring(state.actionItem or ""),
    }, "|")
end

local function emit(player, state, eventName)
    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    local name = Probe.safeMethod(player, "getUsername") or Probe.safeMethod(player, "getDisplayName") or "N/A"
    local onlineID = Probe.safeNumber(player, "getOnlineID")

    log(
        tostring(eventName or "ACTION")
        .. " | epoch=" .. tostring(os.time())
        .. " | player=" .. Probe.sanitize(name)
        .. " | onlineID=" .. Probe.formatValue(onlineID, 0)
        .. " | activity=" .. tostring(state.activity)
        .. " | moving=" .. tostring(state.moving)
        .. " | running=" .. tostring(state.running)
        .. " | sprinting=" .. tostring(state.sprinting)
        .. " | resting=" .. tostring(state.resting)
        .. " | sitGround=" .. tostring(state.sitGround)
        .. " | sitFurniture=" .. tostring(state.sitFurniture)
        .. " | asleep=" .. tostring(state.asleep)
        .. " | performingActionFlag=" .. tostring(state.performingActionFlag)
        .. " | actionMetaType=" .. Probe.sanitize(state.actionMetaType or "N/A")
        .. " | actionType=" .. Probe.sanitize(state.actionType or "N/A")
        .. " | actionItem=" .. Probe.sanitize(state.actionItem or "N/A")
        .. " | x=" .. Probe.formatValue(Probe.safeNumber(player, "getX"))
        .. " | y=" .. Probe.formatValue(Probe.safeNumber(player, "getY"))
        .. " | z=" .. Probe.formatValue(Probe.safeNumber(player, "getZ"))
        .. " | MinutesPerDay=" .. Probe.formatValue(Probe.safeNumber(gameTime, "getMinutesPerDay"))
        .. " | TimeOfDay=" .. Probe.formatValue(Probe.safeNumber(gameTime, "getTimeOfDay"))
        .. " | TrueMultiplier=" .. Probe.formatValue(Probe.safeNumber(gameTime, "getTrueMultiplier"))
    )
end

local function sample()
    if not diagnosticsEnabled() then
        lastSignature = nil
        hadPlayer = false
        return
    end

    local player = type(getPlayer) == "function" and getPlayer() or nil
    if not player or Probe.safeMethod(player, "isDead") == true then
        if hadPlayer then
            log("PLAYER_UNAVAILABLE | epoch=" .. tostring(os.time()))
        end
        lastSignature = nil
        hadPlayer = false
        return
    end

    local state = readState(player)
    local sig = signature(state)
    if sig ~= lastSignature then
        emit(player, state, hadPlayer and "ACTION" or "PLAYER_ACTIVE")
        lastSignature = sig
    end
    hadPlayer = true
end

Events.OnTick.Add(sample)

log("Loaded SPIKE-006 transition-based owning-client action/activity diagnostic; active only when DiagnosticsEnabled=true.")
log("Records local movement/rest/sleep state plus exposed LuaTimedActionNew metadata; inaccessible optional bridge methods are circuit-broken after one failed probe.")
