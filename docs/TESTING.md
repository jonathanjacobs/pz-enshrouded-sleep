# Enshrouded Sleep — Testing Guide

Current status: **Public Alpha candidate / pre-deployment validation**

Current development version: `v0.0.9`

Current behaviorally validated Project Zomboid baseline: `42.20.3`

Historical procedures/results are consolidated in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). The current blocking investigation is [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md).

## 1. Test tiers

### Tier 1 — startup smoke test

Run after any source/configuration change or Project Zomboid update.

Minimum checks:

1. Server starts without Enshrouded Sleep Lua errors.
2. Client starts/connects without Enshrouded Sleep Lua errors.
3. Core controller and clock-state synchronization modules load.
4. Health diagnostic modules load without exceptions.
5. With all players awake, server/client `MinutesPerDay` remains at native baseline.
6. With `DiagnosticsEnabled=false`, there is no continuous one-second diagnostic output.

### Tier 2 — core multiplayer regression

Reference validated configuration:

```text
Baseline MinutesPerDay = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
PartialSleepSpeedScale = 1.0
```

Procedure:

1. Connect two living players.
2. Keep both awake at least 15 seconds; confirm server/client `MinutesPerDay=90`.
3. Put one player to sleep and keep one awake.
4. Confirm:

```text
living=2
sleeping=1
SleepFraction=0.5
CalendarCompressionFactor=20
EffectiveMinutesPerDay=4.5
```

5. Confirm both clients use `MinutesPerDay=4.5`.
6. Hold partial sleep at least 60 real seconds.
7. Confirm sleeping and awake clocks are rapid but visually smooth.
8. Confirm awake movement/actions remain normal-speed.
9. Wake the sleeper; confirm server/clients return to `90`.
10. Put both to sleep; confirm `90` is restored before vanilla full-sleep fast-forward.
11. Wake one; confirm partial `4.5` returns.
12. Wake all; confirm baseline `90`.
13. If practical, disconnect one player and confirm denominator/state recalculation.

The exact v0.0.7 build passed this sequence on PZ 42.20.3. The v0.0.8 solo run did not expose a core regression, but a short two-player core check remains appropriate after SPIKE-004 diagnostic work.

## 2. SPIKE-004 — health/survival time-domain test (CURRENT BLOCKER)

### Objective

Determine which player health/survival systems follow compressed world/calendar time and whether partial sleep creates an unacceptable hazard for an awake player.

### v0.0.8 preliminary solo result

The first health diagnostic integration run was successful:

- health and detailed injury telemetry worked on server and owning client;
- no Enshrouded Sleep diagnostic exception flood occurred;
- a solo character with four active bleeding injuries died within roughly five real seconds after entering **vanilla full sleep**;
- a later healing sleep showed strongly accelerated recovery/timer progression;
- many raw `Stats` getters remained `N/A` in the tested Lua/Kahlua context.

This is useful reference evidence, but it does **not** classify Enshrouded Sleep partial sleep because solo full sleep restores native `MinutesPerDay` and uses vanilla multiplier-driven fast-forward.

v0.0.9 adds public-field fallbacks, Moodle telemetry and direct multiplier/delta context so the decisive two-player run has better observability.

### Required configuration

Use the controlled test server, not the public server.

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
}
```

Use the same v0.0.9 snapshot on server and both clients.

For the first safety run, set native server:

```text
FastForwardMultiplier = 10
```

With two living players and one sleeper, expected partial behavior is approximately:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 5
Baseline MinutesPerDay = 90
Effective MinutesPerDay = 18
```

A 5x signal is large enough to distinguish a world-time-bound process while giving the operator more real time to switch machines and respond to an unsafe test character. Higher FF values can be tested later if needed.

Debug Mode is recommended so repeatable starting conditions can be created deliberately.

### Expected diagnostic prefixes

```text
[EnshroudedSleepDiag][SERVER]
[EnshroudedSleepDiag][CLIENT]
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
```

The health diagnostic emits one broad `PLAYER` sample per living player per real second. It also emits `BODY` lines for injured/non-pristine body parts.

### Metrics captured in v0.0.9

The diagnostic attempts to record, where exposed by the Lua bridge:

