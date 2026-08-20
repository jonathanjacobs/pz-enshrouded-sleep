# Validation History

This document preserves the technical evidence behind the current Enshrouded Sleep architecture. For current procedures, see [`TESTING.md`](TESTING.md); for focused investigations, see [`spikes/`](spikes/); for durable design decisions, see [`adr/`](adr/).

## Summary

The project has progressed through four major evidence questions:

1. can `MinutesPerDay` compress world/calendar time without globally accelerating active simulation? — **yes**;
2. can the MVP rely on vanilla-instantiated player/sleep lifecycle and hand full sleep back to vanilla? — **yes**;
3. can clients be paced coherently with the authoritative compressed day length? — **yes**;
4. do health/survival subsystems create unsafe awake-player effects under calendar compression? — **partially classified; final survival-state test pending**.

The core sleep/clock architecture is behaviorally validated on Project Zomboid 42.20.3 with two players. Public Alpha is paused only for completion of SPIKE-004.

## v0.0.1 — calendar-compression feasibility

- baseline `MinutesPerDay=90`;
- temporary `4.5` produced approximately 20x world/calendar progression;
- `TrueMultiplier` remained `1`;
- awake gameplay did not visibly accelerate;
- exact baseline restoration worked.

Decision: use `MinutesPerDay` as the partial-sleep primitive. See SPIKE-001 and ADR-001.

## v0.0.2 / v0.0.2b — lifecycle and vanilla full sleep

Established:

- server `IsoPlayer:isAsleep()` reflects sleep/wake state;
- dead player objects may remain during respawn and must be excluded from the denominator;
- loading clients may exist before an `IsoPlayer` appears;
- MVP should use instantiated living players rather than a custom readiness registry;
- vanilla full sleep leaves `MinutesPerDay` at baseline and uses another acceleration path.

Decision: restore baseline and step aside when all living players sleep. See SPIKE-002 and ADR-002.

## v0.0.3 / v0.0.4 — proportional controller

Introduced:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

First successful two-player test:

```text
2 living / 0 sleeping -> MinutesPerDay=90
2 living / 1 sleeping -> factor 20 -> MinutesPerDay=4.5
2 living / 2 sleeping -> restore 90 -> vanilla full-sleep takeover
```

Wake restoration and disconnect denominator recalculation passed.

## v0.0.5 — client clock mismatch diagnosed

Read-only diagnostics showed:

```text
SERVER MinutesPerDay = 4.5
CLIENT MinutesPerDay = 90
```

Clients advanced at native day length between server corrections, producing large visible clock jumps and contributing to pathological sleep-duration behavior.

## v0.0.6 / v0.0.7 — explicit client pacing and clean regression

Added explicit server-to-client `MinutesPerDay` synchronization plus a low-frequency convergence heartbeat.

Validated on PZ 42.20.3:

```text
SERVER MinutesPerDay = 4.5
CLIENT A MinutesPerDay = 4.5
CLIENT B MinutesPerDay = 4.5
```

Results:

- smooth sleeping black-screen and awake HUD/watch clocks;
- awake movement/actions remained normal-speed;
- baseline/full-sleep handoff remained correct;
- client `AsleepTime` tracked compressed world time and wake occurred near vanilla `ForceWakeUpTime`;
- v0.0.7 fixed a diagnostic-only Kahlua multi-return numeric conversion error;
- synchronization publication was settled after the controller applied its target;
- issues #1, #2 and #3 were closed.

See SPIKE-003 and ADR-003.

## v0.0.8 — broad health/time-domain instrumentation

Before Public Alpha, review raised a separate question: what happens to an awake wounded or physiologically stressed player when another player triggers calendar compression?

v0.0.8 added read-only server/client health diagnostics with overall health/body health, detailed injured-body-part state and timers, nutrition/weight, sleep context, and clock/compression context.

### Solo vanilla-full-sleep reference — 2026-08-19

A deliberately injured character entered solo sleep. Because it was the only living player, Enshrouded Sleep restored native `MinutesPerDay=90` and vanilla full-sleep fast-forward owned the interval.

Immediately before sleep, health was approximately `81.16` with four active bleeds. Successive roughly one-second samples fell approximately:

```text
69.68 -> 47.74 -> 25.83 -> 6.03 -> 0
```

The character died within about five real seconds. A later healing sleep also showed strong recovery/timer acceleration.

This established that vanilla full-sleep acceleration can strongly affect health/recovery, but it did **not** classify Enshrouded Sleep partial compression because the monitored player was asleep and vanilla owned acceleration.

The run also showed that many legacy named `Stats` getters were unavailable through the tested Lua/Kahlua path.

## v0.0.9 — decisive two-player partial-compression run

The controlled run used two players and contained baseline, partial compression, restored baseline, and later higher-compression intervals.

Observed transitions included:

```text
90 -> 18 -> 90
90 -> 18 -> 90
90 -> 9 -> 90
```

The `18` state represented approximately 5x calendar compression with two living / one sleeping. The later `9` state represented approximately 10x after the native fast-forward setting was increased. `TrueMultiplier` remained `1.0` during partial compression.

### Awake bleeding / injury result

For the monitored awake injured player during the clean comparable interval:

```text
Overall health loss
baseline:   ~-0.07869 health / real second
5x partial: ~-0.07810 health / real second
ratio:      ~0.993x
```

Detailed timers corroborated this:

```text
BleedingTime
baseline:   ~-0.000959 / sec
5x partial: ~-0.000960 / sec

ScratchTime
baseline:   ~-0.000477 / sec
5x partial: ~-0.000477 / sec
```

