# Steam Workshop Publication

Current release stage: **Public Alpha**  
Current mod version: `v0.0.10`  
Project Zomboid Mod ID: `pz-enshrouded-sleep`  
Steam Workshop ID: **3786842301**

Workshop page:

```text
https://steamcommunity.com/sharedfiles/filedetails/?id=3786842301
```

This repository is intentionally structured so a clean copy of the repository root can serve as the Project Zomboid Workshop item directory. No generated deployment tree or packaging script is required.

## Repository / Workshop package layout

```text
pz-enshrouded-sleep/
├── workshop.txt
├── workshop-description.bbcode           # canonical paste-ready Workshop description
├── preview.png                           # Steam Workshop preview, 256x256 PNG
├── Contents/
│   └── mods/
│       └── pz-enshrouded-sleep/
│           ├── mod.info
│           ├── common/
│           └── 42/
│               ├── mod.info
│               ├── poster.png            # in-game poster, 256x256 PNG
│               ├── icon.png              # in-game icon, 32x32 PNG
│               └── media/
├── docs/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── NOTICE
├── ASSET_LICENSE.md
├── THIRD_PARTY_NOTICES.md
└── other public project documentation
```

Supporting public documentation is intentionally allowed in the Workshop item. Private data, logs, credentials, local test artifacts, and source-control metadata are not.

## Authoritative deployable mod tree

There is only one deployable Project Zomboid mod tree:

```text
Contents/mods/pz-enshrouded-sleep/
```

Do not create a second root-level `42/`, `common/`, or `mod.info` copy. Keeping one authoritative tree prevents source/release drift.

## Publication artwork

The Public Alpha package includes three project-provided publication assets:

```text
preview.png                                      256x256 PNG
Contents/mods/pz-enshrouded-sleep/42/poster.png 256x256 PNG
Contents/mods/pz-enshrouded-sleep/42/icon.png     32x32 PNG
```

`preview.png` is the Workshop uploader preview image and must remain at the Workshop item root. The current PZ uploader requires it to be a valid `256x256` PNG no larger than `1000 KB`.

`poster.png` and `icon.png` are stored beside the Build 42 `mod.info`. The versioned metadata explicitly references them:

```text
poster=poster.png
icon=icon.png
```

The repository package-validation workflow checks file presence, PNG identity, expected dimensions, `preview.png` size, and these metadata references.

## Permanent Workshop identity

The first upload created the permanent Workshop Published File ID:

```text
3786842301
```

This ID must be preserved for all future updates. Do not create a new Workshop item for routine releases.

A Steam-backed dedicated server uses both identifiers:

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

The Workshop ID identifies the Steam package to download. `pz-enshrouded-sleep` remains the stable Project Zomboid Mod ID loaded by the game.

The permanent ID is recorded in `workshop.txt`, the top-level README, this publication guide, and `docs/DEPLOYMENT.md`.

## Canonical Workshop description

The paste-ready Steam BBCode description is maintained in:

[`../workshop-description.bbcode`](../workshop-description.bbcode)

That file is the canonical source for the Workshop Description field. It includes the GitHub repository link:

```text
https://github.com/jonathanjacobs/pz-enshrouded-sleep
```

When the public description changes materially, update `workshop-description.bbcode` in Git first and then paste the new contents into the Steam Workshop item.

## Public Workshop description requirements

The Workshop page should clearly disclose:

- Public Alpha status and tested PZ version;
- multiplayer-server scope;
- Workshop ID and Mod ID;
- configuration and compatibility caveats;
- expected world/calendar-time behavior;
- current known limitations;
- a link to the GitHub source/documentation/issues;
- required third-party attribution if any is ever introduced;
- that this is an unofficial community mod and is not developed by, affiliated with, sponsored by, or endorsed by The Indie Stone;
- that this mod is not developed by, affiliated with, sponsored by, or endorsed by Keen Games, developer of *Enshrouded*;
- that no *Enshrouded* code/assets/game content are redistributed by this project.

## Workshop-distributed package validation

The initial upload is complete, but the Workshop-distributed payload should still be validated before issue #5 is closed:

1. subscribe/download Workshop item `3786842301`;
2. inspect the delivered payload and confirm the expected `Contents/mods/pz-enshrouded-sleep/` tree, metadata, and artwork;
3. configure a dedicated test server with:

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

4. run the Tier 1 startup smoke test using the Workshop-distributed copy;
5. run a short two-player partial-sleep regression if practical;
6. verify disable/rollback behavior when practical;
7. confirm intended Workshop visibility and public description.

## Update workflow

For later releases:

1. update source/docs/version in Git;
2. update `workshop-description.bbcode` if the public description changes;
3. complete the release checklist and multiplayer regression appropriate to the change;
4. copy the clean repository contents over the existing local Workshop authoring directory, excluding `.git/` and private/local artifacts;
5. preserve Workshop ID `3786842301` in `workshop.txt`/the uploader;
6. use Project Zomboid `Workshop -> Create and Update Items` to update the existing item;
7. supply an accurate Steam update note;
8. verify the subscribed/dedicated-server copy after publication.

Never create a new Workshop item merely to publish a routine version update.