```text
clock / phase
MinutesPerDay
observed baseline
CalendarCompressionFactor
TimeOfDay
WorldAgeHours
DeltaMinutesPerDay
GameMultiplier
TrueMultiplier
ServerMultiplier
living/sleeping counts and SleepFraction (server)

sleep
isAsleep
AsleepTime
ForceWakeUpTime
SleepingPillsTaken

raw health / survival
Health
OverallBodyHealth
Hunger
Thirst
Fatigue
Endurance
Stress
Panic
Pain
Boredom
Unhappiness
Sickness
Drunkenness
Fear
Sanity
FoodSickness
Poison
InfectionLevel
ApparentInfectionLevel
FakeInfectionLevel
Infected
Temperature
Wetness
CatchACold
ColdStrength
ColdDamageStage

Moodle fallback / secondary state
MoodleHungry
MoodleThirst
MoodleTired
MoodleEndurance
MoodleStress
MoodlePanic
MoodlePain
MoodleBored
MoodleUnhappy
MoodleSick
MoodleDrunk
MoodleBleeding
MoodleInjured
MoodleWet
MoodleHasACold
MoodleHyperthermia
MoodleHypothermia
MoodleZombie
Moodles (compact observed set)

nutrition
Weight
Calories
Carbohydrates
Proteins
Lipids

injury details
body-part Health
Pain / AdditionalPain
Bleeding / BleedingTime
BleedingStemmed
Bandaged / BandageLife / BandageDirty
Cut / CutTime
Scratched / ScratchTime
Bitten / BiteTime
DeepWound / DeepWoundTime
Stitched / StitchTime
FractureTime / Splint / SplintFactor
Burnt / BurnTime
InfectedWound / WoundInfectionLevel
Glass / Bullet
body-part Wetness / SkinTemperature / InnerTemperature / Stiffness
```

For selected raw `Stats` and `BodyDamage` values, v0.0.9 tries the normal getter first and then a guarded documented public-field fallback. `N/A` remains acceptable when neither path is exposed.

Moodle levels are discrete severity states, not substitutes for continuous raw values. Use them as corroborating/fallback evidence.

### Controlled experiment

Use two players with fixed roles:

```text
Player A = awake monitored subject
Player B = sleeper used to trigger partial compression
```

Avoid sleeping pills on Player A. Use them on Player B only if needed to enter sleep reliably.

#### Phase A — native baseline (minimum 60 real seconds)

1. Both players awake.
2. Confirm `MinutesPerDay=90` and server health `phase=baseline`.
3. Use Debug Mode to create controlled nonzero states on Player A.
4. **At minimum create one active bleeding injury.**
5. Also create/adjust several slower variables if practical: hunger, thirst, fatigue, pain, an injury/healing state, sickness/food sickness, temperature/cold, etc.
6. Do not change those variables manually during the measurement window.
7. Hold for at least 60 real seconds.

Goal: obtain baseline change-per-real-second rates and confirm which v0.0.9 raw/Moodle probes are actually populated.

#### Phase B — partial sleep (minimum 60 real seconds, unless unsafe)

1. Player A remains awake with the same monitored conditions.
2. Player B enters normal vanilla sleep.
3. Confirm server reaches `2 living / 1 sleeping`.
4. With native FF=10 and scale=1.0, confirm approximately `CalendarCompressionFactor=5` and `MinutesPerDay=18`.
5. Confirm `GameMultiplier`/`TrueMultiplier` remain consistent with ordinary active gameplay rather than vanilla full-sleep acceleration.
6. Hold the state for at least 60 real seconds **unless Player A's health becomes unsafe**.
7. Player A may stand still to reduce activity/endurance confounding.
8. Do not heal, eat, drink, bandage, medicate, or otherwise reset monitored variables during the comparison interval unless needed to prevent test-character death.

Goal: compare each metric's rate against Phase A while the monitored character remains awake.

#### Phase C — restored baseline (minimum 60 real seconds)

1. Wake Player B.
2. Confirm `MinutesPerDay=90`.
3. Hold another 60 seconds without manually changing monitored variables where practical.

Goal: determine whether rates return toward baseline after compression ends.

#### Optional Phase D — vanilla full sleep

The v0.0.8 solo run already provides a strong vanilla full-sleep reference. Additional all-asleep testing is optional and must not be used to classify partial-compression effects.

### Safety rules

- Use expendable/debug test characters and a test-server save.
- Do not run the first bleeding/infection experiment on a valued public-server character.
- End Phase B early if the subject approaches death.
- Preserve the exact logs before resetting/restarting.

### Analysis

For every numeric variable that changes enough to measure, calculate approximately:

```text
baseline rate = delta(metric) / real seconds during Phase A
partial rate  = delta(metric) / real seconds during Phase B
rate ratio    = partial rate / baseline rate
```

