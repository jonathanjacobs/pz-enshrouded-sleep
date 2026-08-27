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

## Optional runtime integrations / research references not redistributed

### Moodle Framework

The `feature/sleep-benefits` development branch can optionally use **Moodle Framework** by Tchernobill to display the Rested and Well Rested custom moodles.

- Steam Workshop ID: `3396446795`
- Mod ID: `MoodleFramework`
- Integration surface: documented public `MF.createMoodle` / `MF.getMoodle(...):setValue(...)` API plus title/description helpers when available.
- Redistribution: **none**. Enshrouded Sleep does not include Moodle Framework source code, binaries, textures, or other assets.
- Dependency behavior: soft/optional. Sleep-benefit gameplay logic is designed to continue without the framework; only the custom Moodle UI is unavailable.

The framework's documented `30×30` alpha-enabled Moodle texture convention was used only as an interface/asset-dimension requirement. The Rested and Well Rested artwork distributed by Enshrouded Sleep is original project artwork and does not copy Moodle Framework or Lifestyle assets.

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
