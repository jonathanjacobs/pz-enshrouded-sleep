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

## Initial source review — before runtime measurement

These are implementation clues, not substitutes for runtime classification.

### Farming

Current Build 42 vanilla Lua strongly suggests farming is calendar/hour-event driven. `SFarmingSystem:EveryTenMinutes()` derives the current hour from `getGameTime():getTimeOfDay()`, increments persistent `hoursElapsed` state when the hour changes, advances water/disease bookkeeping from that counter, and checks crop `nextGrowing` against `hoursElapsed`.

Working hypothesis: crop maturation and several plant-care systems will scale with accelerated world time. Because persistent farming global-object state is involved, compensation may be more complex than multiplying one transient delta. Loaded/unloaded behavior must be measured.

### Vehicles

Current vanilla vehicle logic updates fuel, battery, engine temperature, headlights, heater and related systems using an `elapsedMinutes` value. Runtime measurement is required to establish what time source ultimately controls that value under dynamic `MinutesPerDay` compression.

### Food

The `Food` API exposes age/rot state and refrigeration/freezing-related values. A strict Food-class diagnostic was added after the first broad collector incorrectly treated generic inventory items with sentinel aging values as food.

### Generators

`IsoGenerator` exposes fuel, condition, activation, connectivity and power-use state, allowing non-mutating observation of a live generator.

## Experimental control

