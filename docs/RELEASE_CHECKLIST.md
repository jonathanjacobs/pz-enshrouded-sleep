# Release Checklist

Use this checklist before any public GitHub release or Steam Workshop publication/update. The Indie Stone policy review items are mandatory release gates.

## Identity and metadata

- [ ] `VERSION`, `Contents/mods/pz-enshrouded-sleep/mod.info`, and `Contents/mods/pz-enshrouded-sleep/42/mod.info` agree.
- [ ] All user-visible Lua startup/version strings identify the current package version.
- [ ] README status/version claims match the release candidate.
- [ ] `CHANGELOG.md` describes material behavior, compatibility, configuration, and packaging changes.
- [ ] The Project Zomboid Mod ID remains exactly `pz-enshrouded-sleep`.
- [ ] The permanent Steam Workshop ID, once assigned, is preserved for updates rather than creating a duplicate item.

## Workshop package structure

- [ ] Repository/Workshop root contains `workshop.txt`.
- [ ] Repository/Workshop root contains a valid `preview.png`: PNG, exactly `256x256`, no larger than `1000 KB`.
- [ ] The single authoritative deployable mod is under `Contents/mods/pz-enshrouded-sleep/`.
- [ ] There is no second root-level `42/`, `common/`, or `mod.info` runtime copy.
- [ ] The versioned Build 42 tree contains the expected `42/mod.info` and `42/media/` content.
- [ ] `Contents/mods/pz-enshrouded-sleep/42/poster.png` exists and is `256x256` PNG.
- [ ] `Contents/mods/pz-enshrouded-sleep/42/icon.png` exists and is `32x32` PNG.
- [ ] `42/mod.info` contains `poster=poster.png` and `icon=icon.png`.

## Indie Stone policy / provenance

- [ ] Recheck the current Project Zomboid Modding Policy for the first Workshop release, a major release, or whenever the policy has not been reviewed recently.
- [ ] Recheck applicable Project Zomboid Terms and Steam Workshop/Subscriber terms for the first Workshop publication.
- [ ] Every distributed code file, asset, model, sound, text, library, executable, model artifact, and data file has a known provenance.
- [ ] Project-owned material is actually ours to license under the repository license or `ASSET_LICENSE.md` boundary.
- [ ] Third-party material has a license or explicit permission allowing the intended use and redistribution.
- [ ] `THIRD_PARTY_NOTICES.md` is complete for all redistributed third-party material.
- [ ] Required third-party credits/permissions are included in the Steam Workshop description where applicable.
- [ ] No Project Zomboid code/assets have been extracted and redistributed without an explicit rights basis.
- [ ] No content has been copied from another mod merely because it is publicly downloadable.
- [ ] No donor-only, paid-access, or otherwise paywalled mod functionality has been introduced.
- [ ] No malicious behavior, licensing/login circumvention, piracy facilitation, or invasive security bypass has been introduced.
- [ ] Any hidden, unexpected, externally sourced, or message-bearing content is disclosed/attributed as required by policy.

## Branding / affiliation disclosures

- [ ] Public branding does not present the project as "Official" Project Zomboid content.
- [ ] README and Workshop description state that Enshrouded Sleep is an unofficial community mod and is not developed by, affiliated with, sponsored by, or endorsed by The Indie Stone.
- [ ] README and Workshop description state that Enshrouded Sleep is not developed by, affiliated with, sponsored by, or endorsed by Keen Games.
- [ ] The project does not redistribute *Enshrouded* code, assets, or game content.
- [ ] The project name/reference to *Enshrouded* is presented only as general gameplay-design inspiration, not as an official relationship.

## Assets and promotion

- [ ] `ASSET_LICENSE.md` accurately describes the licensing boundary for creative/promotional assets.
- [ ] Promotional images, screenshots, logos, sounds, and other media have known provenance and permitted usage.
- [ ] `preview.png`, `poster.png`, and `icon.png` have documented provenance and are safe to distribute.
- [ ] No promotional asset creates a misleading impression of endorsement by The Indie Stone or Keen Games.

## Technical validation

- [ ] Relevant automated/static checks pass where available; if no CI exists, this is stated rather than implied.
- [ ] The current documented multiplayer regression appropriate to this release has been executed.
- [ ] No known high-severity save, world-state, player-state, security, or server-stability regression is being silently shipped.
- [ ] Compatibility claims are limited to versions/configurations actually tested.
- [ ] Install, upgrade, disable, and rollback instructions are accurate for the release stage.
- [ ] Normal Public Alpha configuration uses `DiagnosticsEnabled=false` and `DiagnosticForcedCompressionFactor=1.0`.

## Distribution hygiene

Supporting public project documentation is permitted in the Workshop payload by design. The release boundary is therefore "public and intentional," not "runtime files only."

- [ ] Every file in the uploaded Workshop item is intentionally public.
- [ ] `.git/` source-control metadata is excluded from the local Workshop authoring copy.
- [ ] Development logs, private data, secrets, credentials, personal/local paths, and private test artifacts are excluded.
- [ ] Local ZIPs/backups/scratch files are excluded.
- [ ] Steam Workshop description includes required credits, dependencies, compatibility caveats, configuration notes, Public Alpha status, material disclosures, and non-affiliation statements.
- [ ] If distributed as part of a modpack, permission has been obtained where required; prefer Workshop Collections when redistribution is unnecessary.

## First Workshop publication

- [ ] Use `docs/STEAM_WORKSHOP.md` and the current game-generated Build 42 `ModTemplate` as the packaging/uploader reference.
- [ ] Upload through Project Zomboid `Workshop -> Create and Update Items`.
- [ ] Accept the applicable Steam Workshop legal agreement.
- [ ] Record the assigned permanent Workshop ID in repository documentation and server examples.
- [ ] Prefer an unlisted/private dress rehearsal if available, then inspect the subscribed/downloaded payload.
- [ ] Run a dedicated-server smoke test using the Workshop-distributed copy before broad Public Alpha announcement.

Release decision: **GO / CONDITIONAL GO / NO-GO**

Reviewer/date: ____________________
