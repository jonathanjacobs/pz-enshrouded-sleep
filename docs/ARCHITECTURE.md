# Architecture

This document describes the current Enshrouded Sleep architecture without test-by-test history. For empirical evidence, see [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). For normative behavior, see [`REQUIREMENTS.md`](REQUIREMENTS.md). Durable decisions are recorded under [`adr/`](adr/).

Current development version: `v0.0.8`

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

## Population model

The authoritative server uses:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

A client that has authenticated but does not yet have an instantiated `IsoPlayer` does not count. Dead characters do not count. Respawns, joins, and disconnects affect the denominator when vanilla changes instantiated player state.

ADR-002 records the decision to extend vanilla lifecycle semantics instead of maintaining a second custom readiness registry.

## State machine

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

At `MinutesPerDay=4.5`, world time advances roughly 5.33 in-game minutes per real second.

## Native settings remain authoritative

The controller reads:

- live `GameTime:getMinutesPerDay()` baseline;
- `SleepAllowed`;
- `SleepNeeded`;
- `FastForwardMultiplier`.

Mod-specific configuration:

```text
Enabled = true
PartialSleepSpeedScale = 1.0
DiagnosticsEnabled = false
```

`DiagnosticsEnabled` changes observability only; it must not affect gameplay policy.

## Server authority and client pacing

Testing established that changing server `MinutesPerDay` does not automatically make tested clients use the same day-length pacing value. Without explicit synchronization, clients drift between native multiplayer corrections and visible clocks jump.

The architecture therefore uses:

```text
server controller
    -> calculates/applies authoritative MinutesPerDay

server sync observer
    -> publishes resulting MinutesPerDay

client sync handler
    -> mirrors that MinutesPerDay locally
```

The client does not independently calculate proportional compression and intentionally does not call:

```text
setTimeOfDay()
setMultiplier()
GameServer.syncClock()
```

A two-second heartbeat allows late-loading clients to converge. A one-observer-pass settling guard lets the controller apply the new day length before the synchronization observer publishes a newly observed population/sleep state.

ADR-003 records this client-pacing decision.

## Full-sleep handoff

When all instantiated living players are asleep, Enshrouded Sleep restores the exact baseline `MinutesPerDay` and steps aside. Vanilla then performs its own full-sleep acceleration using a mechanism distinct from `MinutesPerDay`.

## Fail-safe behavior

The server captures the native baseline and fails toward it. Restoration is attempted when:

- partial sleep ends;
- all living players become asleep;
- native sleep is disabled;
- the mod is disabled;
- a recoverable controller error occurs.

The client restores the last server-advertised baseline on disconnect when practical.

## Logging / observability architecture

### Low-volume operational logging

Normal operation retains transition/startup logging:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

### Verbose clock/sleep diagnostics

```text
[EnshroudedSleepDiag][SERVER]
[EnshroudedSleepDiag][CLIENT]
```

### v0.0.8 health/time-domain diagnostics

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
```

All verbose samplers are gated by:

```text
DiagnosticsEnabled = false
```

by default.

When enabled, sampling occurs once per real second rather than every simulation tick.

The new server health diagnostic records every instantiated living player. The client health diagnostic records the owning local player. This dual-sided design is intentional: previous sleep telemetry showed that some useful player timing/state values are exposed differently on server and client.

The health diagnostics are strictly observational and use guarded method calls. Missing Lua-exposed getters become `N/A` rather than failing the gameplay session.

## Architectural boundary — multiple PZ time domains

The validated clock architecture establishes that world/calendar time can be compressed without globally accelerating active movement/combat simulation. It does **not** prove that every health, survival, healing, environmental, or mod subsystem remains tied to real/simulation time.

A subsystem may be:

- simulation/real-time bound;
- world/calendar-time bound;
- mixed/nonlinear;
- event-driven;
- differently exposed on client/server.

This is now a first-class architecture concern rather than a documentation footnote.

### Current blocking investigation

[`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) maps player health/survival variables under baseline and partial compression before Public Alpha deployment.

High-priority variables include:

- bleeding and actual health loss;
- hunger/thirst;
- fatigue/endurance;
- wound/injury healing timers;
- sickness/poison/infection;
- body temperature/cold progression.

If a system is world-time bound, its real-time rate during compression factor `A` may approach `A` times baseline. That behavior is not automatically a defect; the product decision depends on severity and gameplay consequences. High-severity awake-player harm is a deployment blocker.

## Future compensation policy

The architecture deliberately does **not** assume that every world-time-driven system should be compensated.

If SPIKE-004 or later field testing identifies a system that should remain tied to real/simulation time, the natural conceptual compensation factor is:

```text
RealTimeCompensationFactor = 1 / CalendarCompressionFactor
```

Any actual compensation must be system-specific, measured, and validated. Broad global compensation would risk undoing intended world-time progression or fighting vanilla internals.

## Non-health world-time systems

After the player-health safety gate, Public Alpha will characterize:

- food aging/spoilage;
- farming/crops;
- generator fuel usage;
- corpse decay;
- composting;
- weather;
- mods driven by game minutes or `WorldAgeHours`.

Whether these should follow compressed world time, be documented as expected, or receive optional compensation remains an evidence-driven product decision.
