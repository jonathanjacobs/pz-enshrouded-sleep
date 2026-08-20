# Architecture

This document describes the current Enshrouded Sleep architecture. Empirical evidence lives in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); normative behavior in [`REQUIREMENTS.md`](REQUIREMENTS.md); durable decisions under [`adr/`](adr/).

Current development version: `v0.0.10`

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

v0.0.9 also validated factor `5` / `MinutesPerDay=18` and factor `10` / `MinutesPerDay=9` with an awake monitored player.

## Native server settings remain authoritative

The controller reads live `GameTime:getMinutesPerDay()`, `SleepAllowed`, `SleepNeeded`, and `FastForwardMultiplier` from the server runtime.

Normal configuration:

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

## v0.0.10 diagnostic forced-compression state

SPIKE-004 needs to classify several **awake-player** survival variables. v0.0.10 adds a narrow server-only diagnostic state to reproduce a chosen calendar-compression factor without requiring a second sleeping client.

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

The forced diagnostic state is intentionally restricted to exactly one awake connected living player:

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

Returning factor to `1.0`, disabling diagnostics, disabling the mod, or encountering a recoverable failure also exits toward baseline.

While a factor above `1` is armed, normal proportional sleep policy is suppressed so the diagnostic test cannot mix with ordinary multiplayer sleep behavior.

### Synchronization behavior

The server sync observer recognizes `diagnostic-forced` only when `living=1`, `sleeping=0`, and authoritative `MinutesPerDay` is compressed. It publishes the actual compressed value to the connected client. If the population/sleep safety conditions cease to hold, the controller restores baseline and sync follows baseline.

## Fail-safe behavior

The controller captures the native baseline once and fails toward it. Restoration is attempted when normal partial sleep ends, all players become asleep, native sleep is disabled for normal policy, the mod is disabled, diagnostic forced compression is suspended/exited, or a recoverable controller error occurs.

## Logging / observability

Operational prefixes:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

Broad health/body diagnostics:

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
```

Focused v0.0.10 survival diagnostics:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Diagnostic override transitions are conspicuous:

```text
TEST OVERRIDE ACTIVE
TEST OVERRIDE SUSPENDED
TEST OVERRIDE ARMED
```

All one-second telemetry remains gated by `DiagnosticsEnabled=true`.

## Multiple PZ time domains

The validated architecture proves world/calendar time can be compressed without globally accelerating active movement/combat simulation. It does not imply every health, survival, healing, environment, or mod subsystem uses the same clock.

v0.0.9 demonstrated this directly: awake bleeding/injury progression was approximately real-time bound, while core nutrition stores tracked calendar compression almost exactly.

[`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) remains open to classify hunger, thirst, fatigue, endurance and other practical survival variables using the v0.0.10 one-connected-player multiplayer-server test.

## Future compensation policy

No broad compensation is assumed. Any compensation must be system-specific, evidence-based, and validated. The conceptual inverse factor for a world-time-driven system that should remain real-time bound is:

```text
RealTimeCompensationFactor = 1 / CalendarCompressionFactor
```

## Non-health world-time systems

After the player-health gate, Public Alpha will characterize food aging/spoilage, farming/crops, generator fuel usage, corpse decay, composting, weather, and mods driven by game minutes or `WorldAgeHours`.
