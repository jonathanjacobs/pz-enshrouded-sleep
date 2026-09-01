# Project Compliance

Enshrouded Sleep follows the repository rules in [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md), which is the canonical engineering/release interpretation of The Indie Stone's current Project Zomboid Modding Policy for this project.

Before adding third-party material or publishing a release, review:

- [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md) — mandatory mod-policy/provenance rules;
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) — release gate;
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — redistributed-material/prior-art provenance;
- [`ASSET_LICENSE.md`](ASSET_LICENSE.md) — non-code creative-asset licensing boundary;
- [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE) — source licensing/project notices;
- [`docs/STEAM_WORKSHOP.md`](docs/STEAM_WORKSHOP.md) — publication mechanics.

This file intentionally does not duplicate the detailed policy rules or release checklist.

## Project-specific public disclosures

Enshrouded Sleep is an unofficial independent community mod. It is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.

The project name refers to general multiplayer-sleep design inspiration associated with *Enshrouded*. Enshrouded Sleep is not developed by, affiliated with, sponsored by, or endorsed by Keen Games, and the project does not redistribute *Enshrouded* code, assets, models, sounds, text, or game content.

Voluntary support links may be displayed publicly. Donations do not unlock Enshrouded Sleep access, content, bonuses, configuration, support priority, or gameplay functionality; the complete mod remains equally available to non-donors.

## Distribution boundary

The repository is intentionally Workshop-package compatible. The only deployable Project Zomboid runtime tree is:

```text
Contents/mods/pz-enshrouded-sleep/
```

Only intentionally public files may be placed in the Workshop authoring directory. Source-control metadata, private logs/data, credentials, local test artifacts, backups, and other non-public material must be excluded.
