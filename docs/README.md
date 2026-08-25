# Enshrouded Sleep Documentation

Detailed design, testing, deployment, validation evidence, spikes, architecture decisions, and Steam Workshop publication guidance live under `docs/`. The top-level README remains the player/server-admin landing page.

## Current project state

- Version: `v0.0.10`
- Status: **Public Alpha**
- Runtime scope: **multiplayer servers only; local/standalone single-player is out of scope**
- Core sleep/clock architecture: validated on Project Zomboid `42.20.3`
- Steam Workshop ID: `3786842301`
- Public Alpha Workshop validation: dedicated-server/client acquisition and live two-player regression **PASS**
- SPIKE-004: **complete / GO for Public Alpha**
- SPIKE-005: **open / world-system characterization and later compensation feasibility**
- SPIKE-006: **in progress / passive normalization GO; active-effects and safety regression next**
- Health/survival result: awake acute injury/body-health loss approximately real-time bound; hunger/thirst/fatigue and core nutrition stores approximately world/calendar-time bound; resting endurance recovery approximately real-time bound under tested conditions
- Awake-protection result: the diagnostics-only tick-driven normalizer held measurable awake Hunger/Thirst/Fatigue/Calories/Protein/Weight progression approximately at native 1x while world/calendar time ran at approximately 20x; Carbohydrates/Lipids remain to be tested away from clamps
- Confirmed external world-time examples: food aging, generator fuel, vehicle fuel, and vehicle battery drain under the tested conditions
- Repository packaging: Workshop-compatible root with one authoritative runtime tree under `Contents/mods/pz-enshrouded-sleep/`
- Current focus: SPIKE-006 active-effects/safety regression, v0.0.11 awake-player protection feasibility, larger-population field validation, and live lifecycle behavior

## Start here

- [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md) — publication/update workflow, Workshop package layout, permanent ID handling, and Workshop-description guidance.
- [`DEPLOYMENT.md`](DEPLOYMENT.md) — Public Alpha installation, monitoring, diagnostics, and rollback guidance.
- [`ROADMAP.md`](ROADMAP.md) — **single canonical project roadmap** and release-stage criteria.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — proportional compression, vanilla handoff, client synchronization, diagnostic forced compression, and time-domain boundaries.

## Specification and testing

- [`REQUIREMENTS.md`](REQUIREMENTS.md) — canonical MVP requirements and acceptance matrix.
- [`TESTING.md`](TESTING.md) — smoke/regression procedures and Public Alpha field-testing guidance.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — consolidated evidence from v0.0.1 onward.
- [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) — mandatory release/Workshop publication gate.

## Formal spike investigations

- [`spikes/SPIKE-001-minutes-per-day-feasibility.md`](spikes/SPIKE-001-minutes-per-day-feasibility.md) — proved `MinutesPerDay` calendar compression without global active-simulation acceleration.
- [`spikes/SPIKE-002-vanilla-sleep-lifecycle.md`](spikes/SPIKE-002-vanilla-sleep-lifecycle.md) — established vanilla population/sleep/full-sleep semantics.
- [`spikes/SPIKE-003-client-clock-synchronization.md`](spikes/SPIKE-003-client-clock-synchronization.md) — diagnosed/fixed client day-length pacing mismatch.
- [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md) — completed health/survival time-domain investigation; **GO for Public Alpha**.
- [`spikes/SPIKE-005-world-system-time-domains.md`](spikes/SPIKE-005-world-system-time-domains.md) — **open**; characterizes non-health world systems and grades later compensation feasibility.
- [`spikes/SPIKE-006-awake-player-protection.md`](spikes/SPIKE-006-awake-player-protection.md) — **in progress; passive mechanism GO**; investigates safe server-authoritative protection of awake hunger/thirst/fatigue/nutrition/weight during partial-sleep calendar compression.
- [`spikes/SPIKE-006-FIRST-TEST.md`](spikes/SPIKE-006-FIRST-TEST.md) — idle/passive diagnostics-only 1x/20x prototype procedure used to establish feasibility.
- [`spikes/SPIKE-006-ACTIVE-EFFECTS-TEST.md`](spikes/SPIKE-006-ACTIVE-EFFECTS-TEST.md) — next regression for eating/drinking/activity, Carbohydrates/Lipids away from clamps, sleep suspension, and second-player-join safety.

See [`spikes/README.md`](spikes/README.md) for the spike convention.

## Architecture Decision Records

- [`adr/ADR-000-record-format.md`](adr/ADR-000-record-format.md) — ADR process/format convention.
- [`adr/ADR-001-use-minutes-per-day-for-partial-sleep.md`](adr/ADR-001-use-minutes-per-day-for-partial-sleep.md) — use `MinutesPerDay`, not global simulation fast-forward.
- [`adr/ADR-002-extend-vanilla-sleep-lifecycle.md`](adr/ADR-002-extend-vanilla-sleep-lifecycle.md) — extend vanilla lifecycle and hand full sleep back to vanilla.
- [`adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md`](adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md) — explicitly mirror authoritative day-length pacing to clients.

SPIKE-006 may justify a new ADR only if runtime evidence supports a durable awake-player protection architecture. SPIKE-005 may later justify a separate world-system progression-policy ADR.

See [`adr/README.md`](adr/README.md) for the ADR convention.

## Repository-level files

- [`../README.md`](../README.md) — public project overview/status.
- [`../workshop.txt`](../workshop.txt) — Project Zomboid Workshop item descriptor.
- [`../CHANGELOG.md`](../CHANGELOG.md) — version/change history.
- [`../COMPLIANCE.md`](../COMPLIANCE.md) — Project Zomboid mod-policy/compliance entry point.
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) — redistributed-material and prior-art provenance.
- [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) — creative/promotional asset licensing boundary.
- [`../LICENSE`](../LICENSE) — Apache License 2.0 source-code license.
- [`../NOTICE`](../NOTICE) — project notices and non-affiliation statements.

## Documentation policy

Detailed experiments, validation evidence, release procedures, ADRs, compatibility notes, and roadmap changes belong under `docs/`. The top-level README should remain understandable to a player/server administrator without duplicating experimental history.
