# SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression

Status: **In progress / Public Alpha deployment blocker**  
Current implementation target: **v0.0.10**  
Primary test platform: Project Zomboid **42.20.3**  
Tracking issue: **GitHub #4**

## Question

When Enshrouded Sleep shortens `MinutesPerDay`, which awake-player health/survival systems accelerate in real time with compressed world/calendar time, and which remain tied to ordinary active-simulation/real time?

## Scope

Enshrouded Sleep is a **multiplayer-server mod**. This spike does not test or support local/standalone single-player gameplay.

The remaining v0.0.10 experiment uses a normal multiplayer server with **exactly one living player connected**. A diagnostics-only server override temporarily reproduces the same `MinutesPerDay` compression used during real partial sleep while keeping that connected player awake.

## Classification model

- **simulation/real-time bound** — rate per real second remains approximately unchanged during compression;
- **world/calendar-time bound** — rate per real second scales approximately with `CalendarCompressionFactor`;
- **mixed/nonlinear** — rate changes but not proportionally;
- **event-driven** — change depends on another subsystem/event;
- **insufficient/unavailable** — telemetry is not adequate to classify the value.

No compensation should be implemented from assumption alone.

## Instrumentation

Broad health/body diagnostics:

```text
42/media/lua/server/EnshroudedSleep/HealthTimeDomainDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/HealthTimeDomainDiagnostic_Client.lua
```

Focused v0.0.10 survival-state path:

```text
42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
42/media/lua/server/EnshroudedSleep/SurvivalStatDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/SurvivalStatDiagnostic_Client.lua
```

Focused prefixes:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

The server diagnostics observe only instantiated multiplayer server players returned by `getOnlinePlayers()`.

## Build 42.20.3 survival-state API correction

Current Build 42 vanilla Lua reads continuous survival values through registered `CharacterStat` objects:

```lua
local stats = player:getStats()
local hunger = stats:get(CharacterStat.HUNGER)
local thirst = stats:get(CharacterStat.THIRST)
local fatigue = stats:get(CharacterStat.FATIGUE)
local endurance = stats:get(CharacterStat.ENDURANCE)
```

Moodles are keyed by `MoodleType` objects:

```lua
player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
```

Nutrition remains directly available through `player:getNutrition()`.

## v0.0.8 vanilla-full-sleep reference

A deliberately injured character entered full sleep while it was the only living server player. Enshrouded Sleep restored `MinutesPerDay=90`; vanilla full-sleep acceleration owned the interval.

Health fell approximately:

```text
81.16 -> 69.68 -> 47.74 -> 25.83 -> 6.03 -> 0
```

This demonstrated strong vanilla sleep acceleration of health/recovery but did not classify awake partial compression.

## v0.0.9 two-player result — 2026-08-19

The controlled multiplayer run included baseline, approximately 5x partial compression (`MinutesPerDay=18`), restored baseline, and a later approximately 10x interval (`MinutesPerDay=9`). `TrueMultiplier` remained `1.0` during partial compression.

### Awake bleeding/injury — PASS

```text
Overall health loss while actively bleeding
baseline:   ~-0.07869 health / real second
5x partial: ~-0.07810 health / real second
ratio:      ~0.993x
```

Measured `BleedingTime` and `ScratchTime` progression remained approximately `1x`.

**Classification:** measured awake bleeding/injury progression is simulation/real-time bound under the tested conditions.

**Safety consequence:** rapid awake-player bleed-out proportional to calendar compression was not observed.

### Nutrition — world/calendar bound

| Metric | Baseline rate | ~5x partial | Ratio | ~10x partial | Ratio |
|---|---:|---:|---:|---:|---:|
| Calories | -0.2583/s | -1.2928/s | 5.01x | -2.5886/s | 10.00x |
| Carbohydrates | -0.05597/s | -0.27987/s | 5.00x | -0.55972/s | 10.00x |
| Proteins | -0.01374/s | -0.06877/s | 5.00x | -0.13753/s | 10.01x |
| Lipids | -0.01807/s | -0.09036/s | 5.00x | -0.18071/s | 10.00x |

**Classification:** core nutrition stores are world/calendar-time bound.

## Current results table

| Metric / subsystem | Result | Classification | Safety consequence |
|---|---|---|---|
| Overall health loss while bleeding | ~0.993x at 5x compression | simulation/real-time bound | PASS |
| BleedingTime | ~1x | simulation/real-time bound | PASS |
| ScratchTime | ~1x | simulation/real-time bound | PASS |
| Hunger / Hungry Moodle | pending v0.0.10 | unclassified | blocker |
| Thirst / Thirst Moodle | pending v0.0.10 | unclassified | blocker |
| Fatigue / Tired Moodle | pending v0.0.10 | unclassified | blocker |
| Endurance / Endurance Moodle | pending v0.0.10 | unclassified | blocker |
| Stress / Panic / Pain | pending v0.0.10 | unclassified | characterize if measurable |
| Sickness / FoodSickness / Poison | pending v0.0.10 | unclassified | high-value if practical |
| Zombie infection/fever | pending v0.0.10 | unclassified | high-severity if practical |
| Temperature / wetness / cold | pending v0.0.10 | unclassified | characterize if practical |
| Calories | 5.01x at 5x; 10.00x at 10x | world/calendar bound | expected faster metabolism |
| Carbohydrates | 5.00x / 10.00x | world/calendar bound | same |
| Proteins | 5.00x / 10.01x | world/calendar bound | same |
| Lipids | 5.00x / 10.00x | world/calendar bound | same |

