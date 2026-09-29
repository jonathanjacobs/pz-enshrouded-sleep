# Documentation ownership

Do not update for: a change inside one document. Update this file when a subject moves to a different document, or a document is added or removed.

This file defines where mutable project information belongs so the repository does not maintain competing copies of the same facts. Each document in `docs/` opens with a "Do not update for" line naming the information that looks as if it belongs there but has another home.

| Information | Canonical source |
| --- | --- |
| Index of the documents in `docs/` | [`README.md`](README.md); it lists files, and this table decides where a fact belongs |
| Public overview, installation, configuration reference, and release identity | [`../README.md`](../README.md), [`../VERSION`](../VERSION), and [`../CHANGELOG.md`](../CHANGELOG.md) |
| Normative behavior (requirements) and implementation design (architecture) | [`DESIGN.md`](DESIGN.md), with durable decisions in [`adr/`](adr/) |
| Names that saves, server settings, or other mods depend on | Compatibility contracts in [`DESIGN.md`](DESIGN.md#compatibility-contracts); what an update requires of players and operators goes in `Upgrading` notes in [`../CHANGELOG.md`](../CHANGELOG.md) |
| Version-number rules | Mod releases: [`RELEASING.md`](RELEASING.md#choosing-the-version-number). Template releases: [`../CHANGELOG.md`](../CHANGELOG.md#how-the-template-is-versioned) |
| Milestones, sequencing, and current work | [`ROADMAP.md`](ROADMAP.md) |
| Individual defects and open design questions | GitHub Issues, cited by number elsewhere |
| What each pull request description reports | [`../.github/pull_request_template.md`](../.github/pull_request_template.md) |
| Repeatable test procedure | [`TESTING.md`](TESTING.md) |
| Actual test outcomes | [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) |
| Experimental evidence | [`spikes/`](spikes/) |
| Release checklist, Workshop publication, and rollback | [`RELEASING.md`](RELEASING.md) |
| Public Workshop text | [`workshop-description.bbcode`](workshop-description.bbcode) and [`../workshop.txt`](../workshop.txt) |
| Modding-policy rules | [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md) |
| Asset and third-party provenance | [`../CREDITS.md`](../CREDITS.md) |
| Private details kept out of the repository, and leak response | [`PRIVATE_DATA.md`](PRIVATE_DATA.md) |
| License and attribution notices | [`../LICENSE`](../LICENSE) and [`../NOTICE`](../NOTICE); terms for non-code creative assets in [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) |
| External reference links and mods studied for ideas | [`RESEARCH_LINKS.md`](RESEARCH_LINKS.md) |
| Agent working rules and current development context | [`../AGENTS.md`](../AGENTS.md) (imported by [`../CLAUDE.md`](../CLAUDE.md), which holds no rules of its own) |
| Automated checks (package, Lua syntax, sensitive content) | [`../tools/`](../tools/) scripts, documented in [`../tools/README.md`](../tools/README.md) and run by [`../.github/workflows/`](../.github/workflows/README.md) and the [`../.githooks/`](../.githooks/) pre-commit hook |
| Test-cycle scripts and local working folders (logs, decompiled source, research material) | [Local files and automation](TESTING.md#local-files-and-automation) in `TESTING.md`; scripts themselves go in [`../tools/`](../tools/README.md) |

## Where to start by reader

- Server operators and players: [`../README.md`](../README.md)
- Contributors: [`DESIGN.md`](DESIGN.md) and [`ROADMAP.md`](ROADMAP.md)
- Testers: [`TESTING.md`](TESTING.md) and [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md)
- Release maintainers: [`RELEASING.md`](RELEASING.md)

## Duplication rule

Repeat a small fact only when necessary for immediate usability or safety. Do not duplicate complete specifications, validation tables, experimental narratives, roadmaps, or configuration explanations that already have a canonical home.

Update the canonical source first when behavior changes; replace secondary detail with a link where practical.

Known overlaps and how they are resolved:

- **README and Workshop description.** The README owns the full configuration reference. The Workshop description is read on Steam without the repository, so it may carry a shorter summary of the same settings; update it whenever the README's public behavior changes.
- **ROADMAP and GitHub Issues.** Issues own individual defects and questions. The roadmap owns order and milestones and cites issue numbers rather than restating them.
- **AGENTS.md "Current development context" and ROADMAP.** AGENTS.md holds what an agent must know before touching anything (branch roles, evidence limits, environment traps). The roadmap holds the work itself.
- **CHANGELOG and VALIDATION_HISTORY.** The changelog says what changed between releases; validation history says what was observed in tests. Neither repeats the other's detail.
