# Enshrouded Sleep - MVP Requirements

Status: design specification and implementation target for the first functional multiplayer release (`v0.1.0`).

Last updated: 2026-08-14.

The repository now contains development version `v0.0.5`. The proportional calendar-compression algorithm was introduced in `v0.0.3`; `v0.0.4` standardized deployment identity and passed the first successful two-player proportional-sleep test; `v0.0.5` adds read-only client/server clock diagnostics to investigate visual time-display snapping without intentionally changing the proportional controller.

These requirements define the intended behavior based on dedicated-server testing on Project Zomboid Build 42.20.2 and review of the B42 TrueSleep and Sleep With Friends mod implementations.

## 1. Goal

Provide an Enshrouded-style multiplayer sleep extension for Project Zomboid.

Vanilla Project Zomboid remains responsible for sleep eligibility, entering sleep, waking, death, respawn, joining, disconnecting, and full-sleep fast-forward. The mod adds one missing behavior:

> When some, but not all, currently instantiated living players are asleep, dynamically shorten the real-world duration of a Project Zomboid day in proportion to the fraction asleep while leaving active gameplay simulation at normal speed.

The mod accomplishes this by changing `GameTime:MinutesPerDay`. It does **not** globally speed up player movement, combat, zombies, vehicles, animations, physics, inventory actions, timed actions, or crafting.

When all currently instantiated living players are asleep, the mod restores the native day length and allows vanilla Project Zomboid full-sleep fast-forward to take over.

## 2. Design principle: extend vanilla, do not replace it

The MVP is a thin behavioral extension around vanilla sleep.

Vanilla Project Zomboid remains authoritative for:

- whether sleep is allowed;
- whether fatigue is required;
- when a character enters or leaves sleep;
- death and respawn behavior;
- player joining/loading behavior;
- spectators and administrative sessions;
- all-living-players-asleep fast-forward.

The mod does not create a separate multiplayer readiness model and does not predict players that have not yet become instantiated `IsoPlayer` objects.

For MVP purposes, the authoritative population is the currently instantiated living-player population exposed by `getOnlinePlayers()`.

This is consistent with the B42 TrueSleep implementation, which also builds its multiplayer sleep population from `getOnlinePlayers()`, excludes dead players, and steps aside when all living players are asleep.

## 3. Definitions

- **ModID** - stable Project Zomboid identifier `pz-enshrouded-sleep`, used by `mod.info` and the server `Mods=` configuration.
- **Sandbox namespace** - `EnshroudedSleep`, used for the mod's sandbox-variable block.
- **BaselineMinutesPerDay** - the actual live value returned by `getGameTime():getMinutesPerDay()` while the mod is not applying partial-sleep compression.
- **NativeFastForward** - the server's configured `FastForwardMultiplier`.
- **PartialSleepSpeedScale** - the mod-specific administrator tuning factor. Neutral/default value: `1.0`.
- **EffectivePartialSleepCap** - `NativeFastForward * PartialSleepSpeedScale`.
- **LivingPlayers** - currently instantiated player characters returned by `getOnlinePlayers()` for which `isDead() == false`.
- **SleepingPlayers** - LivingPlayers for which `isAsleep() == true`.
- **SleepFraction** - `SleepingPlayers / LivingPlayers`.
- **CalendarCompressionFactor** - the factor by which the configured real-time duration of a PZ day is compressed during partial sleep.
- **EffectiveMinutesPerDay** - `BaselineMinutesPerDay / CalendarCompressionFactor`.
- **RealTimeCompensationFactor** - `1 / CalendarCompressionFactor`; reserved for possible future compensation of systems that should remain tied to real/simulation time.
- **Client clock continuity** - the requirement that sleeping and awake clock displays visually track compressed authoritative world time without long holds followed by large synchronization jumps.

`CalendarCompressionFactor` is a world/calendar pacing factor. It is **not** a global simulation-speed multiplier.

## 4. MVP requirements

### R1 - Respect native `SleepAllowed`

If the native server option `SleepAllowed=false`, the mod must not apply partial-sleep calendar compression and must not override vanilla sleep restrictions.

### R2 - Respect native `SleepNeeded`

The mod must not replace vanilla fatigue or sleep-eligibility rules. `SleepNeeded` and vanilla sleep logic determine whether a player can or must sleep. The mod reacts only to actual sleep state.

