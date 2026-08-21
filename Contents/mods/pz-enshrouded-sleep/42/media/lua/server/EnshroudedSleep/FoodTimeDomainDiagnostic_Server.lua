-- Enshrouded Sleep - SPIKE-005 food time-domain diagnostic
-- Development branch only. Observation-only: never mutates food/container state.

if isClient() then return end

local PREFIX = "[EnshroudedSleepFoodDiag][SERVER]"
local SAMPLE_INTERVAL_SECONDS = 5
local SCAN_RADIUS = 3
local MAX_RECORDS = 24
local lastSampleAt = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function formatNumber(value, decimals)
    value = tonumber(value)
    if value == nil then return "N/A" end
    return string.format("%." .. tostring(decimals or 4) .. "f", value)
end

local function diagnosticsEnabled()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    return vars ~= nil and vars.DiagnosticsEnabled == true
end

local function diagnosticFactor()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local factor = tonumber(vars and vars.DiagnosticForcedCompressionFactor) or 1.0
    if factor < 1.0 then factor = 1.0 end
    if factor > 20.0 then factor = 20.0 end
    return factor
end

local function isFood(item)
    if not item then return false end

    -- Build 42 exposes the normal PZ instanceof bridge to Lua. Prefer the real
    -- Java class test; do not infer Food from generic InventoryItem aging methods.
    if type(instanceof) == "function" then
        local ok, result = pcall(instanceof, item, "Food")
        if ok then return result == true end
    end

    -- Conservative fallback for an unusual bridge environment. Generic
    -- InventoryItem currently reports sentinel 1e9 aging thresholds, which is
    -- exactly what caused the first SPIKE-005 collector to misclassify clothing,
    -- keys, etc. Only accept finite food-like thresholds here.
    local offAge = tonumber(safeMethod(item, "getOffAge"))
    local offAgeMax = tonumber(safeMethod(item, "getOffAgeMax"))
    return offAge ~= nil and offAgeMax ~= nil and offAge < 100000000 and offAgeMax < 100000000
end

local function objectKey(obj)
    local id = safeMethod(obj, "getID")
    if id ~= nil then return tostring(id) end
    return tostring(obj)
end

local function addFood(item, source, records, seen)
    if not isFood(item) or #records >= MAX_RECORDS then return end
    local key = objectKey(item)
    if seen[key] then return end
    seen[key] = true

    records[#records + 1] = {
        source = source,
        item = tostring(safeMethod(item, "getFullType") or safeMethod(item, "getName") or item),
        age = tonumber(safeMethod(item, "getAge")),
        offAge = tonumber(safeMethod(item, "getOffAge")),
        offAgeMax = tonumber(safeMethod(item, "getOffAgeMax")),
        heat = tonumber(safeMethod(item, "getHeat")),
        freezingTime = tonumber(safeMethod(item, "getFreezingTime")),
        frozen = safeMethod(item, "isFrozen"),
        rotten = safeMethod(item, "isRotten"),
    }
end

local function scanContainer(container, source, records, seen, depth)
    if not container or #records >= MAX_RECORDS then return end
    depth = depth or 0
    if depth > 2 then return end

    local items = safeMethod(container, "getItems")
    local size = tonumber(safeMethod(items, "size")) or 0
    for i = 0, size - 1 do
        if #records >= MAX_RECORDS then return end
        local item = safeMethod(items, "get", i)
        if item then
            addFood(item, source, records, seen)
            local nested = safeMethod(item, "getInventory")
            if nested then
                scanContainer(nested, source .. "/nested", records, seen, depth + 1)
            end
        end
    end
end

local function singleLivingPlayer()
    if type(getOnlinePlayers) ~= "function" then return nil, 0 end
    local players = getOnlinePlayers()
    local size = tonumber(safeMethod(players, "size")) or 0
    local selected = nil
    local living = 0
    for i = 0, size - 1 do
        local player = safeMethod(players, "get", i)
        if player and safeMethod(player, "isDead") ~= true then
            living = living + 1
            selected = player
        end
    end
    if living ~= 1 then return nil, living end
    return selected, living
end

local function collectFood(player)
    local records = {}
    local seen = {}

    scanContainer(safeMethod(player, "getInventory"), "player-inventory", records, seen, 0)

    local cell = type(getCell) == "function" and getCell() or nil
    if not cell then return records end

    local px = math.floor(tonumber(safeMethod(player, "getX")) or 0)
    local py = math.floor(tonumber(safeMethod(player, "getY")) or 0)
    local pz = math.floor(tonumber(safeMethod(player, "getZ")) or 0)

    for dx = -SCAN_RADIUS, SCAN_RADIUS do
        for dy = -SCAN_RADIUS, SCAN_RADIUS do
            local x, y = px + dx, py + dy
            local square = safeMethod(cell, "getGridSquare", x, y, pz)
            local objects = square and safeMethod(square, "getObjects") or nil
            local size = tonumber(safeMethod(objects, "size")) or 0
            for i = 0, size - 1 do
                if #records >= MAX_RECORDS then return records end
                local obj = safeMethod(objects, "get", i)
                local container = obj and safeMethod(obj, "getContainer") or nil
                if container then
                    local containerType = tostring(safeMethod(container, "getType") or "container")
                    scanContainer(
                        container,
                        string.format("%s@%d,%d,%d", containerType, x, y, pz),
                        records,
                        seen,
                        0
                    )
                end
            end
        end
    end

    return records
end

local function emitSample()
    local player, living = singleLivingPlayer()
    if not player then
        log("SAMPLE SKIP | reason=requires-exactly-one-living-player | living=" .. tostring(living))
        return
    end

    local gt = type(getGameTime) == "function" and getGameTime() or nil
    local worldAgeHours = tonumber(safeMethod(gt, "getWorldAgeHours"))
    local minutesPerDay = tonumber(safeMethod(gt, "getMinutesPerDay"))
    local trueMultiplier = tonumber(safeMethod(gt, "getTrueMultiplier"))
    local records = collectFood(player)

    log(string.format(
        "SAMPLE | WorldAgeHours=%s | MinutesPerDay=%s | DiagnosticForcedCompressionFactor=%s | TrueMultiplier=%s | food=%d",
        formatNumber(worldAgeHours, 6),
        formatNumber(minutesPerDay, 4),
        formatNumber(diagnosticFactor(), 3),
        formatNumber(trueMultiplier, 4),
        #records
    ))

    for i, r in ipairs(records) do
        log(string.format(
            "FOOD | n=%d | source=%s | item=%s | age=%s | offAge=%s | offAgeMax=%s | heat=%s | freezingTime=%s | frozen=%s | rotten=%s",
            i,
            tostring(r.source),
            tostring(r.item),
            formatNumber(r.age, 6),
            formatNumber(r.offAge, 4),
            formatNumber(r.offAgeMax, 4),
            formatNumber(r.heat, 4),
            formatNumber(r.freezingTime, 4),
            tostring(r.frozen),
            tostring(r.rotten)
        ))
    end
end

local function update()
    if not diagnosticsEnabled() then
        lastSampleAt = nil
        return
    end
    local now = os.time()
    if lastSampleAt ~= nil and now - lastSampleAt < SAMPLE_INTERVAL_SECONDS then return end
    lastSampleAt = now
    emitSample()
end

Events.OnTickEvenPaused.Add(update)

log("Loaded SPIKE-005 Food-class diagnostic; observation-only and gated by DiagnosticsEnabled=true.")
