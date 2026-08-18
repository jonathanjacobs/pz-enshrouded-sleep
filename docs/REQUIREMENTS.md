# Enshrouded Sleep — MVP Requirements

Status: **Public Alpha**

Current development version: `v0.0.7`

Current behaviorally validated Project Zomboid baseline: `42.20.3`

This document defines the intended behavior of the first functional multiplayer release. Historical experiments and evidence are recorded separately in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

## 1. Product goal

Provide Enshrouded-style proportional multiplayer sleeping for Project Zomboid Build 42.

Vanilla Project Zomboid remains responsible for:

- whether sleep is allowed;
- whether fatigue is required;
- entering and leaving sleep;
- death and respawn;
- joining/loading;
- vanilla all-living-players-asleep fast-forward.

Enshrouded Sleep adds one missing behavior:

> When some, but not all, currently instantiated living players are asleep, shorten the real-world duration of the Project Zomboid day in proportion to the sleeping fraction while leaving active gameplay simulation at normal speed.

The implementation uses `GameTime:MinutesPerDay`. It does **not** use global simulation fast-forward for partial sleep.

## 2. Definitions

- **Mod ID** — `pz-enshrouded-sleep`.
- **BaselineMinutesPerDay** — the live authoritative server value returned by `getGameTime():getMinutesPerDay()` when partial compression is not active.
- **NativeFastForward** — the server's configured `FastForwardMultiplier`.
- **PartialSleepSpeedScale** — mod-specific administrator tuning factor; default `1.0`.
- **EffectivePartialSleepCap** — `NativeFastForward * PartialSleepSpeedScale`.
- **LivingPlayers** — instantiated players returned by `getOnlinePlayers()` where `isDead() == false`.
- **SleepingPlayers** — LivingPlayers where `isAsleep() == true`.
- **SleepFraction** — `SleepingPlayers / LivingPlayers`.
- **CalendarCompressionFactor** — proportional world/calendar pacing factor applied during partial sleep.
- **EffectiveMinutesPerDay** — `BaselineMinutesPerDay / CalendarCompressionFactor`.
- **ClientEffectiveMinutesPerDay** — local client day-length pacing value; must track the authoritative server target.
- **DiagnosticsEnabled** — support/development telemetry switch; default `false`; does not change gameplay behavior.

## 3. Core behavioral requirements

### R1 — Respect native sleep policy

If native `SleepAllowed=false`, the mod must not apply partial-sleep compression or bypass vanilla restrictions.

The mod must not replace native `SleepNeeded`, fatigue, or sleep eligibility.

### R2 — Runtime baseline is authoritative

The server must derive baseline day length from:

```lua
getGameTime():getMinutesPerDay()
```

The mod must not hard-code a DayLength-to-minutes mapping.

### R3 — Native fast-forward policy is inherited

The server must read `FastForwardMultiplier` from native server options.

The mod must not hard-code `40`, `120`, or a presumed relationship between configured fast-forward and vanilla's effective full-sleep rate.

### R4 — Minimal administrator tuning

The gameplay configuration remains:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
},
```

`PartialSleepSpeedScale=1.0` is neutral.

### R5 — Use vanilla-visible instantiated population

The proportional denominator consists only of currently instantiated living `IsoPlayer` objects.

The MVP does not maintain a separate registry for:

- loading sockets;
- lobby/character-selection sessions;
- dead characters;
- respawn screens;
- spectators without an instantiated playable character.

### R6 — Admin characters count normally

A spawned living admin character counts the same as any other living player.

### R7 — Dead players are excluded

A player for which `isDead()==true` must not count in either LivingPlayers or SleepingPlayers.

### R8 — Zero sleepers means exact baseline

When `SleepingPlayers == 0`:

```text
CalendarCompressionFactor = 1.0
MinutesPerDay = BaselineMinutesPerDay
```

Server and clients must converge to the native baseline value.

### R9 — Partial sleep is proportional

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
EffectiveMinutesPerDay =
    BaselineMinutesPerDay / CalendarCompressionFactor
```

