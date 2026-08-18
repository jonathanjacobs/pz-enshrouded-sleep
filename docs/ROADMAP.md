# Roadmap

This roadmap describes the current direction for Enshrouded Sleep. It is intentionally evidence-driven: public-alpha findings may change priorities.

## Current phase — Public Alpha

Status: **active field-testing phase**

Current version: `v0.0.7`

Current validated platform baseline: Project Zomboid `42.20.3`

The core two-player architecture is working. Public alpha moves testing onto real multiplayer servers with larger populations and a normal mod stack.

Primary goals:

- exercise proportional sleep with 3–12+ players;
- observe repeated joins, disconnects, deaths, respawns, and sleep/wake cycles;
- verify clock continuity and normal-speed awake gameplay over long sessions;
- detect client/server synchronization edge cases that are rare in controlled tests;
- characterize world-time-driven side effects such as spoilage, crops, generators, hunger/thirst/fatigue, healing, corpse decay, composting, and weather;
- identify compatibility problems with other sleep/recovery or world-time-driven mods;
- keep deployment and rollback simple enough for live server administration.

### Public-alpha exit criteria

Move toward Public Beta when field evidence supports all of the following:

- no recurring clock-jump or client synchronization defect;
- no global acceleration of awake simulation;
- no repeated sleep-duration pathology;
- reliable baseline restoration and vanilla full-sleep handoff across larger player populations;
- proportional behavior validated with more than two living players;
- configuration inheritance validated across at least one alternate native day length and/or `FastForwardMultiplier`;
- public-server log volume and error rate remain operationally acceptable;
- major world-time-driven side effects are understood well enough to document, accept, or explicitly address;
- no known severity-high defect requires administrators to avoid normal gameplay.

## Next phase — Public Beta / v0.1.x

The Public Beta phase should focus on stabilization rather than changing the core sleep model.

Likely work:

- complete the remaining MVP acceptance matrix;
- establish a compatibility matrix for important B42 multiplayer/sleep mods;
- document expected behavior of major world-time-driven systems;
- decide whether any system requires optional real-time compensation or should intentionally follow compressed world time;
- improve administrator-facing configuration/documentation based on alpha feedback;
- reduce or remove development instrumentation that is no longer useful;
- improve distribution/installation workflow for broader public use;
- add regression checks around future Project Zomboid B42 updates.

Public Beta is the point at which the mod should be suitable for broader community testing without requiring the operator to understand its development history.

## v1.0 readiness

A stable `v1.0` should require:

- a stable, well-documented server/client synchronization architecture;
- reliable behavior across representative multiplayer population sizes;
- no known high-severity save/world-state risk caused by the mod;
- clearly documented interaction with world-time-driven systems;
- reliable installation, upgrade, disable, and rollback procedures;
- a concise administrator configuration surface;
- a clean public-facing README and support workflow;
- compatibility claims limited to combinations that have actually been tested.

## Post-MVP candidates

These are possible future features, not commitments:

- player-facing notification when partial-sleep compression begins/ends;
- configuration presets;
- optional policies for selected world-time-driven systems;
- additional administrator observability/status tools;
- compatibility helpers for specific sleep/recovery mods;
- refined behavior around edge-case player lifecycle states if public servers demonstrate a real need;
- configurable sleep windows or other non-vanilla sleep policy extensions.

The project should avoid adding these until the Public Alpha/Beta evidence shows the core mechanic is stable.

## Explicit non-goals for the current alpha

The current alpha is **not** trying to:

- replace vanilla fatigue or sleep eligibility;
- create a separate ready/not-ready voting system;
- implement custom multiplayer lobby/readiness tracking;
- globally fast-forward gameplay simulation;
- guarantee compatibility with every mod;
- compensate every world-time-driven system before observing actual field behavior.
