# Roadmap

This is the **single canonical roadmap** for Enshrouded Sleep. The top-level README links here but intentionally does not duplicate roadmap content.

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player support is not a project goal.

## Current phase — Public Alpha

Status: **Public Alpha / field validation and SPIKE-005 investigation**  
Current version: `v0.0.10`  
Behaviorally validated platform baseline: Project Zomboid `42.20.3`  
Steam Workshop ID: `3786842301`

The pre-alpha technical gates are complete. [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) returned **GO** after controlled v0.0.9/v0.0.10 health/survival testing.

Public Alpha v0.0.10 has been published to Steam Workshop, acquired by the WHG dedicated server and client, and passed a live two-player Workshop-distributed regression including baseline inheritance, proportional partial-sleep compression, live `FastForwardMultiplier` inheritance, client day-length synchronization, and baseline restoration.

The repository uses one authoritative deployable mod tree:

```text
Contents/mods/pz-enshrouded-sleep/
```

## Current development focus — SPIKE-005

[`SPIKE-005`](spikes/SPIKE-005-world-system-time-domains.md) is the primary feature investigation.

Goal: characterize how non-health world systems behave when `MinutesPerDay` is compressed, then determine whether server administrators can safely choose between:

- **world-time progression** — current/default behavior; or
- **simulation-time progression** — supported systems are compensated during partial sleep so they advance approximately as though native `MinutesPerDay` remained in effect.

Initial release-driving systems:

- food aging/spoilage, including refrigeration/freezing;
- farming/crop maturation and related crop timers;
- generator fuel consumption and condition/wear;
- vehicle fuel consumption and battery behavior where practical.

Secondary systems include corpse decay/removal, composting, cooking/fire, world-item removal, erosion/vegetation, weather/climate, and Build 42 animal husbandry clocks.

The project will not assume these systems share one time domain. SPIKE-005 measures time-domain behavior and separately grades compensation feasibility before production behavior changes.

### SPIKE-005 results established so far

Controlled one-player-on-dedicated-server forced-compression testing has now established:

- **generator fuel is world/calendar-time bound**;
  - ~9.0x baseline real-time consumption rate during the 10x phase;
  - ~17.2x baseline real-time consumption rate during the 20x phase;
  - fuel consumed per elapsed world-hour remained close to baseline;
- **ambient food aging/spoilage is world/calendar-time bound**;
  - raw chicken aged ~20.99x faster per real second during 20x compression;
  - aging remained ~1 food-age day per elapsed world day;
- **refrigerated food aging is world/calendar-time bound**;
  - vanilla refrigeration remained effective at ~0.20x ambient aging per elapsed world day;
  - because world time itself was accelerated, refrigerated food still aged ~20x faster per real second during 20x compression;
- `TrueMultiplier` remained `1.0` and native `MinutesPerDay` restoration continued to work during these tests.

Generator condition/wear, frozen food, farming, vehicle fuel/battery, unloaded-chunk/catch-up behavior, and safe compensation hooks remain unresolved.

The old broad diagnostic's generic-item food logging has been removed; food measurement now uses the strict Food-class diagnostic only.

## Evidence established before and during Public Alpha

Validated behavior includes:

- proportional partial-sleep calendar compression;
- normal-speed awake active simulation;
- synchronized server/client `MinutesPerDay` pacing;
- exact baseline restoration;
- vanilla full-sleep handoff;
- wake/disconnect denominator recalculation;
- normal vanilla sleep/wake timing after client pacing synchronization;
- awake bleeding/body-health loss approximately real-time bound under tested compression;
- hunger, thirst, fatigue and core nutrition stores world/calendar-time bound;
- resting endurance recovery approximately real-time bound;
- diagnostic forced-compression safety handoff when the single connected test player sleeps;
- Steam Workshop server/client acquisition and loading for item `3786842301`;
- live two-player Workshop-distributed regression on a native 120-minute server day;
- live inheritance of an administrator change to `FastForwardMultiplier` without restart;
- generator fuel world/calendar-time classification;
- ambient and refrigerated food-aging world/calendar-time classification;
- preservation of vanilla refrigeration behavior under 20x calendar compression.

