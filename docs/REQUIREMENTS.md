# Enshrouded Sleep — MVP Requirements

Status: **Public Alpha**  
Current version: `v0.0.10`  
Current behaviorally validated Project Zomboid baseline: `42.20.3`

This document defines intended MVP behavior and release/package invariants. Enshrouded Sleep is a **multiplayer-server mod**; local/standalone single-player support is out of scope.

## 1. Product goal

Provide Enshrouded-style proportional multiplayer sleeping for Project Zomboid Build 42 servers.

Vanilla Project Zomboid remains responsible for sleep eligibility, fatigue, sleep/wake state, death/respawn, joining/loading, and all-living-players-asleep fast-forward.

Enshrouded Sleep adds one normal gameplay behavior:

> When some, but not all, currently instantiated living server players are asleep, shorten the real-world duration of the PZ day in proportion to the sleeping fraction while leaving active gameplay simulation at normal speed.

The implementation uses `GameTime:MinutesPerDay`; it does **not** use a global simulation multiplier for partial sleep.

## 2. Definitions

- **BaselineMinutesPerDay** — authoritative server `getGameTime():getMinutesPerDay()` when compression is inactive.
- **NativeFastForward** — server `FastForwardMultiplier`.
- **PartialSleepSpeedScale** — administrator multiplier for normal partial sleep; default `1.0`.
- **LivingPlayers** — instantiated server `getOnlinePlayers()` entries where `isDead() == false`.
- **SleepingPlayers** — LivingPlayers where `isAsleep() == true`.
- **SleepFraction** — `SleepingPlayers / LivingPlayers`.
- **CalendarCompressionFactor** — world/calendar pacing factor.
- **EffectiveMinutesPerDay** — `BaselineMinutesPerDay / CalendarCompressionFactor`.
- **DiagnosticsEnabled** — support/development telemetry switch; default `false`.
- **DiagnosticForcedCompressionFactor** — server-test-only factor retained for regression/support; default `1.0` (inactive).
- **RuntimeModRoot** — `Contents/mods/pz-enshrouded-sleep/`, the single authoritative deployable Project Zomboid mod tree.
- **WorkshopRoot** — repository root / local Steam Workshop authoring item containing `workshop.txt`, Workshop artwork, `Contents/`, and intentionally public project documentation.

## 3. Core behavioral requirements

### R1 — Server-only runtime scope

Normal controller policy and server diagnostics are defined against multiplayer server APIs including `getOnlinePlayers()` and `getServerOptions()`. Server code must not introduce local `getPlayer()` fallbacks to support standalone/local games.

### R2 — Respect native sleep policy

If native `SleepAllowed=false`, normal partial-sleep compression must not bypass vanilla sleep restrictions.

### R3 — Runtime baseline is authoritative

The controller must derive baseline from authoritative server `getGameTime():getMinutesPerDay()`. No hard-coded day-length mapping is permitted.

### R4 — Native fast-forward policy is inherited

Normal partial sleep reads `FastForwardMultiplier`; the mod must not hard-code a presumed native fast-forward value.

### R5 — Normal Public Alpha configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

### R6 — Use vanilla-visible instantiated server population

The proportional denominator consists only of currently instantiated living server `IsoPlayer` objects returned by `getOnlinePlayers()`. Dead characters are excluded; admin characters count normally.

### R7 — Zero sleepers means exact baseline

When `SleepingPlayers == 0` during normal gameplay, `CalendarCompressionFactor=1.0` and server/clients must converge to the exact captured baseline.

### R8 — Partial sleep is proportional

When `0 < SleepingPlayers < LivingPlayers`:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

### R9 — Partial sleep must not globally accelerate active gameplay

The controller must not call `GameTime:setMultiplier()` for partial sleep. Awake movement, combat, zombies, vehicles, animations, physics, inventory/timed actions, and crafting must remain normal-speed.

### R10 — All living players asleep hands off to vanilla

When all living server players sleep, Enshrouded Sleep must restore baseline, tell clients to use baseline pacing, and let vanilla full-sleep fast-forward own the state.

### R11 — State changes recalculate promptly

Join/spawn/death/respawn/sleep/wake/disconnect must affect the denominator as soon as visible through server player state.

### R12 — Never slow world time below baseline

`CalendarCompressionFactor >= 1.0`.

