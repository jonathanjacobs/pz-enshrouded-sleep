# SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression

Status: **In progress / Public Alpha deployment blocker**  
Current implementation target: **v0.0.9**  
Primary test platform: Project Zomboid **42.20.3**  
Tracking issue: **GitHub #4** — `SPIKE-004: characterize player health/survival time domains under partial sleep`

## Question

When Enshrouded Sleep shortens `MinutesPerDay`, which player health/survival systems accelerate in real time with compressed world/calendar time, and which remain tied to ordinary active-simulation/real time?

## Why this is blocking Public Alpha deployment

The core sleep/clock architecture is validated, but a live multiplayer server introduces an important safety question. If an awake player is wounded, bleeding, sick, starving, dehydrated, infected, or otherwise under a time-sensitive health effect while another player sleeps, some of those systems may progress faster in real time when the world calendar is compressed.

A system that normally changes slowly but scales approximately with `CalendarCompressionFactor` could become dangerous at high partial-sleep compression. This must be measured before exposing normal public-server characters to the mechanic.

## Hypothesis

Project Zomboid health/survival variables do not necessarily share one time domain. Expected outcomes include:

- **simulation/real-time bound** — rate per real second remains approximately unchanged during partial compression;
- **world-time bound** — rate per real second scales approximately with `CalendarCompressionFactor`;
- **mixed/nonlinear** — rate changes, but not proportionally;
- **event-driven** — value changes only when another subsystem/event fires;
- **client-local/server-local discrepancy** — useful state is exposed differently on the owning client and server.

No compensation should be implemented until this mapping is measured.

## Instrumentation

The spike uses read-only diagnostic modules:

```text
42/media/lua/server/EnshroudedSleep/HealthTimeDomainDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/HealthTimeDomainDiagnostic_Client.lua
```

They run only when:

```lua
DiagnosticsEnabled = true
```

The server samples every instantiated living player once per real second. The client sampler records the owning local player's corresponding state so server/client exposure can be compared.

### v0.0.9 probe strategy

The first v0.0.8 integration run showed that many continuous `Stats` getters are not exposed through the tested Lua/Kahlua bridge even though corresponding public Java fields exist. v0.0.9 therefore uses a layered read strategy:

1. normal getter;
2. guarded public-field fallback where the Java API documents a public field;
3. `N/A` if neither is exposed.

The diagnostic also scans Project Zomboid's Moodle collection by index. Relevant Moodle levels are logged separately and the complete observed Moodle set is emitted as a compact summary. Moodles are a discrete fallback/secondary signal; they are not treated as equivalent to a continuous raw stat.

### Clock/experiment context

Each health sample includes:

- real epoch;
- baseline/partial/full-sleep phase;
- living and sleeping counts on the server;
- sleep fraction;
- `MinutesPerDay`;
- observed native baseline;
- calculated `CalendarCompressionFactor`;
- `TimeOfDay`;
- `WorldAgeHours`;
- `DeltaMinutesPerDay`;
- game multiplier;
- true multiplier;
- server multiplier;
- player sleep state.

These multiplier fields are particularly useful for separating vanilla all-players-asleep fast-forward from Enshrouded Sleep partial `MinutesPerDay` compression.

### General player metrics

Where exposed by the tested Lua bridge, the diagnostic records:

- health / overall body health;
- hunger;
- thirst;
- fatigue;
- endurance;
- stress;
- panic;
- pain;
- boredom;
- unhappiness;
- sickness;
- drunkenness;
- fear;
- sanity;
- food sickness;
- poison level;
- zombie infection level / apparent infection / fake infection state;
- body temperature;
- wetness;
- cold progression metrics;
- sleep counters and sleeping-pill count;
- weight and nutrition stores (calories, carbohydrates, proteins, lipids).

Unavailable APIs are logged as `N/A`; the diagnostic must not fail the gameplay session because one value is not exposed in Lua.

### Moodle fallback / secondary state

v0.0.9 records selected levels for:

- Hungry, Thirst, Tired and Endurance;
- Stress, Panic, Pain, Bored and Unhappy;
- Sick and Drunk;
- Bleeding and Injured;
- Wet and HasACold;
- Hyperthermia and Hypothermia;
- Zombie.

### Injury/body-part metrics

For non-pristine/injured body parts, the diagnostic records:

- body-part identity and health;
- pain / additional pain;
- bleeding flag and bleeding time;
- bleeding stemmed state;
- bandage state/life/dirty state;
- cut and cut timer;
- scratch and scratch timer;
- bite and bite timer;
- deep wound and timer;
- stitch state and timer;
- fracture timer / splint state;
- burn state/timer;
- wound infection state/level;
- embedded glass/bullet state;
- local wetness, skin/inner temperature, and stiffness.

## Preliminary v0.0.8 solo reference run — 2026-08-19

A solo test was run before the decisive two-player experiment. The test character was injured, monitored awake, and then slept under normal solo/vanilla full-sleep behavior.

### Instrumentation result

**PASS:** the new broad diagnostic loaded and ran without an Enshrouded Sleep exception flood.

The captured run contained hundreds of server/client `PLAYER` samples and thousands of injured-body-part `BODY` samples. Overall health and detailed body-part values agreed closely between server and owning client in the portions reviewed.

Useful exposed values included:

- overall health / body health;
- bleeding/injury counts;
- detailed body-part injury and healing timers;
- sleep counters;
- weight, calories, carbohydrates, proteins and lipids;
- cold-related values;
- apparent infection and several body-part infection values.

### Raw-stat exposure gap

The v0.0.8 getter-only implementation produced `N/A` for many values of interest, including:

- hunger;
- thirst;
- fatigue;
- endurance;
- stress;
- panic;
- general pain;
- boredom;
- unhappiness;
- sickness;
- drunkenness;
- fear;
- sanity;
- food sickness;
- poison;
- raw infection level/fake infection level in some contexts;
- aggregate temperature/wetness in some contexts.

This is the direct reason for the v0.0.9 public-field and Moodle fallbacks.

### Vanilla full-sleep reference

The solo run is **not a partial-sleep test**. With one living player asleep, Enshrouded Sleep restored the native `MinutesPerDay=90` and vanilla full-sleep fast-forward owned the state.

Nevertheless, the run provides useful reference evidence:

- with four active bleeding injuries, client health was approximately `81.16` immediately before sleep;
- once solo vanilla sleep began, health samples fell approximately `69.68 -> 47.74 -> 25.83 -> 6.03 -> 0` over about five real seconds;
- the character therefore died extremely quickly under vanilla full-sleep acceleration;
- a later controlled non-bleeding/healing sleep showed strong acceleration of wound/recovery timers and health recovery;
- nutrition stores such as carbohydrates/proteins/lipids accelerated strongly with world progression, while calories behaved less like a simple one-clock metric.

This establishes that health-related systems can respond strongly to **vanilla multiplier-driven sleep acceleration**. It does **not** establish that an awake player will experience the same behavior during Enshrouded Sleep partial compression, because partial sleep deliberately leaves global simulation fast-forward alone and changes only `MinutesPerDay`.

## Decisive controlled test design

Use two test characters and Debug Mode so starting conditions can be deliberately created and repeated.

