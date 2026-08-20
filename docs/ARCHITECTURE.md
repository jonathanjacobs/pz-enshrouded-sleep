# Architecture

This document describes the current Enshrouded Sleep architecture without test-by-test history. For empirical evidence, see [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). For normative behavior, see [`REQUIREMENTS.md`](REQUIREMENTS.md). Durable decisions are recorded under [`adr/`](adr/).

Current development version: `v0.0.10`

## Design goal

Enshrouded Sleep adds proportional multiplayer sleep to Project Zomboid Build 42 while preserving vanilla sleep rules.

The mod does **not** globally fast-forward active simulation. When some but not all living players are asleep, it shortens the real-world duration of the PZ day by changing `GameTime:MinutesPerDay`.

```text
ACTIVE SIMULATION
movement, combat, zombies, vehicles, animations, physics, timed actions
-> intended to remain normal-speed

WORLD / CALENDAR TIME
time of day, date, WorldAgeHours, game-minute/world-time-driven systems
-> advances faster during partial sleep
```

ADR-001 records the decision to use `MinutesPerDay` rather than a global simulation multiplier.

## Normal multiplayer population model

The authoritative server uses:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

A client that has authenticated but does not yet have an instantiated `IsoPlayer` does not count. Dead characters do not count. Respawns, joins, and disconnects affect the denominator when vanilla changes instantiated player state.

ADR-002 records the decision to extend vanilla lifecycle semantics instead of maintaining a second custom readiness registry.

## Normal sleep state machine

```text
SleepingPlayers == 0
    -> restore native baseline MinutesPerDay

0 < SleepingPlayers < LivingPlayers
    -> calculate proportional calendar compression
    -> set compressed MinutesPerDay

SleepingPlayers == LivingPlayers
    -> restore native baseline MinutesPerDay
    -> stop partial compression
    -> vanilla full-sleep fast-forward owns the state
```

The mod never intentionally stacks partial `MinutesPerDay` compression with vanilla all-asleep fast-forward.

## Compression formula

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

Validated two-player example:

```text
BaselineMinutesPerDay = 90
NativeFastForward = 40
PartialSleepSpeedScale = 1.0
LivingPlayers = 2
SleepingPlayers = 1

SleepFraction = 0.5
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

The v0.0.9 SPIKE-004 run also validated factor `5` / `MinutesPerDay=18` and factor `10` / `MinutesPerDay=9` while the monitored player remained awake.

## Native settings remain authoritative

Normal gameplay reads:

- live `GameTime:getMinutesPerDay()` baseline;
- `SleepAllowed`;
- `SleepNeeded`;
- `FastForwardMultiplier`.

Normal Public Alpha configuration:

```text
Enabled = true
PartialSleepSpeedScale = 1.0
DiagnosticsEnabled = false
DiagnosticForcedCompressionFactor = 1.0
```

`DiagnosticForcedCompressionFactor=1.0` is inert.

## Server authority and client pacing

Testing established that changing authoritative `MinutesPerDay` does not automatically make tested multiplayer clients use the same day-length pacing value. The architecture therefore uses:

```text
server controller
    -> calculates/applies authoritative MinutesPerDay

server sync observer
    -> publishes resulting MinutesPerDay

client sync handler
    -> mirrors that MinutesPerDay locally
```

The client does not independently calculate proportional compression and intentionally does not call `setTimeOfDay()` or `setMultiplier()`.

A two-second heartbeat allows late-loading clients to converge. A one-observer-pass settling guard lets the controller apply the new day length before the synchronization observer publishes a newly observed population/sleep state.

ADR-003 records this client-pacing decision.

## Full-sleep handoff

When all instantiated living players are asleep, Enshrouded Sleep restores the exact baseline `MinutesPerDay` and steps aside. Vanilla then performs its own full-sleep acceleration using a mechanism distinct from the mod's partial `MinutesPerDay` compression.

The v0.0.8 solo reference demonstrated why these mechanisms must remain analytically separate: a heavily bleeding sleeping character died within a few real seconds while `MinutesPerDay` remained at baseline and vanilla full-sleep acceleration owned the state.

## v0.0.10 diagnostic forced-compression state

SPIKE-004 still needs to classify several **awake-player** survival values. Requiring a second sleeping client adds operational complexity without changing the causal variable under investigation: `MinutesPerDay`.

v0.0.10 therefore adds a tightly gated diagnostic state:

```text
DiagnosticsEnabled == true
AND
DiagnosticForcedCompressionFactor > 1
```

When at least one living player is observed and none is asleep:

```text
mode = diagnostic-forced
CalendarCompressionFactor = DiagnosticForcedCompressionFactor
EffectiveMinutesPerDay = BaselineMinutesPerDay / DiagnosticForcedCompressionFactor
```

The controller still does **not** call `GameTime:setMultiplier()`.

### Safety boundary

The forced diagnostic state is deliberately subordinate to vanilla sleep safety:

```text
any observed living player asleep
    -> diagnostic override suspended
    -> baseline MinutesPerDay restored
    -> vanilla sleep/full-sleep mechanisms may proceed
