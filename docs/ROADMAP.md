# Roadmap

This is the single canonical roadmap for Enshrouded Sleep. Current runtime semantics belong in [`REQUIREMENTS.md`](REQUIREMENTS.md), implementation detail in [`ARCHITECTURE.md`](ARCHITECTURE.md), and completed evidence in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

## Current phase — Public Beta field validation

The current priority is broad multiplayer evidence for the awake-player protection path and the existing proportional-sleep/client-sync architecture under real server conditions.

### Field goals

- exercise 3–12+ living-player populations and multiple sleeping fractions;
- verify multiple awake players can be protected simultaneously while sleepers remain vanilla-authoritative;
- exercise joins, disconnects, deaths, respawns, and rapidly changing denominators;
- repeat sleep/wake cycles across long sessions;
- monitor client clock continuity and exact baseline restoration;
- observe eating/drinking/activity behavior under natural multiplayer partial sleep;
- characterize CPU/server cost and normal log volume at larger populations;
- identify conflicts with mods that alter sleep, `MinutesPerDay`, CharacterStats, nutrition, timed actions, or chat UI;
- validate protection-only soft rollback and full-mod rollback in normal operations;
- complete the dedicated opt-in sleep-notification smoke test before promoting that feature out of `Unreleased`;
- run focused regression checkpoints after relevant Project Zomboid updates, with 42.20.4 currently recorded for startup/baseline/client-sync compatibility.

Verbose diagnostics should be used for focused evidence windows rather than left enabled continuously.

## Public Beta exit criteria

Move toward a stable release candidate when representative field evidence supports all of the following:

- no recurring clock-jump/client synchronization defect during ordinary play;
- no global acceleration of awake active simulation;
- reliable baseline restoration and vanilla all-asleep handoff;
- awake-player protection remains stable across representative multiplayer populations;
- common direct effects such as eating, drinking, activity, sleep/wake, and lifecycle changes are not materially distorted;
- sleeping-player physiology remains outside the correction path;
- joins/disconnects/deaths/respawns do not leave stale player correction state;
- CPU/log volume is operationally acceptable;
- representative mod-stack interaction is stable enough for routine use;
- opt-in player-facing notifications complete their dedicated smoke test without repeated spam or coupling to sleep/time behavior;
- major external world-time side effects are documented/accepted or addressed through separate evidence-backed work;
- Workshop install/update/rollback is repeatable.

## SPIKE-005 — external world systems

Continue subsystem-specific characterization of systems affected by accelerated game-world time. Existing controlled evidence includes food aging/spoilage, generator fuel, vehicle fuel, and vehicle battery drain; detailed measurements remain in [`spikes/SPIKE-005-world-system-time-domains.md`](spikes/SPIKE-005-world-system-time-domains.md).

Priority unresolved areas include:

- generator wear/condition;
- frozen-food behavior;
- farming/crop maturation;
- unloaded/off-screen catch-up behavior where relevant;
- compensation feasibility and save/synchronization risk for any subsystem proposed for special handling.

SPIKE-005 is not a blanket mandate to compensate world systems. Unsupported systems remain vanilla until evidence justifies a specific policy.

## Administrator UX

Potential follow-up: a read-only admin runtime status panel showing live population, sleepers, effective compression, native/current `MinutesPerDay`, and active mode. This should remain separate from editable sandbox configuration.

## Stable/v1.0 readiness

A stable release requires reliable representative multiplayer behavior, no known high-severity player/save/world-state risk, concise administration, repeatable deployment/rollback, documented world-time interactions, and compatibility claims limited to tested combinations.

## Non-goals

The project is not trying to:

- support local/standalone single-player;
- replace vanilla fatigue/sleep eligibility;
- create a readiness/voting system;
- globally fast-forward active simulation;
- patch Project Zomboid Java/core files for ordinary Workshop distribution;
- guarantee compatibility with every mod;
- preemptively compensate every world-time-driven system.