Then compare the rate ratio to the **observed** compression factor, not an assumed constant:

```text
~1x       -> simulation/real-time bound
~observed CalendarCompressionFactor -> world/calendar-time bound
other     -> mixed/nonlinear/event-driven; investigate further
no useful change -> insufficient data
```

Use both server and owning-client telemetry where available. Use Moodle transitions only as ordinal/discrete evidence.

### Minimum go/no-go questions

Before Public Alpha deployment, answer:

1. Does an awake bleeding player's actual health loss accelerate materially during partial sleep?
2. Do hunger/thirst become dangerously faster in real time?
3. Does fatigue/endurance behavior become disruptive or dangerous?
4. Do wound healing/injury timers scale with compressed calendar time?
5. Do sickness/poison/zombie infection variables accelerate materially?
6. Do temperature/cold effects accelerate materially?
7. Is any observed acceleration severe enough to require a lower initial `PartialSleepSpeedScale`, a lower server FF policy, or code mitigation?

### Decision rule

**GO:** no unacceptable high-severity awake-player effect is found.

**CONDITIONAL GO:** behavior is measurable/understood and can be safely bounded with configuration or a narrowly targeted mitigation.

**NO-GO:** partial sleep can rapidly kill or seriously harm awake players through bleeding, infection, starvation/dehydration, or another high-severity health mechanism.

Record the final decision and metric classification table in [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md).

## 3. Public Alpha field testing (AFTER SPIKE-004 GO)

Once the health gate passes, field testing targets:

- 3–12+ living players;
- one sleeper among many awake players;
- multiple simultaneous sleepers;
- joins/disconnects while partial sleep is active;
- death/respawn while others sleep;
- repeated sleep/wake cycles over long sessions;
- mod-stack interaction;
- non-health world-time systems such as spoilage, generators, crops, corpses, composting and weather.

A useful report includes:

```text
approximate real-world time
players online
players asleep if known
reporting player awake/asleep
what happened
whether error counter increased
whether waking/reconnecting cleared it
```

## 4. Scale / proportionality checks

With native FF `40` and scale `1.0`:

```text
12 living / 1 sleeping -> factor ~3.333
12 living / 3 sleeping -> factor 10
12 living / 6 sleeping -> factor 20
12 living / 9 sleeping -> factor 30
12 living / 12 sleeping -> restore baseline; vanilla owns full sleep
```

Normal Public Alpha play can supply many of these cases naturally.

## 5. Configuration acceptance tests still pending

Controlled-server targets:

- alternate native day length;
- alternate native `FastForwardMultiplier`;
- non-default `PartialSleepSpeedScale` (e.g. 0.5 or 2.0);
- `Enabled=false` restoration;
- practical recoverable fail-safe restoration.

The SPIKE-004 FF=10 run will also provide evidence that partial compression inherits an alternate native `FastForwardMultiplier` correctly.

All tests must preserve exact baseline restoration and vanilla full-sleep handoff.

## 6. Verbose diagnostics policy

Normal play:

```text
DiagnosticsEnabled=false
```

Controlled investigation:

```text
DiagnosticsEnabled=true
```

With v0.0.9 this activates clock/sleep telemetry plus broad raw-stat, Moodle, nutrition and injury telemetry. Log volume can be substantial, so keep diagnostic sessions short and purposeful.

Collect:

```text
server log ZIP / DebugLog
server console
Player A client logs
Player B client logs when practical
```

For SPIKE-004, Player A's owning-client log is particularly important because Player A is the monitored health subject.

## 7. Project Zomboid update regression

For a new B42 build:

1. Review official release notes for multiplayer networking, GameTime, Lua events, sleep/fatigue, body-damage/stat APIs, mod loading or player lifecycle changes.
2. Run Tier 1 smoke testing.
3. If dependencies changed, run Tier 2 core regression.
4. Re-run focused health tests only if the update plausibly affects those systems.
5. Update the validated platform baseline only after successful testing.

## 8. Public Beta transition evidence

Before Public Beta:

- stable operation with more than two players;
- multiple proportional fractions validated;
- no recurrence of issues #1–#3;
- health/time-domain safety gate passed;
- alternate day length / FastForwardMultiplier inheritance tested;
- non-default scale tested;
- explicit disable/fail-safe restoration tested;
- acceptable public-server log/error behavior;
- major world-time-driven effects understood/documented;
- no known high-severity defect requiring rollback from ordinary multiplayer use.

See [`ROADMAP.md`](ROADMAP.md) for phase-level criteria.
