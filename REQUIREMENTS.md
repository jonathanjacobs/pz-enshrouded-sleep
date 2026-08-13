# Enshrouded Sleep - MVP Requirements

Status: design specification for the first functional multiplayer release (`v0.1.0`).

Last updated: 2026-08-13.

The current repository implementation is still diagnostic (`v0.0.2b`). This document defines the behavior the MVP must implement based on the dedicated-server tests completed on Project Zomboid Build 42.20.2.

## 1. Goal

Provide an Enshrouded-style multiplayer sleep mechanic for Project Zomboid in which players may sleep independently.

When only some living players are asleep, the mod accelerates **world/calendar time** in proportion to the fraction of living players asleep while awake gameplay continues at normal simulation speed. When all living players are asleep, the mod stops controlling the clock and allows vanilla Project Zomboid full-sleep fast-forward to take over.

The mod must inherit the server's native time and sleep configuration rather than duplicate it with hard-coded values.

## 2. Definitions

- **BaselineMinutesPerDay** - the actual live value returned by `getGameTime():getMinutesPerDay()` while the mod is not applying partial-sleep acceleration.
- **NativeFastForward** - the server's configured `FastForwardMultiplier`.
- **PartialSleepSpeedScale** - the mod-specific administrator tuning factor. Neutral/default value: `1.0`.
- **LivingPlayers** - instantiated in-world player characters that are not dead.
- **SleepingPlayers** - LivingPlayers for which `IsoPlayer:isAsleep()` is true.
- **SleepFraction** - `SleepingPlayers / LivingPlayers`.
- **READY** - the server has no gameplay session currently in an unsafe transition such as accepted/loading, character creation, death/respawn, or waiting to spawn.
- **NOT READY** - at least one relevant gameplay session is in one of those transition states.

## 3. Native server configuration is authoritative

### R1 - Respect `SleepAllowed`

If the native server option `SleepAllowed=false`, the mod must not provide partial-sleep acceleration or override vanilla sleep restrictions.

### R2 - Respect `SleepNeeded`

The mod must not replace vanilla fatigue or sleep-eligibility rules. `SleepNeeded` and vanilla sleep logic determine whether a player is allowed or required to sleep. The mod reacts to actual sleep state; it does not manufacture sleep eligibility.

### R3 - Derive the baseline day length at runtime

The mod must obtain the current baseline from `getGameTime():getMinutesPerDay()` and must not hard-code a mapping such as `DayLength=4 -> 90`.

`SandboxOptions:getDayLengthMinutes()` may be logged as a validation value, but the live `GameTime` value is the operational source of truth.

### R4 - Derive native fast-forward from the server

The mod must read the server's actual `FastForwardMultiplier`. It must not hard-code `40`, `120`, or any other fast-forward value.

### R5 - Provide one neutral partial-sleep tuning factor

The MVP must expose a sandbox option:

`PartialSleepSpeedScale = 1.0`

This value scales the native server fast-forward value for **partial** sleep only.

`EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale`

Changing the server's native `FastForwardMultiplier` must automatically change the mod's partial-sleep behavior without requiring a matching mod setting.

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

## 4. Player population and readiness

### R7 - The denominator is living instantiated characters

For proportional acceleration, `LivingPlayers` consists of instantiated player characters that are present in the world and not dead.

Do not directly count:

- raw incoming socket attempts
- rejected/unauthorized connection attempts
- loading players that do not yet have an instantiated character
- character-creation-only state
- dead characters for the proportional denominator
- lobby-only sessions
- true spectator/admin sessions with no intended playable character

### R8 - Spawned admins and local/split-screen characters count normally

A spawned admin character is a player character and counts in the denominator. Multiple instantiated playable characters must be counted as separate player characters even if they originate from one client connection.

### R9 - Dead players do not count in the denominator but make the server NOT READY

Testing showed that a dead `IsoPlayer` remains in `getOnlinePlayers()` during the death/character-creation/respawn interval. Dead players must therefore be excluded from `LivingPlayers` and must place the server in NOT READY state until a replacement living character is instantiated or the session disconnects.