### R13 — Fail toward native baseline

On disable, recoverable error, all-awake normal state, full-sleep handoff, or diagnostic-test exit/suspension, restore the exact captured baseline.

## 4. Client synchronization requirements

### R14 — Clients mirror authoritative `MinutesPerDay`

Connected clients must use the server-selected effective day length and must not independently calculate proportional policy.

### R15 — Server remains authoritative

Client synchronization must not use independent `setTimeOfDay()` or global multiplier changes as a substitute for matching server day-length pacing.

### R16 — Late-loading clients converge

A low-frequency heartbeat is permitted so clients that miss a transition still converge.

### R17 — Transition packets represent settled server state

The synchronization layer may defer publication briefly so the controller applies its target before announcement.

### R18 — Client clocks remain coherent without accelerating gameplay

Sleeping black-screen and awake HUD/watch clocks must pace smoothly while active simulation remains normal-speed.

## 5. World-time and player-safety requirements

### R19 — World/calendar systems may progress faster in real time

Changing `MinutesPerDay` intentionally accelerates world/calendar minutes. Systems based on game-world seconds, game minutes, `WorldAgeHours`, or equivalent clocks may therefore progress faster in real time.

### R20 — Compensation requires evidence

No broad compensation may be added from assumption alone. A system must first be measured and its time domain understood.

### R21 — Public Alpha health/survival safety gate — COMPLETE