SPIKE-004 did not justify broad health/survival compensation. Faster hunger/thirst/fatigue/nutrition progression is accepted as a consequence of genuinely faster elapsed game-world time.

## Public Alpha configuration

```text
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
PartialSleepSpeedScale=1.0
```

The diagnostic machinery remains available for controlled support/regression work but is dormant during normal play.

## Public Alpha field goals

Primary goals:

- exercise proportional sleep with 3–12+ living players;
- observe multiple sleeping fractions rather than only the 2-player case;
- exercise joins, disconnects, deaths, respawns, and repeated sleep/wake cycles;
- verify clock continuity and normal-speed awake gameplay over long sessions;
- validate survival behavior under ordinary live conditions;
- complete SPIKE-005 characterization of non-health world-time systems;
- determine which measured subsystems can safely support optional simulation-time compensation;
- characterize pathological survival states not exercised in SPIKE-004 where safe/practical: sickness, poisoning, zombie infection/fever, and extreme thermal injury;
- identify compatibility problems with other sleep/recovery or world-time-driven mods;
- observe client pacing during admin/sandbox changes without the aggressive repeated factor changes used in SPIKE-004;
- continue validating install/update/rollback through the permanent Steam Workshop item.

### Immediate SPIKE-005 sequence

1. Vehicle fuel consumption while engine is running.
2. Vehicle battery behavior if measurable in the same controlled run.
3. Farming/crop maturation and related water/disease/pest timers.
4. Loaded versus unloaded/catch-up behavior for farming and other persistent systems.
5. Generator condition/wear with sufficiently long comparable baseline/compressed intervals.
6. Frozen-food behavior.
7. Compensation-feasibility investigation for confirmed world-time systems.
8. Representative real two-player partial-sleep confirmation before any compensation release decision.

### Public Alpha exit criteria

Move toward Public Beta when field evidence supports:

- no recurring clock-jump/client synchronization defect during ordinary play;
- no global acceleration of awake simulation;
- no repeated sleep-duration pathology;
- no high-severity awake-player health/survival effect beyond documented world-time progression;
- reliable baseline restoration and vanilla full-sleep handoff at larger populations;
- proportional behavior validated with more than two living players;
- configuration inheritance validated across alternate native settings;
- operationally acceptable log/error volume;
- major world-time side effects documented, accepted, or addressed;
- SPIKE-005 has produced a GO / PARTIAL GO / NO-GO decision for optional world-system compensation;
- representative live mod-stack interaction is stable enough for routine operation;
- Workshop install/update/rollback procedure remains repeatable and documented.

## Next feature release candidate

If SPIKE-005 returns GO or PARTIAL GO, the next substantive Alpha release should add administrator-selectable world-system progression policy while preserving current behavior as the default.

Preferred semantics:

```text
WORLD_TIME (default)
    Vanilla world-time-driven systems continue to follow accelerated calendar time.

SIMULATION_TIME
    Only explicitly supported, evidence-backed subsystem adapters are compensated during normal partial sleep.

ADVANCED (future)
    Optional per-subsystem policy using the same adapter architecture.
```

Unsupported systems remain vanilla and must be documented rather than silently represented as compensated.

## Public Beta / v0.1.x

Public Beta focuses on stabilization:

- complete remaining MVP acceptance-matrix items;
- establish a compatibility matrix;
- document major world-time systems;
- stabilize any SPIKE-005-approved subsystem compensation;
- improve administrator UX/distribution;
- reduce or consolidate obsolete diagnostics where appropriate;
- establish repeatable Build 42 regression procedures.

## v1.0 readiness

A stable `v1.0` requires stable server/client synchronization, reliable representative multiplayer behavior, no known high-severity player/save/world-state risk, documented world-time interactions, reliable install/upgrade/disable/rollback procedures, concise administration, and compatibility claims limited to tested combinations.

## Post-MVP candidates

Possible future features include player-facing compression notices, configuration presets, expanded per-subsystem progression controls, administrator observability tools, and compatibility helpers.

## Explicit non-goals

The project is not trying to support local/standalone single-player, replace vanilla fatigue/sleep eligibility, create a separate readiness/voting system, globally fast-forward active simulation, guarantee compatibility with every mod, or preemptively compensate every world-time-driven system.
