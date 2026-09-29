# Releasing

Status: **v1.0.1 release decision recorded; Workshop upload pending.**

Do not update for: player-facing installation or configuration ([`../README.md`](../README.md)), Workshop description text ([`workshop-description.bbcode`](workshop-description.bbcode)), or test results ([`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md)).

This document owns how a version gets from the repository to players: the release checklist, Steam Workshop publication, server updates, post-release checks, and rollback. Player-facing installation and configuration live in [`../README.md`](../README.md); public Workshop text is canonical in [`workshop-description.bbcode`](workshop-description.bbcode).

Project Zomboid Mod ID: `pz-enshrouded-sleep`
Permanent Steam Workshop ID: `3786842301`

## Release checklist

Tick an item only where recorded evidence supports it; evidence lives in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). Require what protects players' saves and the mod's core behavior, and watch the rest during normal play.

- [ ] `VERSION`, `CHANGELOG.md`, both `mod.info` files, the README, the Workshop text, and runtime build stamps agree — `bash tools/validate-package.sh` passes.
- [ ] The Validate Package (package and Lua syntax), Validate Enshrouded Sleep release, and Sensitive Content CI workflows pass on the release commit.
- [ ] The smoke test and two-player sleep test in [`TESTING.md`](TESTING.md) passed on this build (normal-session logs count) and are recorded in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).
- [ ] Multiplayer authority and save/load behavior were tested wherever the public text claims them.
- [ ] No known high-severity save, world, player, client, or server defect is being shipped silently.
- [ ] Public claims (status, compatibility, "tested with", configuration) match the recorded evidence.
- [ ] Every distributed asset and any third-party material is recorded in [`../CREDITS.md`](../CREDITS.md), `NOTICE` still carries the pz-mod-template block, and the [modding-policy checks](PZ_MODDING_POLICY.md#release-checks) are done.
- [ ] Every change to a [compatibility contract](DESIGN.md#compatibility-contracts) since the last release is in that list and in an `Upgrading` subsection of `CHANGELOG.md` that says what server operators and players must do, and the version number follows the rule below.
- [ ] Rollback below is still accurate for this release.

A **stable** release (`1.0.0` or later) additionally needs server and client logs from normal play showing the core behavior with no recurring error from this mod.

### v1.0.1 release record

Current release: `v1.0.1`, the full release of the v1.0.0 package (release labels and version only; no gameplay or configuration change). v1.0.0 was published to the existing Steam Workshop item on 2026-08-31.

#### General gate

- [x] `VERSION`, `CHANGELOG.md`, runtime version strings, and both `mod.info` files agree.
- [x] Public status, compatibility, configuration, and behavior claims match tested evidence and state the remaining validation boundaries.
- [x] The smoke test and two-player sleep test in [`TESTING.md`](TESTING.md) were run (normal-session logs count) and recorded in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). (Project Zomboid 42.21.0, 2026-09-28.)
- [x] No known high-severity save, world, player, client, or server defect is being silently shipped.
- [x] The Workshop package has one authoritative runtime tree and contains no logs, saves, credentials, private configuration, source-control metadata, backups, or unintended assets.
- [x] Provenance, licensing, policy review, attribution, and public disclosures are current under [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md) and [`../CREDITS.md`](../CREDITS.md).
- [x] Installation, update, monitoring, soft rollback, and full rollback instructions are current in the [configuration reference](../README.md#configuration-reference) and [Rollback](#rollback).
- [x] Workshop identifiers, package layout, artwork, and publication metadata pass the [Workshop reference](#workshop-reference).

#### Stable release gate

- [x] Server and at least one client log from normal play show coherent baseline, partial-sleep, and wake transitions without a recurring Enshrouded Sleep error or client clock defect. (42.21.0 server and sleeping-client logs. All-asleep handoff is supported by 156 server-side handoffs in the v1.0.0 WHG window rather than a client log; accepted for the full release.)
- [x] Major world-time interactions and compatibility limits are documented and accepted for the release.
- [x] The optional Rested / Well Rested feature passed its focused server-authority gate and WHG live multiplayer validation. All 301 live sleep decisions matched the active configuration, and durations, expiry, and restart persistence were correct with no errors; this evidence is accepted for the `8`/`12`-hour defaults. The feature remains disabled by default. Death/disable clearing and Moodle presentation were not observed live.

Watch during normal play rather than staging dedicated tests; record anything notable in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md), and treat a real problem here as a blocker for the next release:

- joins, disconnects, deaths, and respawns during partial sleep leaving stale population or awake-protection state;
- eating, drinking, activity, or sleeping-player behavior looking distorted during partial sleep;
- notification banners missing, repeated, or spammy when the option is enabled;
- CPU cost or normal log volume becoming a problem for the server.

Rollback steps are documented under [Rollback](#rollback); they are not rehearsed as a release gate.

#### Deployment gate

- [ ] Stop the server cleanly and back up world, save, and configuration before updating.
- [ ] Upload v1.0.1 to Workshop item `3786842301`, then paste [`workshop-description.bbcode`](workshop-description.bbcode) into the item description (the upload replaces it with the one-line `workshop.txt` summary).
- [ ] Confirm the server and every participating client log `SERVER_BUILD | 1.0.1` / `build=1.0.1` after deployment.
- [ ] Preserve early release logs and use the documented rollback if a problem appears.

Release decision: **GO — v1.0.1 full release**

Review date: **2026-09-28**

History: v1.0.0 was deployed on 2026-08-31 under a conditional Release Candidate decision. WHG live logs from 2026-09-01 to 2026-09-28 and the 2026-09-28 Project Zomboid 42.21.0 checkpoint satisfied the stable gate above.

## Choosing the version number

Choose the increment by what an update does to people already running the mod:

| Increment | When | Effect on existing worlds and servers |
| --- | --- | --- |
| Major (`X.0.0`) | A [compatibility contract](DESIGN.md#compatibility-contracts) is renamed, removed, or changes meaning or default, or players or server operators must act | Something breaks or changes unless they follow the `Upgrading` note |
| Minor (`x.Y.0`) | New features, sandbox options, or other contracts, with existing behavior and defaults unchanged | Existing worlds and settings keep working as before |
| Patch (`x.y.Z`) | Fixes that change no contract | Existing worlds and settings keep working, now without the bug |

Keep breaking changes rare: every one costs every server running the mod.

## Publishing to Steam Workshop

Routine updates must reuse Workshop item `3786842301`. Never create a new Workshop item merely to publish a routine version update.

1. Stop the test server cleanly, and back up the world, save, and configuration of any server you will update.
2. Prepare a clean authoring directory under `Zomboid/Workshop/<item-name>/` from the repository, for example `git archive HEAD | tar -x -C <authoring-dir>`. That exports only tracked files, which keeps `.git/`, logs, saves, credentials, and decompiled source out; tracked docs and tooling come along, which is harmless.
3. In Project Zomboid, use **Workshop → Create and Update Items** to update the existing item.
4. Write an accurate change note (BBCode works). If the uploader does not carry it over, add or edit it on the item's Steam **Change Notes** tab.
5. **Paste [`workshop-description.bbcode`](workshop-description.bbcode) into the item description again.** Every upload replaces the Steam description with the one-line `description=` summary from `workshop.txt`.

**Do not subscribe to the item on the machine that holds the authoring copy.** The subscribed and authoring copies share the Mod ID, and the game can load files from both, so older Lua or sandbox options may run alongside the new version. Verify the distributed package from the dedicated server or from a client without the authoring copy.

## Updating a server

1. Announce the restart/update.
2. Stop the server cleanly.
3. Back up the world/save and server configuration.
4. Preserve the previous known-good package/configuration when practical.
5. Update the existing Workshop item/server package.
6. Verify the [normal configuration](../README.md#configuration-reference) unless the release notes explicitly require otherwise.
7. Start the server and confirm the controller, clock sync, roster logger, awake-protection module, notification modules, and sleep-benefit modules load without an Enshrouded Sleep Lua exception.
8. Confirm native baseline `MinutesPerDay` while all living players are awake.
9. During the first natural partial-sleep event, confirm partial mode appears and later returns to baseline.
10. If `SleepNotificationsEnabled=true`, confirm one concise notification banner appears per effective sleep-state change without repeated spam.
11. If `SleepBenefitsEnabled=true`, confirm from the server log that the first qualifying sleep grants the expected tier for the active thresholds.
12. Preserve early session logs after a material runtime update.

## After publishing

1. The expected `Contents/mods/pz-enshrouded-sleep/` runtime tree is present and `mod.info` metadata and version are correct.
2. The dedicated server acquires the updated Workshop item and logs the new `CONFIG | build=` line; each client receives the same package version and reports the matching `SERVER_BUILD` with no `BUILD_MISMATCH` (see the build-stamp convention in [`DESIGN.md`](DESIGN.md#build-stamp-and-version-handshake)).
3. Poster, icon, and preview show as intended.
4. The smoke test in [`TESTING.md`](TESTING.md) passes on the live server.
5. Keep the early server and client logs from the release in case a problem appears.

## Rollback

Prefer turning off one optional layer before removing the mod.

### Soft rollback — awake protection only

Use this when proportional sleep/clock behavior appears correct but awake Hunger/Thirst/Fatigue/Nutrition/Weight behavior appears wrong or conflicts with another mod:

```text
EnshroudedSleep.AwakePlayerProtectionEnabled=false
```

This disables the survival-state normalizer while leaving proportional partial-sleep calendar compression and vanilla all-asleep handoff active. Preserve logs and compare behavior before removing the entire mod.

### Notification-only rollback

If the sleep/time mechanic is correct but chat notifications are unwanted or conflict with another chat/UI mod, disable only:

```text
EnshroudedSleep.SleepNotificationsEnabled=false
```

This has no effect on time compression, client clock synchronization, or awake-player protection.

### Sleep-benefit-only rollback

If the sleep-benefit system causes XP, Endurance, Moodle, or compatibility problems, disable only:

```text
EnshroudedSleep.SleepBenefitsEnabled=false
```

The server clears active Rested / Well Rested benefit state. Proportional sleep, awake-player protection, and notification behavior remain independently configured. There is no external Moodle dependency to remove; the custom UI ships with the mod and is designed to fail independently of gameplay authority.

### Full rollback

Use a full rollback for core clock/controller/synchronization failures, recurring Enshrouded Sleep exceptions, serious server instability, or player/world-state problems that cannot be isolated to an optional layer.

1. Stop the server cleanly.
2. Preserve incident logs and the affected save/configuration.
3. Remove/disable `pz-enshrouded-sleep` and/or Workshop item `3786842301` through the normal server workflow.
4. Restore the prior package/configuration if needed.
5. Restart and confirm native future sleep/time behavior.

The mod does not maintain a custom persistent sleep database. The Rested system stores only small per-character ModData fields for an earned benefit and expiry; disabling/removing the mod stops using those values. World-time-driven changes that already occurred require a prior save backup if they need to be undone.

## Workshop reference

### Package layout

A clean repository root doubles as the Workshop item directory:

```text
pz-enshrouded-sleep/
├── workshop.txt
├── docs/workshop-description.bbcode
├── preview.png
├── Contents/mods/pz-enshrouded-sleep/   (the only runtime tree; see DESIGN.md)
└── README.md, CHANGELOG.md, the rest of docs/, licensing files
```

Public documentation may be included intentionally in the Workshop item. `.git/`, private logs and data, credentials, local test artifacts, backups, and scratch material must not be copied into the authoring directory.

### `workshop.txt`

- `id=` — `3786842301`; never change it. [`../tools/validate-package.sh`](../tools/validate-package.sh) treats a numeric `id=` as the signal that the project is publishing, and requires the artwork below and a placeholder-free Workshop description.
- `title=` — the public item title.
- `description=` — the one-line summary that overwrites the Steam description on every upload.
- `tags=` — Workshop tags, currently `Build 42;Multiplayer`.
- `visibility=` — `public`.

A Steam-backed dedicated server uses both identifiers: `WorkshopItems=3786842301` selects the Steam package, and `Mods=pz-enshrouded-sleep` is the Project Zomboid Mod ID loaded by the game.

### Artwork

| File | Purpose | Current | Checked by the validator |
| --- | --- | --- | --- |
| `preview.png` (item root) | Workshop uploader preview | 256×256 PNG | PNG, 256×256, at most 1000 KB |
| `Contents/mods/pz-enshrouded-sleep/42/poster.png` | In-game mod-manager poster (`poster=`) | 743×743 PNG | PNG identity |
| `Contents/mods/pz-enshrouded-sleep/42/icon.png` | In-game mod-list icon (`icon=`) | 32×32 PNG | PNG identity |

Record the provenance of every image in [`../CREDITS.md`](../CREDITS.md). Do not silently resize publication artwork as part of an unrelated code release.

### Workshop description

- Update [`workshop-description.bbcode`](workshop-description.bbcode) in Git when public behavior or status changes materially, then paste it into the existing item. Do not keep a second copy of the description anywhere else.
- Steam does not render `[center]` or `[br]`; they show as literal text. Use blank lines for spacing. The validator rejects both.
- An optional support or donation section is allowed as long as donations unlock nothing (rule 5 in [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md)). Host any button image externally and link it with `[url=...][img]...[/img][/url]`.
