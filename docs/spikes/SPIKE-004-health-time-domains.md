# SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression

Status: **In progress / Public Alpha deployment blocker**  
Current implementation target: **v0.0.10**  
Primary test platform: Project Zomboid **42.20.3**  
Tracking issue: **GitHub #4** — `SPIKE-004: characterize player health/survival time domains under partial sleep`

## Question

When Enshrouded Sleep shortens `MinutesPerDay`, which player health/survival systems accelerate in real time with compressed world/calendar time, and which remain tied to ordinary active-simulation/real time?

## Why this blocks Public Alpha

The sleep/clock architecture is validated, but Project Zomboid subsystems do not necessarily share one time domain. A world-time-bound survival variable may advance several times faster in real time while another player sleeps even though movement, combat, vehicles, animations and other active simulation remain normal-speed.

The deployment gate is therefore evidence-based: classify high-severity awake-player effects before normal public-server characters are exposed to partial calendar compression.

## Classification model

- **simulation/real-time bound** — rate per real second remains approximately unchanged during partial compression;
- **world/calendar-time bound** — rate per real second scales approximately with `CalendarCompressionFactor`;
- **mixed/nonlinear** — rate changes but not proportionally;
- **event-driven** — useful change occurs only when another subsystem/event fires;
- **insufficient/unavailable** — the test or Lua exposure is not adequate to classify the value.

No compensation should be implemented from assumption alone.

## Instrumentation

The existing broad health/body diagnostics remain active when `DiagnosticsEnabled=true`:

```text
42/media/lua/server/EnshroudedSleep/HealthTimeDomainDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/HealthTimeDomainDiagnostic_Client.lua
```

v0.0.10 adds a focused Build 42 survival-state path:

```text
42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
42/media/lua/server/EnshroudedSleep/SurvivalStatDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/SurvivalStatDiagnostic_Client.lua
```

The new stream uses:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

and emits one-time `CAPABILITIES` lines plus one-second `SURVIVAL` samples.

All instrumentation is read-only.

## Build 42.20.3 API correction discovered after v0.0.9

The v0.0.9 test still returned `N/A` for hunger, thirst, fatigue, endurance and many related stats, and its Moodle fallback also returned `N/A`.

Review of current vanilla Build 42 Lua and the decompiled 42.20.3 classes identified the cause.

### Continuous survival values

Current vanilla Lua reads registered CharacterStats through `Stats:get(CharacterStat)`:

```lua
local stats = player:getStats()

local hunger = stats:get(CharacterStat.HUNGER)
local thirst = stats:get(CharacterStat.THIRST)
local fatigue = stats:get(CharacterStat.FATIGUE)
local endurance = stats:get(CharacterStat.ENDURANCE)
local stress = stats:get(CharacterStat.STRESS)
local panic = stats:get(CharacterStat.PANIC)
local pain = stats:get(CharacterStat.PAIN)
local boredom = stats:get(CharacterStat.BOREDOM)
local unhappiness = stats:get(CharacterStat.UNHAPPINESS)
local sickness = stats:get(CharacterStat.SICKNESS)
local foodSickness = stats:get(CharacterStat.FOOD_SICKNESS)
local poison = stats:get(CharacterStat.POISON)
local zombieInfection = stats:get(CharacterStat.ZOMBIE_INFECTION)
local zombieFever = stats:get(CharacterStat.ZOMBIE_FEVER)
local temperature = stats:get(CharacterStat.TEMPERATURE)
local wetness = stats:get(CharacterStat.WETNESS)
```

The `CharacterStat` class is marked `@UsedFromLua` and registers these values explicitly. v0.0.10 also probes additional registered stats useful for context: fitness, intoxication, anger, morale, nicotine withdrawal, idleness, sanity and discomfort.

### Moodles

Build 42.20.3 `Moodles` stores moodles in a map keyed by `MoodleType`; its Lua-facing getter is:

```lua
player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
```

The v0.0.9 assumption that Moodles could be enumerated using `getNumMoodles()`, `getMoodleType(i)` and `getMoodleLevel(i)` does not match the current 42.20.3 class.

v0.0.10 therefore directly probes the registered MoodleType constants, including:

```lua
MoodleType.ENDURANCE
MoodleType.TIRED
MoodleType.HUNGRY
MoodleType.PANIC
MoodleType.SICK
MoodleType.BORED
MoodleType.UNHAPPY
MoodleType.BLEEDING
MoodleType.WET
MoodleType.HAS_A_COLD
MoodleType.ANGRY
MoodleType.STRESS
MoodleType.THIRST
MoodleType.INJURED
MoodleType.PAIN
MoodleType.HEAVY_LOAD
MoodleType.DRUNK
MoodleType.ZOMBIE
MoodleType.HYPERTHERMIA
MoodleType.HYPOTHERMIA
MoodleType.WINDCHILL
MoodleType.CANT_SPRINT
MoodleType.UNCOMFORTABLE
MoodleType.NOXIOUS_SMELL
MoodleType.FOOD_EATEN
```

### Nutrition

Nutrition remains directly available through `player:getNutrition()`:

```lua
nutrition:getWeight()
nutrition:getCalories()
nutrition:getCarbohydrates()
nutrition:getProteins()
nutrition:getLipids()
nutrition:isIncWeight()
nutrition:isIncWeightLot()
nutrition:isDecWeight()
nutrition:characterHaveWeightTrouble()
nutrition:canAddFitnessXp()
```

The 42.20.3 decompiled `Nutrition.update()` also explains the v0.0.9 result mechanistically: carbohydrates, proteins, lipids, calories and weight updates use `GameTime.getInstance().getGameWorldSecondsSinceLastUpdate()`, so their rates can follow accelerated world/calendar progression.

## v0.0.8 solo vanilla-full-sleep reference

The initial health diagnostic run established a useful vanilla reference but was not a partial-sleep test.

A character with four active bleeding injuries entered solo vanilla full sleep at roughly `81.16` health. Successive approximately one-second samples fell roughly:

```text
69.68 -> 47.74 -> 25.83 -> 6.03 -> 0
```

The character died within about five real seconds. A later healing sleep also showed strongly accelerated recovery/timers.

Because Enshrouded Sleep had restored `MinutesPerDay=90` and vanilla all-asleep fast-forward owned the state, this result did not classify awake-player partial compression.

## v0.0.9 two-player controlled result — 2026-08-19

The v0.0.9 run included native baseline, approximately 5x partial compression (`MinutesPerDay=18`), restored baseline, and a later approximately 10x partial interval (`MinutesPerDay=9`). `TrueMultiplier` remained `1.0` during partial compression and server/client day-length synchronization behaved correctly.

### Awake bleeding/injury — PASS

During the clean comparable interval:

```text
Overall health loss while actively bleeding
baseline:   ~-0.07869 health / real second
5x partial: ~-0.07810 health / real second
ratio:      ~0.993x
```

Detailed wound timers corroborated the result:

```text
Hand_R BleedingTime
baseline:   ~-0.000959 / sec
5x partial: ~-0.000960 / sec
ratio:      ~1.00x

Hand_R ScratchTime
baseline:   ~-0.000477 / sec
5x partial: ~-0.000477 / sec
ratio:      ~1.00x
```

Other injured-part telemetry showed the same qualitative behavior.

**Classification:** awake active bleeding health loss and the measured bleeding/scratch progression are simulation/real-time bound under the tested partial-compression conditions.

**Safety consequence:** the feared rapid awake-player bleed-out proportional to calendar compression was not observed.

### Nutrition — world/calendar bound

The nutrition signal was exceptionally clean:

| Metric | Baseline rate | ~5x partial rate | Ratio | ~10x partial rate | Ratio | Classification |
|---|---:|---:|---:|---:|---:|---|
| Calories | -0.2583/s | -1.2928/s | **5.01x** | -2.5886/s | **10.00x** | world/calendar-time bound |
| Carbohydrates | -0.05597/s | -0.27987/s | **5.00x** | -0.55972/s | **10.00x** | world/calendar-time bound |
| Proteins | -0.01374/s | -0.06877/s | **5.00x** | -0.13753/s | **10.01x** | world/calendar-time bound |
| Lipids | -0.01807/s | -0.09036/s | **5.00x** | -0.18071/s | **10.00x** | world/calendar-time bound |

Weight moved in the expected direction but the interval was too short/noisy for the same confidence in an exact multiplier.

### v0.0.9 telemetry gap

The controlled test did **not** classify hunger, thirst, fatigue, endurance, stress, panic, general pain, sickness and several related values because the legacy getter/public-field probes remained unavailable and the numeric Moodle enumeration assumption was wrong for Build 42.20.3.

That gap, rather than bleeding, is now the reason SPIKE-004 remains open.

## Current results table

