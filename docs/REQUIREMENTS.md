# Enshrouded Sleep — MVP Requirements

Status: **Public Alpha candidate / pre-deployment validation**

Current development version: `v0.0.9`

Current behaviorally validated Project Zomboid baseline: `42.20.3`

This document defines intended MVP behavior. Historical evidence is recorded in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); focused investigations and architectural decisions are recorded under [`spikes/`](spikes/) and [`adr/`](adr/).

## 1. Product goal

Provide Enshrouded-style proportional multiplayer sleeping for Project Zomboid Build 42.

Vanilla Project Zomboid remains responsible for sleep eligibility, fatigue, sleep/wake state, death/respawn, joining/loading, and all-living-players-asleep fast-forward.

Enshrouded Sleep adds one missing behavior:

> When some, but not all, currently instantiated living players are asleep, shorten the real-world duration of the PZ day in proportion to the sleeping fraction while leaving active gameplay simulation at normal speed.

The implementation uses `GameTime:MinutesPerDay`; it does **not** use a global simulation multiplier for partial sleep.

## 2. Definitions

- **Mod ID** — `pz-enshrouded-sleep`.
- **BaselineMinutesPerDay** — live authoritative server `getGameTime():getMinutesPerDay()` when partial compression is not active.
- **NativeFastForward** — server `FastForwardMultiplier`.
- **PartialSleepSpeedScale** — administrator tuning factor; default `1.0`.
- **EffectivePartialSleepCap** — `NativeFastForward * PartialSleepSpeedScale`.
- **LivingPlayers** — instantiated players returned by `getOnlinePlayers()` where `isDead() == false`.
- **SleepingPlayers** — LivingPlayers where `isAsleep() == true`.
- **SleepFraction** — `SleepingPlayers / LivingPlayers`.
- **CalendarCompressionFactor** — proportional world/calendar pacing factor during partial sleep.
- **EffectiveMinutesPerDay** — `BaselineMinutesPerDay / CalendarCompressionFactor`.
- **ClientEffectiveMinutesPerDay** — client pacing value that must track the authoritative server target.
- **DiagnosticsEnabled** — support/development telemetry switch; default `false`; must not alter gameplay behavior.

## 3. Core behavioral requirements

### R1 — Respect native sleep policy

If native `SleepAllowed=false`, the mod must not apply partial-sleep compression or bypass vanilla restrictions. The mod must not replace native `SleepNeeded`, fatigue, or sleep eligibility.

### R2 — Runtime baseline is authoritative

The server derives baseline from:

```lua
getGameTime():getMinutesPerDay()
```

No hard-coded DayLength-to-minutes mapping is permitted.

### R3 — Native fast-forward policy is inherited

The server reads native `FastForwardMultiplier`; the mod must not hard-code `40`, `120`, or a presumed relationship between configured fast-forward and vanilla full-sleep behavior.

### R4 — Minimal administrator configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
},
```

`PartialSleepSpeedScale=1.0` is neutral.

### R5 — Use vanilla-visible instantiated population

The proportional denominator consists only of currently instantiated living `IsoPlayer` objects. The MVP does not maintain a separate registry for loading sockets, character-selection sessions, dead characters, respawn screens, or non-instantiated spectators.

### R6 — Admin characters count normally

A spawned living admin character counts like any other living player.

### R7 — Dead players are excluded

`isDead()==true` players must not count in LivingPlayers or SleepingPlayers.

### R8 — Zero sleepers means exact baseline

When `SleepingPlayers == 0`:

```text
CalendarCompressionFactor = 1.0
MinutesPerDay = BaselineMinutesPerDay
```

Server and clients must converge to the baseline.

### R9 — Partial sleep is proportional

When `0 < SleepingPlayers < LivingPlayers`:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay =
    BaselineMinutesPerDay / CalendarCompressionFactor
```

No tiers, votes, readiness states, or time-of-day windows are part of the MVP.

### R10 — Partial sleep must not globally accelerate active gameplay

The authoritative controller must not call `GameTime:setMultiplier()` for partial sleep. Awake movement, combat, zombies, vehicles, animations, physics, inventory/timed actions, and crafting must remain normal-speed.

### R11 — World/calendar systems may progress faster in real time

Changing `MinutesPerDay` intentionally accelerates world/calendar minutes. Systems based on game minutes, `WorldAgeHours`, or another calendar-derived clock may progress faster in real time.