## v0.0.10 diagnostic-forced server mode

The remaining causal question is the effect of `MinutesPerDay` on an **awake connected multiplayer player**. v0.0.10 adds:

```text
DiagnosticForcedCompressionFactor
```

Activation requires all of the following:

```text
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
exactly one living player connected to the server
sleeping = 0
```

When active:

```text
mode = diagnostic-forced
EffectiveMinutesPerDay = BaselineMinutesPerDay / DiagnosticForcedCompressionFactor
```

The controller does not call `GameTime:setMultiplier()`.

### Safety invariants

- factor `1.0` is inactive;
- factor is bounded to `1`–`20`;
- if the connected player sleeps, baseline is restored and the override is suspended;
- if a second living player connects, baseline is restored and the override is suspended;
- if no living player is connected, baseline is retained and the override remains armed;
- disabling diagnostics or returning factor to `1.0` returns to normal server policy;
- while the forced factor is armed, ordinary proportional sleep behavior is suppressed to keep the experiment isolated;
- server/client clock synchronization preserves the authoritative `diagnostic-forced` `MinutesPerDay`.

## Preferred v0.0.10 test

Run a normal multiplayer test server with exactly one connected Debug-mode player.

Start with:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

### Phase A — baseline, 60–90 real seconds

1. Exactly one living player connected; player remains awake.
2. `DiagnosticForcedCompressionFactor=1.0`.
3. Confirm baseline `MinutesPerDay` (reference setup: `90`).
4. Confirm `CAPABILITIES` shows usable CharacterStat/Moodle access.
5. Establish useful nonzero hunger, thirst, fatigue and other target states with Debug Mode.
6. Keep the player relatively inactive for 60–90 seconds.

### Phase B — forced compression, 60–90 real seconds

1. Keep the same player connected and awake.
2. Change `DiagnosticForcedCompressionFactor=5.0` using server/admin sandbox controls.
3. Confirm:

```text
TEST OVERRIDE ACTIVE
living=1
sleeping=0
MinutesPerDay≈18   (for baseline 90)
```

4. Confirm `TrueMultiplier`/global multiplier remains ordinary.
5. Hold 60–90 seconds without eating, drinking, sleeping, exercising, medicating or resetting monitored values unless needed for safety.

### Phase C — restored baseline, 60–90 real seconds

1. Return `DiagnosticForcedCompressionFactor=1.0`.
2. Confirm authoritative and client `MinutesPerDay` return to baseline.
3. Hold another 60–90 seconds.

### Optional safety checks

With factor >1 armed:

- if the connected player sleeps, expect `TEST OVERRIDE SUSPENDED` and baseline restoration;
- if a second living player connects, expect `TEST OVERRIDE SUSPENDED` and baseline restoration.

These are implementation safety checks, not part of the rate comparison.

## Analysis

For each numeric CharacterStat with enough movement:

```text
baseline rate = delta(metric) / real seconds
forced rate   = delta(metric) / real seconds
restored rate = delta(metric) / real seconds
rate ratio    = forced rate / baseline rate
```

Compare against the **observed** `CalendarCompressionFactor`. Moodle levels are ordinal corroboration only.

## Why the one-connected-player server test is valid

The remaining question is whether the `MinutesPerDay` reduction itself changes awake-player survival-state rates. The diagnostic override changes the same server-authoritative clock primitive used during real partial sleep, keeps the player awake, leaves the global simulation multiplier alone, and retains the normal multiplayer server/client synchronization path.

It does **not** replace multiplayer regression. It replaces only the remaining health/survival time-domain experiment.

## Go / no-go criteria

**GO:** no unacceptable remaining high-severity awake-player survival effect.

**CONDITIONAL GO:** accelerated behavior is understood and can be safely bounded by configuration or a narrowly targeted validated mitigation.

**NO-GO:** calendar compression can unexpectedly cause rapid starvation/dehydration, infection death, temperature injury, or a comparable severe awake-player failure.

## Outputs still required

1. v0.0.10 CharacterStat/Moodle capability validation on the multiplayer server/client path;
2. baseline → forced factor-5 → restored-baseline telemetry with exactly one connected player;
3. classification of hunger/thirst/fatigue/endurance and other practical high-severity metrics;
4. final Public Alpha GO / CONDITIONAL GO / NO-GO decision;
5. ADR only if results require a new architecture/policy decision;
6. final deployment/docs update.

## Current decision

**Public Alpha remains paused.** The acute bleeding question passed and nutrition is classified. The remaining v0.0.10 test requires only one connected player, but it must run on the normal multiplayer server architecture.
