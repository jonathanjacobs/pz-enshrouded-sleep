# Enshrouded Sleep - MVP Requirements

Status: design specification for the first functional multiplayer release (`v0.1.0`).

Last updated: 2026-08-13.

The current repository implementation is still diagnostic (`v0.0.2b`). This document defines the MVP behavior based on dedicated-server testing on Project Zomboid Build 42.20.2.

## 1. Goal

Provide an Enshrouded-style multiplayer sleep extension for Project Zomboid.

Vanilla Project Zomboid remains responsible for sleep eligibility, entering sleep, waking, death, respawn, joining, disconnecting, and full-sleep fast-forward. The mod adds one missing behavior:

> When some, but not all, currently instantiated living players are asleep, accelerate world/calendar time in proportion to the fraction asleep while awake gameplay continues at normal simulation speed.

When all currently instantiated living players are asleep, the mod restores the native clock baseline and allows vanilla Project Zomboid full-sleep fast-forward to take over.

The mod must inherit native server configuration rather than duplicate it with hard-coded values.

## 2. Design principle: extend vanilla, do not replace it

The MVP is intentionally a thin behavioral extension around vanilla sleep.

Vanilla Project Zomboid remains authoritative for:

- whether sleep is allowed;
- whether fatigue is required;
- when a character enters or leaves sleep;
- death and respawn behavior;
- player joining/loading behavior;
- spectators and administrative sessions;
- all-players-asleep fast-forward.

The mod does not attempt to create a separate multiplayer readiness model or predict players that have not yet become instantiated `IsoPlayer` objects.

For MVP purposes, the authoritative player population is the currently instantiated living-player population exposed by `getOnlinePlayers()`.

## 3. Definitions

- **BaselineMinutesPerDay** - the actual live value returned by `getGameTime():getMinutesPerDay()` while the mod is not applying partial-sleep acceleration.
- **NativeFastForward** - the server's configured `FastForwardMultiplier`.
- **PartialSleepSpeedScale** - the mod-specific administrator tuning factor. Neutral/default value: `1.0`.
- **LivingPlayers** - currently instantiated player characters returned by `getOnlinePlayers()` for which `isDead() == false`.
- **SleepingPlayers** - LivingPlayers for which `isAsleep() == true`.
- **SleepFraction** - `SleepingPlayers / LivingPlayers`.

## 4. MVP requirements

### R1 - Respect native `SleepAllowed`

If the native server option `SleepAllowed=false`, the mod must not provide partial-sleep acceleration and must not override vanilla sleep restrictions.

### R2 - Respect native `SleepNeeded`

The mod must not replace vanilla fatigue or sleep-eligibility rules. `SleepNeeded` and vanilla sleep logic determine whether a player can or must sleep. The mod reacts only to actual sleep state.

### R3 - Derive the baseline day length at runtime

The mod must obtain the live baseline from:

```lua
getGameTime():getMinutesPerDay()
```

The mod must not hard-code a `DayLength` mapping or a fixed minutes-per-day value.

`SandboxOptions:getDayLengthMinutes()` may be logged as a validation value, but the live `GameTime` value is the operational source of truth.

### R4 - Derive native fast-forward from the server

The mod must read the server's actual `FastForwardMultiplier` and must not hard-code `40`, `120`, or any other fast-forward value.

### R5 - Provide one neutral administrator tuning factor

The MVP must expose:

```text
PartialSleepSpeedScale = 1.0
```

This value scales the native server fast-forward value for partial sleep only:

```text
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
```

Changing the server's native `FastForwardMultiplier` must automatically change partial-sleep behavior without requiring a matching mod setting.

### R6 - Log inherited and computed configuration

At startup, the mod should log at minimum:

- BaselineMinutesPerDay
- sandbox day-length minutes, when readable
- SleepAllowed
- SleepNeeded
- NativeFastForward
- PartialSleepSpeedScale
- EffectivePartialSleepCap

This provides an administrator-visible audit trail of the values actually in use.

### R7 - Use vanilla's currently instantiated living-player population

For proportional acceleration, `LivingPlayers` consists only of currently instantiated player characters returned by `getOnlinePlayers()` that are not dead.

The MVP does not separately count or model:

