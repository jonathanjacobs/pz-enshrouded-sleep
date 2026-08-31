# Third-Party Notices

This file records third-party material redistributed with Enshrouded Sleep. Research references, product/game references, and prior art that were reviewed or referenced but not redistributed are listed separately so provenance remains explicit.

## Redistributed third-party material

None currently identified.

Before any third-party code, asset, library, executable, model, sound, data file, text, or other component is distributed with the mod, record at minimum:

- component or asset name;
- version or immutable revision where practical;
- upstream source;
- author/copyright holder(s) where known;
- license or explicit permission basis;
- whether the material was modified;
- redistribution and attribution requirements;
- whether Steam Workshop credit is required and where it appears.

## Research references / prior art not redistributed

### Custom Moodle UI research

The Project Zomboid **Lifestyle** mod Lua supplied during development was reviewed as implementation prior art for Build 42 custom Moodle-style UI behavior. In particular, it demonstrated that a mod can use client `ISUIElement` rendering, vanilla Moodle layout resources, player Moodle state, configurable Moodle sizing, and custom icon/tooltips without requiring a custom Java/core patch.

Enshrouded Sleep's Rested / Well Rested renderer is independently written for this project. It does **not** include, copy, adapt verbatim, or redistribute Lifestyle source code, textures, icons, or other assets. A small optional compatibility check may read Lifestyle's already-existing runtime `LSMoodleManager` / player `LSMoodles` state when Lifestyle is actually installed, solely to reserve visible UI slots and avoid overlap; Enshrouded Sleep does not mutate that state and does not require Lifestyle.

Moodle Framework was also considered during SPIKE-007 as a possible optional UI integration. The final self-contained candidate does not require it and redistributes none of its code or assets.

### Comparative multiplayer-sleep prior art

The following Project Zomboid mods have been examined during design/debugging to understand multiplayer-sleep behavior and implementation constraints:

- **TrueSleep** — reviewed as comparative prior art for multiplayer sleep behavior.
- **Sleep With Friends** by Snuggles — reviewed as comparative prior art for multiplayer sleep behavior.

Their inclusion here does **not** mean their code or assets are included in Enshrouded Sleep. No rights to their content are claimed by this repository. Any future reuse would require an independently verified compatible license or explicit permission before incorporation and redistribution.

## Project Zomboid / The Indie Stone

Project Zomboid, its code, and its assets are property of The Indie Stone and are not licensed as part of this repository. References to Project Zomboid APIs, identifiers, runtime resources, and behavior do not transfer ownership or licensing rights.

Enshrouded Sleep is an unofficial community mod and is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.

## Enshrouded / Keen Games

The project name **Enshrouded Sleep** references the general multiplayer-sleep design concept associated with the game *Enshrouded*, developed by Keen Games.

No *Enshrouded* code, assets, models, textures, sounds, text, executable content, or other game material are included or redistributed by this project.

Enshrouded Sleep is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to Keen Games. References to *Enshrouded* or Keen Games do not claim ownership of their intellectual property and do not imply a business, licensing, or endorsement relationship.