Classification: **simulation/real-time bound under tested conditions**.

Safety interpretation: the feared rapid awake-player bleed-out proportional to calendar compression was not observed.

### Nutrition result

Nutrition stores scaled almost exactly with observed calendar compression:

| Metric | Baseline rate | ~5x partial | Ratio | ~10x partial | Ratio |
|---|---:|---:|---:|---:|---:|
| Calories | -0.2583/s | -1.2928/s | 5.01x | -2.5886/s | 10.00x |
| Carbohydrates | -0.05597/s | -0.27987/s | 5.00x | -0.55972/s | 10.00x |
| Proteins | -0.01374/s | -0.06877/s | 5.00x | -0.13753/s | 10.01x |
| Lipids | -0.01807/s | -0.09036/s | 5.00x | -0.18071/s | 10.00x |

Classification: **world/calendar-time bound**.

This is consistent with the decompiled 42.20.3 `Nutrition.update()` implementation, which updates carbohydrates, lipids, proteins, calories and weight using `GameTime.getInstance().getGameWorldSecondsSinceLastUpdate()`.

### Synchronization regression result

The v0.0.9 health experiment also reconfirmed server/client `MinutesPerDay` convergence, baseline restoration, alternate native fast-forward inheritance, no global `TrueMultiplier` acceleration during partial sleep, and no Enshrouded Sleep exception flood in the reviewed logs.

### Remaining observability failure

Hunger, thirst, fatigue, endurance, stress, panic, general pain, sickness and related continuous values remained `N/A`. The attempted Moodle fallback also remained `N/A`.

Post-run source review established that v0.0.9 was using stale API assumptions. Current Build 42.20.3 vanilla Lua uses:

```lua
player:getStats():get(CharacterStat.HUNGER)
player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
```

## v0.0.10 — corrected survival-state and standalone test stage

v0.0.10 adds the focused survival-state probe and diagnostic streams:

```text
42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
42/media/lua/server/EnshroudedSleep/SurvivalStatDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/SurvivalStatDiagnostic_Client.lua
42/media/lua/server/EnshroudedSleep/StandaloneHealthDiagnostic_Server.lua
```

The shared probe:

- reads continuous survival state through `Stats:get(CharacterStat.*)`;
- reads Moodles through `getMoodleLevel(MoodleType.*)`;
- retains direct Nutrition getters;
- records selected BodyDamage context;
- emits capability diagnostics to distinguish missing globals/enums/objects/methods;
- remains guarded/read-only;
- avoids the known Kahlua multi-return `tonumber()` failure pattern.

### Diagnostics-only forced compression

v0.0.10 also adds `DiagnosticForcedCompressionFactor`, default `1.0`, so the remaining causal test can be run with one awake character.

Activation requires:

```text
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
```

For a 90-minute baseline and factor `5`, the intended test state is:

```text
player awake
MinutesPerDay = 18
CalendarCompressionFactor = 5
no intentional global simulation multiplier change
```

This reproduces the same clock primitive used during multiplayer partial sleep without requiring a second sleeping client.

Safety behavior is intentionally conservative: if any observed living player sleeps, the test override is suspended and the captured baseline is restored before vanilla sleep acceleration can own the sleeping state. Returning the factor to `1.0`, disabling diagnostics, disabling the mod, or a recoverable failure also restores baseline.

### Standalone integration support

The focused server survival diagnostic falls back to `getPlayer()` when no populated online-player collection is available. The standalone health bridge provides matching overall-health/bleeding/body-part telemetry in that case.

At diagnostic factor `1.0`, a standalone session that lacks multiplayer `ServerOptions` is treated as a normal diagnostic baseline rather than a controller error: baseline `MinutesPerDay` is retained and the multiplayer policy path is simply not evaluated.

### Runtime status

The v0.0.10 single-player path is **implemented but not yet runtime-validated in Project Zomboid**. The next run should confirm:

- clean standalone load;
- CharacterStat/Moodle `CAPABILITIES` readability;
- baseline factor `1` telemetry;
- forced factor `5` / expected `MinutesPerDay≈18` while awake;
- ordinary multiplier context during the forced phase;
- exact restoration after returning factor to `1`;
- hunger/thirst/fatigue/endurance and other practical survival-rate classifications.

No health compensation has been implemented.

## Current evidence boundary

Well supported:

- two-player proportional compression;
- client/server `MinutesPerDay` synchronization;
- smooth sleeping/awake clock presentation;
- normal-speed awake active simulation;
- baseline restoration and vanilla full-sleep handoff;
- wake/disconnect recalculation;
- sensible vanilla sleep duration when client pacing is synchronized;
- broad health/body diagnostic integration;
- awake bleeding/health-loss behavior approximately real-time bound under partial compression;
- calories/carbohydrates/proteins/lipids world/calendar-time bound under partial compression;
- alternate native fast-forward inheritance in the SPIKE-004 run.

Current pre-alpha blocker:

- runtime validation of the corrected v0.0.10 `CharacterStat`/`MoodleType` probes and standalone forced-compression path;
- classification of hunger/thirst/fatigue/endurance and other practical high-severity survival variables;
- final SPIKE-004 GO / CONDITIONAL GO / NO-GO decision.

Public Alpha targets after that gate:

- 3–12+ player proportional fractions;
- real join/disconnect/death/respawn behavior;
- long-session stability;
- WHG mod-stack interaction;
- non-health world-time systems such as spoilage, farming, generators, weather, corpses and composting;
- future B42 update regressions.
