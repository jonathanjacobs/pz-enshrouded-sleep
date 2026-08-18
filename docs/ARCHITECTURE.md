# Architecture

This document describes the current Enshrouded Sleep architecture without the historical test-by-test detail. For empirical development history, see [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). For normative behavior, see [`REQUIREMENTS.md`](REQUIREMENTS.md).

## Design goal

Enshrouded Sleep adds proportional multiplayer sleep to Project Zomboid Build 42 while preserving vanilla sleep rules.

The mod does **not** globally fast-forward the active simulation. Instead, when some but not all living players are asleep, it shortens the real-world duration of the Project Zomboid day by changing `GameTime:MinutesPerDay`.

This distinction is central:

```text
ACTIVE SIMULATION
movement, combat, zombies, vehicles, animations, physics, timed actions
-> remains at normal speed

WORLD / CALENDAR TIME
time of day, date, WorldAgeHours, game-minute-driven systems
-> advances faster during partial sleep
```

## Population model

The authoritative server uses the currently instantiated living player population:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

This deliberately follows vanilla-visible player lifecycle semantics. A client that has authenticated but does not yet have an instantiated `IsoPlayer` does not count. Dead characters do not count. Respawns, joins, and disconnects affect the denominator when vanilla changes the instantiated population.

## State machine

The controller has three normal states.

```text
SleepingPlayers == 0
    -> restore native baseline MinutesPerDay

0 < SleepingPlayers < LivingPlayers
    -> calculate proportional calendar compression
    -> set compressed MinutesPerDay

SleepingPlayers == LivingPlayers
    -> restore native baseline MinutesPerDay
    -> stop applying partial compression
    -> vanilla full-sleep fast-forward owns the state
```

The mod never intentionally stacks its `MinutesPerDay` compression with vanilla all-players-asleep fast-forward.

## Compression formula

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

Example using the validated WHG test configuration:

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

The controller derives its policy from Project Zomboid rather than duplicating native settings.

It reads:

- live `GameTime:getMinutesPerDay()` as the baseline;
- `SleepAllowed`;
- `SleepNeeded`;
- `FastForwardMultiplier`.

The mod-specific gameplay settings are intentionally small:

```text
Enabled = true
PartialSleepSpeedScale = 1.0
DiagnosticsEnabled = false
```

`DiagnosticsEnabled` is support instrumentation only and does not change gameplay behavior.

## Server authority and client pacing

Project Zomboid's normal multiplayer synchronization keeps clients close to the authoritative server time, but development testing showed that a runtime server `MinutesPerDay` change is not automatically mirrored to clients.

Enshrouded Sleep therefore has a narrow server-to-client clock-state replication layer:

```text
server controller
    -> calculates and applies authoritative MinutesPerDay

server sync observer
    -> broadcasts the resulting MinutesPerDay

client sync handler
    -> mirrors that MinutesPerDay locally
```

The client does **not** independently calculate proportional compression.

The client sync path intentionally does not call:

```text
setTimeOfDay()
setMultiplier()
GameServer.syncClock()
```

The server remains authoritative for world time and sleep state. The client receives only the day-length pacing value needed to advance smoothly between normal multiplayer time corrections.

A two-second heartbeat allows late-loading clients to converge even if they miss a transition packet. State changes are sent promptly. The server sync observer waits one observer pass after a visible population/sleep-state transition so the authoritative controller can settle `MinutesPerDay` before the new state is published.

## Full-sleep handoff

When all instantiated living players are asleep, Enshrouded Sleep restores the exact baseline `MinutesPerDay` and steps aside.

Vanilla Project Zomboid then performs its own full-sleep acceleration. Testing has shown that vanilla full sleep uses a mechanism distinct from changing `MinutesPerDay`, so the mod does not attempt to reproduce or numerically infer vanilla's full-sleep multiplier.

## Fail-safe behavior

The server captures the native baseline once and fails toward that value.

Recoverable failures should never intentionally leave the server in a compressed day-length state. Baseline restoration is attempted when:

- partial sleep ends;
- all living players become asleep;
- native sleep is disabled;
- the mod is disabled;
- a recoverable controller error occurs.

The client also restores the last server-advertised baseline on disconnect when practical.

## Logging and diagnostics

Normal public-alpha operation retains low-volume transition logging:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

Verbose one-second telemetry is available under:

```text
[EnshroudedSleepDiag][SERVER]
[EnshroudedSleepDiag][CLIENT]
```

but is disabled by default through:

```text
DiagnosticsEnabled = false
```

It should only be enabled temporarily for focused reproduction because it can generate large logs on an active multiplayer server.

## Known architectural boundary: world-time-driven systems

The clock architecture is now behaviorally validated, but changing `MinutesPerDay` intentionally means that world-time-driven systems may progress faster in real time while partial sleep is active.

Systems requiring characterization during public alpha include:

- food aging/spoilage;
- farming/crops;
- generator fuel usage;
- hunger/thirst/fatigue;
- healing;
- corpse decay;
- composting;
- weather;
- other mods driven by game minutes or `WorldAgeHours`.

This is not the same as global simulation acceleration. Whether any of these systems should later be compensated is a product/design decision and is intentionally deferred until field evidence exists.
