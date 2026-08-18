# SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression

Status: **In progress / Public Alpha deployment blocker**  
Implementation target: v0.0.8  
Primary test platform: Project Zomboid 42.20.3

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

v0.0.8 adds read-only diagnostic modules:

```text
42/media/lua/server/EnshroudedSleep/HealthTimeDomainDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/HealthTimeDomainDiagnostic_Client.lua
```

They run only when:

```lua
DiagnosticsEnabled = true
```

The server samples every instantiated living player once per real second. The client sampler records the owning local player's corresponding state so server/client exposure can be compared.

### Clock/experiment context

Each sample includes:

- real epoch;
- baseline/partial/full-sleep phase;
- living and sleeping counts on the server;
- sleep fraction;
- `MinutesPerDay`;
- observed native baseline;
- calculated observational compression factor;
- `TimeOfDay`;
- `WorldAgeHours`;
- player sleep state.

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

## Controlled test design

Use two test characters and Debug Mode so starting conditions can be deliberately created and repeated.

### Phase A — native baseline

1. Start with two living players awake.
2. Enable `DiagnosticsEnabled=true`.
3. Establish controlled health conditions. At minimum include one active bleeding injury; also create useful nonzero hunger/thirst/fatigue and one healing/injury state if practical.
4. Hold both players awake for at least 60 real seconds.
5. Preserve server and both client logs.

### Phase B — partial sleep

1. Keep the affected/injured test character awake.
2. Put the other player to sleep so the established two-player configuration reaches approximately `MinutesPerDay=4.5` / factor 20.
3. Hold the state for at least 60 real seconds unless a health variable becomes unsafe.
4. Do not artificially heal/feed/reset the monitored character during the measurement interval.
5. Observe the same metrics and note any visible health consequences.

### Phase C — restored baseline

1. Wake the sleeper.
2. Hold both players awake another 60 seconds.
3. Confirm `MinutesPerDay` returns to baseline and monitored rates return to baseline behavior where applicable.

### Optional phase D — vanilla full sleep

Both players may sleep briefly to characterize native full-sleep behavior separately. Do not confuse this phase with Enshrouded Sleep partial compression.

## Analysis

For each numeric metric with sufficient variation, compare change per real second across baseline and partial phases.

Example classification:

```text
baseline hunger rate = +0.0004 / real second
partial hunger rate  = +0.0080 / real second
ratio ~= 20
=> world-time bound at factor 20
```

versus:

```text
baseline health loss from bleeding = -0.20 / real second
partial health loss from bleeding  = -0.21 / real second
ratio ~= 1
=> simulation/real-time bound
```

The actual outcome must be derived from the logs; these examples are not predictions.

## Go / no-go criteria

### GO for WHG Public Alpha

Proceed if no high-severity awake-player health/survival effect becomes dangerously accelerated by partial sleep, or if any accelerated behavior is understood and judged acceptable for alpha use.

### CONDITIONAL GO

Proceed only with a lower `PartialSleepSpeedScale`, additional warnings, or a narrowly targeted mitigation if one or more systems accelerate but can be safely bounded without destabilizing the architecture.

### NO-GO

Do not deploy publicly if partial sleep can cause severe or surprising consequences such as rapid awake-player bleed-out, infection death, starvation/dehydration, or another high-severity health effect before an appropriate mitigation is implemented and validated.

## Outputs

The spike must produce:

1. a per-metric time-domain classification table;
2. any required new GitHub issues;
3. a Public Alpha go/conditional-go/no-go decision;
4. an ADR if the findings require a new architectural policy or compensation mechanism;
5. updates to the requirements, roadmap, deployment guidance, validation history, and changelog.

## Current decision

**Public Alpha deployment is paused until this spike is completed.** The validated sleep/clock architecture remains intact; this spike addresses a separate player-safety/time-domain risk discovered during pre-deployment review.
