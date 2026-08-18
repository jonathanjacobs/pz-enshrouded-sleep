# Release Checklist

Use this checklist before any packaged test release, public GitHub release, or Steam Workshop publication. The Indie Stone policy review items are mandatory release gates.

## Identity and metadata

- [ ] `VERSION`, root `mod.info`, and `42/mod.info` agree.
- [ ] README status/version claims match the release candidate.
- [ ] `CHANGELOG.md` describes material behavior, compatibility, configuration, and packaging changes.
- [ ] The project is described as an independent community mod and does not imply endorsement by The Indie Stone.

## Indie Stone policy / provenance

- [ ] Recheck the current Project Zomboid Modding Policy if this is the first Workshop release, a major release, or the policy has not been reviewed recently.
- [ ] Every distributed code file, asset, model, sound, text, library, executable, model artifact, and data file has a known provenance.
- [ ] Project-owned material is actually ours to license under the repository license.
- [ ] Third-party material has a license or explicit permission allowing the intended use and redistribution.
- [ ] `THIRD_PARTY_NOTICES.md` is complete for all redistributed third-party material.
- [ ] Required third-party credits/permissions are included in the Steam Workshop description where applicable.
- [ ] No Project Zomboid code/assets have been extracted and redistributed without an explicit rights basis.
- [ ] No content has been copied from another mod merely because it is publicly downloadable.
- [ ] No donor-only, paid-access, or otherwise paywalled mod functionality has been introduced.
- [ ] No malicious behavior, licensing/login circumvention, piracy facilitation, or invasive security bypass has been introduced.
- [ ] Any hidden, unexpected, externally sourced, or message-bearing content is disclosed/attributed as required by policy.

## Assets and promotion

- [ ] `ASSET_LICENSE.md` accurately describes the licensing boundary for creative/promotional assets.
- [ ] Promotional images, screenshots, logos, sounds, and other media have known provenance and permitted usage.
- [ ] Public branding does not present the project as "Official" Project Zomboid content.

## Technical validation

- [ ] Relevant automated/static checks pass where available.
- [ ] The current documented multiplayer/single-player regression appropriate to this release has been executed.
- [ ] No known high-severity save, world-state, player-state, security, or server-stability regression is being silently shipped.
- [ ] Compatibility claims are limited to versions/configurations actually tested.
- [ ] Install, upgrade, disable, and rollback instructions are accurate for the release stage.

## Distribution

- [ ] The package contains only files intended for end users.
- [ ] Development logs, private data, secrets, credentials, local paths, and test artifacts are excluded.
- [ ] Steam Workshop description includes required credits, dependencies, compatibility caveats, configuration notes, and material disclosures.
- [ ] If distributed as part of a modpack, permission has been obtained where required; prefer Workshop Collections when redistribution is unnecessary.

Release decision: **GO / CONDITIONAL GO / NO-GO**

Reviewer/date: ____________________