### R10 - Accepted/loading gameplay sessions make the server NOT READY

A successfully accepted/authenticated gameplay connection that is still loading, queued, selecting/creating a character, waiting to spawn, or respawning must place the server in NOT READY state even though it may not yet appear in `getOnlinePlayers()`.

### R11 - Rejected raw connection attempts must not create a persistent readiness block

A connection that fails authentication or is rejected before becoming an accepted gameplay session must not hold the server in NOT READY state.

### R12 - Intentional spectators must not permanently block readiness

An intentional spectator/admin connection with no playable character must be distinguishable from a gameplay session that is expected to spawn a character. Such a spectator must not leave the server permanently NOT READY.

### R13 - Recalculate immediately on relevant transitions

The mod must recalculate state when practical on:

- player instantiated/added
- player removed/disconnected
- sleep
- wake
- death
- replacement character spawn
- accepted gameplay connection begins transition
- transitional gameplay connection becomes fully in-world
- readiness changes

A short polling interval may be used as a safety net, but state must not depend on long periodic refreshes.

### R14 - Initial-join readiness detection remains an implementation blocker

The requirement is established, but the final Lua mechanism is not yet selected.

Diagnostic testing found that direct `GameServer.udpEngine.connections` access is not available from the dedicated-server Lua environment even though those fields exist in the Java API. A client-to-server readiness handshake or another Lua-accessible event-based mechanism is the leading implementation approach.

The MVP is not complete until the accepted/loading interval can be detected reliably.

## 5. Clock behavior

### R15 - No sleepers means exact baseline time

If `SleepingPlayers == 0`, the mod must leave or restore `MinutesPerDay` to `BaselineMinutesPerDay`.

### R16 - Partial sleep uses proportional acceleration

When the server is READY and:

`0 < SleepingPlayers < LivingPlayers`

calculate:

`Acceleration = max(1.0, NativeFastForward * PartialSleepSpeedScale * SleepFraction)`

There are no tiers, thresholds, voting rules, or time-of-day windows in the MVP.

### R17 - Partial acceleration is implemented through `MinutesPerDay`

For partial sleep:

`EffectiveMinutesPerDay = BaselineMinutesPerDay / Acceleration`

The exact baseline must be retained for later restoration.

### R18 - Partial sleep is clock-only

The partial-sleep implementation must not call the global simulation fast-forward path such as `GameTime:setMultiplier()`.

Player movement, combat, zombies, vehicles, animations, physics, inventory actions, timed actions, and crafting must continue at normal active-game simulation speed.

The v0.0.1 diagnostic demonstrated that changing `MinutesPerDay` can accelerate world/calendar time without changing `TrueMultiplier`.

### R19 - All living players asleep hands off to vanilla

When the server is READY and all LivingPlayers are asleep:

1. restore `BaselineMinutesPerDay` exactly;
2. stop applying mod partial-sleep acceleration;
3. allow vanilla Project Zomboid full-sleep fast-forward to take over.

The mod must not attempt to imitate vanilla's observed effective full-sleep calendar rate.

### R20 - Never stack mod acceleration with vanilla full-sleep fast-forward

The mod's altered `MinutesPerDay` must never remain active when vanilla all-sleep fast-forward is engaged.

### R21 - NOT READY must never permit accelerated world time

When the server becomes NOT READY:

- stop mod partial-sleep acceleration immediately;
- restore `BaselineMinutesPerDay` exactly;
- prevent vanilla all-sleep fast-forward from causing the world to race ahead while a player is joining, creating a character, dead, or respawning.

Testing showed that vanilla ignores dead players when deciding whether all living players are asleep. Therefore merely restoring `MinutesPerDay` is insufficient if the only living player remains asleep while another player's dead character is awaiting respawn.

The MVP must implement a reliable suppression strategy. Preferred behavior is to let an existing sleeper remain asleep if vanilla fast-forward can be safely suppressed. If that cannot be done reliably, waking/blocking sleep is an acceptable fail-safe because preserving world-time safety takes priority over uninterrupted sleep during NOT READY transitions.