- incoming sockets;
- authenticated/loading clients without an instantiated character;
- character-selection or creation screens;
- dead characters;
- respawn screens;
- lobby-only sessions;
- spectators without an instantiated playable character.

This is intentional. Joining, loading, death, respawn, and spectator semantics are inherited from vanilla Project Zomboid.

### R8 - Spawned admins and multiple instantiated characters count normally

A spawned admin character is a player character and counts normally. Multiple instantiated playable characters count separately.

### R9 - Dead players are excluded from the proportional denominator

A player for which `isDead() == true` does not count in `LivingPlayers` or `SleepingPlayers`.

The mod does not add additional dead-player or respawn gating beyond vanilla behavior.

### R10 - Zero sleepers means exact baseline time

If `SleepingPlayers == 0`, the mod must leave or restore:

```text
MinutesPerDay = BaselineMinutesPerDay
```

### R11 - Partial sleep uses proportional acceleration

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

There are no tiers, voting thresholds, readiness states, or time-of-day windows in the MVP.

### R12 - Partial acceleration is implemented through `MinutesPerDay`

For partial sleep:

```text
EffectiveMinutesPerDay = BaselineMinutesPerDay / Acceleration
```

The exact baseline must be retained for restoration.

### R13 - Partial sleep is clock-only

The mod must not use global simulation fast-forward such as `GameTime:setMultiplier()` for partial sleep.

Awake-player movement, combat, zombies, vehicles, animations, physics, inventory actions, timed actions, and crafting must continue at normal active-game simulation speed.

The v0.0.1 diagnostic demonstrated that changing `MinutesPerDay` can accelerate world/calendar time without changing `TrueMultiplier`.

### R14 - All living players asleep hands off to vanilla

When:

```text
LivingPlayers > 0
SleepingPlayers == LivingPlayers
```

The mod must:

1. restore `BaselineMinutesPerDay` exactly;
2. stop applying partial-sleep acceleration;
3. allow vanilla Project Zomboid full-sleep fast-forward to take over.

The mod must not attempt to reproduce vanilla's observed effective full-sleep calendar rate.

### R15 - Never stack mod acceleration with vanilla full-sleep fast-forward

The mod's altered `MinutesPerDay` must never remain active when all currently instantiated living players are asleep and vanilla full-sleep behavior is taking over.

### R16 - Recalculate promptly as vanilla-visible state changes

The mod must recalculate when practical on player add/remove, sleep, wake, and death changes visible through the instantiated player population.

A short polling interval may be used as a safety net.

The MVP does not require a separate client/server transitional-session handshake.

### R17 - Never slow time below baseline

The mod must never make time pass more slowly than the server's native baseline. `Acceleration` has a minimum of `1.0`.

### R18 - Restore the exact baseline

Whenever partial acceleration ends for any reason, restore the exact captured `BaselineMinutesPerDay`; do not recompute an approximate default.

Restoration conditions include at minimum:

- the last partial sleeper wakes;
- all living players become asleep and vanilla handoff begins;
- the mod is disabled;
- a recoverable error/fail-safe path is entered;
- Lua/mod unload or server shutdown where an appropriate event is available.

### R19 - Fail safe toward native time

Any unexpected error or invalid state must fail toward baseline time rather than leaving the server accelerated.

### R20 - No custom sleep window or custom sleep-permission mode

The MVP does not define `SleepWindowStart`, `SleepWindowEnd`, or a separate `Window Only` versus `Vanilla` permission mode.

If vanilla allows a character to sleep and that character is actually asleep, the mod may react regardless of time of day.

## 5. MVP sandbox configuration

The functional MVP should intentionally keep its configuration small:

```text
Enabled = true
PartialSleepSpeedScale = 1.0
```

The following values are inherited from Project Zomboid and must not be duplicated as mod defaults:

- DayLength / live MinutesPerDay
- SleepAllowed
- SleepNeeded
- FastForwardMultiplier

Diagnostic verbosity options may exist during development but are not part of the core gameplay configuration.

## 6. Vanilla lifecycle semantics are explicitly accepted for MVP

The MVP intentionally does not special-case players that vanilla has not yet instantiated.

Examples:

- A player who is still loading does not affect the proportional denominator until an `IsoPlayer` exists.
- A dead player does not count as living.
- If vanilla considers all remaining living players asleep, vanilla may enter its normal full-sleep fast-forward behavior.
- Disconnects and respawns may temporarily change the living-player denominator as vanilla changes the instantiated population.

