# Enshrouded Sleep Documentation

The repository root is intentionally concise for players and server administrators. Detailed design, testing, deployment, validation evidence, spikes, and architecture decisions live here.

## Current project state

- Development version: `v0.0.8`
- Core sleep/clock architecture: validated on Project Zomboid 42.20.3
- WHG Public Alpha deployment: **paused pending SPIKE-004 health/time-domain validation**

## Start here

- [`DEPLOYMENT.md`](DEPLOYMENT.md) — deployment gate, installation, monitoring, diagnostics, and rollback guidance.
- [`ROADMAP.md`](ROADMAP.md) — current pre-alpha health gate, Public Alpha goals, Public Beta criteria, and longer-term direction.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — proportional compression, vanilla handoff, client synchronization, diagnostics, and time-domain boundaries.

## Specification and testing

- [`REQUIREMENTS.md`](REQUIREMENTS.md) — canonical MVP requirements and acceptance matrix.
- [`TESTING.md`](TESTING.md) — current smoke/regression procedures and the detailed SPIKE-004 health/time-domain test.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — consolidated evidence from v0.0.1 onward.

## Formal spike investigations

- [`spikes/SPIKE-001-minutes-per-day-feasibility.md`](spikes/SPIKE-001-minutes-per-day-feasibility.md) — proved `MinutesPerDay` calendar compression without global active-simulation acceleration.
- [`spikes/SPIKE-002-vanilla-sleep-lifecycle.md`](spikes/SPIKE-002-vanilla-sleep-lifecycle.md) — established vanilla population/sleep/full-sleep semantics.
- [`spikes/SPIKE-003-client-clock-synchronization.md`](spikes/SPIKE-003-client-clock-synchronization.md) — diagnosed/fixed client day-length pacing mismatch.
- [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md) — **current Public Alpha blocker**; maps health/survival systems under calendar compression.

See [`spikes/README.md`](spikes/README.md) for the spike convention.

## Architecture Decision Records

- [`adr/ADR-001-use-minutes-per-day-for-partial-sleep.md`](adr/ADR-001-use-minutes-per-day-for-partial-sleep.md) — use `MinutesPerDay`, not global simulation fast-forward.
- [`adr/ADR-002-extend-vanilla-sleep-lifecycle.md`](adr/ADR-002-extend-vanilla-sleep-lifecycle.md) — extend vanilla lifecycle and hand full sleep back to vanilla.
- [`adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md`](adr/ADR-003-mirror-authoritative-minutes-per-day-to-clients.md) — explicitly mirror authoritative day-length pacing to clients.

See [`adr/README.md`](adr/README.md) for the ADR convention.

## Repository-level files

- [`../README.md`](../README.md) — public project overview/status/roadmap.
- [`../CHANGELOG.md`](../CHANGELOG.md) — human-readable version/change history.
- [`../LICENSE`](../LICENSE) — project license.
- [`../NOTICE`](../NOTICE) — project notices.

## Documentation policy

New investigations, ADRs, compatibility notes, and detailed evidence should be added under `docs/` rather than expanding the top-level README. The landing README should remain understandable to a new visitor who mainly wants to know what the mod does, its maturity, how to install it, and where it is going.
