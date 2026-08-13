# Enshrouded Sleep for Project Zomboid B42

An experimental multiplayer sleep mod for Project Zomboid Build 42 that adds Enshrouded-style proportional partial sleeping while leaving vanilla Project Zomboid in control of normal sleep behavior.

The intended behavior is simple:

- players sleep using vanilla Project Zomboid rules;
- if no currently instantiated living player is asleep, world time stays at the native baseline;
- if some but not all currently instantiated living players are asleep, world/calendar time accelerates in proportion to the fraction asleep;
- awake gameplay remains at normal simulation speed;
- if all currently instantiated living players are asleep, the mod restores the native clock baseline and vanilla full-sleep fast-forward takes over.

The project is currently in the diagnostic/prototyping stage. The current implementation is `v0.0.2b`; the next functional target is the first proportional-sleep prototype.

See [`REQUIREMENTS.md`](REQUIREMENTS.md) for the canonical detailed specification and acceptance tests.

## MVP philosophy: extend vanilla, do not replace it

The mod is intentionally designed as a thin behavioral extension around vanilla sleep rather than a separate multiplayer sleep system.

Vanilla Project Zomboid remains authoritative for:

- `SleepAllowed`;
- `SleepNeeded` and fatigue requirements;
- entering and leaving sleep;
- death and respawn;
- joining and loading;
- spectators and administrative sessions;
- all-living-players-asleep fast-forward.

The mod adds one missing branch:

> When some, but not all, currently instantiated living players are asleep, accelerate world/calendar time proportionally without globally accelerating active gameplay simulation.

The MVP does **not** maintain its own READY/NOT READY state, pre-spawn connection registry, loading-player handshake, or death/respawn suppression layer. It uses the instantiated living-player population that vanilla exposes through `getOnlinePlayers()` and accepts vanilla lifecycle semantics for joining, death, respawn, and disconnects.

## Design principle: inherit native server settings

The production mod must not duplicate Project Zomboid's server configuration with hard-coded values.

The native server remains authoritative for:

- day length / live `MinutesPerDay`;
- `SleepAllowed`;
- `SleepNeeded`;
- `FastForwardMultiplier`.

The MVP adds only:

```text
Enabled = true
PartialSleepSpeedScale = 1.0
```

The live baseline is obtained from:

```lua
getGameTime():getMinutesPerDay()
```

The partial-sleep policy cap is derived from:

```text
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
```

For the currently supplied test-server configuration:

```text
DayLength = 4
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40.0
```

B42 reports a runtime baseline of `MinutesPerDay=90`. Those values are a validated test example only and are not production constants.

## Core MVP requirements

### R1 - Respect native sleep rules

If `SleepAllowed=false`, the mod does not provide partial-sleep acceleration. `SleepNeeded` and vanilla fatigue/sleep eligibility remain authoritative.

### R2 - Runtime day length is authoritative

Capture the exact live baseline from `getGameTime():getMinutesPerDay()`. Do not hard-code a `DayLength` mapping or a fixed minutes-per-day value.

### R3 - Native fast-forward is authoritative

Read the server's configured `FastForwardMultiplier`. Do not hard-code `40`, `120`, or an inferred relationship between them.

### R4 - Provide `PartialSleepSpeedScale`

Expose one administrator tuning factor with neutral value `1.0`:

```text
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
```

Changing the native server fast-forward setting must automatically change partial-sleep behavior.

### R5 - Use currently instantiated living players

`LivingPlayers` means currently instantiated `IsoPlayer`s from `getOnlinePlayers()` for which `isDead() == false`.

Loading clients without a character, dead characters, respawn screens, lobby-only sessions, and spectators without an instantiated playable character are not counted separately by the MVP.

### R6 - Spawned admins count normally

A spawned admin is simply another instantiated player character for purposes of the proportional denominator.

### R7 - Zero sleepers means exact baseline time

If no living player is asleep, leave or restore the exact native `BaselineMinutesPerDay`.

### R8 - Partial sleep is proportional

When:

```text
0 < SleepingPlayers < LivingPlayers
```

calculate:

```text
SleepFraction = SleepingPlayers / LivingPlayers
Acceleration = max(1.0,
    NativeFastForward * PartialSleepSpeedScale * SleepFraction)
```

There are no voting thresholds, acceleration tiers, readiness states, or time-of-day windows.

### R9 - Partial sleep changes `MinutesPerDay`

For partial sleep:

```text
EffectiveMinutesPerDay = BaselineMinutesPerDay / Acceleration
```

Retain the exact native baseline for restoration.

### R10 - Partial sleep is clock-only

Do not use global simulation fast-forward for partial sleep. Awake-player movement, combat, zombies, vehicles, animations, physics, inventory actions, timed actions, and crafting must remain at normal active-game simulation speed.

