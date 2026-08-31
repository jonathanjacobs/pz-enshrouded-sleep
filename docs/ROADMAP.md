# Roadmap

This file owns current work and release-exit criteria. Runtime semantics belong in [`REQUIREMENTS.md`](REQUIREMENTS.md); completed evidence belongs in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

## Current phase — v1.0 release-candidate readiness

Week-long Public Beta server evidence now supports repeated proportional compression, baseline restoration, vanilla full-sleep handoff, changing multiplayer populations, and stable operation in the normal server mod stack. The observed results and their limits are recorded in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

### Remaining release-candidate evidence

- review owning-client logs from representative partial- and full-sleep transitions for clock continuity and client exceptions;
- deliberately exercise join, disconnect, death, and respawn transitions during partial sleep and check for stale correction state;
- smoke-test opt-in sleep notifications, including one-message-per-transition behavior and notification-only rollback;
- verify awake-protection soft rollback and full-mod rollback through the documented operational procedures;
- record whether CPU cost and normal log volume remain acceptable at the representative tested population;
- complete the package, provenance, policy, and deployment checks in [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md).

Continue broader population and mod-stack coverage after v1.0 without implying universal compatibility. Use verbose diagnostics only for focused evidence windows.

## SPIKE-005 — external world systems

Existing controlled evidence covers food aging/spoilage, generator fuel, vehicle fuel, and vehicle battery drain. Generator wear, frozen food, farming/crops, unloaded catch-up behavior, and compensation feasibility remain subsystem-specific open questions. Detailed measurements and future test protocols remain in [`spikes/SPIKE-005-world-system-time-domains.md`](spikes/SPIKE-005-world-system-time-domains.md).

Unsupported systems remain vanilla until evidence justifies a specific policy; SPIKE-005 is not a blanket mandate to compensate world systems.

## Later work

- Consider a read-only administrator status panel for population, sleepers, compression, and active mode.
- Run focused compatibility regressions after relevant Project Zomboid updates.
- Expand representative population and mod-stack coverage without claiming universal compatibility.

## Stable-release boundary

A stable release requires reliable representative multiplayer behavior, no known high-severity player/save/world-state risk, repeatable deployment and rollback, documented world-time interactions, and compatibility claims limited to tested combinations. Optional experimental features require their own validation gate before inclusion.

## Non-goals

The project does not aim to support standalone single-player, replace vanilla sleep eligibility, create a readiness/voting system, globally fast-forward active simulation, patch Project Zomboid Java/core files for ordinary distribution, guarantee compatibility with every mod, or preemptively compensate every world-time-driven system.
