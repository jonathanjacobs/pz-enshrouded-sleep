# Enshrouded Sleep Documentation

The repository root is intentionally kept concise for players and server administrators. Detailed design, testing, deployment, and development records live here.

## Start here

- [`DEPLOYMENT.md`](DEPLOYMENT.md) — Public Alpha installation, monitoring, diagnostics, and rollback guidance.
- [`ROADMAP.md`](ROADMAP.md) — current Public Alpha goals, Public Beta exit criteria, and longer-term direction.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — how proportional calendar compression, vanilla full-sleep handoff, and client clock-state synchronization work.

## Specification and testing

- [`REQUIREMENTS.md`](REQUIREMENTS.md) — canonical MVP requirements and acceptance criteria.
- [`TESTING.md`](TESTING.md) — current smoke/regression tests and Public Alpha field-testing guidance.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — consolidated evidence from the v0.0.1–v0.0.7 development/test sequence.

## Engineering records

- [`spikes/`](spikes/) — focused exploratory investigations. Historical spike-style work is summarized in `VALIDATION_HISTORY.md`; future spikes use `SPIKE-NNN-*.md`.
- [`adr/`](adr/) — architecture decision records for durable cross-cutting decisions.

## Repository-level files

- [`../README.md`](../README.md) — public project overview and quick-start information.
- [`../CHANGELOG.md`](../CHANGELOG.md) — human-readable version/change history.
- [`../LICENSE`](../LICENSE) — project license.
- [`../NOTICE`](../NOTICE) — project notices.

## Documentation policy

New implementation investigations, ADRs, compatibility notes, and detailed test evidence should be added under `docs/` rather than expanding the top-level README. The top-level README should remain understandable to a new visitor who only wants to know what the mod does, its current maturity, how to install it, and where it is going.
