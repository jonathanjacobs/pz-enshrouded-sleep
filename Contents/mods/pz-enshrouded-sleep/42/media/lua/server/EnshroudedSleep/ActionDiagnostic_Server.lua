-- Enshrouded Sleep - SPIKE-006 server action/activity transition diagnostic
-- Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Record low-volume, transition-based activity markers so SPIKE-006 active-
-- effects tests can be reconstructed from logs without requiring the tester to
-- manually note wall-clock timestamps.
--
-- B42.20.3 source exposes IsoPlayer movement/rest/sleep state plus the networked
-- NetworkCharacterAI.performingAction string. LuaTimedActionNew additionally
-- exposes getMetaType()/getTable(), so when the authoritative server has a
-- current character action we record its raw Lua timed-action type as evidence.
--
-- MUTATION BOUNDARY
-- -----------------
-- Read-only. This file never changes player state, action queues, GameTime, or
-- Enshrouded Sleep policy. It is dormant unless DiagnosticsEnabled=true.

if isClient() then return end

local Probe = require "EnshroudedSleep/SurvivalStatProbe"

local PREFIX = "[EnshroudedSleepActionDiag][SERVER]"
local lastSignatureByPlayer = {}
local knownPlayers = {}

local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function playerKey(player)
    local onlineID = Probe.safeNumber(player, "getOnlineID")
    if onlineID ~= nil then return "id:" .. tostring(onlineID) end
    local username = Probe.safeMethod(player, "getUsername")
    if username ~= nil then return "user:" .. tostring(username) end
    return tostring(player)
end

local function itemLabel(value)
    if value == nil then return nil end
    local fullType = Probe.safeMethod(value, "getFullType")
    if fullType ~= nil then return tostring(fullType) end
    local itemType = Probe.safeMethod(value, "getType")
    if itemType ~= nil then return tostring(itemType) end
    if type(value) == "string" or type(value) == "number" then return tostring(value) end
    return nil
end

local function readTimedAction(player)
    local actions = Probe.safeMethod(player, "getCharacterActions")
    local size = Probe.safeNumber(actions, "size")
    if not actions or not size or size <= 0 then
        return nil, nil, nil
    end

    local action = Probe.safeMethod(actions, "get", 0)
    if not action then return nil, nil, nil end

    local metaType = Probe.safeMethod(action, "getMetaType")
    local tableValue = Probe.safeMethod(action, "getTable")
    local rawType = tableValue and Probe.safeMethod(tableValue, "rawget", "Type") or nil

    local actionItem = nil
    if tableValue then
        local keys = { "item", "food", "waterSource", "primaryItem", "item1", "item2" }
        for _, key in ipairs(keys) do
            local value = Probe.safeMethod(tableValue, "rawget", key)
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
        tostring(state.performingAction or ""),
    }, " "))

    if string.find(text, "drink", 1, true) then return "drink-action" end
    if string.find(text, "eat", 1, true) or string.find(text, "food", 1, true) then return "eat-action" end
    if state.performingActionFlag or state.actionMetaType or state.actionType or state.performingAction then
        return "timed-action"
    end
    return "idle"
end

local function readState(player)
    local ai = Probe.safeMethod(player, "getNetworkCharacterAI")
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
        performingAction = Probe.safeMethod(ai, "getPerformingAction"),
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
        tostring(state.performingAction or ""),
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
        .. " | performingAction=" .. Probe.sanitize(state.performingAction or "N/A")
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
        lastSignatureByPlayer = {}
        knownPlayers = {}
        return
    end
    if type(getOnlinePlayers) ~= "function" then return end

    local players = getOnlinePlayers()
    local size = Probe.safeNumber(players, "size")
    if not size then return end

    local seen = {}
    for i = 0, size - 1 do
        local player = Probe.safeMethod(players, "get", i)
        if player and Probe.safeMethod(player, "isDead") ~= true then
            local key = playerKey(player)
            seen[key] = true
            local state = readState(player)
            local sig = signature(state)

            if lastSignatureByPlayer[key] ~= sig then
                emit(player, state, knownPlayers[key] and "ACTION" or "PLAYER_ACTIVE")
                lastSignatureByPlayer[key] = sig
            end
            knownPlayers[key] = true
        end
    end

    for key, _ in pairs(knownPlayers) do
        if not seen[key] then
            log("PLAYER_REMOVED | epoch=" .. tostring(os.time()) .. " | key=" .. Probe.sanitize(key))
            knownPlayers[key] = nil
            lastSignatureByPlayer[key] = nil
        end
    end
end

Events.OnTick.Add(sample)

log("Loaded SPIKE-006 transition-based server action/activity diagnostic; active only when DiagnosticsEnabled=true.")
log("Records raw B42 movement/rest/sleep state plus network performingAction and Lua timed-action metadata when available.")
