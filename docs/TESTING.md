# Enshrouded Sleep — Testing Guide

Current status: **Public Alpha candidate / pre-deployment validation**  
Current development version: `v0.0.10`  
Current behaviorally validated Project Zomboid baseline: `42.20.3`

Historical procedures/results are consolidated in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). The current blocking investigation is [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md).

## 1. Tier 1 — startup smoke test

Run after any source/configuration change or Project Zomboid update.

Minimum checks:

1. Server starts without Enshrouded Sleep Lua errors.
2. Both clients start/connect without Enshrouded Sleep Lua errors.
3. Core controller and clock-state synchronization modules load.
4. Existing health/body diagnostics load without exceptions.
5. New survival diagnostic modules load without exceptions.
6. With all players awake, server/client `MinutesPerDay` remains at native baseline.
7. With `DiagnosticsEnabled=false`, no one-second health/survival diagnostic stream is emitted.

## 2. Tier 2 — core multiplayer regression

Reference validated configuration:

```text
Baseline MinutesPerDay = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
PartialSleepSpeedScale = 1.0
```

Minimum regression:

1. Connect two living players and confirm server/clients at `MinutesPerDay=90`.
2. Put one player to sleep and keep one awake.
3. Confirm `living=2`, `sleeping=1`, factor approximately `20`, and `MinutesPerDay=4.5`.
4. Confirm both clients adopt `4.5` and clocks remain visually smooth.
5. Confirm awake movement/actions remain normal-speed.
6. Wake the sleeper and confirm server/clients return exactly to `90`.
7. Put both to sleep and confirm Enshrouded Sleep restores `90` before vanilla full-sleep fast-forward owns the state.
8. If practical, disconnect one player and confirm population/state recalculation.

The exact v0.0.7 build passed this sequence on PZ 42.20.3. v0.0.9 also showed correct `90 -> 18 -> 90` and `90 -> 9 -> 90` synchronization during SPIKE-004 testing.

## 3. SPIKE-004 evidence already established

The v0.0.9 controlled run does **not** need to be repeated merely to reconfirm bleeding.

Established results:

- awake active-bleeding health loss remained approximately `1x` real-time rate under approximately 5x calendar compression;
- measured `BleedingTime` and `ScratchTime` remained approximately `1x`;
- calories, carbohydrates, proteins and lipids scaled almost exactly with 5x and 10x calendar compression;
- `TrueMultiplier` remained `1.0` during partial compression;
- client/server `MinutesPerDay` synchronization and restoration remained correct.

The remaining test exists because v0.0.9 used outdated survival-stat/Moodle access assumptions and therefore still reported `N/A` for hunger, thirst, fatigue, endurance and related values.

## 4. v0.0.10 corrected survival-state instrumentation

When `DiagnosticsEnabled=true`, v0.0.10 adds:

```text
[EnshroudedSleepSurvivalDiag][SERVER] CAPABILITIES ...
[EnshroudedSleepSurvivalDiag][SERVER] SURVIVAL ...
[EnshroudedSleepSurvivalDiag][CLIENT] CAPABILITIES ...
[EnshroudedSleepSurvivalDiag][CLIENT] SURVIVAL ...
```

The focused diagnostic uses current Build 42 access patterns.

### CharacterStat continuous values

```lua
local stats = player:getStats()

stats:get(CharacterStat.HUNGER)
stats:get(CharacterStat.THIRST)
stats:get(CharacterStat.FATIGUE)
stats:get(CharacterStat.ENDURANCE)
stats:get(CharacterStat.STRESS)
stats:get(CharacterStat.PANIC)
stats:get(CharacterStat.PAIN)
stats:get(CharacterStat.BOREDOM)
stats:get(CharacterStat.UNHAPPINESS)
stats:get(CharacterStat.SICKNESS)
stats:get(CharacterStat.FOOD_SICKNESS)
stats:get(CharacterStat.POISON)
stats:get(CharacterStat.ZOMBIE_INFECTION)
stats:get(CharacterStat.ZOMBIE_FEVER)
stats:get(CharacterStat.TEMPERATURE)
stats:get(CharacterStat.WETNESS)
```

Additional registered CharacterStats are also logged for context.

### Moodle ordinal values

```lua
local moodles = player:getMoodles()

moodles:getMoodleLevel(MoodleType.HUNGRY)
moodles:getMoodleLevel(MoodleType.THIRST)
moodles:getMoodleLevel(MoodleType.TIRED)
moodles:getMoodleLevel(MoodleType.ENDURANCE)
moodles:getMoodleLevel(MoodleType.STRESS)
moodles:getMoodleLevel(MoodleType.PANIC)
moodles:getMoodleLevel(MoodleType.PAIN)
moodles:getMoodleLevel(MoodleType.SICK)
```

The diagnostic directly checks all relevant built-in `MoodleType` constants rather than attempting numeric enumeration.

### Nutrition

```lua
local nutrition = player:getNutrition()

nutrition:getWeight()
nutrition:getCalories()
nutrition:getCarbohydrates()
nutrition:getProteins()
nutrition:getLipids()
nutrition:isIncWeight()
nutrition:isIncWeightLot()
nutrition:isDecWeight()
```

