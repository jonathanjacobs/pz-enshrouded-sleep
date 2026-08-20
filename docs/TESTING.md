# Enshrouded Sleep — Testing Guide

Current status: **Public Alpha candidate / pre-deployment validation**  
Current development version: `v0.0.10`  
Current behaviorally validated Project Zomboid baseline: `42.20.3`

Historical procedures/results are consolidated in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). The current blocking investigation is [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md).

## 1. Tier 1 — startup smoke test

Run after any source/configuration change or Project Zomboid update.

Minimum checks:

1. Game/server starts without Enshrouded Sleep Lua errors.
2. In multiplayer, clients start/connect without Enshrouded Sleep Lua errors.
3. Core controller loads.
4. Existing health/body diagnostics load without exceptions.
5. Focused survival diagnostic modules load without exceptions.
6. With no active compression, `MinutesPerDay` remains at native baseline.
7. With `DiagnosticsEnabled=false`, no one-second health/survival diagnostic stream is emitted.
8. With `DiagnosticForcedCompressionFactor=1.0`, the diagnostic test override is inactive.

## 2. Tier 2 — core multiplayer regression

Reference validated configuration:

```text
Baseline MinutesPerDay = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
PartialSleepSpeedScale = 1.0
DiagnosticsEnabled = false
DiagnosticForcedCompressionFactor = 1.0
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

When `DiagnosticsEnabled=true`, v0.0.10 uses current Build 42 access patterns through the shared `SurvivalStatProbe`:

```text
[EnshroudedSleepSurvivalDiag][SERVER] CAPABILITIES ...
[EnshroudedSleepSurvivalDiag][SERVER] SURVIVAL ...
[EnshroudedSleepSurvivalDiag][CLIENT] CAPABILITIES ...
[EnshroudedSleepSurvivalDiag][CLIENT] SURVIVAL ...
```

Continuous values are read through `Stats:get(CharacterStat)`, Moodles through `getMoodleLevel(MoodleType)`, and Nutrition through its native getters.

For standalone play, the server survival diagnostic falls back to `getPlayer()` if `getOnlinePlayers()` is absent or empty. The fallback injury stream is:

```text
[EnshroudedSleepStandaloneHealthDiag][SERVER]
```

It records overall health, injury counts and detailed active body-part bleeding/wound timers without requiring a multiplayer player collection.

## 5. v0.0.10 single-player SPIKE-004 test — CURRENT BLOCKER

The remaining health/survival time-domain question can now be tested with one awake character.

### Configuration

Start with:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

`DiagnosticForcedCompressionFactor` is test-only. It is ignored unless `DiagnosticsEnabled=true`.

With native baseline `MinutesPerDay=90`:

```text
factor 1 -> 90 min/day (inactive/baseline)
factor 5 -> 18 min/day
factor 10 -> 9 min/day
```

The diagnostic override does not call the global simulation multiplier.

### Safety behavior

If any observed living character sleeps while the forced factor is above `1`, the controller must:

1. suspend the diagnostic override;
2. restore native `MinutesPerDay`;
3. log `TEST OVERRIDE SUSPENDED`;
4. allow vanilla sleep behavior to own the sleeping state.

This prevents diagnostic forced compression from stacking with vanilla full-sleep acceleration.

### Phase A — baseline, 60–90 real seconds

1. Load one expendable/debug test character.
2. Keep `DiagnosticForcedCompressionFactor=1.0`.
3. Confirm baseline `MinutesPerDay`, expected around `90` on the reference setup.
4. Confirm the focused `CAPABILITIES` line reports readable CharacterStats/Moodles. If the useful counts are zero, stop and preserve logs.
5. Use Debug Mode to establish useful nonzero hunger, thirst, fatigue and other desired states.
6. Keep the character awake and relatively inactive for 60–90 seconds.
7. Do not eat, drink, sleep, exercise, medicate or manually reset monitored values during the measurement interval.

### Phase B — diagnostic forced compression, 60–90 real seconds

1. Without changing the monitored character state, set `DiagnosticForcedCompressionFactor=5.0` in the live sandbox/debug configuration.
2. Confirm the controller logs:

```text
TEST OVERRIDE ACTIVE
```

3. Confirm `MinutesPerDay` changes from approximately `90` to approximately `18`.
4. Confirm the character remains awake.
5. Confirm `TrueMultiplier`/global multiplier remains consistent with ordinary awake play.
6. Hold 60–90 seconds without resetting monitored survival values.

If the live sandbox UI does not apply the option immediately, preserve logs and use separate short baseline/forced runs with carefully matched starting conditions. One-session A/B/C remains preferred.

### Phase C — restored baseline, 60–90 real seconds

1. Return `DiagnosticForcedCompressionFactor=1.0`.
2. Confirm `MinutesPerDay` returns to baseline.
3. Hold another 60–90 seconds without resetting monitored state.

### Optional override-suspension safety test

Using an expendable character only, with factor >1 active, attempt to sleep briefly.

Expected:

```text
TEST OVERRIDE SUSPENDED
MinutesPerDay -> baseline
vanilla sleep owns the state
```

This safety check is separate from the rate-comparison experiment.

## 6. Analysis

For each continuous CharacterStat with enough movement:

```text
baseline rate = delta(metric) / real seconds during Phase A
forced rate   = delta(metric) / real seconds during Phase B
restored rate = delta(metric) / real seconds during Phase C
rate ratio    = forced rate / baseline rate
```

Compare against the **observed** compression factor:

```text
~1x                                -> simulation/real-time bound
~CalendarCompressionFactor        -> world/calendar-time bound
other                              -> mixed/nonlinear/event-driven
insufficient change / inaccessible -> unclassified
```

Moodles are ordinal corroboration only. Do not calculate pseudo-continuous rates from Moodle levels.

### Why the one-player result is relevant to multiplayer sleep

The remaining causal question is the effect of the same `MinutesPerDay` reduction on an **awake** character. The forced diagnostic mode changes that exact clock primitive while removing the second player's sleep as a confounder. It is therefore valid for time-domain classification.

It does **not** replace multiplayer controller/synchronization regression, which is tested separately in Tier 2 and Public Alpha.

## 7. Minimum remaining go/no-go questions

Before Public Alpha deployment, answer as far as technically practical:

1. Does hunger accelerate materially with calendar compression?
2. Does thirst accelerate materially?
3. Does fatigue accelerate materially?
4. Is endurance affected in a way that makes awake play disruptive?
5. Do sickness/food-sickness/poison or zombie infection/fever become dangerous under compression?
6. Do temperature/wetness/cold effects create a high-severity hazard?
7. Does any observed acceleration require a lower initial `PartialSleepSpeedScale`, lower server fast-forward policy, warning, or targeted mitigation?

### Decision rule

**GO:** no unacceptable remaining high-severity awake-player effect.

**CONDITIONAL GO:** behavior is understood and can be safely bounded by configuration or a narrowly targeted validated mitigation.

**NO-GO:** calendar compression can unexpectedly cause rapid starvation/dehydration, infection death, temperature injury, or a comparable severe awake-player failure.

Record the decision in [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md).

## 8. Verbose diagnostics policy

Normal play:

```text
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
```

Controlled investigation:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor=1.0 or explicit test value
```