For operational safety and easier computer switching, the recommended first run uses native `FastForwardMultiplier=10` rather than 40. With two living players and one sleeper, that should produce approximately:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 5
Baseline MinutesPerDay = 90
Partial MinutesPerDay = 18
```

A 5x signal is large enough to classify a world-time-bound effect while giving the operator substantially more real time to observe/respond. Higher compression can be tested later if needed.

### Phase A — native baseline

1. Start with two living players awake.
2. Enable `DiagnosticsEnabled=true`.
3. Establish controlled health conditions on Player A. At minimum include one active bleeding injury; also create useful nonzero hunger/thirst/fatigue and one healing/injury state if practical.
4. Hold both players awake for at least 60 real seconds.
5. Preserve server and client logs.

### Phase B — partial sleep

1. Keep Player A, the affected/injured test character, awake.
2. Put Player B to sleep.
3. Confirm the expected partial state (`2 living / 1 sleeping`) and the actual `MinutesPerDay`/compression factor in logs.
4. Hold the state for at least 60 real seconds unless Player A becomes unsafe.
5. Do not artificially heal/feed/reset Player A during the measurement interval unless necessary to prevent test-character death.

### Phase C — restored baseline

1. Wake Player B.
2. Hold both players awake another 60 seconds.
3. Confirm `MinutesPerDay` returns to baseline and monitored rates return toward baseline behavior where applicable.

### Optional Phase D — vanilla full sleep

The v0.0.8 solo run already supplies a useful vanilla reference. Additional all-asleep testing is optional and must not be mixed into the partial-sleep classification.

## Analysis

For each numeric metric with sufficient variation, compare change per real second across baseline and partial phases.

Example classification:

```text
baseline hunger rate = +0.0004 / real second
partial hunger rate  = +0.0020 / real second
observed compression = 5
ratio ~= 5
=> world-time bound
```

versus:

```text
baseline health loss from bleeding = -0.20 / real second
partial health loss from bleeding  = -0.21 / real second
ratio ~= 1
=> simulation/real-time bound
```

These examples are analytical illustrations, not predictions.

## Results table — partial-sleep classification still pending

| Metric / subsystem | Baseline rate | Partial rate | Rate ratio | Server/client agreement | Classification | Safety consequence |
|---|---:|---:|---:|---|---|---|
| Overall health loss while bleeding | TBD | TBD | TBD | TBD | TBD | TBD |
| BleedingTime / wound state | TBD | TBD | TBD | TBD | TBD | TBD |
| Hunger / Hungry Moodle | TBD | TBD | TBD | TBD | TBD | TBD |
| Thirst / Thirst Moodle | TBD | TBD | TBD | TBD | TBD | TBD |
| Fatigue / Tired Moodle | TBD | TBD | TBD | TBD | TBD | TBD |
| Endurance / Endurance Moodle | TBD | TBD | TBD | TBD | TBD | TBD |
| Wound/healing timer(s) | TBD | TBD | TBD | TBD | TBD | TBD |
| Pain / Pain Moodle | TBD | TBD | TBD | TBD | TBD | TBD |
| Sickness / Sick Moodle | TBD | TBD | TBD | TBD | TBD | TBD |
| Poison | TBD | TBD | TBD | TBD | TBD | TBD |
| Zombie infection metrics / Zombie Moodle | TBD | TBD | TBD | TBD | TBD | TBD |
| Temperature / cold Moodles | TBD | TBD | TBD | TBD | TBD | TBD |
| Nutrition stores | TBD | TBD | TBD | TBD | TBD | TBD |

## Go / no-go criteria

### GO for WHG Public Alpha

Proceed if no high-severity awake-player health/survival effect becomes dangerously accelerated by partial sleep, or if any accelerated behavior is understood and judged acceptable for alpha use.

### CONDITIONAL GO

Proceed only with a lower `PartialSleepSpeedScale`, additional warnings, or a narrowly targeted mitigation if one or more systems accelerate but can be safely bounded without destabilizing the architecture.

### NO-GO

Do not deploy publicly if partial sleep can cause severe or surprising consequences such as rapid awake-player bleed-out, infection death, starvation/dehydration, or another high-severity health effect before an appropriate mitigation is implemented and validated.

## Outputs

The spike must produce:

1. a completed per-metric time-domain classification table;
2. any required new GitHub issues;
3. a Public Alpha GO / CONDITIONAL GO / NO-GO decision;
4. an ADR if findings require a new architectural policy or compensation mechanism;
5. updates to requirements, roadmap, deployment guidance, validation history, and changelog.

## Current decision

**Public Alpha deployment remains paused until the two-player partial-sleep comparison is completed.** The v0.0.8 solo run validated the diagnostic concept and supplied a vanilla full-sleep reference; v0.0.9 improves observability for the decisive partial-sleep experiment.
