# Steam Workshop Publication

This document owns Steam Workshop packaging and update mechanics. Runtime configuration belongs in [`DEPLOYMENT.md`](DEPLOYMENT.md); release gates belong in [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md); public description text is canonical in [`../workshop-description.bbcode`](../workshop-description.bbcode).

Project Zomboid Mod ID: `pz-enshrouded-sleep`  
Permanent Steam Workshop ID: `3786842301`

## Package layout

A clean repository root is intentionally usable as the Project Zomboid Workshop item directory:

```text
pz-enshrouded-sleep/
├── workshop.txt
├── workshop-description.bbcode
├── preview.png
├── Contents/
│   └── mods/
│       └── pz-enshrouded-sleep/
│           ├── mod.info
│           ├── common/
│           └── 42/
│               ├── mod.info
│               ├── poster.png
│               ├── icon.png
│               └── media/
├── docs/
├── README.md
├── CHANGELOG.md
└── public licensing/provenance files
```

There is one authoritative deployable runtime tree:

```text
Contents/mods/pz-enshrouded-sleep/
```

Do not create a second root-level `42/`, `common/`, or runtime `mod.info` copy.

Public documentation may be included intentionally in the Workshop item. `.git/`, private logs/data, credentials, local test artifacts, backups, and scratch material must not be copied into the authoring directory.

## Artwork

Current repository assets are:

```text
preview.png                                      256x256 PNG
Contents/mods/pz-enshrouded-sleep/42/poster.png 743x743 PNG
Contents/mods/pz-enshrouded-sleep/42/icon.png     32x32 PNG
```

`preview.png` is the Workshop uploader preview and must remain at the item root; the package-validation workflow enforces its PNG identity, dimensions, and size ceiling. `poster.png` and `icon.png` are referenced by the Build 42 `mod.info` and are also checked by repository validation. Do not silently resize publication artwork as part of an unrelated code release.

## Stable identities

Routine updates must reuse Workshop item `3786842301`.

A Steam-backed dedicated server uses both identifiers:

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

The Workshop ID selects the Steam package; `pz-enshrouded-sleep` is the Project Zomboid Mod ID loaded by the game.

## Canonical Workshop description

Maintain the paste-ready Steam BBCode in:

[`../workshop-description.bbcode`](../workshop-description.bbcode)

When public behavior/status changes materially, update that file in Git and then paste the new contents into the existing Steam Workshop item. Do not maintain a separate prose description in this publication guide.

Required public disclosures and provenance checks are governed by [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md) and [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md).

## Update workflow

1. Complete source/runtime changes and update `VERSION`, mod metadata, changelog, and public description as appropriate.
2. Run the release checklist and the multiplayer regression appropriate to the change.
3. Prepare a clean Workshop authoring directory from the repository root, excluding `.git/` and private/local artifacts.
4. Preserve Workshop ID `3786842301` in `workshop.txt` and the uploader.
5. Use Project Zomboid `Workshop -> Create and Update Items` to update the existing item.
6. Provide an accurate Steam update note.
7. Subscribe/download the resulting item and verify the distributed package rather than relying only on the authoring copy.
8. Run the deployment smoke/regression appropriate to the release.

Never create a new Workshop item merely to publish a routine version update.

## Post-publication verification

Confirm:

- the expected `Contents/mods/pz-enshrouded-sleep/` runtime tree is present;
- `mod.info` metadata/version is correct;
- preview/poster/icon assets load as intended;
- the dedicated server acquires the updated Workshop item;
- clients receive the same package version;
- the smoke test in [`TESTING.md`](TESTING.md) passes;
- rollback instructions in [`DEPLOYMENT.md`](DEPLOYMENT.md) remain accurate.