There are no tiers, voting thresholds, readiness states, or time-of-day windows in the MVP.

### R10 — Partial sleep must not globally accelerate gameplay

The authoritative partial-sleep controller must not call `GameTime:setMultiplier()` or another global fast-forward mechanism.

Awake movement, combat, zombies, vehicles, animations, physics, inventory actions, timed actions, and crafting must remain at normal active-game speed.

### R11 — World/calendar systems follow compressed time unless explicitly compensated

Changing `MinutesPerDay` intentionally accelerates world/calendar minutes in real time.

Systems based on game minutes or `WorldAgeHours` may therefore progress faster during partial sleep. This may include:

- spoilage;
- farming/crops;
- generator fuel;
- hunger/thirst/fatigue;
- healing;
- corpse decay;
- composting;
- weather;
- mods using `Events.EveryOneMinute` or `WorldAgeHours`.

The Public Alpha must characterize these effects before broad compensation is considered.

### R12 — All living players asleep hands off to vanilla

When:

```text
LivingPlayers > 0
SleepingPlayers == LivingPlayers
```

Enshrouded Sleep must:

1. restore server `BaselineMinutesPerDay` exactly;
2. tell clients to use the baseline pacing value;
3. stop applying partial compression;
4. allow vanilla full-sleep fast-forward to own the state.

### R13 — Never intentionally stack compression with vanilla full sleep

The mod's compressed `MinutesPerDay` must not intentionally remain active while vanilla all-players-asleep fast-forward is engaged.

### R14 — Recalculate promptly as vanilla-visible state changes

The server should observe player/sleep state every tick and only write `MinutesPerDay` when the effective target changes.

Join, spawn, death, respawn, sleep, wake, and disconnect must affect the denominator as soon as those states are visible through the instantiated player population.

### R15 — Never slow world time below baseline

`CalendarCompressionFactor` has a minimum of `1.0`.

The mod must never intentionally make a day longer than the native baseline.

### R16 — Restore the exact baseline on exit/failure

Whenever partial compression ends, restore the captured baseline exactly.

This includes:

- last partial sleeper waking;
- all living players becoming asleep;
- native sleep being disabled;
- mod disable;
- recoverable server failure.

Unexpected server state must fail toward native baseline rather than leaving compression active.

## 4. Client synchronization requirements

### R17 — Clients must mirror authoritative `MinutesPerDay`

During partial sleep, connected clients must use the same effective day-length pacing value as the server.

The client must not independently calculate a different proportional target.

### R18 — Server remains authoritative for world time

Client synchronization must not substitute client-side `setTimeOfDay()`, global multiplier changes, or independent world-time ownership for matching day-length pacing.

### R19 — Late-loading clients must converge

A low-frequency heartbeat is permitted so clients that miss a state transition still converge to the current server target.

### R20 — Transition packets must represent settled server state

When population/sleep state changes, the synchronization observer may defer publication for one observer pass so the authoritative controller can apply the corresponding `MinutesPerDay` first.

The sync layer must remain observational with respect to policy calculation.

### R21 — Client clocks must remain visually coherent

The sleeping black-screen clock and awake HUD/watch clock must follow compressed world time without long freezes followed by large network corrections.

Rapid clock movement is expected at high compression. For example, `MinutesPerDay=4.5` corresponds to about 5.33 in-game minutes per real second.

### R22 — Client synchronization must not accelerate awake gameplay

Mirroring `MinutesPerDay` locally must not globally accelerate movement, zombies, vehicles, animations, combat, or timed actions.

## 5. Sleep-duration requirements

### R23 — Vanilla sleep/wake behavior must remain meaningful

Partial compression must not cause a sleeping character to remain asleep across implausibly large world-time intervals because client sleep counters are paced differently from authoritative world time.

Vanilla modifiers such as fatigue, traits, and sleeping pills should continue to influence sleep normally.