Possible systems include player health/survival variables, spoilage, farming, generator fuel, corpse decay, composting, weather, and mods using `EveryOneMinute`/`WorldAgeHours`.

No broad compensation may be added based on assumption alone; effects must be measured first.

### R12 — Public Alpha health/survival safety gate

Before live Public Alpha deployment, controlled testing must determine whether partial compression creates an unacceptable high-severity hazard for an **awake** player.

At minimum, [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) must characterize:

- active bleeding and actual health loss;
- hunger/thirst;
- fatigue/endurance;
- wound/injury healing timers;
- sickness/food sickness/poison where observable;
- zombie infection variables where practical;
- temperature/cold progression where observable.

Public deployment is blocked if partial sleep can unexpectedly cause rapid bleed-out, starvation/dehydration, infection death, or a comparable high-severity player-state failure without a validated mitigation or acceptable configuration bound.

The v0.0.8 solo reference demonstrated that vanilla all-players-asleep fast-forward can accelerate bleeding/recovery dramatically; that result does not satisfy this requirement because the subject was sleeping and Enshrouded partial compression was not active.

### R13 — All living players asleep hands off to vanilla

When `LivingPlayers > 0` and `SleepingPlayers == LivingPlayers`, the mod must restore server baseline exactly, tell clients to use baseline pacing, stop partial compression, and let vanilla full-sleep fast-forward own the state.

### R14 — Never intentionally stack with vanilla full sleep

Compressed `MinutesPerDay` must not intentionally remain active while vanilla all-asleep fast-forward is engaged.

### R15 — Recalculate promptly as vanilla-visible state changes

Observe player/sleep state every server tick; write `MinutesPerDay` only when the target changes. Join/spawn/death/respawn/sleep/wake/disconnect must affect the denominator as soon as visible through instantiated player state.

### R16 — Never slow world time below baseline

`CalendarCompressionFactor >= 1.0`. The mod must not intentionally make a day longer than baseline.

### R17 — Restore exact baseline on exit/failure

Restore the captured baseline when partial compression ends, all living players sleep, native sleep is disabled, the mod is disabled, or a recoverable server failure occurs. Unexpected state must fail toward native baseline.

## 4. Client synchronization requirements

### R18 — Clients mirror authoritative `MinutesPerDay`

During partial sleep, clients must use the same effective day-length pacing value as the server. Clients must not independently calculate a different proportional target.

### R19 — Server remains authoritative for world time

Client synchronization must not use client `setTimeOfDay()`, global multiplier changes, or independent world-time ownership as a substitute for matching server day-length pacing.

### R20 — Late-loading clients converge

A low-frequency heartbeat is permitted so clients that miss a transition still converge.

### R21 — Transition packets represent settled server state

The synchronization observer may defer publication for one observer pass so the authoritative controller applies the new target first. The sync layer remains observational with respect to policy calculation.

### R22 — Client clocks remain visually coherent

Sleeping black-screen and awake HUD/watch clocks must follow compressed world time without long freezes followed by large corrections.

### R23 — Client synchronization must not accelerate active gameplay

Mirroring `MinutesPerDay` locally must not globally accelerate movement, zombies, vehicles, animations, combat, or timed actions.

## 5. Sleep-duration requirements

### R24 — Vanilla sleep/wake behavior remains meaningful

Partial compression must not cause pathological sleep duration because client sleep counters use different pacing. Vanilla fatigue, traits, and sleeping-pill effects should remain meaningful.

Controlled v0.0.6/v0.0.7 evidence shows synchronized client pacing keeps `AsleepTime`/`ForceWakeUpTime` behavior sensible; no custom sleep-duration compensation is currently required.

## 6. Diagnostic requirements

### R25 — Normal logging remains low-volume

One-second development telemetry is disabled by default:

```text
DiagnosticsEnabled = false
```

Low-volume startup/configuration/state-transition logging may remain active.

### R26 — Verbose diagnostics are read-only and comprehensive enough for time-domain analysis

With `DiagnosticsEnabled=true`, support instrumentation may sample once per real second and must remain observational.

The v0.0.9 diagnostics should capture, where exposed:

- server/client clock context including `MinutesPerDay`, `WorldAgeHours`, `DeltaMinutesPerDay` and multiplier values;
- all instantiated living-player general health/survival metrics on the server;
- owning-client equivalent metrics;
- sleep counters;
- nutrition state;
- detailed state/timers for injured body parts;
- relevant Moodle levels as an ordinal fallback/secondary signal.