The diagnostic build can generate substantial logs. Keep sessions short and purposeful.

Collect for the single-player test:

```text
console.txt / game console output
Logs ZIP / DebugLog
```

For multiplayer regressions, collect server console, server logs and relevant client logs.

## 9. Public Alpha field testing — after SPIKE-004 GO

Targets include:

- 3–12+ living players;
- multiple proportional sleeping fractions;
- joins/disconnects/deaths/respawns while compression is active;
- repeated sleep/wake cycles over long sessions;
- normal mod-stack interaction;
- non-health world-time systems such as spoilage, generators, crops, corpses, composting and weather.

Public Alpha must always use:

```text
DiagnosticForcedCompressionFactor=1.0
```

unless a deliberately controlled diagnostic session is being run.

## 10. Project Zomboid update regression

For a new B42 build:

1. Review release/API changes affecting `GameTime`, sleep, player lifecycle, `CharacterStat`, `MoodleType`, `Moodles`, `Nutrition` or BodyDamage.
2. Run Tier 1 smoke testing.
3. Run Tier 2 if relevant engine behavior changed.
4. Re-run focused survival testing only if the update plausibly changes those subsystems.
5. Update the validated platform baseline only after successful testing.

See [`ROADMAP.md`](ROADMAP.md) for phase-level criteria.
