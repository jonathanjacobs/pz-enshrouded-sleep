# Enshrouded Sleep for Project Zomboid B42

An experimental multiplayer sleep mod for Project Zomboid Build 42 that aims to reproduce the useful part of Enshrouded's multiplayer sleep behavior:

- players may sleep independently;
- when only some living players are asleep, world/calendar time accelerates proportionally to the fraction asleep;
- awake players continue playing at normal simulation speed;
- when all living players are asleep, the mod hands control back to vanilla Project Zomboid full-sleep fast-forward.

The project is currently in the diagnostic/prototyping stage. The current implementation is `v0.0.2b`; the first functional target is `v0.1.0`.

See [`REQUIREMENTS.md`](REQUIREMENTS.md) for the canonical detailed specification and acceptance tests.

## Current implementation status

The diagnostic builds have established several important B42.20.2 behaviors:

- dynamically changing `GameTime:getMinutesPerDay()` can accelerate world/calendar time without globally fast-forwarding active gameplay simulation;
- `IsoPlayer:isAsleep()` is reliable server-side;
- dead player objects remain in `getOnlinePlayers()` during the respawn/character-creation interval;
- vanilla ignores dead players when deciding whether all living players are asleep;
- vanilla full-sleep fast-forward does **not** work by changing `MinutesPerDay`;
- on the test server, vanilla instead raised `GameTime:getMultiplier()` from roughly `4.8` to roughly `575` while `MinutesPerDay` remained `90` and `TrueMultiplier` remained `1`;
- an authenticated/loading client can exist for tens of seconds before its character appears in `getOnlinePlayers()`;
- direct `GameServer.udpEngine.connections` access was not exposed to the dedicated-server Lua environment, so the initial-join readiness signal still needs a Lua-safe implementation.

The current `v0.0.2b` probe intentionally does not implement the final proportional sleep mechanic yet.

## Design principle: inherit native server settings

The production mod must not duplicate Project Zomboid's server configuration with hard-coded values.

The native server remains authoritative for:

- day length / live `MinutesPerDay`;
- `SleepAllowed`;
- `SleepNeeded`;
- `FastForwardMultiplier`.

The MVP adds only a neutral tuning factor for partial sleep:

```text
Enabled = true
PartialSleepSpeedScale = 1.0
```

The mod should obtain the live baseline from:

```lua
getGameTime():getMinutesPerDay()
```

and derive the partial-sleep cap from:

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

B42 reports a runtime baseline of `MinutesPerDay=90`. Those values are an example only and are not production constants.

## MVP requirements

### R1 - Respect `SleepAllowed`

If `SleepAllowed=false`, the mod does not provide partial-sleep acceleration and does not override vanilla restrictions.

### R2 - Respect `SleepNeeded`

Vanilla fatigue and sleep eligibility remain authoritative. The mod reacts to actual sleep state rather than creating its own fatigue or permission system.

### R3 - Runtime day length is authoritative

Capture the actual live baseline from `getGameTime():getMinutesPerDay()`. Do not hard-code `DayLength` mappings or a fixed number of minutes per day.

### R4 - Native fast-forward is authoritative

Read the server's configured `FastForwardMultiplier`. Do not hard-code `40`, `120`, or an inferred relationship between them.

### R5 - Provide `PartialSleepSpeedScale`

Expose one administrator tuning factor with neutral value `1.0`:

```text
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
```

Changing the native fast-forward setting must automatically change partial-sleep behavior without requiring a duplicate mod value.

### R6 - Audit inherited values

At startup, log the live baseline, native sleep options, native fast-forward value, mod scale, and effective partial-sleep cap.

### R7 - Proportional denominator is living instantiated characters

`LivingPlayers` means instantiated in-world characters that are not dead.

Do not directly include raw connection attempts, loading-only players, character-creation-only state, dead players, lobby-only sessions, or true spectators in the proportional denominator.

### R8 - Spawned admins and multiple local characters count normally

A spawned admin is a player character. Multiple instantiated playable characters count separately even if they originate from the same client connection.

### R9 - Dead players are excluded from the denominator but force NOT READY

A dead player's object may remain online throughout respawn. Dead players do not count as living, but the session remains transitional until a replacement character is instantiated or the player disconnects.

### R10 - Accepted/loading gameplay sessions force NOT READY

A successfully accepted gameplay connection that is loading, queued, creating/selecting a character, waiting to spawn, or respawning must place the server in NOT READY state before an `IsoPlayer` necessarily exists.

### R11 - Rejected connections do not persistently block readiness

Failed authentication or rejected raw connections must not leave the server stuck in NOT READY.

### R12 - Intentional spectators do not permanently block readiness

A deliberate spectator/admin connection with no expected playable character must not be mistaken indefinitely for a loading gameplay session.

### R13 - Recalculate on state changes

Recalculate player/readiness/sleep state on joins, removals, sleep, wake, death, respawn, accepted transitions, and readiness changes. Polling may be a safety net but should not be the only mechanism.

### R14 - Initial-join readiness detection is still a blocker

