# SPIKE-005 — World-System Time Domains and Compensation Feasibility

Status: **IN PROGRESS**  
Tracking issue: **#6**  
Target phase: **Public Alpha**  
Baseline mod version: **v0.0.10**  
Validated PZ baseline entering spike: **42.20.3**

## Question

When Enshrouded Sleep accelerates Project Zomboid world/calendar time by reducing `GameTime:MinutesPerDay` during partial multiplayer sleep, how do important non-health world systems progress, and which of those systems can safely support an administrator-selectable choice between:

- **World time** — current/default behavior: the subsystem advances with accelerated world/calendar time; or
- **Simulation time** — optional behavior: during partial sleep, the subsystem advances approximately as though the server remained at its native `MinutesPerDay`.

## Why this spike exists

Enshrouded Sleep deliberately separates two time domains:

```text
ACTIVE SIMULATION
movement, combat, zombies, vehicles, animations, physics, timed actions
-> intended normal speed

WORLD / CALENDAR TIME
time of day, date, WorldAgeHours, game-minute/world-time systems
-> faster during partial-sleep compression
```

SPIKE-004 proved that vanilla systems do not all use the same domain. Under controlled compression, hunger, thirst, fatigue and nutrition stores followed accelerated world/calendar time, while awake bleeding/body-health loss and resting endurance recovery remained approximately simulation/real-time bound.

The next release must therefore not assume that food, farming, generators, vehicles, weather, decay, animals and other systems all behave identically.

## Product intent

The current behavior remains the default and compatibility baseline:

```text
World-system progression during partial sleep = WORLD TIME
```

A later feature may offer a server-admin policy that keeps supported systems approximately simulation-time-bound during partial sleep.

Internally, policy must be representable per subsystem even if the first admin UI offers only presets. This avoids forcing unrelated systems into one implementation or semantic choice.

No gameplay compensation is part of this spike unless needed in an isolated development experiment. Production behavior must remain unchanged while characterization is underway.

## Candidate systems

### Tier 1 — release-driving

1. Food aging/spoilage.
2. Refrigerated/frozen food aging and temperature interaction.
3. Farming/crop maturation.
4. Farming water/disease/pest progression where measurable.
5. Generator fuel consumption.
6. Generator condition/wear where measurable.
7. Vehicle fuel consumption while engine is running.
8. Vehicle battery drain/charge where practical.

### Tier 2 — important characterization

9. Corpse decay/removal.
10. Composting.
11. Cooking/heat/fire progression.
12. World-item removal timers.
13. Erosion/vegetation progression.
14. Weather/climate progression.
15. Build 42 animal hunger, growth, reproduction and related husbandry clocks where practical.

### Tier 3 — compatibility boundary

16. Representative modded systems keyed to game minutes, `WorldAgeHours`, calendar dates, or vanilla update events.

The spike is not required to make every Tier 2/3 subsystem compensable. It is required to document what is known and avoid unsupported claims.

## Experimental control

Use the existing server-only diagnostic forced-compression mode with one connected, awake player:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor=<factor>
```

The controller already suspends forced compression if that player sleeps or if another living player connects, preventing accidental mixing with ordinary proportional sleep.

Initial comparison factors:

```text
1x baseline
5x
10x
20x where safe and informative
```

The primary comparison is rate per real elapsed second versus rate per authoritative world-hour.

## Common telemetry

Every subsystem sample/test record should include:

```text
real timestamp / real elapsed seconds
WorldAgeHours
TimeOfDay
MinutesPerDay
baseline MinutesPerDay
effective CalendarCompressionFactor
controller mode
living-player count
sleeping-player count
subsystem identifier / object location or identity
subsystem-specific state
```

Telemetry cadence must remain wall-clock gated so diagnostics do not themselves accelerate with compressed world time.

## Classification model

For each subsystem, assign one primary classification:

### WORLD/CALENDAR-TIME BOUND

Observed rate scales approximately with `CalendarCompressionFactor` in real time and remains approximately constant per elapsed world-hour.

### SIMULATION/REAL-TIME BOUND

Observed rate remains approximately constant per real second despite changing `MinutesPerDay`.

### HYBRID

Different aspects of the subsystem use different domains, or measured rate depends on both active simulation and world-time state.

### CHUNK-LOAD / CATCH-UP DRIVEN

The subsystem primarily resolves elapsed time when objects/chunks load or when a periodic catch-up path executes rather than continuously.

### UNKNOWN / INCONCLUSIVE

Instrumentation, duration, environmental confounding, or API visibility is insufficient for a defensible classification.

## Compensation-feasibility model

Time-domain classification and compensation feasibility are separate decisions.

For every measured subsystem record:

- authority: server / client / mixed / unknown;
- exposed state needed for measurement;
- exposed state needed for correction;
- clean event/API hook available: yes/no/unknown;
- persistent-save implications;
- multiplayer synchronization implications;
- interaction with sandbox settings;
- interaction with unloaded chunks/catch-up logic;
- likely mod-compatibility risk;
- intervention grade.

Intervention grades:

```text
A — clean, localized, server-authoritative hook; strong compensation candidate
B — feasible with bounded integration and explicit regression tests
C — technically possible but invasive/brittle; do not enable by default
D — requires replacement/monkey-patching of major vanilla logic or creates save/sync risk; exclude
? — insufficient evidence
```

## Conceptual compensation

For a world-time-bound subsystem intentionally kept at baseline/simulation pacing during partial sleep, the conceptual inverse rate is:

```text
RealTimeCompensationFactor = 1 / CalendarCompressionFactor
```

This is a model, not an instruction to multiply arbitrary vanilla fields by that factor.

Correct implementation may instead require delaying updates, adjusting accumulated elapsed time, controlling subsystem-specific delta values, or using another API-defined mechanism. Directly rewriting persistent state every tick is disfavored.

## Experimental matrix

| System | Baseline | 5x | 10x | 20x | Classification | Authority | Grade | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Food aging/spoilage | pending | pending | pending | optional | pending | pending | ? | Include fresh/refrigerated/frozen cases |
| Crop maturation | pending | pending | pending | optional | pending | pending | ? | Use known planted/growth state |
| Crop water/disease/pests | pending | pending | pending | optional | pending | pending | ? | Separate from maturation if needed |
| Generator fuel | pending | pending | pending | optional | pending | pending | ? | Known load and initial fuel |
| Generator wear | pending | pending | pending | optional | pending | pending | ? | If condition state is exposed/reliably changing |
| Vehicle fuel | pending | pending | pending | optional | pending | pending | ? | Engine running, stationary controlled test |
| Vehicle battery | pending | pending | pending | optional | pending | pending | ? | Controlled electrical load if practical |
| Corpse decay/removal | pending | pending | pending | optional | pending | pending | ? | May require longer intervals |
| Compost | pending | pending | pending | optional | pending | pending | ? | May be chunk/catch-up driven |
| Cooking/fire | pending | pending | pending | optional | pending | pending | ? | Distinguish active heat process from calendar aging |
| Item removal | pending | pending | pending | optional | pending | pending | ? | Sandbox-dependent |
| Erosion/vegetation | pending | pending | pending | optional | pending | pending | ? | Long-duration/catch-up likely |
| Weather/climate | pending | pending | pending | optional | pending | pending | ? | Likely intended to follow calendar |
| Animals | pending | pending | pending | optional | pending | pending | ? | Split husbandry clocks if heterogeneous |

## Initial implementation architecture if GO

Do not build one monolithic compensation loop.

Preferred structure:

```text
WorldProgressionPolicy
    -> reads authoritative partial-sleep compression state
    -> exposes current policy/preset and inverse factor

