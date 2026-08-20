# Enshrouded Sleep — Testing Guide

Current status: **Public Alpha candidate / pre-deployment validation**  
Current development version: `v0.0.10`  
Current behaviorally validated Project Zomboid baseline: `42.20.3`

Enshrouded Sleep is a **multiplayer-server mod**. The procedures below assume a Project Zomboid server and connected client(s); local/standalone single-player is not a supported test/runtime target.

Historical procedures/results are consolidated in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). The current blocking investigation is [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md).

## 1. Tier 1 — startup smoke test

Run after any source/configuration change or Project Zomboid update.

Minimum checks:

1. Server starts without Enshrouded Sleep Lua errors.
2. Client(s) connect without Enshrouded Sleep Lua errors.
3. Core controller and client clock synchronization load.
4. Health/body and focused survival diagnostics load without exceptions.
5. With all connected players awake and no test override, `MinutesPerDay` remains at native baseline.
6. With `DiagnosticsEnabled=false`, no one-second diagnostic stream is emitted.
7. With `DiagnosticForcedCompressionFactor=1.0`, the diagnostic test override is inactive.

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

The exact v0.0.7 build passed this sequence on PZ 42.20.3. v0.0.9 also validated `90 -> 18 -> 90` and `90 -> 9 -> 90` during SPIKE-004.

## 3. SPIKE-004 evidence already established

The v0.0.9 controlled run established:

- awake active-bleeding health loss remained approximately `1x` real-time rate under ~5x calendar compression;
- measured `BleedingTime` and `ScratchTime` remained approximately `1x`;
- calories, carbohydrates, proteins and lipids scaled almost exactly with 5x and 10x calendar compression;
- `TrueMultiplier` remained `1.0` during partial compression;
- client/server `MinutesPerDay` synchronization and restoration remained correct.

The remaining test exists because v0.0.9 used outdated survival-stat/Moodle access assumptions and still reported `N/A` for hunger, thirst, fatigue, endurance and related values.

## 4. v0.0.10 corrected survival-state instrumentation

With `DiagnosticsEnabled=true`, v0.0.10 adds:

```text
[EnshroudedSleepSurvivalDiag][SERVER] CAPABILITIES ...
[EnshroudedSleepSurvivalDiag][SERVER] SURVIVAL ...
[EnshroudedSleepSurvivalDiag][CLIENT] CAPABILITIES ...
[EnshroudedSleepSurvivalDiag][CLIENT] SURVIVAL ...
```

Continuous values use `Stats:get(CharacterStat)`, Moodles use `getMoodleLevel(MoodleType)`, and Nutrition uses native getters. The server sampler observes only living multiplayer players in `getOnlinePlayers()`.

## 5. v0.0.10 one-connected-player server test — CURRENT BLOCKER

Use a normal multiplayer test server with **exactly one living player connected**.

Start with:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

`DiagnosticForcedCompressionFactor` is server-test-only and ignored unless diagnostics are enabled.

For a native baseline of `MinutesPerDay=90`:

```text
factor 1 -> 90 min/day
factor 5 -> 18 min/day
factor 10 -> 9 min/day
```

The forced test does not call the global simulation multiplier.

### Activation/safety contract

The override may compress only when:

```text
living = 1
sleeping = 0
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
```

Expected safety behavior:

```text
player sleeps        -> restore baseline; suspend override
second player joins  -> restore baseline; suspend override
no players connected -> retain baseline; override remains armed
factor returns to 1  -> normal server policy resumes
```

While a factor above `1` is armed, ordinary proportional-sleep policy is suppressed so the diagnostic run cannot mix with a real multiplayer partial-sleep state.

### Phase A — baseline, 60–90 real seconds

