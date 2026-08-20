# Roadmap

This is the **single canonical roadmap** for Enshrouded Sleep. The top-level README links here but intentionally does not duplicate roadmap content.

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player support is not a project goal.

## Current phase — Pre-Public-Alpha validation

Status: **Public Alpha candidate; deployment paused pending final survival-state characterization**  
Current development version: `v0.0.10`  
Behaviorally validated platform baseline: Project Zomboid `42.20.3`

The core two-player sleep/clock architecture is working. The remaining pre-alpha gate is [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md).

### Evidence established by v0.0.9

The controlled multiplayer run showed:

- awake bleeding health loss remained approximately real-time bound (`~0.993x` at ~5x compression);
- measured `BleedingTime` and scratch progression remained approximately `1x`;
- no rapid awake-player bleed-out from `MinutesPerDay` compression was observed;
- calories, carbohydrates, proteins and lipids tracked 5x/10x calendar compression almost exactly;
- server/client `MinutesPerDay` synchronization and baseline restoration remained correct;
- `TrueMultiplier` remained `1.0` during partial compression.

This proves player systems use different time domains.

### Why v0.0.10 exists

v0.0.9 could not observe hunger, thirst, fatigue, endurance and several related values because the diagnostic used outdated Stats/Moodle access assumptions.

v0.0.10 corrects those probes using `CharacterStat`, `MoodleType` and Nutrition APIs. It also adds a tightly gated **one-connected-player multiplayer-server** forced-compression test mode.

The test mode requires:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor>1
exactly one living player connected
player awake
```

If the player sleeps or another living player connects, the override restores baseline and suspends itself.

### Current blocker

Run one focused v0.0.10 server test and classify:

- hunger;
- thirst;
- fatigue;
- endurance;
- stress/panic/pain where useful;
- sickness/food sickness/poison where practical;
- zombie infection/fever where practical;
- temperature/wetness/cold state where practical.

### Recommended v0.0.10 test

```text
Normal multiplayer test server
Exactly one connected living player

Phase A: factor=1.0, baseline, 60–90 s
Phase B: factor=5.0, expected MPD≈18 from baseline 90, 60–90 s
Phase C: factor=1.0, restored baseline, 60–90 s
```

Verify `CAPABILITIES`, server/client `MinutesPerDay`, and ordinary `TrueMultiplier` behavior before interpreting rates.

### Pre-alpha exit criteria

Move to Public Alpha when:

- v0.0.10 loads cleanly on server and connected client;
- corrected CharacterStat/Moodle telemetry is verified or remaining gaps are explicitly characterized;
- baseline → forced factor-5 → restored-baseline telemetry is collected with exactly one connected player;
- high-severity survival variables are sufficiently classified;
- no unacceptable rapid awake-player survival failure is observed, or an acceptable mitigation/configuration bound is adopted;
- the normal two-player sleep regression still passes;
- SPIKE-004 records a formal **GO / CONDITIONAL GO / NO-GO** decision.

## Public Alpha — next

If SPIKE-004 produces a GO or acceptable conditional GO, deploy to a real multiplayer server with:

```text
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
```

Primary goals:

- exercise proportional sleep with 3–12+ players;
- observe joins, disconnects, deaths, respawns, and repeated sleep/wake cycles;
- verify clock continuity and normal-speed awake gameplay over long sessions;
- validate survival behavior under ordinary live conditions;
- characterize non-health world-time systems such as spoilage, crops, generators, corpse decay, composting and weather;
- identify compatibility problems with other sleep/recovery or world-time-driven mods.

### Public Alpha exit criteria

Move toward Public Beta when field evidence supports:

- no recurring clock-jump/client synchronization defect;
- no global acceleration of awake simulation;
- no repeated sleep-duration pathology;
- no high-severity awake-player health/survival effect caused by partial compression;
- reliable baseline restoration and vanilla full-sleep handoff at larger populations;
- proportional behavior validated with more than two living players;
- configuration inheritance validated across alternate native settings;
- operationally acceptable log/error volume;
- major world-time side effects documented, accepted, or addressed.

## Public Beta / v0.1.x

Public Beta focuses on stabilization: complete the MVP acceptance matrix, establish a compatibility matrix, document major world-time systems, decide whether any measured system needs targeted compensation, improve admin UX/distribution, reduce obsolete diagnostics, and establish B42 regression procedures.

## v1.0 readiness

A stable `v1.0` requires stable server/client synchronization, reliable representative multiplayer behavior, no known high-severity player/save/world-state risk, documented world-time interactions, reliable install/upgrade/disable/rollback procedures, concise administration, and compatibility claims limited to tested combinations.

## Post-MVP candidates

Possible future features include player-facing compression notices, configuration presets, selected evidence-based compensation policies, administrator observability tools, and compatibility helpers.

## Explicit non-goals

The project is not trying to support local/standalone single-player, replace vanilla fatigue/sleep eligibility, create a separate readiness/voting system, globally fast-forward active simulation, guarantee compatibility with every mod, or preemptively compensate every world-time-driven system.
