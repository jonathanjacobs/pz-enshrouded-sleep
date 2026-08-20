# Enshrouded Sleep — MVP Requirements

Status: **Public Alpha candidate / pre-deployment validation**  
Current development version: `v0.0.10`  
Current behaviorally validated Project Zomboid baseline: `42.20.3`

This document defines intended MVP behavior. Historical evidence lives in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); focused investigations and architectural decisions live under [`spikes/`](spikes/) and [`adr/`](adr/).

## 1. Product goal

Provide Enshrouded-style proportional multiplayer sleeping for Project Zomboid Build 42.

Vanilla Project Zomboid remains responsible for sleep eligibility, fatigue, sleep/wake state, death/respawn, joining/loading, and all-living-players-asleep fast-forward.

Enshrouded Sleep adds one behavior:

> When some, but not all, currently instantiated living players are asleep, shorten the real-world duration of the PZ day in proportion to the sleeping fraction while leaving active gameplay simulation at normal speed.

The implementation uses `GameTime:MinutesPerDay`; it does **not** use a global simulation multiplier for partial sleep.

## 2. Definitions

- **BaselineMinutesPerDay** — live authoritative server `getGameTime():getMinutesPerDay()` when partial compression is inactive.
- **NativeFastForward** — server `FastForwardMultiplier`.
- **PartialSleepSpeedScale** — administrator multiplier; default `1.0`.
- **LivingPlayers** — instantiated `getOnlinePlayers()` entries where `isDead() == false`.
- **SleepingPlayers** — LivingPlayers where `isAsleep() == true`.
- **SleepFraction** — `SleepingPlayers / LivingPlayers`.
- **CalendarCompressionFactor** — proportional world/calendar pacing factor during partial sleep.
- **EffectiveMinutesPerDay** — `BaselineMinutesPerDay / CalendarCompressionFactor`.
- **DiagnosticsEnabled** — support/development telemetry switch; default `false`; must not change gameplay behavior.

## 3. Core behavioral requirements

### R1 — Respect native sleep policy

If native `SleepAllowed=false`, the mod must not apply partial-sleep compression or bypass vanilla sleep restrictions.

### R2 — Runtime baseline is authoritative

The server must derive baseline from `getGameTime():getMinutesPerDay()`. No hard-coded day-length mapping is permitted.

### R3 — Native fast-forward policy is inherited

The server reads `FastForwardMultiplier`; the mod must not hard-code a presumed native fast-forward value.

### R4 — Minimal administrator configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
}
```

### R5 — Use vanilla-visible instantiated population

The proportional denominator consists only of currently instantiated living `IsoPlayer` objects. Dead characters are excluded; admin characters count normally.

### R6 — Zero sleepers means exact baseline

When `SleepingPlayers == 0`, `CalendarCompressionFactor=1.0` and server/clients must converge to the exact captured baseline.

### R7 — Partial sleep is proportional

When `0 < SleepingPlayers < LivingPlayers`:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay =
    BaselineMinutesPerDay / CalendarCompressionFactor
```

### R8 — Partial sleep must not globally accelerate active gameplay

The controller must not call `GameTime:setMultiplier()` for partial sleep. Awake movement, combat, zombies, vehicles, animations, physics, inventory/timed actions, and crafting must remain normal-speed.

### R9 — All living players asleep hands off to vanilla

When all living players sleep, Enshrouded Sleep must restore server baseline, tell clients to use baseline pacing, and let vanilla full-sleep fast-forward own the state. Compressed `MinutesPerDay` must not intentionally stack with vanilla all-asleep fast-forward.

### R10 — State changes recalculate promptly

Join/spawn/death/respawn/sleep/wake/disconnect must affect the denominator as soon as visible through instantiated player state. The controller may observe every tick but should write `MinutesPerDay` only when the target changes.

### R11 — Never slow world time below baseline

`CalendarCompressionFactor >= 1.0`.

### R12 — Fail toward native baseline

On disable, recoverable error, all-awake state, or full-sleep handoff, restore the exact captured baseline.

