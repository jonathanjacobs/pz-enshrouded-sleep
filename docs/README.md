# Enshrouded Sleep Documentation

Detailed design, testing, deployment, validation evidence, spikes, architecture decisions, and Steam Workshop publication guidance live under `docs/`. The top-level README remains the player/server-admin landing page.

## Current project state

- Version: `v0.1.0`
- Status: **Public Beta / multiplayer field validation**
- Runtime scope: multiplayer servers only; local/standalone single-player is out of scope
- Validated platform baseline: Project Zomboid `42.20.3`
- Steam Workshop ID: `3786842301`
- Core proportional sleep/client clock architecture: validated
- SPIKE-004: complete / health-survival time domains characterized sufficiently for release
- SPIKE-005: open / external world-system characterization and later compensation feasibility
- SPIKE-006: controlled feasibility **GO**; production awake-player protection promoted for Public Beta field validation
- Awake protection: Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, and Weight for awake living players during normal partial sleep
- Sleeping players remain vanilla-authoritative; all-living-asleep still hands control to vanilla full-sleep acceleration
- Current focus: larger-population multiplayer evidence, lifecycle transitions, long sessions, compatibility/mod-stack interactions, and rollback behavior

## Start here

- [`DEPLOYMENT.md`](DEPLOYMENT.md) — Public Beta installation, monitoring, diagnostics, soft rollback, and full rollback.
- [`ROADMAP.md`](ROADMAP.md) — single canonical roadmap and Beta exit criteria.
- [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md) — Workshop update/package workflow.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — proportional compression, vanilla handoff, client synchronization, diagnostic forced compression, and time-domain boundaries.
- [`TESTING.md`](TESTING.md) — smoke/regression and field-testing procedures.
- [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) — detailed evidence chronology.
- [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) — mandatory release/Workshop publication gate.

## SPIKE investigations

- [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md) — health/survival time-domain classification.
- [`spikes/SPIKE-005-world-system-time-domains.md`](spikes/SPIKE-005-world-system-time-domains.md) — external world-system time domains; still open.
- [`spikes/SPIKE-006-awake-player-protection.md`](spikes/SPIKE-006-awake-player-protection.md) — controlled awake-player protection investigation; passive and active-effect feasibility passed.
- [`spikes/SPIKE-006-FIRST-TEST.md`](spikes/SPIKE-006-FIRST-TEST.md) — initial passive test procedure/history.
- [`spikes/SPIKE-006-ACTIVE-EFFECTS-TEST.md`](spikes/SPIKE-006-ACTIVE-EFFECTS-TEST.md) — active-effect/sleep-safety test procedure used before Beta promotion.

The controlled 20x SPIKE-006 path showed near-native passive survival progression while the world clock remained near 20x and `TrueMultiplier=1.0`. Eating, drinking, running/sprinting, sleep suspension, wake reinitialization, Carbohydrates/Lipids away from their clamps, and clean baseline restoration were observed without a relevant Enshrouded Sleep Lua failure. Real multiplayer partial-sleep behavior is now a Public Beta field-validation target rather than a claim of completed broad validation.

## Repository-level files

- [`../README.md`](../README.md) — public overview/status
- [`../workshop.txt`](../workshop.txt) — Workshop descriptor
- [`../workshop-description.bbcode`](../workshop-description.bbcode) — canonical Steam description
- [`../CHANGELOG.md`](../CHANGELOG.md) — release history
- [`../COMPLIANCE.md`](../COMPLIANCE.md) — Project Zomboid mod-policy compliance
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) — provenance/prior-art notices
- [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) — creative asset licensing boundary
- [`../LICENSE`](../LICENSE) and [`../NOTICE`](../NOTICE) — source license/notices

## Documentation policy

Experimental detail belongs in spike/validation documents; server-admin behavior belongs in README/deployment/configuration guidance. Compatibility and validation claims must remain limited to evidence actually collected.
