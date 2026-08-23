-- Enshrouded Sleep - low-volume multiplayer sleep-roster transition logging
-- Project Zomboid Build 42.20+
--
-- PURPOSE
-- -------
-- Make ordinary field reports diagnosable without enabling verbose diagnostics.
-- Whenever the living-player roster, awake/sleeping identities, effective
-- MinutesPerDay, native FastForwardMultiplier, or PartialSleepSpeedScale changes,
-- emit one compact server log line showing exactly who PZ currently considers
-- awake and asleep.
--
-- This module is observational only. It never changes player state, GameTime,
-- server options, or sandbox options.

if isClient() then return end

local PREFIX = "[EnshroudedSleep]"
local lastSignature = nil

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function toNumber(value)
    if value == nil then return nil end
    local direct = tonumber(value)
    if direct ~= nil then return direct end
    local ok, text = pcall(tostring, value)
    return ok and tonumber(text) or nil
end

local function formatNumber(value, decimals)
    if type(value) ~= "number" then return "N/A" end
    return string.format("%." .. tostring(decimals or 3) .. "f", value)
end

local function sanitize(value)
    local text = tostring(value or "unknown")
    text = string.gsub(text, "[,%[%]|]", "_")
    return text
end

local function playerLabel(player)
    local name = safeMethod(player, "getUsername")
        or safeMethod(player, "getDisplayName")
        or "unknown"
    local onlineID = toNumber(safeMethod(player, "getOnlineID"))
    if onlineID ~= nil then
        return sanitize(name) .. "#" .. tostring(math.floor(onlineID))
    end
    return sanitize(name)
end

local function readNativeFastForward()
    if type(getServerOptions) ~= "function" then return nil end
    local ok, options = pcall(getServerOptions)
    if not ok or not options then return nil end
    return toNumber(safeMethod(options, "getDouble", "FastForwardMultiplier"))
end

local function readPartialSleepSpeedScale()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return tonumber(vars and vars.PartialSleepSpeedScale) or 1.0
end

local function collectRoster()
    local awake = {}
    local sleeping = {}

    if type(getOnlinePlayers) ~= "function" then
        return awake, sleeping
    end

    local players = getOnlinePlayers()
    local size = toNumber(safeMethod(players, "size"))
    if not size then return awake, sleeping end

    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if player and safeMethod(player, "isDead") ~= true then
            local label = playerLabel(player)
            if safeMethod(player, "isAsleep") == true then
                sleeping[#sleeping + 1] = label
            else
                awake[#awake + 1] = label
            end
        end
    end

    table.sort(awake)
    table.sort(sleeping)
    return awake, sleeping
end

local function joinLabels(values)
    if #values == 0 then return "" end
    return table.concat(values, ",")
end

local function update()
    local awake, sleeping = collectRoster()
    local living = #awake + #sleeping

    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    local minutesPerDay = toNumber(safeMethod(gameTime, "getMinutesPerDay"))
    local trueMultiplier = toNumber(safeMethod(gameTime, "getTrueMultiplier"))
    local nativeFastForward = readNativeFastForward()
    local partialScale = readPartialSleepSpeedScale()

    -- Include timing inputs in the signature so live admin changes are recorded
    -- even if the player roster itself does not change.
    local signature = table.concat({
        joinLabels(awake),
        joinLabels(sleeping),
        formatNumber(minutesPerDay, 6),
        formatNumber(nativeFastForward, 6),
        formatNumber(partialScale, 6),
    }, "|")

    if signature == lastSignature then return end
    lastSignature = signature

    print(string.format(
        "%s ROSTER | living=%d | awake=%d [%s] | sleeping=%d [%s] | MinutesPerDay=%s | FastForwardMultiplier=%s | PartialSleepSpeedScale=%s | TrueMultiplier=%s",
        PREFIX,
        living,
        #awake,
        joinLabels(awake),
        #sleeping,
        joinLabels(sleeping),
        formatNumber(minutesPerDay, 3),
        formatNumber(nativeFastForward, 3),
        formatNumber(partialScale, 3),
        formatNumber(trueMultiplier, 3)
    ))
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(update)
else
    Events.OnTick.Add(update)
end

print(PREFIX .. " Loaded low-volume sleep-roster transition logger (awake/sleeping identities + timing inputs).")