Current evidence shows that once client `MinutesPerDay` matches the server, `AsleepTime` and vanilla `ForceWakeUpTime` behave sensibly. No custom sleep-duration compensation is currently required.

## 6. Operational requirements

### R24 — Normal public-alpha logging must remain low volume

Normal operation may log startup/configuration and meaningful state transitions.

One-second development telemetry must be disabled by default:

```text
DiagnosticsEnabled = false
```

When explicitly enabled for troubleshooting, verbose telemetry may log server/client clock and sleep state once per real second.

### R25 — Rollback must be straightforward

The mod must not require a custom persistent database or custom sleep-state migration to disable.

A server administrator must be able to stop the server, remove/disable the mod, restart, and return future sleep/time behavior to vanilla. A pre-deployment save backup remains required during alpha because world time that has already elapsed cannot be undone by removing the mod.

## 7. Validated reference examples

### Two-player validated case

With:

```text
BaselineMinutesPerDay = 90
NativeFastForward = 40
PartialSleepSpeedScale = 1.0
LivingPlayers = 2
SleepingPlayers = 1
```

expected and validated behavior is:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

### Four-player proportional example

With baseline `120`, FF `40`, and scale `1.0`:

```text
0/4 sleeping -> 120 min/day
1/4 sleeping -> 12 min/day
2/4 sleeping -> 6 min/day
3/4 sleeping -> 4 min/day
4/4 sleeping -> restore 120; vanilla full-sleep fast-forward owns the state
```

This four-player example remains an acceptance target until exercised in multiplayer testing.

## 8. MVP acceptance matrix

The MVP/Public Beta transition should demonstrate:

1. **Baseline inheritance** — alternate native day length is captured automatically. `PENDING`
2. **Fast-forward inheritance** — alternate native `FastForwardMultiplier` changes proportional behavior automatically. `PENDING`
3. **Neutral scale** — scale `1.0` uses native FF as the proportional policy input. `VALIDATED`
4. **Scale tuning** — alternate scale values change compression proportionally. `PENDING`
5. **Two-player partial sleep** — 1/2 sleeping at baseline 90 / FF 40 produces `4.5`. `VALIDATED`
6. **3+ player proportionality** — multiple fractional sleeper counts behave according to formula. `PUBLIC ALPHA TARGET`
7. **Awake simulation remains normal**. `VALIDATED`
8. **World/calendar progression follows compression**. `VALIDATED`
9. **Wake restores exact baseline**. `VALIDATED`
10. **100% asleep restores baseline before vanilla handoff**. `VALIDATED`
11. **Population changes recalculate correctly**. `VALIDATED for disconnect; broader alpha coverage pending`
12. **Recoverable failure/disable restores baseline**. `PENDING explicit failure/disable test`
13. **Client day-length synchronization**. `VALIDATED`
14. **Sleeping clock continuity**. `VALIDATED — issue #1 closed`
15. **Awake HUD/watch continuity**. `VALIDATED — issue #2 closed`
16. **Server authority / no client global fast-forward**. `VALIDATED`
17. **Vanilla sleep-duration compatibility**. `VALIDATED in controlled tests — issue #3 closed`
18. **Heartbeat/client handler remains error-free**. `VALIDATED in v0.0.7 regression`
19. **Transition packets reflect settled state**. `VALIDATED in v0.0.7 regression`
20. **Public-server operational stability at larger population**. `PUBLIC ALPHA TARGET`
21. **Major world-time-driven side effects characterized**. `PUBLIC ALPHA TARGET`

## 9. Current out-of-scope items

The alpha does not currently include:

- custom sleep windows;
- custom fatigue/sleep eligibility;
- ready/not-ready voting;
- pre-spawn socket/readiness tracking;
- custom death/respawn gating;
- broad automatic compensation of all world-time-driven systems;
- guaranteed compatibility with every sleep/recovery mod;
- player-facing compression notifications;
- configuration presets.

Possible future work is tracked in [`ROADMAP.md`](ROADMAP.md).
