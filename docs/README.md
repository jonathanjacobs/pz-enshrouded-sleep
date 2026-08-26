# Enshrouded Sleep Documentation

The top-level [`README.md`](../README.md) is the public/player landing page. Detailed engineering and administration material lives here.

To prevent documentation drift, [`DOCUMENTATION_OWNERSHIP.md`](DOCUMENTATION_OWNERSHIP.md) defines which file owns each kind of mutable project information. Secondary documents should link to the canonical source instead of maintaining parallel copies of formulas, validation results, roadmaps, or configuration explanations.

## Core documents

- [`REQUIREMENTS.md`](REQUIREMENTS.md) — normative runtime behavior and supported scope.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — implementation design, authority boundaries, and component responsibilities.
- [`DEPLOYMENT.md`](DEPLOYMENT.md) — server installation, configuration, monitoring, diagnostics, and rollback.
- [`TESTING.md`](TESTING.md) — current smoke, regression, and Public Beta field-test procedures.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — concise validation chronology and decisions.
- [`ROADMAP.md`](ROADMAP.md) — current work, Public Beta exit criteria, and later goals.
- [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md) — Workshop packaging and publication/update procedure.
- [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) — mandatory public-release gate.

## Evidence and design decisions

Detailed experiments belong under [`spikes/`](spikes/). Durable architectural decisions belong under [`adr/`](adr/).

Current major investigations include:

- [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md) — health/survival time-domain classification.
- [`spikes/SPIKE-005-world-system-time-domains.md`](spikes/SPIKE-005-world-system-time-domains.md) — external world-system time domains and compensation feasibility.
- [`spikes/SPIKE-006-awake-player-protection.md`](spikes/SPIKE-006-awake-player-protection.md) — awake-player survival protection investigation supporting the Public Beta implementation.

## Compliance and provenance

- [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md) — repository development/release rules derived from the current Indie Stone modding-policy requirements.
- [`../COMPLIANCE.md`](../COMPLIANCE.md) — project compliance entry point.
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) — redistributed-material and prior-art provenance.
- [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) — creative/promotional asset licensing boundary.
- [`../LICENSE`](../LICENSE) and [`../NOTICE`](../NOTICE) — source licensing and project notices.

## Historical/release records

- [`../CHANGELOG.md`](../CHANGELOG.md) — user/release-facing change history.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — technical validation chronology.

The changelog should summarize what changed; validation history should summarize what was established; SPIKE documents retain the detailed evidence. Those three records should not reproduce each other verbatim.
