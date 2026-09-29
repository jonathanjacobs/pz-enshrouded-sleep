# Research links

Status: **Mods studied recorded; reference links not yet populated**

Do not update for: material the mod distributes ([`../CREDITS.md`](../CREDITS.md)), or saved copies of external pages (keep those in a local folder outside the repository).

External reference sources for the target Project Zomboid build. These are citations, not redistributed content — see [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md) for the boundary between studying external material and copying it.

- Community wiki: `TBD`
- Javadocs / API reference: `TBD`
- Other stable references: `TBD`

Local copies (saved wiki pages, community notes, other Workshop mods studied for implementation ideas) belong in a local folder outside the repository; this file is for stable links only.

## Mods studied for reference

Other Project Zomboid mods examined for implementation *ideas* (not copied code or assets — see [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md); public availability of a mod does not grant redistribution rights). Listed here for credit and traceability. Their inclusion here does **not** mean their code or assets are included in Enshrouded Sleep, and no rights to their content are claimed. If any code or asset is ever actually adapted or copied, it must instead be recorded in [`../CREDITS.md`](../CREDITS.md) with full provenance before release.

| Mod | Author | What we looked at it for |
| --- | --- | --- |
| Lifestyle | `TBD` | Implementation prior art for Build 42 custom Moodle-style UI (see below) |
| Moodle Framework | `TBD` | Considered during SPIKE-007 as a possible optional UI integration; the final self-contained renderer does not require it |
| TrueSleep | `TBD` | Comparative prior art for multiplayer sleep behavior |
| Sleep With Friends | Snuggles | Comparative prior art for multiplayer sleep behavior |

### Custom Moodle UI research

The Project Zomboid **Lifestyle** mod Lua supplied during development was reviewed as implementation prior art for Build 42 custom Moodle-style UI behavior. In particular, it demonstrated that a mod can use client `ISUIElement` rendering, vanilla Moodle layout resources, player Moodle state, configurable Moodle sizing, and custom icon/tooltips without requiring a custom Java/core patch.

Enshrouded Sleep's Rested / Well Rested renderer is independently written for this project. It does **not** include, copy, adapt verbatim, or redistribute Lifestyle source code, textures, icons, or other assets. A small optional compatibility check may read Lifestyle's already-existing runtime `LSMoodleManager` / player `LSMoodles` state when Lifestyle is actually installed, solely to reserve visible UI slots and avoid overlap; Enshrouded Sleep does not mutate that state and does not require Lifestyle.

Moodle Framework was also considered during SPIKE-007 as a possible optional UI integration. The final self-contained candidate does not require it and redistributes none of its code or assets.
