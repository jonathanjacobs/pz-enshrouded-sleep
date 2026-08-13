if isClient() then return end

-- Enshrouded Sleep - Player/Connection State Probe
-- v0.0.2b diagnostic instrumentation for Project Zomboid Build 42.20+
--
-- Purpose:
--   1. Observe instantiated in-world player lifecycle and sleep/death state.
--   2. Observe accepted network connections before an IsoPlayer is instantiated.
--   3. Measure vanilla full-sleep fast-forward behavior.
--
-- This build intentionally DOES NOT modify GameTime, MinutesPerDay, or any
-- game-time/simulation multiplier.

local PREFIX = "[EnshroudedSleep:Probe]"

local previousPlayers = {}
local previousPlayerCount = -1
local previousConnections = {}
local previousConnectionCount = -1
local lastScanAt = 0
local lastHeartbeatAt = 0
local sleepTelemetryWasActive = false
local connectionApiWarningLogged = false

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function now()
    return os.time()
end

local function safeCall(obj, methodName, ...)
    if not obj then return "nil" end

    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return "N/A" end

    local ok, value = pcall(method, obj, ...)
    if not ok then return "ERROR" end
    return value
end

local function safeField(obj, fieldName)
    if not obj then return "nil" end
    local ok, value = pcall(function() return obj[fieldName] end)
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

local function getGameTimeTelemetry()
    local gt = getGameTime()
    if not gt then
        return {
            clock = "N/A",
            minutesPerDay = "N/A",
            multiplier = "N/A",
            serverMultiplier = "N/A",
            trueMultiplier = "N/A",
            worldAgeHours = "N/A",
        }
    end

    local hour = safeCall(gt, "getHour")
    local minute = safeCall(gt, "getMinutes")
    local clock
    if type(hour) == "number" and type(minute) == "number" then
        clock = string.format("%02d:%02d", hour, minute)
    else
        clock = tostring(safeCall(gt, "getTimeOfDay"))
    end

    return {
        clock = clock,
        minutesPerDay = tostring(safeCall(gt, "getMinutesPerDay")),
        multiplier = tostring(safeCall(gt, "getMultiplier")),
        serverMultiplier = tostring(safeCall(gt, "getServerMultiplier")),
        trueMultiplier = tostring(safeCall(gt, "getTrueMultiplier")),
        worldAgeHours = tostring(safeCall(gt, "getWorldAgeHours")),
    }
end

local function formatClock()
    return getGameTimeTelemetry().clock
end

local function getGameServerFastForward()
    if not GameServer then return "N/A" end
    return tostring(safeField(GameServer, "bFastForward"))
end

local function getConfiguredFastForwardMultiplier()
    if not ServerOptions then return "N/A" end

    local ok, value = pcall(function()
        local instance = ServerOptions.getInstance()
        if not instance then return "N/A" end
        return instance:getDouble("FastForwardMultiplier")
    end)

    if not ok then return "ERROR" end
    return tostring(value)
end

