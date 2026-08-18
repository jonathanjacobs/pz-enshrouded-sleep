# Roadmap

This roadmap is evidence-driven. Findings from controlled spikes and Public Alpha field use may change priorities.

## Current phase — Pre-Public-Alpha validation

Status: **Public Alpha candidate; deployment paused pending health/time-domain characterization**

Current development version: `v0.0.8`

Current behaviorally validated platform baseline: Project Zomboid `42.20.3`

The core two-player sleep/clock architecture is working and the original clock/sleep defects are closed. Before moving onto the WHG public multiplayer server, the project is completing one additional safety gate:

- [`SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression`](spikes/SPIKE-004-health-time-domains.md)

### Current blocker

Determine whether awake-player health/survival systems become dangerously accelerated in real time while another player sleeps.

Priority variables include:

- bleeding and overall health loss;
- hunger and thirst;
- fatigue/endurance;
- wound healing;
- sickness/food sickness/poison;
- zombie infection timing;
- body temperature/wetness/cold progression;
- pain and related injury timers.

### Pre-alpha exit criteria

Move to Public Alpha when:

- v0.0.8 diagnostics load without errors;
- controlled baseline/partial/baseline health telemetry is collected;
- high-severity player-state variables are classified by time domain;
- no unacceptable rapid awake-player bleed-out, starvation/dehydration, infection progression, or comparable safety problem is observed, **or** a validated mitigation is in place;
- the normal core two-player regression still passes after the diagnostic additions;
- a formal GO / CONDITIONAL GO / NO-GO decision is recorded in SPIKE-004.

## Public Alpha — next

If SPIKE-004 produces a GO or acceptable conditional GO, deploy to a real multiplayer server with the normal Public Alpha configuration:

```text
Enabled = true
PartialSleepSpeedScale = 1.0 (unless SPIKE-004 recommends a lower initial value)
DiagnosticsEnabled = false
```

Primary goals:

- exercise proportional sleep with 3–12+ players;
- observe repeated joins, disconnects, deaths, respawns, and sleep/wake cycles;
- verify clock continuity and normal-speed awake gameplay over long sessions;
- detect client/server synchronization edge cases that are rare in controlled tests;
- validate player health/survival behavior under ordinary live conditions after the controlled spike;
- characterize non-health world-time-driven effects such as spoilage, crops, generators, corpse decay, composting, and weather;
- identify compatibility problems with other sleep/recovery or world-time-driven mods;
- keep deployment and rollback simple enough for live server administration.

### Public Alpha exit criteria

Move toward Public Beta when field evidence supports all of the following:

- no recurring clock-jump or client synchronization defect;
- no global acceleration of awake simulation;
- no repeated sleep-duration pathology;
- no high-severity awake-player health effect caused by partial compression;
- reliable baseline restoration and vanilla full-sleep handoff across larger populations;
- proportional behavior validated with more than two living players;
- configuration inheritance validated across at least one alternate native day length and/or `FastForwardMultiplier`;
- public-server log volume and error rate remain operationally acceptable;
- major world-time-driven side effects are understood well enough to document, accept, or explicitly address;
- no known severity-high defect requires administrators to avoid normal gameplay.

## Public Beta / v0.1.x

Public Beta should focus on stabilization rather than replacing the validated core sleep model.

Likely work:

- complete the remaining MVP acceptance matrix;
- establish a compatibility matrix for important B42 multiplayer/sleep mods;
- document expected behavior of major world-time-driven systems;
- decide whether any measured system needs optional real-time compensation or should intentionally follow compressed world time;
- improve administrator-facing configuration/documentation based on alpha feedback;
- reduce/remove development instrumentation no longer useful;
- improve distribution/installation workflow;
- add regression checks around future Project Zomboid B42 updates.

## v1.0 readiness

A stable `v1.0` should require:

- stable, documented server/client synchronization architecture;
- reliable behavior across representative multiplayer population sizes;
- no known high-severity player/save/world-state risk caused by the mod;
- clearly documented interaction with world-time-driven systems;
- reliable installation, upgrade, disable, and rollback procedures;
- concise administrator configuration;
- clean support/reporting workflow;
- compatibility claims limited to combinations actually tested.

## Post-MVP candidates

Possible future features, not commitments:

- player-facing notification when partial-sleep compression begins/ends;
- configuration presets;
- optional policies/compensation for selected measured world-time-driven systems;
- administrator observability/status tools;
- compatibility helpers for specific sleep/recovery mods;
- refined lifecycle handling if public-server evidence demonstrates a real need;
- configurable sleep windows or other non-vanilla sleep policy extensions.

## Explicit non-goals for the current pre-alpha/alpha work

The project is not currently trying to:

- replace vanilla fatigue or sleep eligibility;
- create a separate ready/not-ready voting system;
- implement custom lobby/readiness tracking;
- globally fast-forward active gameplay simulation;
- guarantee compatibility with every mod;
- preemptively compensate every world-time-driven system without measured evidence.