1. Start the multiplayer server.
2. Connect exactly one expendable/debug player.
3. Keep `DiagnosticForcedCompressionFactor=1.0`.
4. Confirm server/client baseline `MinutesPerDay` (reference setup: `90`).
5. Confirm the focused `CAPABILITIES` line reports useful CharacterStat/Moodle access. If not, stop and preserve logs.
6. Use Debug Mode to establish useful nonzero hunger, thirst, fatigue and other desired states.
7. Keep the player awake and relatively inactive for 60–90 seconds.
8. Do not eat, drink, sleep, exercise, medicate or manually reset monitored values during the measurement interval.

### Phase B — diagnostic forced compression, 60–90 real seconds

1. Keep the same single player connected and awake.
2. Change `DiagnosticForcedCompressionFactor=5.0` using server/admin sandbox controls.
3. Confirm the server logs:

```text
TEST OVERRIDE ACTIVE
living=1
sleeping=0
```

4. Confirm server/client `MinutesPerDay` changes from approximately `90` to `18`.
5. Confirm `TrueMultiplier`/global multiplier remains consistent with ordinary awake play.
6. Hold 60–90 seconds without resetting monitored values.

### Phase C — restored baseline, 60–90 real seconds

1. Return `DiagnosticForcedCompressionFactor=1.0`.
2. Confirm authoritative and client `MinutesPerDay` return to baseline.
3. Hold another 60–90 seconds without resetting monitored state.

### Optional override-suspension checks

Using expendable test characters only:

- while factor >1 is active, put the connected player to sleep; expect `TEST OVERRIDE SUSPENDED` and baseline restoration;
- while factor >1 is active, connect a second living player; expect `TEST OVERRIDE SUSPENDED` and baseline restoration.

These checks are separate from the survival-rate comparison.

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
~1x                         -> simulation/real-time bound
~CalendarCompressionFactor -> world/calendar-time bound
other                       -> mixed/nonlinear/event-driven
insufficient/inaccessible   -> unclassified
```

Moodles are ordinal corroboration only.

### Why this is relevant to real partial sleep

The diagnostic test changes the same server-authoritative `MinutesPerDay` primitive used during real partial sleep while keeping the connected player awake, retaining the multiplayer server/client synchronization path, and leaving the global simulation multiplier untouched. This isolates the remaining time-domain question without needing a second computer.

It does **not** replace Tier 2 multiplayer sleep regression.

## 7. Minimum remaining go/no-go questions

Before Public Alpha deployment, classify as far as technically practical:

1. hunger;
2. thirst;
3. fatigue;
4. endurance;
5. sickness/food sickness/poison and zombie infection/fever where practical;
6. temperature/wetness/cold effects where practical;
7. whether any observed acceleration requires a lower initial sleep-compression policy or targeted mitigation.

**GO:** no unacceptable remaining high-severity awake-player effect.  
**CONDITIONAL GO:** behavior is understood and safely bounded.  
**NO-GO:** calendar compression can unexpectedly cause rapid starvation/dehydration, infection death, temperature injury, or comparable severe failure.

## 8. Verbose diagnostics policy

Normal play:

```text
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
```

Controlled one-player server test:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor=1.0 -> 5.0 -> 1.0
```

Collect:

```text
server console
server Logs/DebugLog
connected test player's client Logs/DebugLog
```

## 9. Public Alpha field testing — after SPIKE-004 GO

Targets include 3–12+ living players, multiple sleeping fractions, joins/disconnects/deaths/respawns, repeated sleep/wake cycles, long-session stability, normal mod-stack interaction, and non-health world-time systems such as spoilage, generators, crops, corpses, composting and weather.

Public Alpha must normally use `DiagnosticForcedCompressionFactor=1.0`.

## 10. Project Zomboid update regression

For a new B42 build, review relevant `GameTime`, sleep/lifecycle, `CharacterStat`, `MoodleType`, `Nutrition` and BodyDamage changes; run Tier 1; run Tier 2 if engine behavior changed; and re-run focused survival testing only when relevant.

See [`ROADMAP.md`](ROADMAP.md) for phase criteria.