These are accepted MVP semantics rather than defects in the mod.

A stricter connection/readiness model may be considered later only if real server use demonstrates that vanilla lifecycle behavior causes a practical problem worth solving.

## 7. Empirically validated behavior from B42.20.2 testing

These observations inform the requirements but are not hard-coded production constants.

### Test server configuration

The supplied test server currently has:

```text
DayLength = 4
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40.0
```

At runtime, `DayLength=4` produced `MinutesPerDay=90`.

### Clock-only spike

With a runtime baseline of 90 minutes/day, the v0.0.1 test set `MinutesPerDay` to `4.5`, corresponding to a requested 20x clock acceleration. World time advanced at approximately the expected rate while `TrueMultiplier` remained `1`.

### Server-side sleep detection

`IsoPlayer:isAsleep()` changed reliably on the dedicated server when a player entered and left sleep.

### Vanilla full-sleep behavior

With the sole living player asleep:

- `MinutesPerDay` remained `90`;
- `GameTime:getMultiplier()` rose from approximately `4.8` to approximately `575`;
- `TrueMultiplier` remained `1`;
- the observed calendar rate was approximately 120x baseline even though `FastForwardMultiplier=40.0`.

Therefore the production mod must not assume that the configured `FastForwardMultiplier` numerically equals vanilla's observed effective calendar-speed factor. The configured value is used as the administrator's partial-sleep policy input; vanilla controls the 100% asleep case.

### Death/respawn behavior

A dead player's `IsoPlayer` remained in `getOnlinePlayers()` through character recreation. The replacement character used a new object identity while retaining the same observed online ID.

Vanilla full-sleep fast-forward began when the only living player was asleep even while another dead player object remained online. The MVP now explicitly accepts that as vanilla lifecycle behavior rather than adding a separate readiness override.

### Initial-join behavior

An accepted client can spend tens of seconds authenticated/loading before its character appears in `getOnlinePlayers()`.

The MVP now explicitly accepts that interval as vanilla behavior. The mod does not need to predict or count that player before the `IsoPlayer` exists.

## 8. Proportional examples

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

## 9. MVP acceptance tests

The MVP should not be considered complete until the following are demonstrated on a dedicated B42 server:

1. **Configuration inheritance:** changing native DayLength changes the captured runtime baseline without editing mod configuration.
2. **Fast-forward inheritance:** changing native `FastForwardMultiplier` automatically changes partial-sleep acceleration.
3. **Neutral tuning:** `PartialSleepSpeedScale=1.0` uses the native fast-forward value as the partial-sleep cap.
4. **Fine tuning:** changing `PartialSleepSpeedScale` proportionally changes partial-sleep acceleration.
5. **Two-player partial sleep:** with baseline 90, native FF 40, scale 1.0, one of two sleeping produces approximately 20x clock acceleration and `MinutesPerDay=4.5`.
6. **Awake simulation remains normal:** movement, zombies, combat, vehicles, animations, inventory/timed actions, and crafting do not globally fast-forward during partial sleep.
7. **Wake restoration:** waking the last partial sleeper restores the exact baseline immediately.
8. **100% handoff:** all currently instantiated living players asleep restores baseline before vanilla fast-forward takes over, with no stacking.
9. **Population changes:** player join/spawn, death, respawn, and disconnect change the proportional denominator only when the instantiated living-player population changes.
10. **Failure safety:** disabling the mod or encountering a recoverable error restores baseline time.

## 10. Explicitly out of scope for MVP

The following may be considered after the core mechanic is stable:

- custom time-of-day sleep windows;
- custom fatigue/sleep eligibility;
- pre-spawn/loading-player readiness tracking;
- custom death/respawn fast-forward suppression;
- spectator-session readiness tracking;
- per-system time-domain compensation;
- keeping awake-player hunger/thirst/fatigue/healing at real-time rates during clock acceleration;
- compensating food spoilage, farming, generator fuel, corpse decay, composting, or similar systems;
- per-system `Follow World Time` versus `Compensate to Real Time` policies;
- player-facing acceleration notifications;
- configuration presets.

The MVP should first establish the smallest reliable extension of vanilla Project Zomboid sleep behavior that adds proportional partial-sleep clock acceleration.