The core five nutrition values were already observed successfully in v0.0.9; v0.0.10 retains them in the focused stream to correlate them with CharacterStat changes.

## 5. Focused v0.0.10 SPIKE-004 test — CURRENT BLOCKER

Use the controlled test server, not the public server.

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
}
```

Use the same v0.0.10 snapshot on server and both clients.

Set native server:

```text
FastForwardMultiplier = 10
```

With two living players and one sleeper on the 90-minute-day test server, expect approximately:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 5
EffectiveMinutesPerDay = 18
```

### Player roles

```text
Player A = awake monitored subject
Player B = sleeper used to trigger partial compression
```

Keep Player A relatively inactive to reduce endurance/activity confounding. Do not deliberately create bleeding; that question already passed.

### Phase A — baseline, 60–90 real seconds

1. Both players awake.
2. Confirm server/client `MinutesPerDay=90`.
3. Inspect the new `CAPABILITIES` lines before continuing.
4. Desired capability result is nonzero/readable CharacterStats and Moodles on the monitored side(s). If those counts are zero, stop and preserve logs; do not waste the full run.
5. In Debug Mode, establish useful nonzero hunger, thirst, fatigue and other target states on Player A without putting the character at immediate risk.
6. Once starting conditions are established, do not eat, drink, sleep, exercise, medicate or otherwise reset those values during the measurement interval.
7. Hold 60–90 real seconds.

### Phase B — partial compression, 60–90 real seconds

1. Keep Player A awake.
2. Put Player B to sleep.
3. Confirm `2 living / 1 sleeping`, approximately factor `5`, and `MinutesPerDay=18`.
4. Confirm `TrueMultiplier` remains consistent with ordinary active gameplay rather than vanilla full-sleep acceleration.
5. Hold Player A relatively still for 60–90 real seconds.
6. Do not manually reset monitored survival values unless necessary for safety.

### Phase C — restored baseline, 60–90 real seconds

1. Wake Player B.
2. Confirm server/client `MinutesPerDay=90`.
3. Hold Player A another 60–90 seconds without resetting monitored values.

## 6. Analysis

For each continuous CharacterStat with enough movement:

```text
baseline rate = delta(metric) / real seconds during Phase A
partial rate  = delta(metric) / real seconds during Phase B
restored rate = delta(metric) / real seconds during Phase C
rate ratio    = partial rate / baseline rate
```

Compare the ratio to the **observed** compression factor:

```text
~1x                                -> simulation/real-time bound
~CalendarCompressionFactor        -> world/calendar-time bound
other                              -> mixed/nonlinear/event-driven
insufficient change / inaccessible -> unclassified
```

Moodles are ordinal corroboration only. Do not calculate pseudo-continuous rates from Moodle levels.

Compare server and owning-client values where both are readable. A server/client exposure difference is itself a useful result and should be recorded.

## 7. Minimum remaining go/no-go questions

Before Public Alpha deployment, answer as far as technically practical:

1. Does hunger accelerate materially with calendar compression?
2. Does thirst accelerate materially?
3. Does fatigue accelerate materially?
4. Is endurance affected in a way that makes awake play disruptive?
5. Do sickness/food-sickness/poison or zombie infection/fever become dangerous under partial compression?
6. Do temperature/wetness/cold effects create a high-severity hazard?
7. Does any observed acceleration require a lower initial `PartialSleepSpeedScale`, lower server fast-forward policy, warning, or targeted mitigation?

### Decision rule

**GO:** no unacceptable remaining high-severity awake-player effect.

**CONDITIONAL GO:** behavior is understood and can be safely bounded by configuration or a narrowly targeted validated mitigation.

**NO-GO:** partial sleep can unexpectedly cause rapid starvation/dehydration, infection death, temperature injury, or a comparable severe awake-player failure.

Record the decision in [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md).

## 8. Verbose diagnostics policy

Normal play:

```text
DiagnosticsEnabled=false
```

Controlled investigation:

```text
DiagnosticsEnabled=true
```

The diagnostic build can generate substantial logs. Keep sessions short and purposeful.

Collect:

```text
server console
server DebugLog/log ZIP
Player A client logs
Player B client logs when practical
```

## 9. Public Alpha field testing — after SPIKE-004 GO

Targets include:

- 3–12+ living players;
- multiple proportional sleeping fractions;
- joins/disconnects/deaths/respawns while compression is active;
- repeated sleep/wake cycles over long sessions;
- normal mod-stack interaction;
- non-health world-time systems such as spoilage, generators, crops, corpses, composting and weather.

## 10. Project Zomboid update regression

For a new B42 build:

1. Review release/API changes affecting `GameTime`, sleep, player lifecycle, `CharacterStat`, `MoodleType`, `Moodles`, `Nutrition` or BodyDamage.
2. Run Tier 1 smoke testing.
3. Run Tier 2 if relevant engine behavior changed.
4. Re-run focused survival testing only if the update plausibly changes those subsystems.
5. Update the validated platform baseline only after successful testing.

See [`ROADMAP.md`](ROADMAP.md) for phase-level criteria.
