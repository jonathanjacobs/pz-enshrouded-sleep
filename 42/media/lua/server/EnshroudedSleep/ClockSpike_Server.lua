if isClient() then return end

-- Enshrouded Sleep - Player State Probe
-- v0.0.2 diagnostic instrumentation for Project Zomboid Build 42.20+
--
-- Purpose:
--   Observe instantiated in-world player lifecycle and sleep/death state.
--   This build intentionally DOES NOT modify GameTime or MinutesPerDay.

local PREFIX = "[EnshroudedSleep:Probe]"

local previousPlayers = {}
local previousCount = -1
local lastScanAt = 0
local lastHeartbeatAt = 0

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function now()
    return os.time()
end

local function safeCall(obj, methodName)
    if not obj then return "nil" end
    local method = obj[methodName]
    if not method then return "N/A" end

    local ok, value = pcall(method, obj)
    if not ok then return "ERROR" end
    return value
end

local function getConfig()
    local vars = SandboxVars and SandboxVars.EnshroudedSleepClockSpike or nil
    return {
        enabled = vars == nil or vars.Enabled ~= false,
        heartbeatSeconds = math.max(5, tonumber(vars and vars.HeartbeatSeconds) or 10),
    }
end

local function formatClock()
    local gt = getGameTime()
    if not gt then return "N/A" end

    local hour = safeCall(gt, "getHour")
    local minute = safeCall(gt, "getMinutes")
    if type(hour) == "number" and type(minute) == "number" then
        return string.format("%02d:%02d", hour, minute)
    end

    return tostring(safeCall(gt, "getTimeOfDay"))
end

local function playerSnapshot(player)
    local username = safeCall(player, "getUsername")
    local displayName = safeCall(player, "getDisplayName")
    local onlineID = safeCall(player, "getOnlineID")
    local asleep = safeCall(player, "isAsleep")
    local dead = safeCall(player, "isDead")
    local accessLevel = safeCall(player, "getAccessLevel")
    local godMode = safeCall(player, "isGodMod")
    local x = safeCall(player, "getX")
    local y = safeCall(player, "getY")
    local z = safeCall(player, "getZ")

    return {
        key = tostring(player),
        username = tostring(username),
        displayName = tostring(displayName),
        onlineID = tostring(onlineID),
        asleep = tostring(asleep),
        dead = tostring(dead),
        accessLevel = tostring(accessLevel),
        godMode = tostring(godMode),
        x = tostring(x),
        y = tostring(y),
        z = tostring(z),
    }
end

local function describePlayer(s)
    return string.format(
        "user=%s | display=%s | onlineID=%s | object=%s | asleep=%s | dead=%s | access=%s | god=%s | pos=(%s,%s,%s)",
        s.username,
        s.displayName,
        s.onlineID,
        s.key,
        s.asleep,
        s.dead,
        s.accessLevel,
        s.godMode,
        s.x,
        s.y,
        s.z
    )
end

local function stateFingerprint(s)
    -- Deliberately excludes position so walking does not spam state-change logs.
    return table.concat({
        s.username,
        s.displayName,
        s.onlineID,
        s.asleep,
        s.dead,
        s.accessLevel,
        s.godMode,
    }, "|")
end

local function scanPlayers(forceHeartbeat)
    local players = getOnlinePlayers()
    local count = players and players:size() or 0
    local current = {}

    if count ~= previousCount then
        log(string.format(
            "PLAYER COUNT CHANGED | previous=%d | current=%d | clock=%s",
            previousCount,
            count,
            formatClock()
        ))
        previousCount = count
    end

    if players then
        for i = 0, count - 1 do
            local player = players:get(i)
            if player then
                local snapshot = playerSnapshot(player)
                current[snapshot.key] = snapshot

                local old = previousPlayers[snapshot.key]
                if not old then
                    log("PLAYER ADDED | " .. describePlayer(snapshot) .. " | clock=" .. formatClock())
                elseif stateFingerprint(old) ~= stateFingerprint(snapshot) then
                    log("PLAYER STATE CHANGED | before={" .. describePlayer(old)
                        .. "} | after={" .. describePlayer(snapshot)
                        .. "} | clock=" .. formatClock())
                end
            end
        end
    end

    for key, old in pairs(previousPlayers) do
        if not current[key] then
            log("PLAYER REMOVED | " .. describePlayer(old) .. " | clock=" .. formatClock())
        end
    end

    previousPlayers = current

    if forceHeartbeat then
        local sleeping = 0
        local dead = 0
        for _, snapshot in pairs(current) do
            if snapshot.asleep == "true" then sleeping = sleeping + 1 end
            if snapshot.dead == "true" then dead = dead + 1 end
        end

        log(string.format(
            "HEARTBEAT | inWorld=%d | sleeping=%d | dead=%d | clock=%s",
            count,
            sleeping,
            dead,
            formatClock()
        ))

        for _, snapshot in pairs(current) do
            log("PLAYER SNAPSHOT | " .. describePlayer(snapshot))
        end
    end
end

local function update()
    local config = getConfig()
    if not config.enabled then return end

    local t = now()
    if t == lastScanAt then return end
    lastScanAt = t

    local heartbeat = false
    if lastHeartbeatAt == 0 or t - lastHeartbeatAt >= config.heartbeatSeconds then
        lastHeartbeatAt = t
        heartbeat = true
    end

    scanPlayers(heartbeat)
end

Events.OnTickEvenPaused.Add(update)

log("Loaded v0.0.2 player-state diagnostic probe.")
log("This build DOES NOT modify MinutesPerDay or any game-time multiplier.")
log("Watching getOnlinePlayers() for join, removal, sleep, death, access-level and object-identity transitions.")