Diagnostics must not heal, damage, feed, fatigue, infect, wake, sleep, change Moodles, change time, or otherwise mutate player state.

### R27 — Diagnostic access must tolerate Java/Lua bridge differences

A public Java method or field documented by PZ is not assumed to be exposed identically through Lua/Kahlua.

For selected v0.0.9 health/survival values, diagnostics may:

1. attempt the normal getter;
2. attempt a guarded public-field fallback;
3. report `N/A` when neither is available.

Moodle levels may be recorded as discrete corroborating/fallback evidence, but must not be presented as continuous raw-stat equivalents.

Unavailable getters/fields/Moodles must degrade safely rather than breaking gameplay.

### R28 — Diagnostic implementation must avoid known Kahlua multi-return conversion failure

Numeric conversion must not use the unsafe `tonumber(safeMethod(...))` pattern that caused the v0.0.6 `Double` -> `String` exception. The first method return value must be captured separately before conversion.

## 7. Operational requirements

### R29 — Rollback is straightforward

The mod must not require a custom persistent database or sleep-state migration to disable. Administrators must be able to stop the server, remove/disable the mod, restart, and return future time/sleep behavior to vanilla. Pre-deployment backups remain required during alpha because elapsed world time cannot be undone by removing the mod.

## 8. Validated reference examples

Validated historical example with baseline `90`, native FF `40`, scale `1.0`, two living and one sleeping:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

This server/client behavior is validated on PZ 42.20.3.

Current SPIKE-004 safety-test target with baseline `90`, native FF `10`, scale `1.0`, two living and one sleeping:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 5
EffectiveMinutesPerDay = 18
```

This is intentionally a lower-risk test target and remains pending validation.

Four-player acceptance example with baseline `120`, FF `40`, scale `1.0`:

```text
0/4 -> 120 min/day
1/4 -> 12 min/day
2/4 -> 6 min/day
3/4 -> 4 min/day
4/4 -> restore 120; vanilla owns full sleep
```

## 9. MVP acceptance matrix

1. **Baseline inheritance** — alternate native day length captured automatically. `PENDING`
2. **Fast-forward inheritance** — alternate native FF changes proportional behavior automatically. `PENDING; v0.0.9 SPIKE-004 FF=10 run will exercise this`
3. **Neutral scale 1.0**. `VALIDATED`
4. **Scale tuning** — non-default scale changes compression proportionally. `PENDING`
5. **Two-player partial sleep 90/40 -> 4.5**. `VALIDATED`
6. **3+ player proportionality**. `PUBLIC ALPHA TARGET`
7. **Awake active simulation remains normal**. `VALIDATED`
8. **World/calendar progression follows compression**. `VALIDATED`
9. **Wake restores exact baseline**. `VALIDATED`
10. **100% asleep restores baseline before vanilla handoff**. `VALIDATED`
11. **Population changes recalculate correctly**. `VALIDATED for disconnect; broader alpha coverage pending`
12. **Disable/fail-safe restores baseline**. `PENDING explicit test`
13. **Client day-length synchronization**. `VALIDATED`
14. **Sleeping clock continuity**. `VALIDATED — issue #1 closed`
15. **Awake HUD/watch continuity**. `VALIDATED — issue #2 closed`
16. **Server authority / no client global fast-forward**. `VALIDATED`
17. **Vanilla sleep-duration compatibility**. `VALIDATED — issue #3 closed`
18. **Heartbeat/client handler error-free**. `VALIDATED v0.0.7`
19. **Transition packets reflect settled state**. `VALIDATED v0.0.7`
20. **Health/survival time-domain safety gate**. `CURRENT PRE-ALPHA BLOCKER — SPIKE-004`
21. **Broad health/body diagnostic integration**. `VALIDATED v0.0.8 solo; v0.0.9 fallback coverage pending`
22. **Public-server stability at larger population**. `PUBLIC ALPHA TARGET AFTER #20`
23. **Non-health world-time side effects characterized**. `PUBLIC ALPHA TARGET`

## 10. Current out-of-scope items

- custom sleep windows;
- custom fatigue/sleep eligibility;
- ready/not-ready voting;
- pre-spawn socket/readiness tracking;
- custom death/respawn gating;
- broad automatic compensation without measured evidence;
- guaranteed compatibility with every sleep/recovery mod;
- player-facing compression notifications;
- configuration presets.

Possible future work is tracked in [`ROADMAP.md`](ROADMAP.md).
