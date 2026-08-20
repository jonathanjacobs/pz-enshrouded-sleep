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

- **simulation/real-time bound** — rate per real second remains approximately unchanged during compression;
- **world/calendar-time bound** — rate per real second scales approximately with `CalendarCompressionFactor`;
- **mixed/nonlinear** — rate changes but not proportionally;
- **event-driven** — useful change occurs only when another subsystem/event fires;
- **insufficient/unavailable** — the test or Lua exposure is not adequate to classify the value.

No compensation should be implemented from assumption alone.

## Instrumentation

Existing broad health/body diagnostics remain available when `DiagnosticsEnabled=true`:

```text
42/media/lua/server/EnshroudedSleep/HealthTimeDomainDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/HealthTimeDomainDiagnostic_Client.lua
```

v0.0.10 adds the focused Build 42 survival-state path:

```text
42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
42/media/lua/server/EnshroudedSleep/SurvivalStatDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/SurvivalStatDiagnostic_Client.lua
42/media/lua/server/EnshroudedSleep/StandaloneHealthDiagnostic_Server.lua
```

Focused prefixes:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
[EnshroudedSleepStandaloneHealthDiag][SERVER]
```

All instrumentation is read-only. The standalone bridge activates only when diagnostics are enabled and no populated online-player collection is visible; it uses `getPlayer()` to preserve detailed health/injury observability in a standalone game.

## Build 42.20.3 survival-state API correction

Current vanilla Build 42 Lua reads registered continuous survival values through `Stats:get(CharacterStat)`:

```lua
local stats = player:getStats()
local hunger = stats:get(CharacterStat.HUNGER)
local thirst = stats:get(CharacterStat.THIRST)
local fatigue = stats:get(CharacterStat.FATIGUE)
local endurance = stats:get(CharacterStat.ENDURANCE)
local stress = stats:get(CharacterStat.STRESS)
local panic = stats:get(CharacterStat.PANIC)
local pain = stats:get(CharacterStat.PAIN)
```

The focused probe also covers boredom, unhappiness, sickness, food sickness, poison, zombie infection/fever, temperature, wetness, fitness, morale, intoxication, discomfort and other registered CharacterStats.

Moodles are keyed by `MoodleType` objects:

```lua
player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
```

Nutrition remains directly available through `player:getNutrition()`.

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

**Classification:** awake active bleeding health loss and the measured bleeding/scratch progression are simulation/real-time bound under the tested partial-compression conditions.

**Safety consequence:** the feared rapid awake-player bleed-out proportional to calendar compression was not observed.

### Nutrition — world/calendar bound

| Metric | Baseline rate | ~5x partial rate | Ratio | ~10x partial rate | Ratio | Classification |
|---|---:|---:|---:|---:|---:|---|
| Calories | -0.2583/s | -1.2928/s | **5.01x** | -2.5886/s | **10.00x** | world/calendar-time bound |
| Carbohydrates | -0.05597/s | -0.27987/s | **5.00x** | -0.55972/s | **10.00x** | world/calendar-time bound |
| Proteins | -0.01374/s | -0.06877/s | **5.00x** | -0.13753/s | **10.01x** | world/calendar-time bound |
| Lipids | -0.01807/s | -0.09036/s | **5.00x** | -0.18071/s | **10.00x** | world/calendar-time bound |

The v0.0.9 run did not classify hunger, thirst, fatigue, endurance and several related states because its legacy Stats/Moodle access assumptions were wrong for current Build 42.20.3. That observability gap is what v0.0.10 addresses.

## Current results table

| Metric / subsystem | Baseline rate | Compressed rate | Rate ratio | Classification | Safety consequence |
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
| Calories | -0.2583/s | -1.2928/s at 5x | 5.01x | world/calendar-time bound | expected faster metabolism during compression |
| Carbohydrates | -0.05597/s | -0.27987/s at 5x | 5.00x | world/calendar-time bound | same |
| Proteins | -0.01374/s | -0.06877/s at 5x | 5.00x | world/calendar-time bound | same |
| Lipids | -0.01807/s | -0.09036/s at 5x | 5.00x | world/calendar-time bound | same |

## v0.0.10 preferred decisive follow-up — single-player forced compression

The remaining question is the effect of a shorter `MinutesPerDay` on an **awake** character. A second sleeper is not required to isolate that causal variable.

v0.0.10 therefore adds a diagnostic-only controller path:

```text
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
```

When active, the controller applies:

```text
EffectiveMinutesPerDay = BaselineMinutesPerDay / DiagnosticForcedCompressionFactor
```

without changing the global simulation multiplier and without placing the character to sleep.

### Safety invariants

- default factor is `1.0`, which is inactive;
- the override cannot activate unless verbose diagnostics are also enabled;
- the controller clamps the test factor to a maximum of `20`;
- if **any observed living player sleeps**, the forced override is suspended and native baseline is restored;
- disabling diagnostics or returning the factor to `1.0` restores normal policy;
- this mode is not part of normal Public Alpha gameplay.

### Preferred test configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

Use one awake Debug-mode character.

### Phase A — baseline, 60–90 real seconds

1. Start with `DiagnosticForcedCompressionFactor=1.0`.
2. Confirm native `MinutesPerDay=90` and normal multiplier context.
3. Inspect the focused `CAPABILITIES` record. If CharacterStats are not readable, preserve logs before continuing.
4. Establish useful nonzero hunger, thirst, fatigue and other target states using Debug Mode.
5. Keep the character awake and relatively inactive for 60–90 seconds.

### Phase B — forced calendar compression, 60–90 real seconds

1. Without sleeping or resetting the monitored state, change `DiagnosticForcedCompressionFactor` to `5.0` in the live sandbox/debug configuration.
2. Confirm the controller logs `TEST OVERRIDE ACTIVE`.
3. Confirm `MinutesPerDay` changes from `90` to approximately `18`.
4. Confirm global/true multiplier remains consistent with ordinary awake play.
5. Hold the awake character relatively still for 60–90 seconds.
6. Do not eat, drink, sleep, exercise, medicate or manually reset monitored values unless required for safety.

### Phase C — restored baseline, 60–90 real seconds

1. Return `DiagnosticForcedCompressionFactor` to `1.0`.
2. Confirm `MinutesPerDay=90` is restored.
3. Hold another 60–90 seconds without resetting monitored values.

If live sandbox editing proves unavailable in the tested single-player UI, the same three phases may be collected as separate short runs with identical controlled starting conditions; one-session A/B/C is preferred because it reduces between-run confounding.

### Optional safety check

While the forced factor is above `1`, briefly attempt to sleep only if doing so is safe for the expendable test character. Expected behavior is immediate baseline restoration and a `TEST OVERRIDE SUSPENDED` state before vanilla sleep acceleration proceeds. This is an implementation safety check, not part of the survival-rate comparison.

## Analysis

For each numeric CharacterStat with enough movement:

```text
baseline rate = delta(metric) / real seconds
forced rate   = delta(metric) / real seconds
restored rate = delta(metric) / real seconds
rate ratio    = forced rate / baseline rate
```

Compare against the **observed** `CalendarCompressionFactor`, not merely the configured test factor.

Moodle levels remain ordinal corroboration, not substitutes for continuous CharacterStat values.

### Why this single-player test is valid

The causal question remaining in SPIKE-004 is whether changing `MinutesPerDay` changes an awake character's survival-state rates. The diagnostic override changes that same clock primitive while keeping the character awake and leaving the global simulation multiplier untouched. It therefore isolates the time-domain question more cleanly than requiring a second sleeping character.

This does **not** replace normal multiplayer regression. It replaces only the remaining health/survival time-domain experiment.

## Go / no-go criteria

### GO for WHG Public Alpha

Proceed if no remaining high-severity awake-player survival effect becomes dangerously accelerated, or if accelerated behavior is understood and acceptable for alpha use.

### CONDITIONAL GO

Proceed with a lower `PartialSleepSpeedScale`, a lower server fast-forward policy, warnings, or a narrowly targeted validated mitigation if an accelerated system can be bounded safely.

### NO-GO

Do not deploy publicly if partial sleep can unexpectedly cause rapid starvation/dehydration, infection death, temperature injury, or another comparable high-severity awake-player failure before mitigation.

## Outputs still required

1. v0.0.10 CharacterStat/Moodle capability validation in the single-player diagnostic path;
2. baseline → forced-compression → restored-baseline survival telemetry;
3. classification of hunger/thirst/fatigue/endurance and other practical high-severity metrics;
4. final Public Alpha GO / CONDITIONAL GO / NO-GO decision;
5. ADR only if results require a new architectural policy or compensation mechanism;
6. final requirements/roadmap/deployment/validation/changelog update.

## Current decision

**Public Alpha remains paused.** The v0.0.9 run passed the acute awake-bleeding safety question and proved nutrition stores are world/calendar-time bound. v0.0.10 now allows the remaining survival-state classification to be completed with one awake single-player/debug character rather than requiring a second computer.