local function playerSnapshot(player)
    return {
        key = tostring(player),
        username = tostring(safeCall(player, "getUsername")),
        displayName = tostring(safeCall(player, "getDisplayName")),
        onlineID = tostring(safeCall(player, "getOnlineID")),
        asleep = tostring(safeCall(player, "isAsleep")),
        dead = tostring(safeCall(player, "isDead")),
        accessLevel = tostring(safeCall(player, "getAccessLevel")),
        godMode = tostring(safeCall(player, "isGodMod")),
        x = tostring(safeCall(player, "getX")),
        y = tostring(safeCall(player, "getY")),
        z = tostring(safeCall(player, "getZ")),
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

local function playerStateFingerprint(s)
    -- Deliberately excludes position so movement does not spam state changes.
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

local function getAnyPlayerFromConnection(connection)
    if not GameServer then return nil end

    local okMethod, method = pcall(function() return GameServer.getAnyPlayerFromConnection end)
    if not okMethod or not method then return nil end

    local ok, player = pcall(method, connection)
    if not ok then return nil end
    return player
end

local function connectionSnapshot(connection)
    local guid = safeCall(connection, "getConnectedGUID")
    local anyPlayer = getAnyPlayerFromConnection(connection)

    return {
        key = tostring(guid) .. "@" .. tostring(connection),
        object = tostring(connection),
        guid = tostring(guid),
        username = tostring(safeField(connection, "username")),
        steamID = tostring(safeField(connection, "steamID")),
        ownerID = tostring(safeField(connection, "ownerID")),
        accessLevel = tostring(safeField(connection, "accessLevel")),
        wasInLoadingQueue = tostring(safeField(connection, "wasInLoadingQueue")),
        fullyConnected = tostring(safeCall(connection, "isFullyConnected")),
        connectionType = tostring(safeCall(connection, "getConnectionType")),
        anyPlayer = anyPlayer and tostring(anyPlayer) or "nil",
        anyPlayerOnlineID = anyPlayer and tostring(safeCall(anyPlayer, "getOnlineID")) or "nil",
        anyPlayerDead = anyPlayer and tostring(safeCall(anyPlayer, "isDead")) or "nil",
    }
end

local function describeConnection(s)
    return string.format(
        "user=%s | guid=%s | steamID=%s | ownerID=%s | object=%s | accessByte=%s | fullyConnected=%s | wasInLoadingQueue=%s | type=%s | anyPlayer=%s | anyPlayerOnlineID=%s | anyPlayerDead=%s",
        s.username,
        s.guid,
        s.steamID,
        s.ownerID,
        s.object,
        s.accessLevel,
        s.fullyConnected,
        s.wasInLoadingQueue,
        s.connectionType,
        s.anyPlayer,
        s.anyPlayerOnlineID,
        s.anyPlayerDead
    )
end

local function connectionStateFingerprint(s)
    return table.concat({
        s.username,
        s.guid,
        s.steamID,
        s.ownerID,
        s.accessLevel,
        s.fullyConnected,
        s.wasInLoadingQueue,
        s.connectionType,
        s.anyPlayer,
        s.anyPlayerOnlineID,
        s.anyPlayerDead,
    }, "|")
end

local function getConnectionList()
    if not GameServer then return nil, "GameServer unavailable" end

    local engine = safeField(GameServer, "udpEngine")
    if engine == "ERROR" or engine == "nil" or engine == nil then
        return nil, "GameServer.udpEngine unavailable"
    end

    local connections = safeField(engine, "connections")
    if connections == "ERROR" or connections == "nil" or connections == nil then
        return nil, "GameServer.udpEngine.connections unavailable"
    end

    return connections, nil
end

local function scanConnections(forceHeartbeat)
    local connections, err = getConnectionList()
    if not connections then
        if not connectionApiWarningLogged then
            connectionApiWarningLogged = true
            log("CONNECTION TELEMETRY UNAVAILABLE | " .. tostring(err))
        end
        return 0
    end

    local size = safeCall(connections, "size")
    if type(size) ~= "number" then
        if not connectionApiWarningLogged then
            connectionApiWarningLogged = true
            log("CONNECTION TELEMETRY UNAVAILABLE | could not read connections:size() | value=" .. tostring(size))
        end
        return 0
    end

    local current = {}

    if size ~= previousConnectionCount then
        log(string.format(
            "CONNECTION COUNT CHANGED | previous=%d | current=%d | inWorld=%d | clock=%s",
            previousConnectionCount,
            size,
            getOnlinePlayers() and getOnlinePlayers():size() or 0,
            formatClock()
        ))
        previousConnectionCount = size
    end

    for i = 0, size - 1 do
        local connection = safeCall(connections, "get", i)
        if connection and connection ~= "ERROR" and connection ~= "N/A" and connection ~= "nil" then
            local snapshot = connectionSnapshot(connection)
            current[snapshot.key] = snapshot

            local old = previousConnections[snapshot.key]
            if not old then
                log("CONNECTION ADDED | " .. describeConnection(snapshot) .. " | clock=" .. formatClock())
            elseif connectionStateFingerprint(old) ~= connectionStateFingerprint(snapshot) then
                log("CONNECTION STATE CHANGED | before={" .. describeConnection(old)
                    .. "} | after={" .. describeConnection(snapshot)
                    .. "} | clock=" .. formatClock())
            end
        end
    end

    for key, old in pairs(previousConnections) do
        if not current[key] then
            log("CONNECTION REMOVED | " .. describeConnection(old) .. " | clock=" .. formatClock())
        end
    end

    previousConnections = current

    if forceHeartbeat then
        log(string.format("CONNECTION HEARTBEAT | connections=%d | clock=%s", size, formatClock()))
        for _, snapshot in pairs(current) do
            log("CONNECTION SNAPSHOT | " .. describeConnection(snapshot))
        end
    end

    return size
end

local function scanPlayers(forceHeartbeat)
    local players = getOnlinePlayers()
    local count = players and players:size() or 0
    local current = {}
    local sleeping = 0
    local dead = 0
    local living = 0

    if count ~= previousPlayerCount then
        log(string.format(
            "PLAYER COUNT CHANGED | previous=%d | current=%d | clock=%s",
            previousPlayerCount,
            count,
            formatClock()
        ))
        previousPlayerCount = count
    end

    if players then
        for i = 0, count - 1 do
            local player = players:get(i)
            if player then
                local snapshot = playerSnapshot(player)
                current[snapshot.key] = snapshot

                if snapshot.asleep == "true" then sleeping = sleeping + 1 end
                if snapshot.dead == "true" then
                    dead = dead + 1
                else
                    living = living + 1
                end

                local old = previousPlayers[snapshot.key]
                if not old then
                    log("PLAYER ADDED | " .. describePlayer(snapshot) .. " | clock=" .. formatClock())
                elseif playerStateFingerprint(old) ~= playerStateFingerprint(snapshot) then
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
        log(string.format(
            "HEARTBEAT | inWorld=%d | living=%d | sleeping=%d | dead=%d | clock=%s",
            count,
            living,
            sleeping,
            dead,
            formatClock()
        ))

        for _, snapshot in pairs(current) do
            log("PLAYER SNAPSHOT | " .. describePlayer(snapshot))
        end
    end

    return {
        inWorld = count,
        living = living,
        sleeping = sleeping,
        dead = dead,
    }
end

local function logSleepTelemetry(label, playerStats, connectionCount)
    local time = getGameTimeTelemetry()
    log(string.format(
        "%s | clock=%s | connections=%d | inWorld=%d | living=%d | sleeping=%d | dead=%d | bFastForward=%s | configuredFastForward=%s | MinutesPerDay=%s | Multiplier=%s | ServerMultiplier=%s | TrueMultiplier=%s | WorldAgeHours=%s",
        label,
        time.clock,
        connectionCount,
        playerStats.inWorld,
        playerStats.living,
        playerStats.sleeping,
        playerStats.dead,
        getGameServerFastForward(),
        getConfiguredFastForwardMultiplier(),
        time.minutesPerDay,
        time.multiplier,
        time.serverMultiplier,
        time.trueMultiplier,
        time.worldAgeHours
    ))
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

    -- Scan connections first so the log shows network state before player state.
    local connectionCount = scanConnections(heartbeat)
    local playerStats = scanPlayers(heartbeat)

    local bFastForward = getGameServerFastForward()
    local sleepTelemetryActive = playerStats.sleeping > 0 or bFastForward == "true"

    if sleepTelemetryActive then
        logSleepTelemetry("SLEEP TELEMETRY", playerStats, connectionCount)
    elseif sleepTelemetryWasActive then
        logSleepTelemetry("SLEEP TELEMETRY END", playerStats, connectionCount)
    end

    sleepTelemetryWasActive = sleepTelemetryActive
end

Events.OnTickEvenPaused.Add(update)

log("Loaded v0.0.2b player/connection-state diagnostic probe.")
log("This build DOES NOT modify MinutesPerDay or any game-time/simulation multiplier.")
log("Watching getOnlinePlayers(), GameServer.udpEngine.connections, and vanilla sleep fast-forward telemetry.")
