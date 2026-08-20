# Roadmap

This is the **single canonical roadmap** for Enshrouded Sleep. The top-level README links here but intentionally does not duplicate roadmap content.

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player support is not a project goal.

## Current phase — Public Alpha

Status: **Public Alpha / preparing first Steam Workshop publication and field validation**  
Current version: `v0.0.10`  
Behaviorally validated platform baseline: Project Zomboid `42.20.3`

The pre-alpha technical gates are complete. [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) returned **GO** after controlled v0.0.9/v0.0.10 health/survival testing.

The repository is now structured as a Workshop item with one authoritative deployable mod tree:

```text
Contents/mods/pz-enshrouded-sleep/
```

The permanent Steam Workshop ID and publication artwork remain pending the first upload. See [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md).

## Immediate Public Alpha publication steps

1. Validate `preview.png` (and any `poster.png`/`icon.png` used) against the current Build 42 game-generated `ModTemplate`.
2. Complete [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md), including current Indie Stone policy/terms review and provenance checks.
3. Upload v0.0.10 through Project Zomboid `Workshop -> Create and Update Items`.
4. Record and preserve the permanent Steam Workshop ID.
5. Prefer an unlisted/private dress rehearsal if available and inspect the subscribed payload.
6. Run a dedicated-server smoke test using the Workshop-distributed copy.
7. Make the Public Alpha Workshop item public/broadly announced after the packaged deployment path is verified.

## Evidence established before Public Alpha

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
- diagnostic forced-compression safety handoff when the single connected test player sleeps.

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
- characterize non-health world-time systems such as spoilage, crops, generators, corpse decay, composting and weather;
- characterize pathological survival states not exercised in SPIKE-004 where safe/practical: sickness, poisoning, zombie infection/fever, and extreme thermal injury;
- identify compatibility problems with other sleep/recovery or world-time-driven mods;
- observe client pacing during admin/sandbox changes without the aggressive repeated factor changes used in SPIKE-004;
- validate install/update/rollback through the permanent Steam Workshop item rather than development copies.

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
- representative live mod-stack interaction is stable enough for routine operation;
- Workshop install/update/rollback procedure is repeatable and documented.

## Public Beta / v0.1.x

Public Beta focuses on stabilization:

- complete remaining MVP acceptance-matrix items;
- establish a compatibility matrix;
- document major world-time systems;
- decide whether any measured subsystem needs targeted compensation;
- improve administrator UX/distribution;
- reduce or consolidate obsolete diagnostics where appropriate;
- establish repeatable Build 42 regression procedures.

## v1.0 readiness

A stable `v1.0` requires stable server/client synchronization, reliable representative multiplayer behavior, no known high-severity player/save/world-state risk, documented world-time interactions, reliable install/upgrade/disable/rollback procedures, concise administration, and compatibility claims limited to tested combinations.

## Post-MVP candidates

Possible future features include player-facing compression notices, configuration presets, selected evidence-based compensation policies, administrator observability tools, and compatibility helpers.

## Explicit non-goals

The project is not trying to support local/standalone single-player, replace vanilla fatigue/sleep eligibility, create a separate readiness/voting system, globally fast-forward active simulation, guarantee compatibility with every mod, or preemptively compensate every world-time-driven system.
