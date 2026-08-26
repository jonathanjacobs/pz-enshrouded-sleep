-- Enshrouded Sleep - SPIKE-005 non-mutating world-system diagnostic collector
-- Public Alpha v0.0.10 / development branch only
--
-- Food aging is intentionally handled by FoodTimeDomainDiagnostic_Server.lua,
-- which performs strict Food-class validation. This collector observes only
-- generators, farming objects and the test player's current vehicle.
--
-- Observation only: this file does not compensate, rewrite, delay or otherwise
-- alter vanilla world-system behavior.

if isClient() then return end

local PREFIX = "[EnshroudedSleepWorldDiag][SERVER]"
local SAMPLE_INTERVAL_SECONDS = 5
local SCAN_RADIUS = 3
local MAX_GENERATOR_RECORDS = 8
local MAX_CROP_RECORDS = 8

local lastSampleAt = nil

local function log(message)
    print(PREFIX .. " " .. tostring(message))
end

local function formatNumber(value, decimals)
    value = tonumber(value)
    if value == nil then return "N/A" end
    return string.format("%." .. tostring(decimals or 4) .. "f", value)
end

local function safeMethod(obj, methodName, ...)
    if not obj then return nil end
    local okMethod, method = pcall(function() return obj[methodName] end)
    if not okMethod or not method then return nil end
    local ok, value = pcall(method, obj, ...)
    if not ok then return nil end
    return value
end

local function safeField(obj, fieldName)
    if not obj then return nil end
    local ok, value = pcall(function() return obj[fieldName] end)
    if not ok then return nil end
    return value
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

local function getSingleLivingPlayer()
    if type(getOnlinePlayers) ~= "function" then return nil, 0 end
    local players = getOnlinePlayers()
    if not players then return nil, 0 end

    local size = tonumber(safeMethod(players, "size")) or 0
    local living = 0
    local selected = nil

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

local function objectKey(obj)
    if not obj then return "nil" end
    local id = safeMethod(obj, "getID")
    if id ~= nil then return tostring(id) end
    return tostring(obj)
end

local function addGeneratorRecord(obj, x, y, z, records, seen)
    if not obj or #records >= MAX_GENERATOR_RECORDS then return end

    local fuel = tonumber(safeMethod(obj, "getFuel"))
    local activated = safeMethod(obj, "isActivated")
    if fuel == nil or activated == nil then return end

    local key = objectKey(obj)
    if seen[key] then return end
    seen[key] = true

    records[#records + 1] = {
        x = x,
        y = y,
        z = z,
        fuel = fuel,
        condition = tonumber(safeMethod(obj, "getCondition")),
        activated = activated,
        connected = safeMethod(obj, "isConnected"),
        powerUsing = tonumber(safeMethod(obj, "getTotalPowerUsing")),
    }
end

local function addCropRecord(obj, x, y, z, records, seen)
    if not obj or #records >= MAX_CROP_RECORDS then return end
    local modData = safeMethod(obj, "getModData")
    if not modData then return end

    local seedType = safeField(modData, "seedType")
    local nbOfGrow = safeField(modData, "nbOfGrow")
    local nextGrowing = safeField(modData, "nextGrowing")

    if seedType == nil and nbOfGrow == nil and nextGrowing == nil then return end

    local key = objectKey(obj)
    if seen[key] then return end
    seen[key] = true

    records[#records + 1] = {
        x = x,
        y = y,
        z = z,
        seedType = seedType,
        nbOfGrow = tonumber(nbOfGrow),
        nextGrowing = tonumber(nextGrowing),
        waterLvl = tonumber(safeField(modData, "waterLvl")),
        health = tonumber(safeField(modData, "health")),
        mildewLvl = tonumber(safeField(modData, "mildewLvl")),
        aphidLvl = tonumber(safeField(modData, "aphidLvl")),
        fliesLvl = tonumber(safeField(modData, "fliesLvl")),
        state = safeField(modData, "state"),
    }
end

local function scanNearbyWorld(player, generatorRecords, cropRecords)
    local cell = type(getCell) == "function" and getCell() or nil
    if not cell then return end

    local px = math.floor(tonumber(safeMethod(player, "getX")) or 0)
    local py = math.floor(tonumber(safeMethod(player, "getY")) or 0)
    local pz = math.floor(tonumber(safeMethod(player, "getZ")) or 0)

    local seenGenerators = {}
    local seenCrops = {}

    for dx = -SCAN_RADIUS, SCAN_RADIUS do
        for dy = -SCAN_RADIUS, SCAN_RADIUS do
            local x = px + dx
            local y = py + dy
            local square = safeMethod(cell, "getGridSquare", x, y, pz)
            if square then
                local objects = safeMethod(square, "getObjects")
                local size = tonumber(safeMethod(objects, "size")) or 0

                for i = 0, size - 1 do
                    local obj = safeMethod(objects, "get", i)
                    if obj then
                        addGeneratorRecord(obj, x, y, pz, generatorRecords, seenGenerators)
                        addCropRecord(obj, x, y, pz, cropRecords, seenCrops)
                    end
                end
            end
        end
    end
end

