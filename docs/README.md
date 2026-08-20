# Enshrouded Sleep Documentation

Detailed design, testing, deployment, validation evidence, spikes, and architecture decisions live under `docs/`. The top-level README remains a player/server-admin landing page.

## Current project state

- Development version: `v0.0.10`
- Core sleep/clock architecture: validated on Project Zomboid `42.20.3`
- v0.0.9 two-player health result: awake bleeding/injury progression approximately real-time bound; core nutrition stores approximately proportional to calendar compression
- Current blocker: run the v0.0.10 single-player diagnostic-forced-compression test and classify hunger/thirst/fatigue/endurance and related high-severity survival state
- WHG Public Alpha deployment: **paused pending completion of SPIKE-004**

## Start here

- [`DEPLOYMENT.md`](DEPLOYMENT.md) — deployment gate, installation, monitoring, diagnostics, and rollback guidance.
- [`ROADMAP.md`](ROADMAP.md) — **single canonical project roadmap** and release-stage criteria.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — proportional compression, vanilla handoff, client synchronization, diagnostic forced compression, and time-domain boundaries.

## Specification and testing

- [`REQUIREMENTS.md`](REQUIREMENTS.md) — canonical MVP requirements and acceptance matrix.
- [`TESTING.md`](TESTING.md) — current smoke/regression procedures and the single-player v0.0.10 SPIKE-004 survival-state test.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — consolidated evidence from v0.0.1 onward.

## Formal spike investigations

- [`spikes/SPIKE-001-minutes-per-day-feasibility.md`](spikes/SPIKE-001-minutes-per-day-feasibility.md) — proved `MinutesPerDay` calendar compression without global active-simulation acceleration.
- [`spikes/SPIKE-002-vanilla-sleep-lifecycle.md`](spikes/SPIKE-002-vanilla-sleep-lifecycle.md) — established vanilla population/sleep/full-sleep semantics.
- [`spikes/SPIKE-003-client-clock-synchronization.md`](spikes/SPIKE-003-client-clock-synchronization.md) — diagnosed/fixed client day-length pacing mismatch.
- [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md) — **current Public Alpha blocker**; maps awake-player health/survival behavior under calendar compression.

See [`spikes/README.md`](spikes/README.md) for the spike convention.

## Architecture Decision Records

- [`adr/ADR-000-record-format.md`](adr/ADR-000-record-format.md) — ADR process/format convention.
- [`adr/ADR-001-use-minutes-per-day-for-partial-sleep.md`](adr/ADR-001-use-minutes-per-day-for-partial-sleep.md) — use `MinutesPerDay`, not global simulation fast-forward.
- [`adr/ADR-002-extend-vanilla-sleep-lifecycle.md`](adr/ADR-002-extend-vanilla-sleep-lifecycle.md) — extend vanilla lifecycle and hand full sleep back to vanilla.
- [`adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md`](adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md) — explicitly mirror authoritative day-length pacing to clients.

See [`adr/README.md`](adr/README.md) for the ADR convention.

## Repository-level files

- [`../README.md`](../README.md) — public project overview/status; intentionally does not duplicate the roadmap.
- [`../CHANGELOG.md`](../CHANGELOG.md) — human-readable version/change history.
- [`../COMPLIANCE.md`](../COMPLIANCE.md) — Project Zomboid mod-policy/compliance entry point.
- [`../LICENSE`](../LICENSE) — Apache License 2.0 source-code license.
- [`../NOTICE`](../NOTICE) — project notices.

## Documentation policy

New investigations, ADRs, compatibility notes, detailed evidence, and roadmap changes belong under `docs/`. The top-level README should remain understandable to a new visitor who mainly wants to know what the mod does, its maturity, installation/configuration, and where to find the canonical engineering documents.