## 4. Client synchronization requirements

### R13 — Clients mirror authoritative `MinutesPerDay`

Clients must use the server-selected effective day length during partial sleep; clients must not independently calculate policy.

### R14 — Server remains authoritative for world time

Client synchronization must not use client `setTimeOfDay()`, global multiplier changes, or independent world-time ownership as a substitute for matching server day-length pacing.

### R15 — Late-loading clients converge

A low-frequency heartbeat is permitted so clients that miss a transition still converge.

### R16 — Transition packets represent settled server state

The synchronization layer may defer publication briefly so the controller applies its target before the state is announced.

### R17 — Client clocks remain coherent without accelerating gameplay

Sleeping black-screen and awake HUD/watch clocks must pace smoothly while client active simulation remains normal-speed.

## 5. World-time and player-safety requirements

### R18 — World/calendar systems may progress faster in real time

Changing `MinutesPerDay` intentionally accelerates world/calendar minutes. Systems based on game-world seconds, game minutes, `WorldAgeHours`, or equivalent clocks may therefore progress faster in real time.

Potential systems include player survival state, spoilage, farming, generator fuel, corpse decay, composting, weather, and mods driven by game time.

### R19 — Compensation requires evidence

No broad compensation may be added from assumption alone. A system must first be measured and its time domain understood.

### R20 — Public Alpha health/survival safety gate

Before live Public Alpha deployment, [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) must characterize high-severity awake-player consequences sufficiently to make a GO / CONDITIONAL GO / NO-GO decision.

Current evidence from v0.0.9 establishes:

- awake active-bleeding health loss remained approximately `1x` during ~5x partial compression;
- measured bleeding/scratch timers remained approximately `1x`;
- calories, carbohydrates, proteins and lipids scaled approximately with the observed 5x/10x calendar-compression factors;
- therefore different player systems demonstrably use different time domains.

Remaining priority variables are hunger, thirst, fatigue, endurance, sickness/food sickness/poison, zombie infection/fever, and temperature/cold state where practical.

Public deployment remains blocked if partial sleep can unexpectedly cause rapid starvation/dehydration, infection death, temperature injury, or a comparable high-severity awake-player failure without a validated mitigation or acceptable configuration bound.

## 6. Diagnostic requirements

### R21 — Normal logging remains low-volume

One-second telemetry must be disabled by default with `DiagnosticsEnabled=false`. Low-volume startup/configuration/state-transition logging may remain active.

### R22 — Verbose diagnostics remain observational

When `DiagnosticsEnabled=true`, instrumentation may sample once per real second but must not heal, damage, feed, fatigue, infect, wake, sleep, change Moodles, change time, or otherwise mutate player state.

### R23 — Build 42 CharacterStat access is the primary survival-stat path

For Build 42.20.3, continuous registered survival values should be observed through the current vanilla pattern:

```lua
local stats = player:getStats()
local hunger = stats:get(CharacterStat.HUNGER)
```

The diagnostic should directly probe relevant registered values including:

```text
HUNGER
THIRST
FATIGUE
ENDURANCE
STRESS
PANIC
PAIN
BOREDOM
UNHAPPINESS
SICKNESS
FOOD_SICKNESS
POISON
ZOMBIE_INFECTION
ZOMBIE_FEVER
TEMPERATURE
WETNESS
```

Additional registered CharacterStats may be logged when useful for context.

Legacy named getters/public fields may remain compatibility fallbacks but must not be treated as the canonical Build 42.20.3 access path.

### R24 — Build 42 Moodle access is keyed by MoodleType

Moodle diagnostics must query concrete `MoodleType` objects:

```lua
local moodles = player:getMoodles()
local hungry = moodles:getMoodleLevel(MoodleType.HUNGRY)
```

The diagnostic must not assume numeric enumeration APIs exist. Moodles are ordinal corroboration, not continuous substitutes for CharacterStats.

### R25 — Nutrition telemetry remains direct and correlated

