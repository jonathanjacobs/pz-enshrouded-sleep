# SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression

Status: **Complete — GO for Public Alpha**  
Completed: **2026-08-19**  
Implementation/test version: **v0.0.10**  
Primary platform: Project Zomboid **42.20.3**  
Tracking issue: **GitHub #4**

## Question

When Enshrouded Sleep shortens `MinutesPerDay`, which awake-player health/survival systems accelerate in real time with compressed world/calendar time, and which remain tied to ordinary active-simulation/real time?

## Scope

Enshrouded Sleep is a **multiplayer-server mod**. This spike did not test or add local/standalone single-player support.

The investigation used both a two-player real partial-sleep test and a one-connected-player multiplayer-server diagnostic override that reproduced the same server-authoritative `MinutesPerDay` compression while keeping the monitored player awake.

## Classification model

- **simulation/real-time bound** — rate per real second remains approximately unchanged during compression;
- **world/calendar-time bound** — rate per real second scales approximately with `CalendarCompressionFactor`;
- **mixed/nonlinear** — rate changes but not proportionally;
- **event-driven** — change depends on another subsystem/event;
- **insufficient/unavailable** — telemetry is not adequate to classify the value.

No compensation was implemented from assumption alone.

## Instrumentation

The repository was later restructured for direct Steam Workshop publication. The authoritative runtime paths are now under `Contents/mods/pz-enshrouded-sleep/`.

Broad health/body diagnostics:

```text
Contents/mods/pz-enshrouded-sleep/42/media/lua/server/EnshroudedSleep/HealthTimeDomainDiagnostic_Server.lua
Contents/mods/pz-enshrouded-sleep/42/media/lua/client/EnshroudedSleep/HealthTimeDomainDiagnostic_Client.lua
```

Focused v0.0.10 survival diagnostics:

```text
Contents/mods/pz-enshrouded-sleep/42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
Contents/mods/pz-enshrouded-sleep/42/media/lua/server/EnshroudedSleep/SurvivalStatDiagnostic_Server.lua
Contents/mods/pz-enshrouded-sleep/42/media/lua/client/EnshroudedSleep/SurvivalStatDiagnostic_Client.lua
```

The path move did not change the tested runtime logic.

v0.0.10 capability validation succeeded on the owning client and server path. The client reported:

```text
CharacterStatsResolved=24/24
CharacterStatsReadable=24/24
MoodlesResolved=25/25
MoodlesReadable=25/25
NutritionReadable=10/10
```

Continuous survival values therefore became observable through current Build 42 `CharacterStat` APIs rather than the stale getter assumptions used by the earlier diagnostic.

## v0.0.8 vanilla-full-sleep reference

A deliberately injured character entered full sleep while it was the only living server player. Enshrouded Sleep restored `MinutesPerDay=90`; vanilla full-sleep acceleration owned the interval.

Health fell approximately:

```text
81.16 -> 69.68 -> 47.74 -> 25.83 -> 6.03 -> 0
```

This demonstrated strong vanilla sleep acceleration of health/recovery but did not classify awake partial compression.

## v0.0.9 two-player result

The controlled two-player run included baseline, approximately 5x partial compression (`MinutesPerDay=18`), restored baseline, and a later approximately 10x interval (`MinutesPerDay=9`). `TrueMultiplier` remained `1.0` during partial compression.

### Awake bleeding/injury

```text
Overall health loss while actively bleeding
baseline:   ~-0.07869 health / real second
5x partial: ~-0.07810 health / real second
ratio:      ~0.993x
```

Measured `BleedingTime` and `ScratchTime` progression remained approximately `1x`.

**Classification:** simulation/real-time bound under the tested conditions.

**Safety consequence:** rapid awake-player bleed-out proportional to calendar compression was not observed.

### Nutrition

| Metric | Baseline rate | ~5x partial | Ratio | ~10x partial | Ratio |
|---|---:|---:|---:|---:|---:|
| Calories | -0.2583/s | -1.2928/s | 5.01x | -2.5886/s | 10.00x |
| Carbohydrates | -0.05597/s | -0.27987/s | 5.00x | -0.55972/s | 10.00x |
| Proteins | -0.01374/s | -0.06877/s | 5.00x | -0.13753/s | 10.01x |
| Lipids | -0.01807/s | -0.09036/s | 5.00x | -0.18071/s | 10.00x |

**Classification:** core nutrition stores are world/calendar-time bound.

## v0.0.10 one-connected-player server result

The final diagnostic run exercised baseline plus approximately 5x, 10x and 20x forced calendar compression while exactly one player remained connected to the multiplayer server and awake. The server-authoritative clock used the same `MinutesPerDay` primitive as real partial sleep, and `TrueMultiplier` remained `1.0` during compression.

A clean baseline-versus-first-5x comparison produced approximately:

| Metric | Observed ratio | Classification |
|---|---:|---|
| Hunger | 4.85x | world/calendar-time bound |
| Thirst | 4.67x | world/calendar-time bound |
| Fatigue | 5.46x | world/calendar-time bound |
| Carbohydrates | 4.99x | world/calendar-time bound |
| Proteins | 4.99x | world/calendar-time bound |
| Lipids | 4.99x | world/calendar-time bound |