### R3 - Derive the baseline day length at runtime

The mod must obtain the live baseline from:

```lua
getGameTime():getMinutesPerDay()
```

The mod must not hard-code a `DayLength` mapping or a fixed minutes-per-day value.

`getSandboxOptions():getDayLengthMinutes()` may be logged as a validation value, but the live `GameTime` value is the operational source of truth.

### R4 - Derive native fast-forward from the server

The mod must read the server's actual `FastForwardMultiplier` through native server options. It must not hard-code `40`, `120`, or any inferred relationship between the configured value and vanilla's observed full-sleep calendar rate.

### R5 - Provide one neutral administrator tuning factor

The MVP must expose:

```text
PartialSleepSpeedScale = 1.0
```

The partial-sleep policy cap is:

```text
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
```

Changing the native `FastForwardMultiplier` must automatically change partial-sleep behavior without requiring a duplicate mod setting.

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

For proportional compression, `LivingPlayers` consists only of currently instantiated player characters returned by `getOnlinePlayers()` that are not dead.

The MVP does not separately count or model:

- incoming sockets;
- authenticated/loading clients without an instantiated character;
- character-selection or creation screens;
- dead characters;
- respawn screens;
- lobby-only sessions;
- spectators without an instantiated playable character.

Joining, loading, death, respawn, and spectator semantics are inherited from vanilla Project Zomboid.

### R8 - Spawned admins and multiple instantiated characters count normally

A spawned admin character is a player character and counts normally. Multiple instantiated playable characters count separately.

### R9 - Dead players are excluded from the proportional denominator

A player for which `isDead() == true` does not count in `LivingPlayers` or `SleepingPlayers`.

The mod does not add additional dead-player or respawn gating beyond vanilla behavior.

### R10 - Zero sleepers means exact baseline day length

If `SleepingPlayers == 0`, the mod must leave or restore:

```text
MinutesPerDay = BaselineMinutesPerDay
CalendarCompressionFactor = 1.0
```

### R11 - Partial sleep uses proportional calendar compression

When:

```text
0 < SleepingPlayers < LivingPlayers
```

calculate:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
```

There are no tiers, voting thresholds, readiness states, or time-of-day windows in the MVP.

### R12 - Partial sleep changes `MinutesPerDay`

For partial sleep:

```text
EffectiveMinutesPerDay =
    BaselineMinutesPerDay / CalendarCompressionFactor