Subsystem adapters
    FoodProgression
    FarmingProgression
    GeneratorProgression
    VehicleProgression
    ...only where evidence supports intervention
```

Suggested policy semantics:

```text
DEFAULT / WORLD_TIME
    Vanilla world-time progression is untouched.

SIMULATION_TIME preset
    Supported adapters compensate only while normal partial sleep compression is active.
    Unsupported/excluded systems remain vanilla and are documented.

ADVANCED
    Future per-subsystem selections using the same adapter layer.
```

The policy must not alter:

- vanilla all-players-asleep fast-forward;
- active movement/combat/zombie/vehicle simulation rate;
- ordinary no-sleeper server behavior;
- unsupported vanilla systems merely to make the preset appear comprehensive.

## Fail-safe requirements for any later compensation feature

1. Default is exact current behavior: no subsystem intervention.
2. Compensation acts only during normal partial-sleep compression unless a development test explicitly says otherwise.
3. Disabling the mod or compensation stops intervention without requiring world repair.
4. Errors fail toward vanilla subsystem behavior, not continued state rewriting.
5. Do not accumulate hidden debt that is dumped into a subsystem when compression ends unless that behavior is explicitly designed and tested.
6. Unloaded-chunk behavior must be characterized before claiming world-wide compensation.
7. No destructive migration of existing saves.

## Test protocol outline

### A. Baseline

- Native `MinutesPerDay`.
- Forced factor `1.0`.
- Record stable environmental/input conditions.
- Measure subsystem delta over a sufficiently long real interval.

### B. 5x and 10x

- Change only forced compression factor.
- Repeat equivalent setup/interval.
- Compare:
  - delta per real second;
  - delta per world-hour;
  - expected multiplier versus measured multiplier.

### C. 20x stress/visibility test

Use only where it makes a slow effect easier to classify and does not create avoidable world/save risk.

### D. Loaded versus unloaded/catch-up

For systems capable of progressing off-screen/unloaded, explicitly test whether leaving and reloading the area changes the observed behavior.

### E. Real two-player confirmation

After single-player-on-dedicated-server characterization, confirm representative Tier 1 findings with real partial sleep using at least two living players before making a compensation release decision.

## Required output

For each Tier 1 subsystem, final results must answer:

1. What state changed?
2. What time domain controlled it?
3. Was scaling proportional to compression?
4. Was behavior continuous or catch-up based?
5. Who owns authoritative state?
6. Is there a clean compensation mechanism?
7. What are the save/sync/mod-compatibility risks?
8. Should the first admin-selectable simulation-time preset include it?

## Decision gate

### GO

Proceed to a compensation feature release if at least the highest-impact resource systems have safe, bounded interventions and the resulting behavior can be explained accurately to server admins.

### PARTIAL GO

Ship a preset covering only proven Grade A/B systems and document exclusions. This is preferable to invasive attempts at complete coverage.

### NO-GO

If safe compensation requires broad monkey-patching, state churn, unreliable object discovery, or save/synchronization risk, retain world-time behavior and document it rather than destabilizing the Public Alpha.

## Acceptance criteria

- [ ] Non-mutating instrumentation exists for Tier 1 systems.
- [ ] Baseline measurements captured.
- [ ] 5x measurements captured.
- [ ] 10x measurements captured.
- [ ] 20x used selectively where useful.
- [ ] Tier 1 time domains classified.
- [ ] Authority/catch-up behavior documented.
- [ ] Compensation grades assigned.
- [ ] Representative real partial-sleep confirmation completed.
- [ ] Admin policy/preset recommendation finalized.
- [ ] Architecture/validation/roadmap updated with results.
- [ ] GO / PARTIAL GO / NO-GO recorded.
