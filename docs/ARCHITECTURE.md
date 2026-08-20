# Architecture

This document describes the current Enshrouded Sleep architecture. Empirical evidence lives in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); normative behavior in [`REQUIREMENTS.md`](REQUIREMENTS.md); durable decisions under [`adr/`](adr/).

Current version: `v0.0.10`  
Release phase: **Public Alpha**

## Design goal

Enshrouded Sleep is a **Project Zomboid Build 42 multiplayer-server mod**. It adds proportional multiplayer sleep while preserving vanilla sleep rules. Local/standalone single-player support is outside project scope.

The mod does **not** globally fast-forward active simulation. When some but not all living server players are asleep, it shortens the real-world duration of the PZ day by changing `GameTime:MinutesPerDay`.

```text
ACTIVE SIMULATION
movement, combat, zombies, vehicles, animations, physics, timed actions
-> intended normal speed

WORLD / CALENDAR TIME
time of day, date, WorldAgeHours, game-minute/world-time systems
-> faster during compression
```

ADR-001 records the decision to use `MinutesPerDay` rather than a global simulation multiplier.

## Server population model

The authoritative server uses only:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

Dead characters do not count. Loading clients do not count until vanilla exposes an instantiated `IsoPlayer`. There is no local `getPlayer()` fallback in server policy or server diagnostics.

ADR-002 records the decision to extend vanilla lifecycle semantics rather than maintain a separate readiness registry.

## Normal sleep state machine

```text
SleepingPlayers == 0
    -> baseline MinutesPerDay

0 < SleepingPlayers < LivingPlayers
    -> proportional calendar compression

SleepingPlayers == LivingPlayers
    -> restore baseline MinutesPerDay
    -> vanilla full-sleep fast-forward owns the state
```

The mod never intentionally stacks partial `MinutesPerDay` compression with vanilla all-asleep acceleration.

## Compression formula

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

Validated reference:

```text
BaselineMinutesPerDay = 90
NativeFastForward = 40
LivingPlayers = 2
SleepingPlayers = 1
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

Controlled validation also exercised factors `5`, `10`, and `20` while monitoring an awake player.

## Native server settings remain authoritative

The controller reads live `GameTime:getMinutesPerDay()`, `SleepAllowed`, `SleepNeeded`, and `FastForwardMultiplier` from the server runtime.

Normal Public Alpha configuration:

```text
Enabled=true
PartialSleepSpeedScale=1.0
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
```

## Server authority and client pacing

The server controller calculates/applies authoritative `MinutesPerDay`; the server sync observer publishes it; connected clients mirror it locally so HUD/watch/sleep clocks remain smoothly paced.

The client does not independently calculate proportional compression and does not use `setTimeOfDay()` or `setMultiplier()` as a substitute for server authority.

ADR-003 records this client-pacing decision.

## Full-sleep handoff

When all living server players are asleep, Enshrouded Sleep restores baseline `MinutesPerDay` and steps aside. Vanilla then performs its own full-sleep acceleration through a separate mechanism.

The v0.0.8 one-player-on-server full-sleep reference demonstrated why these mechanisms must remain analytically separate: a heavily bleeding sleeping player died rapidly while `MinutesPerDay` remained at baseline and vanilla full-sleep acceleration owned the state.

## Diagnostic forced-compression state

v0.0.10 retains a narrow server-only diagnostic state for regression/support testing. It was used to complete SPIKE-004 and is dormant during normal Public Alpha play.

Activation requires:

```text
DiagnosticsEnabled == true
DiagnosticForcedCompressionFactor > 1
LivingPlayers == 1
SleepingPlayers == 0
```

When active:

```text
mode = diagnostic-forced
CalendarCompressionFactor = DiagnosticForcedCompressionFactor
EffectiveMinutesPerDay = BaselineMinutesPerDay / DiagnosticForcedCompressionFactor
```

The controller still does **not** call `GameTime:setMultiplier()`.

### Safety boundary

```text
player sleeps
    -> restore baseline
    -> suspend override

second living player connects
    -> restore baseline
    -> suspend override

zero living players
    -> retain baseline
    -> override remains armed
```

Returning factor to `1.0`, disabling diagnostics, disabling the mod, or encountering a recoverable failure exits toward baseline. While a factor above `1` is armed, normal proportional sleep policy is suppressed so the diagnostic test cannot mix with ordinary multiplayer sleep behavior.

The v0.0.10 runtime test validated the sleep-suspension path.

## Fail-safe behavior

The controller captures the native baseline once and fails toward it. Restoration is attempted when normal partial sleep ends, all players become asleep, native sleep is disabled for normal policy, the mod is disabled, diagnostic forced compression is suspended/exited, or a recoverable controller error occurs.

## Logging / observability

Operational prefixes:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

Verbose diagnostics:

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

All one-second telemetry remains gated by `DiagnosticsEnabled=true`.

## Multiple PZ time domains — validated finding

SPIKE-004 confirmed that different player systems use different time domains.

**Approximately simulation/real-time bound under tested conditions:**

- awake bleeding/body-health loss;
- measured bleeding/scratch timers;
- resting endurance recovery.

**World/calendar-time bound:**

- hunger;
- thirst;
- fatigue;
- calories;
- carbohydrates;
- proteins;
- lipids.

This means faster survival-need progression during partial sleep is expected because genuine game-world time is passing faster. No broad health/survival compensation is currently justified.

Active sickness/food poisoning, poison, zombie infection/fever and extreme thermal injury were not present during the controlled test and remain Public Alpha characterization targets.

## Future compensation policy

Any compensation must be system-specific, evidence-based, and validated. The conceptual inverse factor for a world-time-driven system that should intentionally remain real-time bound is:

```text
RealTimeCompensationFactor = 1 / CalendarCompressionFactor
```

## Non-health world-time systems

Public Alpha will characterize food aging/spoilage, farming/crops, generator fuel usage, corpse decay, composting, weather, and mods driven by game minutes or `WorldAgeHours`.
