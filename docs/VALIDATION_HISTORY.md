# Validation History

This document preserves the technical evidence behind the current Enshrouded Sleep architecture. For current procedures, see [`TESTING.md`](TESTING.md); for focused investigations, see [`spikes/`](spikes/); for durable design decisions, see [`adr/`](adr/).

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player support is not part of the intended runtime model.

## Summary

The project answered four major pre-alpha questions:

1. can `MinutesPerDay` compress world/calendar time without globally accelerating active simulation? — **yes**;
2. can the MVP rely on vanilla-instantiated server player/sleep lifecycle and hand full sleep back to vanilla? — **yes**;
3. can connected clients be paced coherently with authoritative compressed day length? — **yes**;
4. do health/survival subsystems create an unacceptable awake-player hazard under calendar compression? — **no under the tested conditions; SPIKE-004 returned GO**.

The core architecture is behaviorally validated on Project Zomboid 42.20.3. v0.0.10 is the current **Public Alpha** build.

## v0.0.1 — calendar-compression feasibility

- baseline `MinutesPerDay=90`;
- temporary `4.5` produced approximately 20x world/calendar progression;
- `TrueMultiplier` remained `1`;
- awake gameplay did not visibly accelerate;
- exact baseline restoration worked.

Decision: use `MinutesPerDay` as the partial-sleep primitive. See SPIKE-001 and ADR-001.

## v0.0.2 / v0.0.2b — lifecycle and vanilla full sleep

Established that server `IsoPlayer:isAsleep()` reflects sleep/wake state, dead player objects may persist during respawn and must be excluded, loading clients do not count until an `IsoPlayer` exists, and vanilla full sleep leaves `MinutesPerDay` at baseline while using a separate acceleration path.

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

Read-only diagnostics showed the server at `MinutesPerDay=4.5` while clients remained at `90`, producing visible clock corrections.

## v0.0.6 / v0.0.7 — explicit client pacing and clean regression

Added explicit server-to-client `MinutesPerDay` synchronization plus a low-frequency heartbeat.

Validated on PZ 42.20.3:

```text
SERVER MinutesPerDay = 4.5
CLIENT A MinutesPerDay = 4.5
CLIENT B MinutesPerDay = 4.5
```

Results included smooth sleeping/awake clocks, normal-speed awake actions, correct baseline/full-sleep handoff, sensible `AsleepTime`/`ForceWakeUpTime`, the v0.0.7 Kahlua conversion fix, and settled state publication. Issues #1–#3 were closed.

## v0.0.8 — broad health/time-domain instrumentation

A one-player-on-server vanilla-full-sleep reference showed rapid vanilla health progression while Enshrouded Sleep had restored baseline `MinutesPerDay=90`:

```text
81.16 -> 69.68 -> 47.74 -> 25.83 -> 6.03 -> 0
```

This showed why vanilla full-sleep acceleration and Enshrouded partial compression had to be tested separately.

## v0.0.9 — two-player health/nutrition classification

Observed normal real partial-sleep transitions included `90 -> 18 -> 90` and `90 -> 9 -> 90`, with `TrueMultiplier=1.0` during compressed awake play.

### Awake bleeding/injury

```text
baseline health loss:   ~-0.07869 / real second
5x partial health loss: ~-0.07810 / real second
ratio:                  ~0.993x
```

Measured `BleedingTime` and `ScratchTime` also remained approximately `1x`.

Classification: **simulation/real-time bound under tested conditions**.

### Nutrition

| Metric | ~5x ratio | ~10x ratio |
|---|---:|---:|
| Calories | 5.01x | 10.00x |
| Carbohydrates | 5.00x | 10.00x |
| Proteins | 5.00x | 10.01x |
| Lipids | 5.00x | 10.00x |

Classification: **world/calendar-time bound**.

## v0.0.10 — corrected survival-state diagnostics and final pre-alpha gate

v0.0.10 added current Build 42 `CharacterStat`/`MoodleType` instrumentation and a diagnostics-only forced-compression test for exactly one awake living player connected to the multiplayer server.

Capability validation succeeded:

```text
CharacterStatsResolved=24/24
CharacterStatsReadable=24/24
MoodlesResolved=25/25
MoodlesReadable=25/25
NutritionReadable=10/10
```

The test exercised baseline plus approximately 5x, 10x and 20x calendar compression while the player remained awake. `TrueMultiplier` remained `1.0` during forced compression.

### Survival rates

Clean baseline-versus-5x comparison:

| Metric | Observed ratio | Classification |
|---|---:|---|
| Hunger | 4.85x | world/calendar-time bound |
| Thirst | 4.67x | world/calendar-time bound |
| Fatigue | 5.46x | world/calendar-time bound |
| Carbohydrates | 4.99x | world/calendar-time bound |
| Proteins | 4.99x | world/calendar-time bound |
| Lipids | 4.99x | world/calendar-time bound |

A short adjacent 10x-versus-baseline control produced approximately:

```text
Hunger       9.54x
Thirst       9.45x
Fatigue      9.48x
Proteins     9.48x
Lipids       9.48x
Body health  0.95x
```

This reinforced the split between world-time survival needs and real-time acute health loss.

### Endurance

Resting/recovery rates were approximately:

```text
10x: +0.00176 endurance/sec
20x: +0.00178 endurance/sec
10x: +0.00169 endurance/sec
```

Classification: **resting endurance recovery is simulation/real-time bound under the tested condition**.

### Temperature and inactive pathological states

Temperature remained physiologically stable and no hyperthermia/hypothermia hazard appeared. Active sickness, food sickness, poison, zombie infection/fever and extreme thermal injury were not present and remain unclassified.

### Diagnostic override safety

The forced-compression path correctly restored baseline and suspended itself when the connected player slept, preventing stacking with vanilla full-sleep acceleration.

### Client synchronization observation

During repeated live admin/sandbox factor changes, a few isolated client samples temporarily reverted to baseline `MinutesPerDay`. The authoritative server remained compressed and the normal ClockState heartbeat restored the client value within roughly a second. This is retained as a Public Alpha robustness observation, not the historical v0.0.5 failure mode.

## SPIKE-004 decision

**GO — Public Alpha.**

The evidence supports these classifications:

**Simulation/real-time bound under tested conditions**

- awake bleeding/body-health loss;
- measured bleeding/scratch timers;
- resting endurance recovery.

**World/calendar-time bound**

- hunger;
- thirst;
- fatigue;
- calories;
- carbohydrates;
- proteins;
- lipids.

No broad health/survival compensation is justified. Faster hunger/thirst/fatigue/nutrition progression is documented as an expected consequence of genuinely faster elapsed game-world time.

## Current evidence boundary

Well supported:

- two-player proportional compression;
- client/server `MinutesPerDay` synchronization;
- smooth sleeping/awake clock presentation;
- normal-speed awake active simulation;
- baseline restoration and vanilla full-sleep handoff;
- wake/disconnect recalculation;
- sensible vanilla sleep duration when client pacing is synchronized;
- awake acute injury/health loss approximately real-time bound;
- hunger/thirst/fatigue/nutrition world/calendar-time bound;
- resting endurance recovery approximately real-time bound;
- alternate native fast-forward inheritance;
- one-player server diagnostic override safety behavior.

Public Alpha characterization targets:

- 3–12+ player proportional fractions;
- live joins/disconnects/deaths/respawns;
- long-session stability and WHG mod-stack interaction;
- active sickness/poison/zombie infection/extreme thermal states where safely reproducible;
- spoilage, farming, generators, corpses, composting and weather;
- client pacing robustness during live admin/sandbox reconfiguration.
