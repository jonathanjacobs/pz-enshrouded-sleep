# Project documents

Do not update for: a change inside one document. Update this index when a file or folder in `docs/` is added, removed, or renamed. Where a given fact belongs is decided in [`DOCUMENTATION_OWNERSHIP.md`](DOCUMENTATION_OWNERSHIP.md); this file only lists what is here.

Everything in this folder is for people developing the mod. Players and server operators need only the root [`README.md`](../README.md) and the Workshop page.

## Designing the mod

| Document | Question it answers |
| --- | --- |
| [`DESIGN.md`](DESIGN.md) | What must the mod do, which names must never change, and how does the code do it? |
| [`ROADMAP.md`](ROADMAP.md) | What is being worked on now, and in what order? |
| [`adr/`](adr/README.md) | Which technical decisions with real alternatives were made, and why? |
| [`spikes/`](spikes/README.md) | What did an experiment show about uncertain engine behavior? |

## Testing it

| Document | Question it answers |
| --- | --- |
| [`TESTING.md`](TESTING.md) | Which checks and in-game tests show the mod works, and where do logs and test scripts go? |
| [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) | What was actually observed in tests, on which build, and what was not covered? |

## Releasing it

| Document | Question it answers |
| --- | --- |
| [`RELEASING.md`](RELEASING.md) | How does a version get to the Workshop, which number does it get, and how is it rolled back? |
| [`workshop-description.bbcode`](workshop-description.bbcode) | What does the Workshop page say? Pasted into Steam after every upload |

## Rules that apply throughout

| Document | Question it answers |
| --- | --- |
| [`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md) | What does The Indie Stone's modding policy require of this mod? |
| [`PRIVATE_DATA.md`](PRIVATE_DATA.md) | Which server, player, and credential details must never reach the repository, and what if one does? |
| [`DOCUMENTATION_OWNERSHIP.md`](DOCUMENTATION_OWNERSHIP.md) | Which document owns which fact? |

## Reference and setup

| Document | Question it answers |
| --- | --- |
| [`RESEARCH_LINKS.md`](RESEARCH_LINKS.md) | Which external references and other mods were used for ideas? |
| [`images/`](images/) | Which images does the root README show? Holds the Enshrouded Sleep banner |

Outside this folder: [`../CHANGELOG.md`](../CHANGELOG.md) records what changed in each release, [`../CREDITS.md`](../CREDITS.md) where every distributed asset came from, [`../ASSET_LICENSE.md`](../ASSET_LICENSE.md) the terms for the mod's creative assets, and [`../AGENTS.md`](../AGENTS.md) the working rules for coding agents.