| Metric / subsystem | Baseline rate | Partial rate | Rate ratio | Classification | Safety consequence |
|---|---:|---:|---:|---|---|
| Overall health loss while bleeding | ~-0.07869/s | ~-0.07810/s at 5x | ~0.993x | simulation/real-time bound | PASS; no accelerated awake bleed-out observed |
| BleedingTime | ~-0.000959/s | ~-0.000960/s at 5x | ~1.00x | simulation/real-time bound | PASS |
| ScratchTime | ~-0.000477/s | ~-0.000477/s at 5x | ~1.00x | simulation/real-time bound | PASS |
| Hunger / Hungry Moodle | pending v0.0.10 | pending | pending | unclassified | deployment gate remains open |
| Thirst / Thirst Moodle | pending v0.0.10 | pending | pending | unclassified | deployment gate remains open |
| Fatigue / Tired Moodle | pending v0.0.10 | pending | pending | unclassified | deployment gate remains open |
| Endurance / Endurance Moodle | pending v0.0.10 | pending | pending | unclassified | deployment gate remains open |
| Stress / Panic / Pain | pending v0.0.10 | pending | pending | unclassified | characterize if measurable |
| Sickness / FoodSickness / Poison | pending v0.0.10 | pending | pending | unclassified | high-value if practical |
| Zombie infection/fever | pending v0.0.10 | pending | pending | unclassified | high-severity if practical |
| Temperature / wetness / cold | pending v0.0.10 | pending | pending | unclassified | characterize if practical |
| Calories | -0.2583/s | -1.2928/s at 5x | 5.01x | world/calendar-time bound | expected faster metabolism during partial compression |
| Carbohydrates | -0.05597/s | -0.27987/s at 5x | 5.00x | world/calendar-time bound | same |
| Proteins | -0.01374/s | -0.06877/s at 5x | 5.00x | world/calendar-time bound | same |
| Lipids | -0.01807/s | -0.09036/s at 5x | 5.00x | world/calendar-time bound | same |

## v0.0.10 decisive follow-up test

There is no need to recreate the bleeding experiment unless a regression appears.

Use two players with native `FastForwardMultiplier=10` and `DiagnosticsEnabled=true`.

### Phase A — baseline

1. Both players awake.
2. Confirm `MinutesPerDay=90`.
3. Confirm the new server/client `CAPABILITIES` lines report readable CharacterStats and Moodles.
4. Use Debug Mode to establish nonzero hunger, thirst, fatigue and any other target states without placing the monitored character at immediate risk.
5. Keep the monitored player awake and relatively inactive for 60–90 real seconds.

### Phase B — partial compression

1. Keep Player A awake and unchanged.
2. Put Player B to sleep.
3. Confirm `2 living / 1 sleeping`, approximately factor `5`, and `MinutesPerDay=18`.
4. Hold 60–90 real seconds.
5. Do not eat, drink, sleep, exercise, medicate or otherwise reset monitored state during the interval unless required for safety.

### Phase C — restored baseline

1. Wake Player B.
2. Confirm server/client `MinutesPerDay=90`.
3. Hold another 60–90 seconds.

For each numeric CharacterStat with enough movement:

```text
baseline rate = delta(metric) / real seconds
partial rate  = delta(metric) / real seconds
rate ratio    = partial rate / baseline rate
```

Compare against the **observed** compression factor.

Moodle levels remain ordinal corroboration, not substitutes for continuous CharacterStat values.

## Go / no-go criteria

### GO for WHG Public Alpha

Proceed if no remaining high-severity awake-player survival effect becomes dangerously accelerated, or if accelerated behavior is understood and acceptable for alpha use.

### CONDITIONAL GO

Proceed with a lower `PartialSleepSpeedScale`, a lower server fast-forward policy, warnings, or a narrowly targeted validated mitigation if an accelerated system can be bounded safely.

### NO-GO

Do not deploy publicly if partial sleep can unexpectedly cause rapid starvation/dehydration, infection death, temperature injury, or another comparable high-severity awake-player failure before mitigation.

## Outputs still required

1. v0.0.10 CharacterStat/Moodle capability validation;
2. classification of hunger/thirst/fatigue/endurance and other practical high-severity metrics;
3. final Public Alpha GO / CONDITIONAL GO / NO-GO decision;
4. ADR only if results require a new architectural policy or compensation mechanism;
5. final requirements/roadmap/deployment/validation/changelog update.

## Current decision

**Public Alpha remains paused.** The v0.0.9 run passed the acute awake-bleeding safety question and proved nutrition stores are world/calendar-time bound. The remaining blocker is the focused v0.0.10 classification of survival variables that v0.0.9 could not observe through the outdated access paths.
