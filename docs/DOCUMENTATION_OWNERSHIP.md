# Documentation ownership

This file defines where mutable project information belongs so the repository does not maintain multiple competing copies of the same facts.

| Information | Canonical source |
|---|---|
| Public/player overview and current release identity | [`../README.md`](../README.md) and [`../VERSION`](../VERSION) |
| Normative runtime behavior | [`REQUIREMENTS.md`](REQUIREMENTS.md) |
| Implementation design and component responsibilities | [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`adr/`](adr/) |
| Server installation, configuration, monitoring, and rollback | [`DEPLOYMENT.md`](DEPLOYMENT.md) |
| Current regression and field-test procedures | [`TESTING.md`](TESTING.md) |
| Historical validation chronology | [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) |
| Detailed experimental evidence | [`spikes/`](spikes/) |
| Current/future work and release-exit criteria | [`ROADMAP.md`](ROADMAP.md) |
| Steam Workshop packaging/publication procedure | [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md) |
| Release gates | [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) |
| Release-to-release change summary | [`../CHANGELOG.md`](../CHANGELOG.md) |
| Mod-policy/provenance rules | [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md), [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md), and [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) |

## Duplication rule

Other documents may repeat a small fact when it is required for immediate usability or safety—for example the two Steam/PZ identifiers in deployment instructions, the normal diagnostics defaults in a rollback procedure, or a release gate in the checklist. They should not reproduce long formulas, validation tables, experimental narratives, roadmaps, or complete configuration explanations when a canonical document already owns that material.

When behavior changes, update the canonical source first and replace secondary explanations with links where practical.
