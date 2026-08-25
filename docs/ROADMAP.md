# Roadmap

This is the **single canonical roadmap** for Enshrouded Sleep. The top-level README links here but intentionally does not duplicate roadmap content.

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player support is not a project goal.

## Current phase — Public Alpha

Status: **Public Alpha / field validation and SPIKE-006 awake-player protection investigation**  
Current version: `v0.0.10`  
Behaviorally validated platform baseline: Project Zomboid `42.20.3`  
Steam Workshop ID: `3786842301`

The pre-alpha technical gates are complete. [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) returned **GO** after controlled v0.0.9/v0.0.10 health/survival testing.

Public Alpha v0.0.10 has been published to Steam Workshop, acquired by the WHG dedicated server and client, and passed a live two-player Workshop-distributed regression including baseline inheritance, proportional partial-sleep compression, live `FastForwardMultiplier` inheritance, client day-length synchronization, and baseline restoration.

The repository uses one authoritative deployable mod tree:

```text
Contents/mods/pz-enshrouded-sleep/
```

## Current development focus — SPIKE-006 / v0.0.11 candidate

[`SPIKE-006`](spikes/SPIKE-006-awake-player-protection.md) is now the primary next-release investigation.

Goal: protect **awake players** from the extra survival-stat/metabolic progression caused by partial-sleep `MinutesPerDay` compression, while leaving sleeping players, active simulation, acute health systems, and external world systems on their appropriate vanilla paths.

Initial protection target:

- hunger;
- thirst;
- fatigue;
- calories;
- carbohydrates;
- proteins;
- lipids;
- weight progression.

The implementation must preserve vanilla:

- eating/drinking effects;
- activity/exercise effects;
- traits;
- thermoregulation modifiers;
- sandbox stat multipliers;
- sleeping-player physiology;
- server authority.

No broad health compensation is planned. SPIKE-004 showed that tested bleeding/body-health loss and resting endurance recovery were already approximately simulation/real-time bound.

### Current SPIKE-006 result

The diagnostics-only tick-driven post-update normalizer has now passed its first controlled passive runtime test.

With a native 90-minute day and diagnostic factor 20:

```text
MinutesPerDay     = 4.5
world clock       ≈ 20x
TrueMultiplier    = 1.0
living            = 1
sleeping          = 0
```

Stable authoritative server measurements showed protected passive rates approximately equal to native real-time pacing:

```text
Hunger            0.989x
Thirst            1.000x
Fatigue           1.001x
Calories          1.000x
Proteins          1.000x
Weight progression 1.008x
World clock       19.997x
```

Carbohydrates and Lipids were already at their vanilla lower clamp and therefore remain unmeasured in this run.

Decision: **GO for the passive normalization mechanism; not yet a production GO.** The current blocker is the active-effects/safety regression defined in [`SPIKE-006-ACTIVE-EFFECTS-TEST.md`](spikes/SPIKE-006-ACTIVE-EFFECTS-TEST.md).

### B42.20.3 source finding

The decompiled Build 42.20.3 implementation explains the observed SPIKE-004 behavior:

- awake hunger/thirst/fatigue multiply their base rates by `GameTime.getDeltaMinutesPerDay()`;
- `getDeltaMinutesPerDay()` is `30 / MinutesPerDay`;
- nutrition macros, calories, and weight use `GameTime.getGameWorldSecondsSinceLastUpdate()`;
- that world-time delta scales with `1440 / MinutesPerDay`;
- passive nutrition updates are authoritative on the non-client side.

Therefore the observed acceleration is structural, not a diagnostic artifact.

The cleanest theoretical solution—changing the Java `ZomboidGlobals` awake rates—is not directly available to ordinary Workshop Lua in B42.20.3 because the Java `zombie.ZomboidGlobals` class/static fields are not exposed as a safe mutable Lua API.

SPIKE-006 is therefore testing a narrowly gated server-authoritative post-update normalizer before any production behavior is selected.

## SPIKE-005 status — world systems

[`SPIKE-005`](spikes/SPIKE-005-world-system-time-domains.md) remains open but is no longer a prerequisite to the next release.

Accumulated evidence supports the working assumption that systems representing passage of game-world time should be presumed world/calendar-time bound unless source/runtime evidence indicates otherwise.

Confirmed examples:

- **generator fuel** — world/calendar-time bound;
- **ambient food aging/spoilage** — world/calendar-time bound;
- **refrigerated food aging** — world/calendar-time bound with vanilla ~0.20x refrigeration modifier preserved;
- **vehicle fuel while idling** — world/calendar-time bound;
- **vehicle battery drain under a stable engine-off electrical load** — world/calendar-time bound.

External world-system compensation is deferred until after awake-player protection. Current/default world-time behavior remains unchanged.

Remaining SPIKE-005 questions include:

- farming/crop implementation and unloaded/catch-up behavior;
- generator condition/wear;
- frozen-food behavior;
- safe subsystem-specific compensation hooks;
- compatibility implications of optional world-resource protection.

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
- vehicle fuel world/calendar-time classification;
- vehicle battery-drain world/calendar-time classification under a stable tested electrical load;
- preservation of vanilla refrigeration behavior under 20x calendar compression;
- SPIKE-006 tick-driven passive awake-player normalization at approximately 1x while world/calendar time ran at approximately 20x;
- owning-client survival state tracking remained coherent with the server during the successful SPIKE-006 passive run.

## Public Alpha configuration

Normal Public Alpha configuration remains:

```text
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
PartialSleepSpeedScale=1.0
```

The SPIKE-006 branch adds:

```text
DiagnosticAwakeProtectionPrototype=false
```

That option is a development-only test control and is not intended for ordinary gameplay.

## Immediate SPIKE-006 sequence

Completed:

1. Run the diagnostics-only idle/stationary prototype at native 1x then forced 20x. — **PASS**
2. Determine whether hunger/thirst/fatigue/nutrition/weight return from ~20x progression toward ~1x real-time pacing. — **PASS for measurable fields; Carbohydrates/Lipids were clamped**
3. Verify `TrueMultiplier=1.0`, world clock remains compressed, and the correction path is active/server-authoritative. — **PASS**

Next:

4. Exercise eating and drinking during compression and compare direct effect magnitude with baseline.
5. Exercise walking/running/sprinting and resting/sitting at native 1x and protected 20x.
6. Exercise Well Fed and representative safe rate modifiers where practical.
7. Re-test Carbohydrates/Lipids with values away from their clamps.
8. Verify sleeping suspends awake-player normalization before sleeping physiology is altered.
9. Verify a second living player joining suspends the forced diagnostic prototype safely and restores native `MinutesPerDay`.
10. Characterize legitimate same-direction effects that could be mistaken for calendar-driven passive progression where a safe/reproducible test is available.
11. Decide GO / PARTIAL GO / NO-GO for a production v0.0.11 awake-player protection implementation.
12. If GO/PARTIAL GO, replace diagnostics-only scaffolding with a production policy/configuration and run real two-player partial-sleep validation.

## Public Alpha field goals

Primary live goals remain:

- exercise proportional sleep with 3–12+ living players;
- observe multiple sleeping fractions rather than only the 2-player case;
- exercise joins/disconnects/deaths/respawns;
- repeated sleep/wake cycles;
- long-session stability;
- normal live mod-stack interaction;
- identify compatibility problems with other sleep/recovery or world-time-driven mods;
- observe client pacing during ordinary administration and sandbox changes;
- continue validating install/update/rollback through the permanent Steam Workshop item.

World-system characterization can continue opportunistically, but it is not blocking the awake-player-protection release investigation.

## Public Alpha exit criteria

Move toward Public Beta when field evidence supports:

- no recurring clock-jump/client synchronization defect during ordinary play;
- no global acceleration of awake simulation;
- no repeated sleep-duration pathology;
- no high-severity awake-player health/survival effect beyond documented policy;
- reliable baseline restoration and vanilla full-sleep handoff at larger populations;
- proportional behavior validated with more than two living players;
- configuration inheritance validated across alternate native settings;
- operationally acceptable log/error volume;
- major world-time side effects documented, accepted, or addressed;
- any shipped awake-player protection has passed passive and active-effect regression;
- representative live mod-stack interaction is stable enough for routine operation;
- Workshop install/update/rollback procedure remains repeatable and documented.

## Next feature release candidate — v0.0.11

The next substantive Alpha release should focus first on **awake-player survival protection**, not broad world-resource compensation.

Proposed product semantics:

```text
Current/default behavior
    World clock advances proportionally during partial sleep.
    External world systems continue to follow vanilla world time.

Awake-player protection
    Supported awake-player hunger/thirst/fatigue/nutrition/weight progression
    is normalized toward native real-time pacing during partial sleep.

Sleeping players
    Never normalized by the awake-player protection path.
    Vanilla sleeping physiology remains authoritative.

All living players asleep
    Enshrouded Sleep restores native MinutesPerDay.
    Vanilla full-sleep acceleration owns the state.
```

Exact administrator configuration and default value will be chosen only after SPIKE-006 active-effect/safety evidence.

## Later feature candidate — world-system progression policy

After awake-player protection is stable, return to SPIKE-005 compensation feasibility.

Potential future semantics:

```text
WORLD_TIME (default/current)
    External world-time-driven systems follow accelerated calendar time.

SIMULATION_TIME
    Only explicitly supported, evidence-backed subsystem adapters are
    compensated during normal partial sleep.

ADVANCED (future)
    Optional per-subsystem policy using the same adapter architecture.
```

Unsupported systems must remain vanilla and be documented rather than silently represented as compensated.

## Public Beta / v0.1.x

Public Beta focuses on stabilization:

- complete remaining MVP acceptance-matrix items;
- establish a compatibility matrix;
- stabilize any SPIKE-006-approved awake-player protection;
- document major world-time systems;
- stabilize any later SPIKE-005-approved subsystem compensation;
- improve administrator UX/distribution;
- reduce or consolidate obsolete diagnostics where appropriate;
- establish repeatable Build 42 regression procedures.

## v1.0 readiness

A stable `v1.0` requires stable server/client synchronization, reliable representative multiplayer behavior, no known high-severity player/save/world-state risk, documented world-time interactions, reliable install/upgrade/disable/rollback procedures, concise administration, and compatibility claims limited to tested combinations.

## Post-MVP candidates

Possible future features include player-facing compression notices, configuration presets, expanded per-subsystem progression controls, administrator observability tools, and compatibility helpers.

## Explicit non-goals

The project is not trying to support local/standalone single-player, replace vanilla fatigue/sleep eligibility, create a separate readiness/voting system, globally fast-forward active simulation, patch Project Zomboid Java/core files for ordinary Workshop distribution, guarantee compatibility with every mod, or preemptively compensate every world-time-driven system.