`getOnlinePlayers()` is too late for initial loading. Direct `GameServer.udpEngine.connections` access was unavailable from server Lua during testing. A client-to-server readiness handshake or another Lua-accessible event mechanism must be implemented before MVP completion.

### R15 - Zero sleepers means baseline time

If no living player is asleep, leave or restore the exact baseline `MinutesPerDay`.

### R16 - Partial sleep is proportional

When READY and:

```text
0 < SleepingPlayers < LivingPlayers
```

calculate:

```text
SleepFraction = SleepingPlayers / LivingPlayers
Acceleration = max(1.0,
    NativeFastForward * PartialSleepSpeedScale * SleepFraction)
```

There are no voting thresholds or acceleration tiers.

### R17 - Partial sleep changes `MinutesPerDay`

For partial sleep:

```text
EffectiveMinutesPerDay = BaselineMinutesPerDay / Acceleration
```

Retain the exact baseline for restoration.

### R18 - Partial sleep is clock-only

Do not use global simulation fast-forward for partial sleep. Awake player movement, combat, zombies, vehicles, animations, physics, inventory, timed actions, and crafting must remain at normal active-game simulation speed.

### R19 - 100% living players asleep hands off to vanilla

When READY and all living players are asleep:

1. restore baseline `MinutesPerDay` exactly;
2. stop applying mod partial acceleration;
3. allow native Project Zomboid full-sleep fast-forward to take over.

Do not imitate the empirically observed vanilla calendar rate with a hard-coded multiplier.

### R20 - Never stack partial acceleration with vanilla fast-forward

The mod's altered `MinutesPerDay` must never remain active during native all-sleep fast-forward.

### R21 - NOT READY must never permit accelerated world time

When NOT READY:

- stop partial acceleration immediately;
- restore the exact baseline;
- prevent vanilla full-sleep fast-forward from racing the world ahead while another player is joining, dead, creating a character, or respawning.

Testing proved that restoring `MinutesPerDay` alone is not sufficient because vanilla can ignore the dead player and fast-forward if every remaining living player is asleep.

The preferred implementation keeps existing sleepers asleep while suppressing vanilla fast-forward. If that cannot be made reliable, waking or blocking sleep during NOT READY is an acceptable safety fallback.

### R22 - Never slow time below baseline

Acceleration has a minimum of `1.0`.

### R23 - Restore the exact baseline

Restore the captured baseline whenever partial acceleration ends, including wake, vanilla handoff, readiness loss, disable, error/fail-safe paths, and shutdown/unload where supported.

### R24 - Fail safe toward normal time

Unexpected errors must leave the server at native baseline time rather than accelerated time.

### R25 - No custom sleep window in the MVP

There is no `SleepWindowStart` or `SleepWindowEnd`. If vanilla permits sleep and the character is actually asleep, the mod may react regardless of time of day.

### R26 - No custom sleep-permission mode in the MVP

There is no separate `Window Only` versus `Vanilla` permission mode. Vanilla determines sleep eligibility.

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

## Important vanilla observation

On the current B42.20.2 test server, `FastForwardMultiplier=40.0` did **not** correspond to an observed 40x calendar rate during vanilla full sleep. The measured effective calendar rate was roughly 120x, while `MinutesPerDay` stayed at 90 and `GameTime:getMultiplier()` rose to roughly 575.

That observation is deliberately **not** converted into a production constant or a `3 x FastForwardMultiplier` rule. Partial sleep uses the configured server value as an administrator policy input; full sleep remains native PZ behavior.

## MVP acceptance criteria

The first functional release is not complete until dedicated-server testing demonstrates:

1. changing native day length automatically changes the captured baseline;
2. changing native `FastForwardMultiplier` automatically changes partial-sleep acceleration;
3. `PartialSleepSpeedScale=1.0` is neutral and other values scale proportionally;
4. one of two players sleeping at native FF 40 produces approximately 20x clock acceleration;
5. awake gameplay simulation remains normal during partial sleep;
6. waking the last partial sleeper restores baseline immediately;
7. all living players asleep restores baseline before vanilla takes over, with no stacking;
8. accepted/loading players trigger NOT READY before they appear in `getOnlinePlayers()`;
9. death/respawn prevents both mod and vanilla accelerated world time until the session is ready again or disconnected;
10. failed authentication does not create a persistent readiness block;
11. disabling the mod or hitting a recoverable error restores baseline time.

## Explicitly out of scope for MVP

The first release intentionally excludes:

- time-of-day sleep windows;
- custom fatigue/sleep eligibility;
- per-system time-domain compensation;
- special handling for hunger, thirst, fatigue, healing, spoilage, farming, generator fuel, corpse decay, composting, etc.;
- per-system world-time versus real-time policy presets;
- player-facing acceleration/readiness notifications.

Those can be evaluated after the core multiplayer clock and lifecycle behavior is stable.

## Current development build

`v0.0.2b` is a diagnostic player/sleep-state probe. It is not yet the functional MVP.

Current Mod ID:

```text
EnshroudedSleepClockSpike
```

The Mod ID has intentionally remained unchanged during the diagnostic phase so the development server does not need its `Mods=` entry changed between test builds.