# Project Zomboid Modding Policy Compliance

This repository is developed under a project-wide compliance rule: work intended for distribution as a Project Zomboid mod must comply with The Indie Stone's current Project Zomboid Modding Policy, the Project Zomboid Terms and Conditions incorporated by that policy, and applicable distribution-platform rules.

Authoritative policy:

- https://projectzomboid.com/blog/modding-policy/

Last reviewed for this repository: **2026-08-20**, during preparation for the first Steam Workshop Public Alpha publication.

This document is an engineering and release-control policy for this repository. It does not replace the authoritative Indie Stone policy.

## Mandatory development rules

1. **Original work and provenance**
   - Code, art, audio, models, text, data, and other material added to the repository must be original to this project or have a documented license/permission that allows the intended use and redistribution.
   - Public availability of another mod does not imply permission to copy or redistribute its contents.
   - Studying another mod for behavior, interoperability, API discovery, or prior art does not authorize copying its implementation or assets.

2. **Third-party material**
   - Any incorporated third-party component must be recorded in `THIRD_PARTY_NOTICES.md` before distribution.
   - The record must identify the component, source, version/revision where practical, copyright holder or author where known, license or permission basis, modification status, redistribution requirements, and required attribution.
   - Required Workshop attribution must be included on the Steam Workshop description as well as in the repository.

3. **Project Zomboid / The Indie Stone property**
   - Project Zomboid code and assets remain property of The Indie Stone and are not relicensed by this repository's Apache-2.0 license.
   - Prefer references to vanilla APIs, identifiers, tiles, sprites, sounds, or other resources at runtime over copying/extracting those resources into this repository.
   - Any proposed redistribution of Project Zomboid material requires an explicit rights review before inclusion.

4. **Unofficial status**
   - The mod, repository, documentation, branding, release notes, and Workshop page must not call the project "Official" or imply endorsement by The Indie Stone.
   - Public-facing material should identify the project as an independent community mod.

5. **No prohibited commercialization**
   - Access to the mod or in-mod functionality must not be sold or restricted to donors unless an arrangement with The Indie Stone expressly permits it.
   - Donations may not unlock exclusive mod content or functionality.
   - This repository intentionally carries no GitHub funding/sponsorship hook for the mod during Public Alpha Workshop publication, avoiding ambiguity between project distribution and monetization.

6. **No malicious or circumvention behavior**
   - The mod must not intentionally damage users' devices, remove or bypass Project Zomboid login/licensing controls, facilitate playing without purchasing the game, or use invasive security/sandbox bypass techniques merely to obtain functionality.

7. **Content and disclosure**
   - Do not add prohibited objectionable content as defined by the Indie Stone policy.
   - Hidden, unexpected, externally sourced, or message-bearing content introduced by an update must be disclosed/attributed where required by the policy and must not be silently introduced through an update.
   - Workshop descriptions and changelogs should accurately describe material behavior changes.

8. **Modpacks and redistribution**
   - Do not publish or redistribute another author's mod in public or unlisted modpacks without the required permission.
   - Prefer Steam Workshop Collections when the goal is to assemble independently maintained mods rather than redistribute them.

## License boundary

The repository's Apache License 2.0 applies only to material for which this project has the right to grant that license. It does not relicense Project Zomboid content or third-party material. Non-code creative assets may have separate terms described in `ASSET_LICENSE.md`.

## Release gate

A release is not considered publishable until `docs/RELEASE_CHECKLIST.md` has been reviewed for the release candidate. The live Indie Stone Modding Policy must be rechecked before the first Steam Workshop release and periodically thereafter because the policy may change.
