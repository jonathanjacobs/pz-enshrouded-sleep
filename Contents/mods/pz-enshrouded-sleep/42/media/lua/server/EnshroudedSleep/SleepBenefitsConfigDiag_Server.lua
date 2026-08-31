-- Enshrouded Sleep - concise sleep-benefit configuration diagnostics
-- Development-only helper for SPIKE-007. Read-only; never mutates sandbox/player state.

if isClient() then return end

local PREFIX = "[EnshroudedSleepBenefits][SERVER]"
local BUILD_VERSION = "0.1.1+sleep-benefits-server-xp-dev"
local lastSignature = nil

local function value(vars, key, fallback)
    if vars and vars[key] ~= nil then return vars[key] end
    return fallback
end

local function emitIfChanged()
    local vars = SandboxVars and SandboxVars.EnshroudedSleep or nil
    local enabled = vars ~= nil and vars.SleepBenefitsEnabled == true
    local restedMin = tonumber(value(vars, "RestedMinimumSleepHours", 6.0)) or 6.0
    local restedDuration = tonumber(value(vars, "RestedDurationHours", 12.0)) or 12.0
    local restedXP = tonumber(value(vars, "RestedXPBonusPercent", 5.0)) or 5.0
    local wellMin = tonumber(value(vars, "WellRestedMinimumSleepHours", 9.0)) or 9.0
    local wellDuration = tonumber(value(vars, "WellRestedDurationHours", 24.0)) or 24.0
    local wellXP = tonumber(value(vars, "WellRestedXPBonusPercent", 5.0)) or 5.0
    local wellEndurance = tonumber(value(vars, "WellRestedEnduranceRecoveryBonusPercent", 10.0)) or 10.0
    local diagnostics = vars ~= nil and vars.DiagnosticsEnabled == true

    local signature = table.concat({
        tostring(enabled), tostring(restedMin), tostring(restedDuration), tostring(restedXP),
        tostring(wellMin), tostring(wellDuration), tostring(wellXP), tostring(wellEndurance),
        tostring(diagnostics),
    }, "|")
    if signature == lastSignature then return end
    lastSignature = signature

    print(string.format(
        "%s CONFIG | build=%s | Enabled=%s | Rested=%.2fh/%.2fh/+%.2f%%XP | WellRested=%.2fh/%.2fh/+%.2f%%XP/+%.2f%%Endurance | Diagnostics=%s",
        PREFIX, BUILD_VERSION, tostring(enabled), restedMin, restedDuration, restedXP,
        wellMin, wellDuration, wellXP, wellEndurance, tostring(diagnostics)
    ))
end

if Events.OnTickEvenPaused then
    Events.OnTickEvenPaused.Add(emitIfChanged)
else
    Events.OnTick.Add(emitIfChanged)
end

print(PREFIX .. " Loaded config diagnostics | build=" .. BUILD_VERSION)
