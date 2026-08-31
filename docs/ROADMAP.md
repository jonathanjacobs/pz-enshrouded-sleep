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

`main` now carries the optional **Rested / Well Rested** reward layer developed on `feature/sleep-benefits` for servers where sleeping is permitted but not required. The feature is still unreleased and remains disabled by default until explicitly enabled by a server administrator.

## SPIKE-007 — voluntary sleep rewards

Goal: determine whether optional sleep can provide a modest positive incentive without becoming mandatory or distorting combat/skill balance.

Current feature-branch defaults:

- `<6` game hours slept → no new benefit;
- `6–<9` hours → **Rested**, +5% XP for 12 game hours;
- `>=9` hours → **Well Rested**, +5% XP and +10% Endurance recovery for 24 game hours;
- all thresholds, durations, and percentages are server sandbox options;
- benefits do not stack;
- Rested / Well Rested use an Enshrouded Sleep-owned `ISUIElement` Moodle renderer and original artwork; no external Moodle framework is required;
- the renderer follows the player's current B42 Moodle size and includes read-only Lifestyle stack coexistence when Lifestyle is detected.

Completed checkpoint: the ADR-004 server-authoritative XP path passed a one-player dedicated-server run at an unambiguous `100%` setting, producing exact flat bonus arithmetic across Carving, Fitness, Sprinting, and Strength without recursion or a relevant runtime error. The configured percentage is a direct input to the validated formula, and the module has no access-level/admin-mode branch; default `5%` and non-admin behavior are not separate implementation gates.

SPIKE-007 is accepted for integration into `main`. Broader two-player validation of reward classification, XP gain, positive Endurance recovery, expiry/reconnect/death behavior, feature-only rollback, built-in Moodle display/scaling, and vanilla/Lifestyle stack coexistence will be collected during the next production release. The live-validation plan remains in [`spikes/SPIKE-007-sleep-benefits.md`](spikes/SPIKE-007-sleep-benefits.md) and tracking issue [#10](https://github.com/jonathanjacobs/pz-enshrouded-sleep/issues/10).

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
