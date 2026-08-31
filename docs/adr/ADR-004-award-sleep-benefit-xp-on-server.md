# ADR-004 — Award Sleep-Benefit XP on the Server

Status: **Accepted**

Decision established: feature/sleep-benefits development

ADR written: 2026-08-31

## Context

SPIKE-007 initially listened for positive XP on the owning client and called `addXpNoMultiplier()` there using a percentage received in server-authored benefit state. Focused dedicated-server tests observed normal exercise activity but no `XP_BONUS` diagnostic at several configured percentages. The tested character's Fitness and Strength were below maximum, so a capped skill did not explain the absence.

The installed Build 42 server `XpSystem/XpUpdate.lua` registers `Events.AddXP` with an `(owner, perk, amount)` callback. Server-side observation also better matches the existing authority boundary: sleep qualification, active benefit state, expiry, and sandbox percentages already belong to the server.

## Decision

The dedicated server will award sleep-benefit XP:

1. observe positive `Events.AddXP` callbacks;
2. use the callback's player and perk directly rather than enumerating skills;
3. read the player's authoritative active benefit and the current server sandbox percentage;
4. add `amount × percentage / 100` to the same perk through `addXpNoMultiplier()`;
5. use a per-player recursion guard around that flat award;
6. disable only the XP capability for the server session if the event or flat-award API is unavailable or fails.

The client receives XP percentage data for presentation only and does not award or request XP.

## Alternatives considered

### Keep the owning-client award path

Rejected because the focused live test produced no observable awards and because it leaves XP mutation on the less authoritative side of the multiplayer boundary.

### Enumerate every possible skill when a character loads

Rejected because it does not identify when or how much XP was earned. The event already supplies the exact perk and amount, including supported modded perks that use the standard XP path.

### Add a client command requesting each bonus

Rejected because it creates a client-controlled XP request surface and duplicates information already available to the server event.

## Consequences / tradeoffs

Positive:

- benefit qualification and XP mutation share one authority boundary;
- no maintained skill allowlist is required;
- normal standard-event perks are handled generically;
- clients cannot directly mint the reward;
- XP failures remain isolated from sleep and clock behavior.

Tradeoffs:

- the design depends on Build 42 continuing to expose the server `AddXP` event and `addXpNoMultiplier()`;
- mods that bypass the standard XP event will not receive this reward;
- ordering with other server XP modifiers may affect which amount is observed and requires runtime validation;
- focused runtime validation has passed for the configurable percentage formula; the module has no access-level/admin-mode branch. Other-mod ordering and broader two-player coverage remain live-validation targets, and the feature remains behind the disabled-by-default feature flag.

## Validation evidence

- [`../spikes/SPIKE-007-sleep-benefits.md`](../spikes/SPIKE-007-sleep-benefits.md)
- [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md)
- focused one-player server-XP retest: `35` events, `52.9` base XP, and `52.9` flat bonus XP at `100%` across four perks, with no arithmetic mismatch or recursion
- installed Build 42 `media/lua/server/XpSystem/XpUpdate.lua`

## Related issues/spikes/commits

- SPIKE-007
- GitHub issue #10
- Feature branch `feature/sleep-benefits`
