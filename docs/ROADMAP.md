# Roadmap

Status: **v1.0.x stable maintenance**

Do not update for: test results ([`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md)), the details of an individual defect or question (its GitHub Issue), or release criteria ([`RELEASING.md`](RELEASING.md#release-checklist)).

Track milestones, their order, known risks, and the evidence required to leave each milestone. Cite issues here by number rather than restating them. Runtime semantics belong in the [requirements](DESIGN.md#requirements).

## Current phase — v1.0.x stable maintenance

v1.0.2 is the current release, uploaded to the existing Steam Workshop item on 2026-09-29 and tagged as a [GitHub release](https://github.com/jonathanjacobs/pz-enshrouded-sleep/releases/tag/v1.0.2). It is the first Workshop upload since v1.0.0 (2026-08-31) and carries the v1.0.1 relabel, which was tagged on GitHub but never uploaded. v1.0.2 changes no gameplay or configuration. Its Workshop package has a one-player smoke test on Project Zomboid 42.21.0; the WHG live evidence and 42.21.0 checkpoint for the unchanged gameplay code are also in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

Ongoing work:

- watch the items listed in the [release checklist](RELEASING.md#v101-release-record) during normal play;
- run the update checks in [`TESTING.md`](TESTING.md) after each Project Zomboid release.

Continue broader population and mod-stack coverage without implying universal compatibility. Use verbose diagnostics only for focused evidence windows.

The optional **Rested / Well Rested** reward layer is part of v1.0.x and remains disabled by default until explicitly enabled by a server administrator.

## SPIKE-007 — voluntary sleep rewards

Goal: determine whether optional sleep can provide a modest positive incentive without becoming mandatory or distorting combat/skill balance.

Current defaults:

- `<8` game hours slept → no new benefit;
- `8–12` hours (inclusive) → **Rested**, +10% XP for 4 game hours;
- `>12` hours → **Well Rested**, +10% XP and +10% Endurance recovery for 6 game hours;
- all thresholds, durations, and percentages are server sandbox options;
- benefits do not stack;
- Rested / Well Rested use an Enshrouded Sleep-owned `ISUIElement` Moodle renderer and original artwork; no external Moodle framework is required;
- the renderer follows the player's current B42 Moodle size and includes read-only Lifestyle stack coexistence when Lifestyle is detected.

Completed checkpoint: the ADR-004 server-authoritative XP path passed a one-player dedicated-server run at an unambiguous `100%` setting, producing exact flat bonus arithmetic across Carving, Fitness, Sprinting, and Strength without recursion or a relevant runtime error. The configured percentage is a direct input to the validated formula, and the module has no access-level/admin-mode branch; the current default `10%` and non-admin behavior are not separate implementation gates.

Completed live validation (2026-09-28): WHG v1.0.0 server logs showed all 301 live sleep decisions matching the active configuration across 58 sessions, along with correct durations, expiry, and restart persistence, and no errors. That evidence is accepted for the `8`/`12`-hour defaults, and tracking issue [#10](https://github.com/jonathanjacobs/pz-enshrouded-sleep/issues/10) is closed. Details are in [`spikes/SPIKE-007-sleep-benefits.md`](spikes/SPIKE-007-sleep-benefits.md).

Not yet observed live, and to check opportunistically rather than as release gates: death clearing, feature-disable clearing, Moodle display/scaling, and vanilla/Lifestyle stack coexistence.

## SPIKE-005 — external world systems

Existing controlled evidence covers food aging/spoilage, generator fuel, vehicle fuel, and vehicle battery drain. Generator wear, frozen food, farming/crops, unloaded catch-up behavior, and compensation feasibility remain subsystem-specific open questions. Detailed measurements and future test protocols remain in [`spikes/SPIKE-005-world-system-time-domains.md`](spikes/SPIKE-005-world-system-time-domains.md).

Unsupported systems remain vanilla until evidence justifies a specific policy; SPIKE-005 is not a blanket mandate to compensate world systems.

## Later work

- Consider a read-only administrator status panel for population, sleepers, compression, and active mode.
- Expand representative population and mod-stack coverage without claiming universal compatibility.

## Stable-release boundary

A stable release requires reliable multiplayer behavior in normal play, no known high-severity player/save/world-state risk, documented deployment and rollback, documented world-time interactions, and compatibility claims limited to tested combinations. Optional experimental features require their own validation gate before inclusion.

## Non-goals

The project does not aim to support standalone single-player, replace vanilla sleep eligibility, create a readiness/voting system, globally fast-forward active simulation, patch Project Zomboid Java/core files for ordinary distribution, guarantee compatibility with every mod, or preemptively compensate every world-time-driven system.