```

The exact baseline must be retained for restoration.

This should be understood as dynamically shortening the real-world duration of a 24-hour PZ day, not globally accelerating the simulation.

### R13 - Partial sleep must not globally fast-forward simulation

The mod must never use `GameTime:setMultiplier()` or another global simulation-fast-forward path for partial sleep.

Awake-player movement, combat, zombies, vehicles, animations, physics, inventory actions, timed actions, and crafting must continue at normal active-game simulation speed.

The v0.0.1 dedicated-server diagnostic demonstrated that changing `MinutesPerDay` can accelerate `WorldAgeHours` and the calendar without changing `TrueMultiplier`.

### R14 - Game-time-driven systems may advance faster in real time

Changing `MinutesPerDay` changes the rate at which PZ world/calendar minutes elapse. Therefore systems implemented in terms of game minutes, world age, or similar world-time measurements may also progress faster in real time while partial sleep compression is active.

This is distinct from global simulation acceleration.

Potentially affected systems include, subject to validation:

- crop/farming progression;
- food aging/spoilage;
- generator fuel consumption;
- hunger/thirst/fatigue changes;
- healing;
- corpse decay;
- composting;
- weather or other world-time-driven systems;
- mods that use `Events.EveryOneMinute` or `WorldAgeHours` as a timing source.

The MVP documents and accepts this behavior; it does not yet compensate individual systems.

### R15 - All living players asleep hands off to vanilla

When:

```text
LivingPlayers > 0
SleepingPlayers == LivingPlayers
```

The mod must:

1. restore `BaselineMinutesPerDay` exactly;
2. stop applying partial-sleep calendar compression;
3. allow vanilla Project Zomboid full-sleep fast-forward to take over.

For design/debugging purposes, the theoretical continuous-model target may be calculated as:

```text
BaselineMinutesPerDay / max(1, EffectivePartialSleepCap)
```

but it must **not** be applied while vanilla full-sleep fast-forward is active because the two mechanisms could stack.

### R16 - Never stack mod compression with vanilla full-sleep fast-forward

The mod's altered `MinutesPerDay` must never intentionally remain active when all currently instantiated living players are asleep and vanilla full-sleep behavior is taking over.

### R17 - Recalculate promptly as vanilla-visible state changes

The mod must recalculate as player population, sleep, wake, death, respawn, and disconnect changes become visible through the instantiated player population.

The functional prototype should observe state every server tick, while only calling `setMinutesPerDay()` when the target actually changes. This minimizes the overlap window when the final awake player falls asleep and vanilla fast-forward engages.

### R18 - Never slow world time below native baseline

`CalendarCompressionFactor` has a minimum of `1.0`. The mod must never make a PZ day longer than the native `BaselineMinutesPerDay`.

### R19 - Restore the exact baseline and fail safe toward native time

Whenever partial compression ends for any reason, restore the exact captured `BaselineMinutesPerDay`; do not recompute an approximate default.

Restoration conditions include at minimum:

- the last partial sleeper wakes;
- all living players become asleep and vanilla handoff begins;
- native `SleepAllowed` becomes false;
- the mod is disabled;
- a recoverable error/fail-safe path is entered.

Unexpected or unreadable state must fail toward native baseline time rather than leaving the world compressed.

### R20 - No custom sleep window or custom sleep-permission mode

The MVP does not define `SleepWindowStart`, `SleepWindowEnd`, or a separate `Window Only` versus `Vanilla` permission mode.

If vanilla allows a character to sleep and that character is actually asleep, the mod may react regardless of time of day.

### R21 - Client clock displays must track compressed world time coherently

During partial-sleep compression, the sleeping black-screen clock and the awake player's HUD/watch clock must represent the authoritative compressed world time with reasonable visual continuity.

At high compression factors the displayed game minutes will necessarily advance rapidly. For example, `MinutesPerDay=4.5` corresponds to approximately 5.33 in-game minutes per real second. The requirement is therefore not slow or one-minute-at-a-time presentation; it is avoidance of long apparent freezes followed by large multi-minute or multi-hour correction jumps under normal network conditions.

The eventual fix must preserve server authority and must not globally accelerate player/zombie/vehicle/timed-action simulation.

## 5. MVP sandbox configuration

The functional MVP intentionally keeps its configuration small:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
},
```

The following values are inherited from Project Zomboid and must not be duplicated as mod defaults:

- DayLength / live MinutesPerDay
- SleepAllowed
- SleepNeeded
- FastForwardMultiplier

`PartialSleepSpeedScale` is a policy modifier, not an alternate copy of `FastForwardMultiplier`.

Examples:

```text
NativeFastForward = 40
PartialSleepSpeedScale = 1.0 -> partial cap 40
PartialSleepSpeedScale = 0.5 -> partial cap 20
PartialSleepSpeedScale = 2.0 -> partial cap 80
```

## 6. Vanilla lifecycle semantics are explicitly accepted for MVP

The MVP intentionally does not special-case players that vanilla has not yet instantiated.

Examples:

- A player who is still loading does not affect the proportional denominator until an `IsoPlayer` exists.
- A dead player does not count as living.
- If vanilla considers all remaining living players asleep, vanilla may enter its normal full-sleep fast-forward behavior.
- Disconnects and respawns may temporarily change the living-player denominator as vanilla changes the instantiated population.

These are accepted MVP semantics rather than defects in the mod.

A stricter connection/readiness model may be reconsidered later only if real server use demonstrates a practical problem.

## 7. Time-domain model and future compensation

The architecture deliberately separates two concepts:

```text
ACTIVE SIMULATION TIME
movement, combat, zombie behavior, animations, vehicles, physics, timed actions
-> remains at normal simulation speed

WORLD / CALENDAR TIME
day/night clock, date, WorldAgeHours, game-minute-driven systems
-> compressed during partial sleep
```

For a partial-sleep state with:

```text
CalendarCompressionFactor = A
```

a future system that should remain tied to real/simulation time could potentially use:

```text
RealTimeCompensationFactor = 1 / A
```

Whether individual vanilla systems can be compensated safely must be established separately. Per-system compensation is not part of the MVP.

## 8. Findings from other B42 sleep mods

### TrueSleep

Review of the supplied TrueSleep source found that it:

- uses `getOnlinePlayers()` as the server-side population source;
- excludes dead players;
- checks actual `isAsleep()` state server-side;
- steps aside when all living players are asleep so vanilla owns full-sleep fast-forward;
- uses `WorldAgeHours` to measure world-time progression for its own sleep-recovery logic.

This supports the MVP's vanilla-extension and server-authoritative population model.

### Sleep With Friends

Review of the supplied B42.13 Sleep With Friends source found that it:

- does not modify GameTime or the global fast-forward multiplier;
- performs fatigue/endurance recovery as a separate sleep concern;
- uses `Events.EveryOneMinute` as a timing source;
- derives its real-time recovery assumptions from the static `SandboxVars.DayLength` configuration.

Because Enshrouded Sleep dynamically changes runtime `MinutesPerDay`, game-minute callbacks can occur more frequently in real time during compression. Therefore Sleep With Friends real-time recovery assumptions may be altered when both mods are active.

Compatibility with other sleep/recovery mods is not guaranteed by the MVP and should be tested explicitly.

## 9. Empirically validated behavior from B42.20.2 testing

These observations inform the requirements but are not hard-coded production constants.

### Test server configuration

The supplied test server has been validated with:

```text
DayLength = 4
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40.0
```

At runtime, `DayLength=4` produced `MinutesPerDay=90`.

### Clock-compression spike

With a runtime baseline of 90 minutes/day, the v0.0.1 test set `MinutesPerDay` to `4.5`, corresponding to a 20x calendar-compression factor. World time advanced at approximately the expected rate while `TrueMultiplier` remained `1`.

### Server-side sleep detection

`IsoPlayer:isAsleep()` changed reliably on the dedicated server when a player entered and left sleep.

### Vanilla full-sleep behavior

With the sole living player asleep:

- `MinutesPerDay` remained `90`;
- `GameTime:getMultiplier()` rose from approximately `4.8` to approximately `575`;
- `TrueMultiplier` remained `1`;
- the observed calendar rate was approximately 120x baseline even though `FastForwardMultiplier=40.0`.

Therefore the configured `FastForwardMultiplier` is used as the administrator's partial-sleep policy input; the mod does not assume it numerically equals vanilla's effective full-sleep calendar rate.

### Death/respawn and initial join

Dead player objects can remain in `getOnlinePlayers()` during respawn, while loading players can exist before their `IsoPlayer` appears. The MVP accepts these vanilla population semantics rather than adding a separate readiness layer.

### First successful two-player proportional-sleep test - v0.0.4

The first successful two-player v0.0.4 test validated:

```text
2 living / 0 sleeping
-> baseline MinutesPerDay=90.000

2 living / 1 sleeping
-> SleepFraction=0.5000
-> CalendarCompressionFactor=20.000
-> EffectiveMinutesPerDay=4.500
-> RealTimeCompensationFactor=0.05000

2 living / 2 sleeping
-> restore MinutesPerDay=90.000
-> vanilla full-sleep fast-forward owns the state
```

The controller also correctly returned to partial mode when one of two players woke, recalculated the denominator when a client disconnected, and restored the exact baseline when compression ended. No Enshrouded Sleep controller error or fail-safe was observed during these state transitions.

The same test exposed two client-display defects: the sleeping black-screen clock and the awake HUD/watch clock advanced in visible jumps during partial compression. These are tracked as GitHub issues #1 and #2 and motivate R21 and the v0.0.5 diagnostic build.

## 10. v0.0.5 clock-synchronization diagnostic plan

v0.0.5 is intentionally read-only instrumentation. It must not be treated as a speculative clock fix.

Once per real second, the server diagnostic records authoritative:

```text
MinutesPerDay
TimeOfDay
WorldAgeHours
DeltaMinutesPerDay
Multiplier
TrueMultiplier
ServerMultiplier
LivingPlayers
SleepingPlayers
```

The client diagnostic records its own corresponding GameTime values and, where exposed through Kahlua, public `GameTime` fields including:

```text
ServerTimeOfDay
ServerLastTimeOfDay
TimeOfDay
```

The diagnostic must not call `setMinutesPerDay()`, `setTimeOfDay()`, `setMultiplier()`, `GameServer.syncClock()`, or player/sleep mutation APIs.

The next two-player test should answer, in order:

1. Does client `getMinutesPerDay()` change from `90` to approximately `4.5` while one of two living players sleeps?
2. Does client `getTimeOfDay()` itself advance continuously or remain stale and then snap toward `ServerTimeOfDay`?
3. Do `ServerTimeOfDay` / `ServerLastTimeOfDay` update at a cadence different from local `TimeOfDay`?
4. If underlying client GameTime is already smooth, is the remaining defect isolated to the sleeping/HUD clock presentation layer?

No synchronization or interpolation fix should be selected until these questions are answered empirically.

## 11. Proportional examples

For a server with:

```text
BaselineMinutesPerDay = 120
NativeFastForward = 40
PartialSleepSpeedScale = 1.0
LivingPlayers = 4
```

partial sleep produces:

```text
0 of 4 sleeping -> factor 1x  -> 120 min/day
1 of 4 sleeping -> factor 10x -> 12 min/day
2 of 4 sleeping -> factor 20x -> 6 min/day
3 of 4 sleeping -> factor 30x -> 4 min/day
4 of 4 sleeping -> theoretical 40x / 3 min/day, but NOT applied;
                     restore 120 and hand off to vanilla full-sleep fast-forward
```

On the current test server with a 90-minute baseline:

```text
1 of 2 sleeping:
SleepFraction = 0.5
CalendarCompressionFactor = 40 * 1.0 * 0.5 = 20
EffectiveMinutesPerDay = 90 / 20 = 4.5
```

## 12. MVP acceptance tests

The MVP should not be considered complete until dedicated-server testing demonstrates:

1. **Configuration inheritance:** changing native DayLength changes the captured runtime baseline without editing mod configuration.
2. **Fast-forward inheritance:** changing native `FastForwardMultiplier` automatically changes partial-sleep compression.
3. **Neutral tuning:** `PartialSleepSpeedScale=1.0` uses the native fast-forward value as the partial-sleep policy cap.
4. **Fine tuning:** changing `PartialSleepSpeedScale` proportionally changes partial-sleep compression.
5. **Two-player partial sleep:** with baseline 90, native FF 40, scale 1.0, one of two sleeping produces approximately factor 20 and `MinutesPerDay=4.5`. **Validated in v0.0.4.**
6. **Four-player proportionality:** with baseline 120, native FF 40, scale 1.0, 1/4, 2/4, and 3/4 sleeping produce approximately 12, 6, and 4 MinutesPerDay respectively.
7. **Awake simulation remains normal:** movement, zombies, combat, vehicles, animations, inventory/timed actions, and crafting do not globally fast-forward during partial sleep.
8. **World-time progression:** calendar time and `WorldAgeHours` advance according to the applied `CalendarCompressionFactor`.
9. **Wake restoration:** waking the last partial sleeper restores the exact baseline immediately. **Observed in v0.0.4.**
10. **100% handoff:** all currently instantiated living players asleep restores baseline before vanilla fast-forward takes over, with no intentional stacking. **Observed in v0.0.4.**
11. **Population changes:** join/spawn, death, respawn, and disconnect affect the denominator only as vanilla changes the instantiated living-player population; disconnect recalculation was observed in v0.0.4.
12. **Failure safety:** disabling the mod or encountering a recoverable error restores baseline time.
13. **Client clock continuity:** sleeping and awake clock displays advance with visually coherent compressed world time and do not exhibit large periodic correction jumps under normal network conditions.
14. **Server authority:** any eventual clock-continuity fix keeps the server authoritative and does not change awake simulation speed.

## 13. Explicitly out of scope for MVP

The following may be considered after the core mechanic is stable:

- time-of-day sleep windows;
- custom fatigue/sleep eligibility;
- pre-spawn/loading-player readiness tracking;
- custom death/respawn fast-forward suppression;
- spectator-session readiness tracking;
- per-system time-domain compensation;
- explicit real-time compensation for hunger, thirst, fatigue, healing, spoilage, farming, generator fuel, corpse decay, composting, or similar systems;
- per-system `Follow World Time` versus `Compensate to Real Time` policies;
- guaranteed compatibility with other sleep/recovery mods;
- player-facing compression notifications;
- configuration presets.

The MVP should first establish the smallest reliable extension of vanilla Project Zomboid sleep behavior that adds proportional partial-sleep calendar compression without globally accelerating active simulation and presents that compressed world time coherently to connected clients.
