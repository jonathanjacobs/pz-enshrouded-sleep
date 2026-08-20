# Validation History

This document preserves the technical evidence behind the current Enshrouded Sleep architecture. For current procedures, see [`TESTING.md`](TESTING.md); for focused investigations, see [`spikes/`](spikes/); for durable design decisions, see [`adr/`](adr/).

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player support is not part of the validated or intended runtime model.

## Summary

The project has progressed through four major evidence questions:

1. can `MinutesPerDay` compress world/calendar time without globally accelerating active simulation? — **yes**;
2. can the MVP rely on vanilla-instantiated server player/sleep lifecycle and hand full sleep back to vanilla? — **yes**;
3. can connected clients be paced coherently with authoritative compressed day length? — **yes**;
4. do health/survival subsystems create unsafe awake-player effects under calendar compression? — **partially classified; final survival-state test pending**.

The core sleep/clock architecture is behaviorally validated on Project Zomboid 42.20.3 with two players. Public Alpha remains paused for completion of SPIKE-004.

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
- MVP should use instantiated living server players rather than a custom readiness registry;
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

Clients advanced at native day length between server corrections, producing visible clock jumps and contributing to pathological sleep-duration behavior.

## v0.0.6 / v0.0.7 — explicit client pacing and clean regression

Added explicit server-to-client `MinutesPerDay` synchronization plus a low-frequency convergence heartbeat.

Validated on PZ 42.20.3:

```text
SERVER MinutesPerDay = 4.5
CLIENT A MinutesPerDay = 4.5
CLIENT B MinutesPerDay = 4.5
```

Results included smooth sleeping/awake clocks, normal-speed awake actions, correct baseline/full-sleep handoff, sensible `AsleepTime`/`ForceWakeUpTime`, the v0.0.7 Kahlua conversion fix, and settled state publication. Issues #1–#3 were closed.

## v0.0.8 — broad health/time-domain instrumentation

Before Public Alpha, review raised a separate question: what happens to an awake wounded or physiologically stressed player when another player triggers calendar compression?

v0.0.8 added broad server/client health diagnostics.

### One-player-on-server vanilla-full-sleep reference — 2026-08-19

A deliberately injured character slept while it was the only living player connected to the server. Enshrouded Sleep restored `MinutesPerDay=90` and vanilla full-sleep acceleration owned the interval.

Health fell approximately:

```text
81.16 -> 69.68 -> 47.74 -> 25.83 -> 6.03 -> 0
```

This established that vanilla full-sleep acceleration can strongly affect health/recovery, but it did not classify awake partial compression.

## v0.0.9 — decisive two-player partial-compression run

Observed transitions included:

```text
90 -> 18 -> 90
90 -> 18 -> 90
90 -> 9 -> 90
```

The `18` state represented approximately 5x calendar compression with two living / one sleeping. The `9` state represented approximately 10x. `TrueMultiplier` remained `1.0` during partial compression.

### Awake bleeding/injury result

```text
Overall health loss
baseline:   ~-0.07869 health / real second
5x partial: ~-0.07810 health / real second
ratio:      ~0.993x
```

Measured `BleedingTime` and `ScratchTime` remained approximately `1x`.

Classification: **simulation/real-time bound under tested conditions**.

Safety interpretation: rapid awake-player bleed-out proportional to calendar compression was not observed.

### Nutrition result

| Metric | Baseline rate | ~5x partial | Ratio | ~10x partial | Ratio |
|---|---:|---:|---:|---:|---:|
| Calories | -0.2583/s | -1.2928/s | 5.01x | -2.5886/s | 10.00x |
| Carbohydrates | -0.05597/s | -0.27987/s | 5.00x | -0.55972/s | 10.00x |
| Proteins | -0.01374/s | -0.06877/s | 5.00x | -0.13753/s | 10.01x |
| Lipids | -0.01807/s | -0.09036/s | 5.00x | -0.18071/s | 10.00x |

Classification: **world/calendar-time bound**.

The run also reconfirmed server/client `MinutesPerDay` convergence, baseline restoration, alternate native fast-forward inheritance, and ordinary `TrueMultiplier` during partial compression.

### Remaining observability failure

Hunger, thirst, fatigue, endurance and related continuous values remained `N/A`. Post-run source review established that v0.0.9 used stale API assumptions. Current Build 42.20.3 vanilla Lua uses:

```lua
player:getStats():get(CharacterStat.HUNGER)
player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
```

## v0.0.10 — corrected survival-state and one-player server test stage

v0.0.10 adds:

```text
42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
42/media/lua/server/EnshroudedSleep/SurvivalStatDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/SurvivalStatDiagnostic_Client.lua
```

The shared probe reads current Build 42 CharacterStats, Moodles, Nutrition and selected BodyDamage context, emits capability diagnostics, remains guarded/read-only, and avoids the known Kahlua multi-return conversion failure.

### Diagnostics-only forced compression

`DiagnosticForcedCompressionFactor` is a server-test-only control, default `1.0`.

Activation requires:

```text
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
exactly one living player connected to the multiplayer server
that player awake
```

For baseline `90` and factor `5`:

```text
living = 1
sleeping = 0
MinutesPerDay = 18
CalendarCompressionFactor = 5
no intentional global simulation multiplier change
```

If that player sleeps or another living player connects, the override restores baseline and suspends itself. With no living players connected, baseline is retained. Returning factor to `1.0`, disabling diagnostics, disabling the mod, or a recoverable failure returns to normal/baseline behavior.

While a factor above `1` is armed, ordinary proportional sleep policy is suppressed to isolate the experiment.

### Corrected scope

An intermediate v0.0.10 implementation mistakenly added local/standalone `getPlayer()` fallbacks and a standalone health bridge. Those changes were removed before runtime validation.

The final v0.0.10 test path uses the normal multiplayer server architecture only: `getOnlinePlayers()`, server `GameTime`, server options, server-authoritative `MinutesPerDay`, and the existing server-to-client clock synchronization path.

### Runtime status

The final v0.0.10 one-connected-player server path is **implemented but not yet runtime-validated**. The next run should confirm:

- clean server/client load;
- CharacterStat/Moodle capability readability;
- baseline factor `1` telemetry;
- forced factor `5` / expected `MinutesPerDay≈18` with `living=1`, `sleeping=0`;
- ordinary multiplier context during forced compression;
- exact restoration after factor returns to `1`;
- hunger/thirst/fatigue/endurance and other practical survival classifications.

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
- awake bleeding/health-loss approximately real-time bound under partial compression;
- calories/carbohydrates/proteins/lipids world/calendar-time bound;
- alternate native fast-forward inheritance.

Current pre-alpha blocker:

- runtime validation of the corrected v0.0.10 CharacterStat/Moodle probes on the one-connected-player multiplayer-server path;
- classification of hunger/thirst/fatigue/endurance and other practical high-severity survival variables;
- final SPIKE-004 GO / CONDITIONAL GO / NO-GO decision.

Public Alpha targets after that gate include 3–12+ player proportional fractions, real join/disconnect/death/respawn behavior, long-session stability, WHG mod-stack interaction, non-health world-time systems, and future B42 regressions.