### R22 - Never slow time below baseline

The mod must never make time pass more slowly than the server's native baseline. `Acceleration` has a minimum of `1.0`.

### R23 - Restore the exact baseline

Whenever partial acceleration ends for any reason, restore the exact captured `BaselineMinutesPerDay`; do not recompute an approximate default.

Restoration conditions include at minimum:

- last partial sleeper wakes
- all living players become asleep and vanilla handoff begins
- server becomes NOT READY
- mod is disabled
- diagnostic/error/fail-safe path
- Lua/mod unload or server shutdown where an appropriate event is available

### R24 - Fail safe toward normal time

Any unexpected error or invalid state must fail toward baseline time rather than leaving the server accelerated.

## 6. MVP sandbox configuration

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

## 7. No custom sleep window in the MVP

### R25 - No `SleepWindowStart` or `SleepWindowEnd`

The MVP must not restrict acceleration to an arbitrary clock window such as 21:00-06:00.

If vanilla allows a character to sleep and the character is actually asleep, the mod may react regardless of time of day.

### R26 - No custom sleep-permission mode

The MVP does not add a separate `Window Only` versus `Vanilla` sleep-permission system. Vanilla Project Zomboid remains responsible for sleep eligibility.

A configurable sleep window may be reconsidered later only if server administrators demonstrate a concrete need for it.

## 8. Empirically validated behavior from B42.20.2 testing

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

Vanilla full-sleep fast-forward began when the only living player was asleep even while another dead player object remained online. This is the basis for R9 and R21.

### Initial-join behavior

An accepted client can spend tens of seconds or longer authenticated/loading before its character appears in `getOnlinePlayers()`. `getOnlinePlayers()` alone is therefore not sufficient for readiness detection.

The v0.0.2b attempt to inspect `GameServer.udpEngine.connections` from server Lua failed safely because `GameServer` was not exposed in that Lua environment.

## 9. MVP acceptance tests

The MVP should not be considered complete until the following are demonstrated on a dedicated B42 server.

1. **Configuration inheritance:** changing native DayLength changes the captured runtime baseline without editing mod configuration.
2. **Fast-forward inheritance:** changing native `FastForwardMultiplier` automatically changes partial-sleep acceleration.
3. **Neutral tuning:** `PartialSleepSpeedScale=1.0` uses the native fast-forward value as the partial-sleep cap.
4. **Fine tuning:** changing `PartialSleepSpeedScale` proportionally changes partial-sleep acceleration.
5. **Two-player partial sleep:** with baseline 90, native FF 40, scale 1.0, one of two sleeping produces approximately 20x clock acceleration and `MinutesPerDay=4.5`.
6. **Awake simulation remains normal:** movement, zombies, combat, vehicles, animations, inventory/timed actions and crafting do not globally fast-forward during partial sleep.
7. **Wake restoration:** waking the last partial sleeper restores the exact baseline immediately.
8. **100% handoff:** all living players asleep restores baseline before vanilla fast-forward takes over; there is no stacking.
9. **Join safety:** an accepted/loading second player makes the server NOT READY before their character appears in `getOnlinePlayers()` and prevents accelerated world time.
10. **Death/respawn safety:** death and character recreation make the server NOT READY and prevent both mod and vanilla accelerated world time until the replacement character is ready or the player disconnects.
11. **Rejected connection safety:** failed authentication does not create a persistent readiness block.
12. **Failure safety:** disabling the mod or encountering a recoverable error restores baseline time.

## 10. Explicitly out of scope for MVP

The following may be considered after the core mechanic is stable:

- custom time-of-day sleep windows
- custom sleep eligibility rules
- per-system time-domain compensation
- keeping awake-player hunger/thirst/fatigue/healing at real-time rates during clock acceleration
- compensating food spoilage, farming, generator fuel, corpse decay, composting, or similar systems
- per-system `Follow World Time` versus `Compensate to Real Time` policies
- player-facing acceleration/readiness notifications
- configuration presets

The MVP should first establish a safe, predictable multiplayer clock mechanic with correct player lifecycle handling.