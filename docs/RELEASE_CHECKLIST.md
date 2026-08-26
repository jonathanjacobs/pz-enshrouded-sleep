# Release Checklist

Use this checklist before any public GitHub release or Steam Workshop publication/update. The Indie Stone policy review items are mandatory release gates.

## Identity and metadata

- [ ] `VERSION`, root mod `mod.info`, and `42/mod.info` agree.
- [ ] README, Workshop descriptor/description, changelog, and deployment guide identify the current release stage/version.
- [ ] User-visible runtime version/protocol strings that affect support or synchronization are current.
- [ ] Project Zomboid Mod ID remains exactly `pz-enshrouded-sleep`.
- [ ] Permanent Steam Workshop ID `3786842301` is preserved.

## Workshop package structure

- [ ] Repository/Workshop root contains `workshop.txt` and valid `preview.png`.
- [ ] The single authoritative deployable mod is under `Contents/mods/pz-enshrouded-sleep/`.
- [ ] No second root-level `42/`, `common/`, or `mod.info` runtime copy exists.
- [ ] Build 42 poster/icon references and dimensions remain valid.

## Indie Stone policy / provenance

- [ ] Recheck the current Project Zomboid Modding Policy for a major release or when it has not been reviewed recently.
- [ ] Every distributed code file/asset/text/library has known provenance and redistribution rights.
- [ ] `THIRD_PARTY_NOTICES.md`, `ASSET_LICENSE.md`, `LICENSE`, and `NOTICE` remain accurate.
- [ ] No Project Zomboid or third-party mod code/assets are redistributed without an explicit rights basis.
- [ ] No paid/donor-exclusive functionality, malicious behavior, licensing circumvention, piracy facilitation, or undisclosed hidden content is introduced.
- [ ] Required permissions/credits are present in the Workshop description where applicable.

## Branding / affiliation disclosures

- [ ] Public branding does not present the project as Official Project Zomboid content.
- [ ] README and Workshop description retain The Indie Stone non-affiliation language.
- [ ] README and Workshop description retain Keen Games non-affiliation language.
- [ ] No Enshrouded code/assets/game content are redistributed.

## Technical validation

- [ ] Automated/static package checks pass where available.
- [ ] The documented regression appropriate to the release has been executed or, for an explicitly identified Public Beta live-field feature, its post-deployment validation boundary is documented.
- [ ] No known high-severity save/world/player/server stability defect is being silently shipped.
- [ ] Compatibility claims are limited to tested evidence.
- [ ] Install, update, disable, and rollback instructions are current.
- [ ] Normal operation uses `DiagnosticsEnabled=false` and `DiagnosticForcedCompressionFactor=1.0`.
- [ ] `AwakePlayerProtectionEnabled=true` is intentional for Public Beta and its independent soft-rollback behavior is documented.
- [ ] For v0.1.1, `SleepNotificationsEnabled=false` remains the default; live WHG notification validation and notification-only rollback are documented.
- [ ] Runtime Lua contains no `loadstring`/`loadstream` dependency after the Project Zomboid 42.20.4 security change.

## Distribution hygiene

- [ ] Every uploaded Workshop file is intentionally public.
- [ ] `.git/`, development logs, private data, secrets, credentials, personal/local paths, ZIP backups, and scratch files are excluded.
- [ ] Workshop description includes status, configuration, compatibility caveats, material disclosures, and non-affiliation statements.

## Deployment gate

- [ ] Stop server cleanly and back up world/save/config before update.
- [ ] Confirm server/client package version consistency after update.
- [ ] Confirm native baseline `MinutesPerDay` with all players awake.
- [ ] Confirm at least one partial-sleep transition and exact baseline restoration when practical.
- [ ] For v0.1.1 with notifications enabled, confirm one transition-based notification appears without repeated chat spam; disable `SleepNotificationsEnabled` first if the notification path misbehaves.
- [ ] Preserve early field logs for a new Beta feature rollout.

Release decision: **GO / CONDITIONAL GO / NO-GO**

Reviewer/date: ____________________