```

Other exit paths also restore baseline:

- `DiagnosticsEnabled=false`;
- `DiagnosticForcedCompressionFactor=1.0`;
- mod disabled;
- recoverable error;
- no living player observed.

The configured factor is bounded to `1`–`20` and is test-only.

### Standalone player discovery

Normal multiplayer population semantics remain `getOnlinePlayers()`-based. For the diagnostic-only single-player path, a guarded `getPlayer()` fallback is permitted when the online-player collection is absent or empty.

This fallback exists only to make one-character SPIKE-004 telemetry and the test override observable in standalone play. It does not redefine the normal multiplayer denominator.

### Hosted synchronization behavior

If the same diagnostic forced state is ever used on a hosted multiplayer test, the server sync observer recognizes `diagnostic-forced` and broadcasts the actual authoritative compressed `MinutesPerDay`. It must not misclassify the no-sleeper state as normal baseline and send baseline back to clients.

## Fail-safe behavior

The controller captures the native baseline once and fails toward it. Restoration is attempted when:

- normal partial sleep ends;
- all living players become asleep;
- native sleep is disabled during normal policy;
- the mod is disabled;
- diagnostic forced compression is disabled/suspended;
- a recoverable controller error occurs.

The client restores the last server-advertised baseline on disconnect when practical.

## Logging / observability architecture

### Low-volume operational logging

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

Diagnostic override transitions are intentionally conspicuous:

```text
TEST OVERRIDE ACTIVE
TEST OVERRIDE SUSPENDED
TEST OVERRIDE ARMED
```

### Broad health/body diagnostics

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
```

These retain the detailed injury/body telemetry already useful in v0.0.8/v0.0.9 testing.

### Focused v0.0.10 survival diagnostics

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

A shared `SurvivalStatProbe` reads current Build 42 continuous values through `Stats:get(CharacterStat)`, Moodles through `getMoodleLevel(MoodleType)`, Nutrition through direct getters, and emits capability diagnostics for unavailable paths.

### Standalone injury bridge

```text
[EnshroudedSleepStandaloneHealthDiag][SERVER]
```

This activates only when diagnostics are enabled, no populated `getOnlinePlayers()` collection is available, and a local `getPlayer()` exists. It preserves detailed overall-health/bleeding/body-part telemetry for the single-player test.

All one-second samplers are gated by `DiagnosticsEnabled=true` and should remain disabled in normal play.

## Architectural boundary — multiple PZ time domains

The validated clock architecture establishes that world/calendar time can be compressed without globally accelerating active movement/combat simulation. It does **not** imply that every health, survival, healing, environmental, or mod subsystem uses the same time domain.

A subsystem may be:

- simulation/real-time bound;
- world/calendar-time bound;
- mixed/nonlinear;
- event-driven;
- differently exposed on client/server.

v0.0.9 demonstrated both categories directly: awake bleeding/injury progression was approximately real-time bound, while core nutrition stores tracked calendar compression almost exactly.

[`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) remains open to classify hunger, thirst, fatigue, endurance and other practical survival variables using the v0.0.10 single-player forced-compression path.

## Future compensation policy

The architecture deliberately does **not** assume that every world-time-driven system should be compensated.

If measured evidence establishes a system that should remain tied to real/simulation time, the conceptual compensation factor is:

```text
RealTimeCompensationFactor = 1 / CalendarCompressionFactor
```

Any implementation must be system-specific and validated. Broad global compensation would risk undoing intended world-time progression or fighting vanilla internals.

## Non-health world-time systems

After the player-health safety gate, Public Alpha will characterize food aging/spoilage, farming/crops, generator fuel usage, corpse decay, composting, weather, and mods driven by game minutes or `WorldAgeHours`.
