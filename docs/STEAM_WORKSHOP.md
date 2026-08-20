# Steam Workshop Publication

Current release stage: **Public Alpha**  
Current mod version: `v0.0.10`  
Project Zomboid Mod ID: `pz-enshrouded-sleep`  
Steam Workshop ID: **pending first publication**

This repository is intentionally structured so a clean copy of the repository root can serve as the Project Zomboid Workshop item directory. No generated deployment tree or packaging script is required.

## Repository / Workshop package layout

```text
pz-enshrouded-sleep/
├── workshop.txt
├── preview.png                         # Steam Workshop preview, 256x256 PNG
├── Contents/
│   └── mods/
│       └── pz-enshrouded-sleep/
│           ├── mod.info
│           ├── common/
│           └── 42/
│               ├── mod.info
│               ├── poster.png          # in-game poster, 256x256 PNG
│               ├── icon.png            # in-game icon, 32x32 PNG
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

## Before first upload

1. Confirm `VERSION`, `Contents/mods/pz-enshrouded-sleep/mod.info`, and `Contents/mods/pz-enshrouded-sleep/42/mod.info` all report the intended version.
2. Confirm normal Public Alpha settings are:

```text
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
```

3. Confirm the three publication artwork files above are present and pass the repository package-validation check.
4. Review `docs/RELEASE_CHECKLIST.md` and `COMPLIANCE.md`.
5. Recheck The Indie Stone's current Project Zomboid Modding Policy and applicable terms immediately before upload.
6. Make a clean copy of the repository contents into the Workshop authoring directory shown by the game client. Do **not** include `.git/`, local logs, credentials, archives/backups, or private test artifacts.

Typical authoring location on Windows:

```text
C:\Users\<user>\Zomboid\Workshop\EnshroudedSleep\
```

Use the actual path shown by the installed Project Zomboid client if it differs.

## Upload through Project Zomboid

Use the game client:

```text
Main Menu
-> Workshop
-> Create and Update Items
```

Select the local Enshrouded Sleep Workshop item, review title/description/tags/visibility, and perform the first upload. Steam will assign a permanent Workshop Published File ID.

For the first publication, an unlisted/private dress rehearsal is recommended if the uploader UI permits it. Subscribe to the resulting item, verify the downloaded payload, run a dedicated-server smoke test using the Workshop copy, then switch visibility to Public when satisfied.

## After Steam assigns the Workshop ID

Record the ID in:

- this file;
- `workshop.txt`;
- `README.md` installation instructions;
- `docs/DEPLOYMENT.md`;
- server deployment examples;
- future release notes where useful.

A Steam-backed dedicated server will normally need both concepts:

```text
WorkshopItems=<Steam Workshop ID>
Mods=pz-enshrouded-sleep
```

The Workshop ID identifies the Steam package to download. `pz-enshrouded-sleep` remains the stable Project Zomboid Mod ID loaded by the game.

## Public Workshop description requirements

The Workshop page should clearly disclose:

- Public Alpha status and tested PZ version;
- multiplayer-server scope;
- Mod ID;
- configuration and compatibility caveats;
- expected world/calendar-time behavior;
- current known limitations;
- required third-party attribution if any is ever introduced;
- that this is an unofficial community mod and is not developed by, affiliated with, sponsored by, or endorsed by The Indie Stone;
- that this mod is not developed by, affiliated with, sponsored by, or endorsed by Keen Games, developer of *Enshrouded*;
- that no *Enshrouded* code/assets/game content are redistributed by this project.

## Workshop description starter

```text
[h1]Enshrouded Sleep — Public Alpha[/h1]

Proportional multiplayer sleeping for Project Zomboid Build 42 servers.

[b]Version:[/b] 0.0.10
[b]Tested with:[/b] Project Zomboid 42.20.3
[b]Mod ID:[/b] pz-enshrouded-sleep

When some, but not all, living players sleep, Enshrouded Sleep proportionally compresses world/calendar time while awake active gameplay remains at normal simulation speed. When all living players sleep, vanilla Project Zomboid full-sleep fast-forward takes over.

[h2]Public Alpha[/h2]
Back up your server before installing or updating. Broader multiplayer and world-system field testing is still in progress.

[h2]Important time behavior[/h2]
World/calendar time genuinely passes faster during partial sleep. Survival needs and other systems tied to elapsed world time may therefore progress while another survivor sleeps. See the GitHub documentation for detailed validation and known limitations.

[h2]Configuration[/h2]
Recommended Public Alpha settings:
DiagnosticsEnabled=false
DiagnosticForcedCompressionFactor=1.0
PartialSleepSpeedScale=1.0

[h2]Compatibility[/h2]
Other mods that alter multiplayer sleep, MinutesPerDay, GameTime pacing, or sleep fast-forward may conflict.

[h2]Unofficial community mod[/h2]
Enshrouded Sleep is not developed by, affiliated with, sponsored by, or endorsed by The Indie Stone.

Enshrouded Sleep is also not developed by, affiliated with, sponsored by, or endorsed by Keen Games. The project name refers only to general multiplayer-sleep design inspiration associated with the game Enshrouded; no Enshrouded code, assets, or game content are included.
```

## Update workflow

For later releases:

1. update source/docs/version in Git;
2. complete the release checklist and multiplayer regression appropriate to the change;
3. copy the clean repository contents over the existing local Workshop authoring directory, excluding `.git/` and private/local artifacts;
4. preserve the existing Workshop ID in `workshop.txt`/the uploader;
5. use Project Zomboid `Workshop -> Create and Update Items` to update the existing item;
6. supply an accurate Steam update note;
7. verify the subscribed/dedicated-server copy after publication.

Never create a new Workshop item merely to publish a routine version update.