A short adjacent 10x-versus-baseline comparison, after sleep had reset fatigue and with nearly identical player conditions, produced roughly:

```text
Hunger       9.54x
Thirst       9.45x
Fatigue      9.48x
Proteins     9.48x
Lipids       9.48x
Body health  0.95x
```

This provided a strong internal control: survival needs tracked compressed world time while ongoing body-health loss did not.

### Endurance

During resting/recovery intervals:

```text
10x compression: ~+0.00176 endurance/sec
20x compression: ~+0.00178 endurance/sec
10x compression: ~+0.00169 endurance/sec
```

Doubling calendar compression from 10x to 20x did not materially change the recovery rate.

**Classification:** resting endurance recovery is simulation/real-time bound under the tested condition. Endurance depletion during strenuous activity was not separately characterized.

### Temperature and pathological states

Temperature remained within a normal physiological range and no hyperthermia/hypothermia Moodle hazard appeared despite aggressive 10x/20x test periods.

The following remained zero/not active and therefore are **not classified** by this spike:

- active sickness / food sickness;
- poison;
- zombie infection / zombie fever;
- extreme thermal injury.

These move to Public Alpha characterization rather than remain deployment blockers.

## Diagnostic override safety result

The one-player forced-compression state also passed its important sleep-suspension check. While a forced factor was armed, the player went to sleep; the controller restored baseline `MinutesPerDay` and suspended the override, preventing forced compression from stacking with vanilla full-sleep acceleration.

The override remains diagnostics-only, bounded, and inactive in normal play at factor `1.0`.

## Client synchronization observation

During aggressive live admin/sandbox factor changes, a few isolated client samples temporarily reverted from compressed `MinutesPerDay` to baseline while the authoritative server remained compressed. The normal ClockState heartbeat reapplied the server value within roughly a second.

This differs from the historical v0.0.5 synchronization defect: the server remained correct and the client self-healed. The resets coincided with repeated live sandbox/debug option changes used by the experiment, so this is retained as a Public Alpha robustness observation rather than a release blocker.

## Final results table

| Metric / subsystem | Result | Classification | Decision |
|---|---|---|---|
| Active bleeding health loss | ~0.993x at 5x | simulation/real-time bound | PASS |
| BleedingTime | ~1x | simulation/real-time bound | PASS |
| ScratchTime | ~1x | simulation/real-time bound | PASS |
| Ongoing body-health loss | ~0.95x in 10x/baseline control | simulation/real-time bound | PASS |
| Hunger | ~4.85x at 5x; ~9.54x in 10x control | world/calendar-time bound | accepted behavior |
| Thirst | ~4.67x at 5x; ~9.45x in 10x control | world/calendar-time bound | accepted behavior |
| Fatigue | ~5.46x at 5x; ~9.48x in 10x control | world/calendar-time bound | accepted behavior |
| Resting endurance recovery | ~1x across 10x/20x | simulation/real-time bound | PASS |
| Calories | ~5.01x / 10.00x | world/calendar-time bound | accepted behavior |
| Carbohydrates | ~5.00x / 10.00x; 4.99x in v0.0.10 5x test | world/calendar-time bound | accepted behavior |
| Proteins | ~5.00x / 10.01x; ~9.48x in 10x control | world/calendar-time bound | accepted behavior |
| Lipids | ~5.00x / 10.00x; ~9.48x in 10x control | world/calendar-time bound | accepted behavior |
| Temperature / thermal state | no proportional hazard observed | not clearly compression-bound | PASS for tested range |
| Sickness / food sickness / poison | inactive | unclassified | Public Alpha target |
| Zombie infection / fever | inactive | unclassified | Public Alpha target |
| Extreme thermal injury | not induced | unclassified | Public Alpha target |

## Interpretation

The feared failure mode was not observed. Enshrouded Sleep calendar compression does **not** appear to multiply acute awake-player injury damage under the tested conditions.

Hunger, thirst, fatigue and nutrition do advance with world/calendar time. This is consistent with the mod's semantic model: if several in-game hours pass while another survivor sleeps, those survival needs also experience those elapsed in-game hours.

This behavior is documented and accepted for Public Alpha. No broad health/survival compensation is justified by the evidence collected here.

## Final decision

**GO — Public Alpha.**

Rationale:

1. acute awake-player bleeding/body-health loss did not scale with calendar compression;
2. resting endurance recovery did not scale with calendar compression;
3. hunger/thirst/fatigue/nutrition scale with world time in a coherent, predictable way;
4. no thermal hazard appeared under aggressive compression;
5. the diagnostic override safety handoff to vanilla full sleep worked;
6. remaining pathological states were not active and can be characterized during Public Alpha without blocking deployment.

No new ADR is required because the results do not change the existing architecture. The current decision is to preserve the `MinutesPerDay` design and document world-time-driven survival progression as an expected consequence.

## Follow-up

Public Alpha should characterize:

- 3–12+ player proportional fractions;
- joins/disconnects/deaths/respawns;
- long-session stability;
- active sickness/poison/zombie infection and extreme thermal states if safely reproducible;
- spoilage, crops, generators, corpse decay, composting and weather;
- client clock robustness during live admin/sandbox reconfiguration.
