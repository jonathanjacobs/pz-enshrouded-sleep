# Enshrouded Sleep Documentation

Detailed design, testing, deployment, validation evidence, spikes, and architecture decisions live under `docs/`. The top-level README remains the player/server-admin landing page.

## Current project state

- Version: `v0.0.10`
- Status: **Public Alpha**
- Runtime scope: **multiplayer servers only; local/standalone single-player is out of scope**
- Core sleep/clock architecture: validated on Project Zomboid `42.20.3`
- SPIKE-004: **complete / GO for Public Alpha**
- Health/survival result: awake acute injury/body-health loss approximately real-time bound; hunger/thirst/fatigue and core nutrition stores approximately world/calendar-time bound; resting endurance recovery approximately real-time bound under tested conditions
- Current focus: larger-population field validation, live lifecycle behavior, non-health world-time systems, and pathological survival states not exercised in SPIKE-004

## Start here

- [`DEPLOYMENT.md`](DEPLOYMENT.md) — Public Alpha installation, monitoring, diagnostics, and rollback guidance.
- [`ROADMAP.md`](ROADMAP.md) — **single canonical project roadmap** and release-stage criteria.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — proportional compression, vanilla handoff, client synchronization, diagnostic forced compression, and time-domain boundaries.

## Specification and testing

- [`REQUIREMENTS.md`](REQUIREMENTS.md) — canonical MVP requirements and acceptance matrix.
- [`TESTING.md`](TESTING.md) — smoke/regression procedures and Public Alpha field-testing guidance.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — consolidated evidence from v0.0.1 onward.

## Formal spike investigations

- [`spikes/SPIKE-001-minutes-per-day-feasibility.md`](spikes/SPIKE-001-minutes-per-day-feasibility.md) — proved `MinutesPerDay` calendar compression without global active-simulation acceleration.
- [`spikes/SPIKE-002-vanilla-sleep-lifecycle.md`](spikes/SPIKE-002-vanilla-sleep-lifecycle.md) — established vanilla population/sleep/full-sleep semantics.
- [`spikes/SPIKE-003-client-clock-synchronization.md`](spikes/SPIKE-003-client-clock-synchronization.md) — diagnosed/fixed client day-length pacing mismatch.
- [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md) — completed health/survival time-domain investigation; **GO for Public Alpha**.

See [`spikes/README.md`](spikes/README.md) for the spike convention.

## Architecture Decision Records

- [`adr/ADR-000-record-format.md`](adr/ADR-000-record-format.md) — ADR process/format convention.
- [`adr/ADR-001-use-minutes-per-day-for-partial-sleep.md`](adr/ADR-001-use-minutes-per-day-for-partial-sleep.md) — use `MinutesPerDay`, not global simulation fast-forward.
- [`adr/ADR-002-extend-vanilla-sleep-lifecycle.md`](adr/ADR-002-extend-vanilla-sleep-lifecycle.md) — extend vanilla lifecycle and hand full sleep back to vanilla.
- [`adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md`](adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md) — explicitly mirror authoritative day-length pacing to clients.

SPIKE-004 did not require a new ADR because its results did not change the chosen architecture.

See [`adr/README.md`](adr/README.md) for the ADR convention.

## Repository-level files

- [`../README.md`](../README.md) — public project overview/status.
- [`../CHANGELOG.md`](../CHANGELOG.md) — version/change history.
- [`../COMPLIANCE.md`](../COMPLIANCE.md) — Project Zomboid mod-policy/compliance entry point.
- [`../LICENSE`](../LICENSE) — Apache License 2.0 source-code license.
- [`../NOTICE`](../NOTICE) — project notices.

## Documentation policy

New investigations, ADRs, compatibility notes, detailed evidence, and roadmap changes belong under `docs/`. The top-level README should remain understandable to a new server administrator or player without duplicating engineering history.