local function vehicleRecord(player)
    local vehicle = safeMethod(player, "getVehicle")
    if not vehicle then return nil end

    local gasTank = safeMethod(vehicle, "getPartById", "GasTank")
    local batteryPart = safeMethod(vehicle, "getBattery") or safeMethod(vehicle, "getPartById", "Battery")
    local batteryItem = batteryPart and safeMethod(batteryPart, "getInventoryItem") or nil

    -- BaseVehicle:getBatteryCharge() is the canonical vehicle charge value used
    -- by vanilla vehicle electrical logic. The previous diagnostic attempted to
    -- read InventoryItem:getUsedDelta(), which is not reliably exposed for the
    -- vehicle battery object in B42 and produced N/A in the first vehicle test.
    local batteryCharge = tonumber(safeMethod(vehicle, "getBatteryCharge"))
    local batteryItemCharge = batteryItem and tonumber(safeMethod(batteryItem, "getCurrentUsesFloat")) or nil

    return {
        script = safeMethod(vehicle, "getScriptName"),
        running = safeMethod(vehicle, "isEngineRunning"),
        engineSpeed = tonumber(safeMethod(vehicle, "getEngineSpeed")),
        fuel = gasTank and tonumber(safeMethod(gasTank, "getContainerContentAmount")) or nil,
        batteryCharge = batteryCharge,
        batteryItemCharge = batteryItemCharge,
        headlightsOn = safeMethod(vehicle, "getHeadlightsOn"),
        lightbarLightsMode = tonumber(safeMethod(vehicle, "getLightbarLightsMode")),
        lightbarSirenMode = tonumber(safeMethod(vehicle, "getLightbarSirenMode")),
    }
end

local function emitSample()
    local player, living = getSingleLivingPlayer()
    if not player then
        log("SAMPLE SKIP | reason=requires-exactly-one-living-player | living=" .. tostring(living))
        return
    end

    local gameTime = type(getGameTime) == "function" and getGameTime() or nil
    local worldAgeHours = tonumber(safeMethod(gameTime, "getWorldAgeHours"))
    local timeOfDay = tonumber(safeMethod(gameTime, "getTimeOfDay"))
    local minutesPerDay = tonumber(safeMethod(gameTime, "getMinutesPerDay"))
    local trueMultiplier = tonumber(safeMethod(gameTime, "getTrueMultiplier"))

    local generatorRecords = {}
    local cropRecords = {}
    scanNearbyWorld(player, generatorRecords, cropRecords)
    local vehicle = vehicleRecord(player)

    log(string.format(
        "SAMPLE | WorldAgeHours=%s | TimeOfDay=%s | MinutesPerDay=%s | DiagnosticForcedCompressionFactor=%s | TrueMultiplier=%s | generators=%d | crops=%d | vehicle=%s",
        formatNumber(worldAgeHours, 6),
        formatNumber(timeOfDay, 6),
        formatNumber(minutesPerDay, 4),
        formatNumber(diagnosticFactor(), 3),
        formatNumber(trueMultiplier, 4),
        #generatorRecords,
        #cropRecords,
        vehicle and "yes" or "no"
    ))

    for i, record in ipairs(generatorRecords) do
        log(string.format(
            "GENERATOR | n=%d | xyz=%d,%d,%d | activated=%s | connected=%s | fuel=%s | condition=%s | powerUsing=%s",
            i,
            record.x,
            record.y,
            record.z,
            tostring(record.activated),
            tostring(record.connected),
            formatNumber(record.fuel, 6),
            formatNumber(record.condition, 4),
            formatNumber(record.powerUsing, 6)
        ))
    end

    for i, record in ipairs(cropRecords) do
        log(string.format(
            "CROP | n=%d | xyz=%d,%d,%d | seedType=%s | nbOfGrow=%s | nextGrowing=%s | waterLvl=%s | health=%s | mildew=%s | aphid=%s | flies=%s | state=%s",
            i,
            record.x,
            record.y,
            record.z,
            tostring(record.seedType),
            formatNumber(record.nbOfGrow, 2),
            formatNumber(record.nextGrowing, 4),
            formatNumber(record.waterLvl, 4),
            formatNumber(record.health, 4),
            formatNumber(record.mildewLvl, 4),
            formatNumber(record.aphidLvl, 4),
            formatNumber(record.fliesLvl, 4),
            tostring(record.state)
        ))
    end

    if vehicle then
        log(string.format(
            "VEHICLE | script=%s | running=%s | engineSpeed=%s | fuel=%s | batteryCharge=%s | batteryItemCharge=%s | headlightsOn=%s | lightbarLightsMode=%s | lightbarSirenMode=%s",
            tostring(vehicle.script),
            tostring(vehicle.running),
            formatNumber(vehicle.engineSpeed, 3),
            formatNumber(vehicle.fuel, 6),
            formatNumber(vehicle.batteryCharge, 8),
            formatNumber(vehicle.batteryItemCharge, 8),
            tostring(vehicle.headlightsOn),
            tostring(vehicle.lightbarLightsMode),
            tostring(vehicle.lightbarSirenMode)
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

log("Loaded SPIKE-005 world-system diagnostic collector (generators/crops/vehicle); vehicle battery uses BaseVehicle:getBatteryCharge(); food uses the strict Food-class diagnostic.")