### R11 - All living players asleep hands off to vanilla

When all currently instantiated living players are asleep:

1. restore baseline `MinutesPerDay` exactly;
2. stop applying mod partial acceleration;
3. allow native Project Zomboid full-sleep fast-forward to take over.

Do not imitate vanilla's measured full-sleep rate with a hard-coded value.

### R12 - Never stack with vanilla full-sleep fast-forward

The mod's altered `MinutesPerDay` must never remain active during the all-living-players-asleep vanilla handoff.

### R13 - Recalculate as vanilla-visible player state changes

Recalculate on player population, sleep, wake, death, respawn, and disconnect changes as they become visible through the instantiated player population. A short polling interval may be used as a safety net.

### R14 - Never slow below baseline

Acceleration has a minimum of `1.0`.

### R15 - Restore exact baseline and fail safe toward native time

Whenever partial acceleration ends, is disabled, or encounters an error, restore the exact captured `BaselineMinutesPerDay`.

### R16 - No custom sleep window or permission layer

There is no `SleepWindowStart`, `SleepWindowEnd`, or separate `Window Only` versus `Vanilla` sleep-permission mode in the MVP.

## Proportional examples

With native `FastForwardMultiplier=40` and `PartialSleepSpeedScale=1.0`:

```text
1 of 2 sleeping -> 20x clock acceleration
1 of 3 sleeping -> 13.33x
2 of 3 sleeping -> 26.67x
3 of 4 sleeping -> 30x
```

On the current test server, where the runtime baseline is 90 minutes/day:

```text
1 of 2 sleeping:
Acceleration = 20x
EffectiveMinutesPerDay = 90 / 20 = 4.5
```

At 100% asleep, the mod restores `90` and hands off to vanilla rather than continuing the proportional formula.

## What the diagnostic builds established

Testing on B42.20.2 established that:

- changing `GameTime:getMinutesPerDay()` can accelerate world/calendar time without globally fast-forwarding active gameplay simulation;
- `IsoPlayer:isAsleep()` is reliable server-side;
- `IsoPlayer:isDead()` is sufficient to exclude dead characters from the proportional denominator;
- dead player objects can remain in `getOnlinePlayers()` during respawn;
- vanilla may treat the remaining living sleepers as "everyone asleep" even while a dead player object remains online;
- an authenticated/loading client may exist before its `IsoPlayer` appears in `getOnlinePlayers()`;
- vanilla full-sleep fast-forward does not work by changing `MinutesPerDay`.

The last three behaviors are now explicitly accepted as vanilla lifecycle semantics for the MVP rather than treated as blockers requiring a separate readiness subsystem.

## Important vanilla observation

On the current B42.20.2 test server, `FastForwardMultiplier=40.0` did **not** correspond to an observed 40x calendar rate during vanilla full sleep. The measured effective calendar rate was roughly 120x, while `MinutesPerDay` stayed at 90 and `GameTime:getMultiplier()` rose from roughly `4.8` to roughly `575`.

That observation is deliberately **not** converted into a production constant or a `3 x FastForwardMultiplier` rule. Partial sleep uses the configured server value as an administrator policy input; full sleep remains native PZ behavior.

## MVP acceptance criteria

The first functional release should demonstrate on a dedicated B42 server that:

1. changing native day length automatically changes the captured baseline;
2. changing native `FastForwardMultiplier` automatically changes partial-sleep acceleration;
3. `PartialSleepSpeedScale=1.0` is neutral and other values scale proportionally;
4. one of two players sleeping at native FF 40 produces approximately 20x clock acceleration;
5. awake gameplay simulation remains normal during partial sleep;
6. waking the last partial sleeper restores baseline immediately;
7. all currently instantiated living players asleep restores baseline before vanilla takes over, with no stacking;
8. join/spawn, death, respawn, and disconnect affect the denominator only as vanilla changes the instantiated living-player population;
9. disabling the mod or hitting a recoverable error restores baseline time.

## Explicitly out of scope for MVP

The first release intentionally excludes:

- time-of-day sleep windows;
- custom fatigue/sleep eligibility;
- pre-spawn/loading-player readiness tracking;
- custom death/respawn fast-forward suppression;
- spectator-session readiness tracking;
- per-system time-domain compensation;
- special handling for hunger, thirst, fatigue, healing, spoilage, farming, generator fuel, corpse decay, composting, etc.;
- per-system world-time versus real-time policy presets;
- player-facing acceleration notifications.

Those can be evaluated after the core proportional-sleep mechanic is stable.

## Current development build

`v0.0.2b` is a diagnostic player/sleep-state probe. It is not yet the functional MVP.

Current Mod ID:

```text
EnshroudedSleepClockSpike
```

The Mod ID has intentionally remained unchanged during the diagnostic phase so the development server does not need its `Mods=` entry changed between test builds.