Use the existing server-only diagnostic forced-compression mode with one connected, awake player:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor=<factor>
```

The controller suspends forced compression if that player sleeps or if another living player connects, preventing accidental mixing with ordinary proportional sleep.

Comparison factors:

```text
1x baseline
5x when useful
10x
20x where safe and informative
```

The primary comparison is rate per real elapsed second versus rate per authoritative world-hour/world-day.

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

Telemetry cadence remains wall-clock gated so diagnostics do not themselves accelerate with compressed world time.

## Classification model

### WORLD/CALENDAR-TIME BOUND

Observed rate scales approximately with `CalendarCompressionFactor` in real time and remains approximately constant per elapsed world-hour/world-day.

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

## Runtime result 1 — generator fuel consumption

Controlled dedicated-server testing used one connected awake player, a running connected generator with stable `powerUsing=0.002`, baseline `MinutesPerDay=90`, and diagnostic compression factors of 10x and 20x. `TrueMultiplier` remained `1.0`.

Observed intervals after the generator was filled and stabilized:

| Phase | Real elapsed | World hours elapsed | Fuel consumed | Fuel / real second | Fuel / world hour |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1x baseline | 409.0 s | 1.817 h | 0.0040 | 0.00000978 | 0.00220 |
| 10x | 45.4 s | 2.016 h | 0.0040 | 0.0000881 | 0.00198 |
| 20x | 130.9 s | 11.624 h | 0.0220 | 0.0001681 | 0.00189 |

Real-time consumption therefore increased approximately:

```text
10x phase: ~9.0x baseline real-time rate
20x phase: ~17.2x baseline real-time rate
```

The deviation from exact 10x/20x scaling is consistent with the generator's coarse/discrete fuel decrement size and relatively short observation windows. The stronger invariant is that fuel consumed per elapsed world-hour remained close to the baseline rate while real-time consumption accelerated sharply.

**Classification: WORLD/CALENDAR-TIME BOUND — CONFIRMED.**

Generator condition changed from `100` to `99` during the 20x interval. That is evidence that wear may also be calendar-time driven, but there is not yet a sufficiently long baseline comparison to classify generator condition/wear.

Compensation feasibility remains unresolved; classification alone does not justify direct fuel rewrites.

## Runtime result 2 — food aging/spoilage

A second controlled dedicated-server run used newly placed `Base.ChickenWhole` samples at ambient temperature and in a refrigerator. Baseline was `MinutesPerDay=90`; the compressed phase used factor 20 (`MinutesPerDay=4.5`). `TrueMultiplier` remained `1.0`.

The dedicated strict Food-class diagnostic was used for these measurements. Generic `InventoryItem` records from the earlier broad collector are invalid for food analysis and have been removed from that collector.

### Ambient raw chicken

Baseline controlled interval:

```text
real elapsed:       25.099 s
world elapsed:      0.111512 h
food age increase:  0.004424 days
food age/world day: ~0.952
```

20x interval:

```text
real elapsed:       520.2 s
world elapsed:      46.193146 h
food age increase:  1.924535 days
food age/world day: ~0.9999
```

Ambient food-aging rate per real second increased by approximately `20.99x` between the baseline and 20x intervals, while aging per elapsed world-day remained approximately one food-age day per world day.

**Classification: ambient food aging/spoilage = WORLD/CALENDAR-TIME BOUND — CONFIRMED.**

### Refrigerated raw chicken

After the refrigerator sample reached stable `heat=0.2`, the short baseline interval produced approximately:

```text
food age/world day: ~0.196
```

Across the full 20x compressed interval with stable `heat=0.2`:

```text
real elapsed:       520.2 s
world elapsed:      46.193146 h
food age increase:  0.384907 days
food age/world day: ~0.2000
```

The refrigeration modifier therefore remained intact under compression: refrigerated food aged at about 20% of the ambient rate per world day. Because world days themselves were passing 20x faster in real time, the refrigerated sample's aging per real second increased approximately `20.4x` relative to the stable baseline sample.

**Classification: refrigerated food aging = WORLD/CALENDAR-TIME BOUND with vanilla refrigeration modifier preserved — CONFIRMED.**

Frozen-food behavior has not yet been measured and remains pending.

## Experimental matrix

| System | Baseline | 5x | 10x | 20x | Classification | Authority | Grade | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ambient food aging/spoilage | measured | — | — | measured | **WORLD/CALENDAR** | server-observed | ? | ~0.95–1.00 food-age day/world day; ~21x real-time rate at 20x |
| Refrigerated food aging | measured | — | — | measured | **WORLD/CALENDAR** | server-observed | ? | vanilla ~0.20x refrigeration modifier preserved |
| Frozen food aging | pending | pending | pending | optional | pending | pending | ? | separate freezing/catch-up behavior still needed |
| Crop maturation | pending | pending | pending | optional | pending | likely server | ? | source review indicates hour/calendar-driven |
| Crop water/disease/pests | pending | pending | pending | optional | pending | likely server | ? | persistent farming counters/state involved |
| Generator fuel | measured | — | measured | measured | **WORLD/CALENDAR** | server-observed | ? | ~9.0x real-time rate at 10x; ~17.2x at 20x; fuel/world-hour near baseline |
| Generator wear | partial | — | partial | partial | pending | server-observed | ? | condition 100→99 during 20x; no comparable baseline interval yet |
| Vehicle fuel | pending | pending | pending | optional | pending | pending | ? | vanilla update consumes elapsedMinutes; caller time basis unresolved |
| Vehicle battery | pending | pending | pending | optional | pending | pending | ? | same elapsedMinutes ambiguity as fuel |
| Corpse decay/removal | pending | pending | pending | optional | pending | pending | ? | may require longer intervals |
| Compost | pending | pending | pending | optional | pending | pending | ? | may be chunk/catch-up driven |
| Cooking/fire | pending | pending | pending | optional | pending | pending | ? | distinguish active heat process from calendar aging |
| Item removal | pending | pending | pending | optional | pending | pending | ? | sandbox-dependent |
| Erosion/vegetation | pending | pending | pending | optional | pending | pending | ? | long-duration/catch-up likely |
| Weather/climate | pending | pending | pending | optional | pending | pending | ? | likely intended to follow calendar |
| Animals | pending | pending | pending | optional | pending | pending | ? | split husbandry clocks if heterogeneous |

## Current interpretation

Two high-impact resource systems are now confirmed to follow accelerated world/calendar time:

- generator fuel;
- food aging/spoilage, including refrigerated food after vanilla refrigeration modifiers are applied.

This confirms the gameplay concern motivating SPIKE-005: under current/default behavior, an awake player's generator fuel and perishable food can be consumed/aged much faster in real time while another player sleeps, even though active simulation remains at normal speed.

This is sufficient to justify continuing toward an optional simulation-time policy, but not sufficient to choose an implementation. Safe compensation hooks and vehicle/farming behavior still need investigation.

## Conceptual compensation

For a world-time-bound subsystem intentionally kept at baseline/simulation pacing during partial sleep, the conceptual inverse rate is:

```text
RealTimeCompensationFactor = 1 / CalendarCompressionFactor
```

This is a model, not an instruction to multiply arbitrary persistent fields by that factor.

Correct implementation may instead require delaying updates, adjusting accumulated elapsed time, controlling subsystem-specific delta values, or using another API-defined mechanism. Directly rewriting persistent state every tick is disfavored.

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
    Supported adapters compensate only while normal partial-sleep compression is active.
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

## Remaining test protocol

### Vehicle fuel/battery — next

Use one connected awake player and a controlled stationary-running vehicle. Compare baseline versus 20x while recording fuel and battery state. If fuel usage is too small/noisy at idle, use a reproducible active load without changing other variables.

### Farming

Create known crops and measure `nbOfGrow`, `nextGrowing`, water and disease/pest state across baseline/compressed intervals. Include loaded versus unloaded/catch-up behavior before considering compensation.

### Generator wear

Run a sufficiently long baseline and compressed comparison to determine whether condition loss scales with world time or another mechanism.

### Frozen food

Measure fully frozen food separately from refrigerated food; do not extrapolate the refrigeration result to freezing/catch-up behavior.

### Real two-player confirmation

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

- [x] Non-mutating instrumentation exists for generator and strict Food-class observation.
- [x] Baseline measurements captured for generator fuel and food aging.
- [x] 10x generator measurement captured.
- [x] 20x generator and food measurements captured.
- [x] Generator fuel classified.
- [x] Ambient and refrigerated food aging classified.
- [ ] Frozen food characterized.
- [ ] Farming/crop systems classified.
- [ ] Vehicle fuel/battery classified.
- [ ] Generator wear classified or explicitly left unresolved.
- [ ] Authority/catch-up behavior documented sufficiently for compensation design.
- [ ] Compensation grades assigned.
- [ ] Representative real partial-sleep confirmation completed.
- [ ] Admin policy/preset recommendation finalized.
- [ ] Architecture/validation/roadmap updated with final results.
- [ ] GO / PARTIAL GO / NO-GO recorded.