At minimum, diagnostics should retain:

```lua
nutrition:getWeight()
nutrition:getCalories()
nutrition:getCarbohydrates()
nutrition:getProteins()
nutrition:getLipids()
```

Additional non-mutating nutrition state may be observed where exposed.

### R26 — Capability failures must be diagnosable

Focused survival diagnostics should emit enough one-time capability information to distinguish:

- missing `CharacterStat` global;
- unresolved CharacterStat constant;
- unavailable `Stats:get(CharacterStat)` call;
- missing `MoodleType` global;
- unavailable `getMoodleLevel(MoodleType)` call;
- unavailable Nutrition object/method.

An unavailable path must degrade to `N/A` rather than break gameplay.

### R27 — Avoid the known Kahlua multi-return conversion failure

Do not pass a multi-return safe-wrapper expression directly into `tonumber()`. Capture the method return first, then convert it.

### R28 — Existing injury diagnostics remain available during SPIKE-004

The validated broad health/body stream should remain available for detailed injured-body-part state even though v0.0.10 adds a separate focused CharacterStat/Moodle/Nutrition stream.

## 7. Sleep-duration and operational requirements

### R29 — Vanilla sleep/wake behavior remains meaningful

Vanilla fatigue, traits, sleeping pills and wake timing should remain meaningful. Current evidence shows synchronized client pacing keeps `AsleepTime`/`ForceWakeUpTime` behavior sensible; no custom sleep-duration compensation is presently required.

### R30 — Rollback remains straightforward

The mod must not require a persistent custom database or migration to disable. Administrators must be able to stop the server, remove/disable the mod, restart, and return future sleep/time behavior to vanilla. Backups remain appropriate during alpha because elapsed world time cannot be undone by removing the mod.

## 8. Validated reference examples

Validated two-player reference with baseline `90`, native FF `40`, scale `1.0`:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

SPIKE-004 focused safety configuration with baseline `90`, native FF `10`, scale `1.0`:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 5
EffectiveMinutesPerDay = 18
```

The v0.0.9 run validated this alternate-fast-forward partial state and also exercised a later factor-10 / `MinutesPerDay=9` interval.

## 9. MVP acceptance matrix

1. Baseline inheritance — `PENDING alternate native day-length test`
2. Native fast-forward inheritance — `VALIDATED in SPIKE-004 with FF=10 and later FF=20 behavior`
3. Neutral scale `1.0` — `VALIDATED`
4. Non-default scale tuning — `PENDING`
5. Two-player partial sleep `90/40 -> 4.5` — `VALIDATED`
6. 3+ player proportionality — `PUBLIC ALPHA TARGET`
7. Awake active simulation remains normal — `VALIDATED`
8. World/calendar progression follows compression — `VALIDATED`
9. Wake restores exact baseline — `VALIDATED`
10. All-asleep restores baseline before vanilla handoff — `VALIDATED`
11. Population changes recalculate correctly — `VALIDATED for disconnect; broader alpha coverage pending`
12. Disable/fail-safe restores baseline — `PENDING explicit test`
13. Client day-length synchronization — `VALIDATED`
14. Sleeping/awake clock continuity — `VALIDATED; issues #1/#2 closed`
15. Vanilla sleep-duration compatibility — `VALIDATED; issue #3 closed`
16. Health/body diagnostic integration — `VALIDATED`
17. Awake bleeding safety under partial compression — `VALIDATED ~1x; PASS`
18. Nutrition time-domain classification — `VALIDATED; world/calendar-time bound`
19. Corrected CharacterStat/Moodle telemetry — `IMPLEMENTED v0.0.10; runtime validation pending`
20. Hunger/thirst/fatigue/endurance safety classification — `CURRENT PRE-ALPHA BLOCKER`
21. Public-server stability at larger population — `PUBLIC ALPHA TARGET`
22. Non-health world-time side effects — `PUBLIC ALPHA TARGET`

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

Future work is tracked only in [`ROADMAP.md`](ROADMAP.md).
