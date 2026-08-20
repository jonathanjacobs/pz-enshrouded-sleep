# Project Compliance

Enshrouded Sleep follows the shared Willow Hill Games Project Zomboid mod-development compliance baseline.

Before adding third-party material or preparing any release, review:

- [`docs/PZ_MODDING_POLICY.md`](docs/PZ_MODDING_POLICY.md) — mandatory Indie Stone policy and provenance rules.
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) — release gate and publication checklist.
- [`docs/STEAM_WORKSHOP.md`](docs/STEAM_WORKSHOP.md) — Workshop package/publication procedure.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — redistributed third-party material and research/prior-art provenance.
- [`ASSET_LICENSE.md`](ASSET_LICENSE.md) — licensing boundary for non-code creative assets.
- [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE) — licensing and project notices.

## Project Zomboid / The Indie Stone

The authoritative external policy is The Indie Stone's Project Zomboid Modding Policy. The live policy and applicable Project Zomboid terms must be rechecked before first Steam Workshop publication and periodically thereafter.

Project Zomboid is developed by The Indie Stone. Enshrouded Sleep is an **unofficial independent community mod**. It is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.

The project must not redistribute Project Zomboid code/assets without an explicit rights basis, must not incorporate third-party/mod content without required permission/licensing, must not present itself as Official, and must comply with the Modding Policy's restrictions on commercialisation, hidden/unexpected content, and other prohibited material.

## Enshrouded / Keen Games

The project name refers to the general multiplayer-sleep design inspiration associated with the game *Enshrouded*.

Enshrouded Sleep is **not** developed by, affiliated with, sponsored by, endorsed by, or otherwise official to Keen Games. The project does not include or redistribute *Enshrouded* code, assets, models, sounds, text, or other game content. Any future use of Keen Games material would require an independently verified rights basis and explicit provenance review before inclusion.

## Workshop distribution boundary

The Git repository is intentionally Workshop-package compatible. Public project documentation may be distributed with the Workshop item, but only files intended to be public may be included.

The authoritative runtime tree is:

```text
Contents/mods/pz-enshrouded-sleep/
```

Source-control metadata (`.git/`), private logs, credentials, local test artifacts, and other non-public material must not be copied into the Project Zomboid Workshop authoring directory.