[`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) completed the pre-alpha health/survival safety gate and returned **GO**.

Measured classifications:

- awake bleeding/body-health loss — approximately simulation/real-time bound under tested conditions;
- measured bleeding/scratch injury timers — approximately simulation/real-time bound;
- resting endurance recovery — approximately simulation/real-time bound under the tested condition;
- hunger — world/calendar-time bound;
- thirst — world/calendar-time bound;
- fatigue — world/calendar-time bound;
- calories/carbohydrates/proteins/lipids — world/calendar-time bound.

Faster hunger/thirst/fatigue/nutrition progression is accepted and documented as a consequence of genuinely faster elapsed world time. No broad health/survival compensation is required for Public Alpha.

Active sickness/food poisoning, poison, zombie infection/fever and extreme thermal injury remain Public Alpha characterization targets because those states were not active during SPIKE-004.

## 6. Diagnostic requirements

### R22 — Normal logging remains low-volume

One-second telemetry must be disabled by default with `DiagnosticsEnabled=false`.

### R23 — Verbose diagnostics remain observational

Health/survival instrumentation may sample once per real second but must not mutate health/survival state. The only permitted diagnostic-time mutation is the explicit server `MinutesPerDay` test override.

### R24 — Build 42 CharacterStat access

Continuous survival values should be observed through current Build 42 `Stats:get(CharacterStat)` APIs.

### R25 — Build 42 Moodle access

Moodle diagnostics must query concrete `MoodleType` objects rather than assume numeric enumeration APIs.

### R26 — Nutrition telemetry

At minimum retain weight, calories, carbohydrates, proteins and lipids from `player:getNutrition()`.

### R27 — Capability failures must be diagnosable

Focused survival diagnostics should emit one-time capability information and degrade unavailable paths to `N/A` rather than break gameplay.

### R28 — Avoid the known Kahlua multi-return conversion failure

Capture safe-wrapper return values before passing them to `tonumber()`.

### R29 — Existing injury diagnostics remain available

The broad health/body stream should remain available for detailed injured-body-part state during support/regression work.

### R30 — Diagnostic forced compression is server-only, explicit, bounded, and isolated

The forced-compression test may apply compressed server `MinutesPerDay` only when:

```text
DiagnosticsEnabled == true
DiagnosticForcedCompressionFactor > 1.0
LivingPlayers == 1
SleepingPlayers == 0
```

Requirements:

- default factor is exactly `1.0` and inactive;
- factor is bounded to `1.0`–`20.0`;
- target is `BaselineMinutesPerDay / DiagnosticForcedCompressionFactor`;
- the path must not call `GameTime:setMultiplier()`;
- player population must come from server `getOnlinePlayers()` only;
- if no living player is connected, retain baseline and keep the override armed;
- if the connected player sleeps, suspend the override and restore baseline;
- if a second living player connects, suspend the override and restore baseline;
- while a factor above `1` is armed, normal proportional-sleep policy is suppressed;
- disabling diagnostics or returning factor to `1.0` resumes normal server policy;
- client synchronization must preserve `diagnostic-forced` only while the exact one-awake-player conditions hold;
- the control is test-only and must remain `1.0` during normal Public Alpha operation;
- no standalone/local-game fallback or bridge is permitted.

## 7. Sleep-duration, packaging, and operational requirements

### R31 — Vanilla sleep/wake behavior remains meaningful

Vanilla fatigue, traits, sleeping pills and wake timing should remain meaningful. No custom sleep-duration compensation is presently required.

### R32 — Rollback remains straightforward

The mod must not require a persistent custom database or migration to disable. Administrators must be able to stop the server, remove/disable the mod, restart, and return future sleep/time behavior to vanilla.

### R33 — One authoritative runtime package tree

The only deployable Project Zomboid mod tree in the repository is:

```text
Contents/mods/pz-enshrouded-sleep/
```

Requirements:

- no second root-level `42/`, `common/`, or runtime `mod.info` copy;
- Build 42 versioned runtime files remain under `RuntimeModRoot/42/`;
- required Build 42 scanner placeholder directories remain present;
- source/runtime changes are made directly in this authoritative tree rather than copied into a generated distribution tree.

### R34 — Workshop wrapper is public and intentional

The repository root may be used as the Steam Workshop item wrapper and may intentionally contain public project documentation in addition to `workshop.txt`, artwork, and `Contents/`.

Requirements:

- every uploaded outer file is intentionally public;
- `.git/`, credentials, private logs, local test data, and scratch/backups are excluded from the Workshop authoring copy;
- `workshop.txt` preserves the permanent Workshop ID after first publication;
- the required valid `preview.png` is present before first upload;
- any referenced `poster.png`/`icon.png` exists and meets current Build 42 client requirements;
- normal Workshop server deployment distinguishes the permanent Steam Workshop ID from the stable Project Zomboid Mod ID `pz-enshrouded-sleep`;
- public Workshop/README/legal material includes required The Indie Stone disclaimers and the project's explicit Keen Games non-affiliation disclosure.

## 8. Reference examples

Validated normal multiplayer reference:

```text
BaselineMinutesPerDay = 90
NativeFastForward = 40
LivingPlayers = 2
SleepingPlayers = 1
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

Retained one-connected-player server diagnostic reference:

```text
BaselineMinutesPerDay = 90
LivingPlayers = 1
SleepingPlayers = 0
DiagnosticForcedCompressionFactor = 5
EffectiveMinutesPerDay = 18
```

Workshop/server identity reference after first publication:

```text
WorkshopItems=<permanent Steam Published File ID>
Mods=pz-enshrouded-sleep
```

## 9. MVP acceptance matrix

1. Baseline inheritance — `PENDING alternate native day-length test`
2. Native fast-forward inheritance — `VALIDATED`
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
17. Awake bleeding safety under compression — `VALIDATED ~1x; PASS`
18. Nutrition time-domain classification — `VALIDATED; world/calendar-time bound`
19. Corrected CharacterStat/Moodle telemetry — `VALIDATED v0.0.10: 24/24 stats, 25/25 moodles`
20. One-connected-player server forced-compression path — `VALIDATED v0.0.10`
21. Hunger/thirst/fatigue/endurance safety classification — `VALIDATED sufficiently for Public Alpha; SPIKE-004 GO`
22. Public-server stability at larger population — `PUBLIC ALPHA TARGET`
23. Non-health world-time side effects — `PUBLIC ALPHA TARGET`
24. Single authoritative Workshop/runtime repository tree — `IMPLEMENTED v0.0.10 publication preparation`
25. Workshop-distributed dedicated-server smoke test — `PENDING first Steam upload`

## 10. Out of scope

- local/standalone single-player support;
- custom sleep windows;
- custom fatigue/sleep eligibility;
- ready/not-ready voting;
- custom lobby/readiness tracking;
- broad automatic compensation without measured evidence;
- guaranteed compatibility with every sleep/recovery mod;
- player-facing compression notifications;
- configuration presets;
- generated build/deployment packaging scripts for normal Workshop publication.

Future work is tracked only in [`ROADMAP.md`](ROADMAP.md).
