# Design

Status: **Current for v1.0.1**

Do not update for: task status or milestones ([`ROADMAP.md`](ROADMAP.md)), test results ([`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md)), or experiment narratives ([`spikes/`](spikes/)).

This document has two parts with different authority. **Requirements** state what the mod must do, as players and server operators see it. **Architecture** describes how the current implementation does it. Keep them separate: an implementation detail is not a requirement until it is written into the requirements section, and a requirement does not change because the code happens to behave differently.

## Requirements

### Project identity

- Mod name: Enshrouded Sleep
- Mod ID: `pz-enshrouded-sleep`
- Target Build: Build 42; `versionMin=42.20.0`, validated on 42.21.0
- Primary supported mode: dedicated multiplayer server only; standalone single-player and hosted (listen) games are not supported targets

### Scope

Enshrouded Sleep is a multiplayer-server mod. Local/standalone single-player support is outside scope.

- In scope: letting part of a multiplayer server population sleep without requiring every living player to go to bed at the same time — for server operators, who configure it, and for players, who experience it.
- Explicitly out of scope:
  - local/standalone single-player support;
  - custom fatigue or sleep eligibility;
  - ready/not-ready voting or lobby readiness tracking;
  - global active-simulation fast-forward during partial sleep;
  - broad automatic compensation of unmeasured world systems;
  - guaranteed compatibility with every sleep, survival, time-altering, XP, endurance, or chat/UI mod;
  - Project Zomboid Java/core-file patching for ordinary Workshop distribution.

### Definitions

- **BaselineMinutesPerDay** — captured authoritative server day length when Enshrouded Sleep compression is inactive.
- **NativeFastForward** — live server `FastForwardMultiplier`.
- **PartialSleepSpeedScale** — administrator multiplier applied to normal partial-sleep compression.
- **LivingPlayers** — server `getOnlinePlayers()` entries where `isDead()==false`.
- **SleepingPlayers** — LivingPlayers where `isAsleep()==true`.
- **SleepFraction** — `SleepingPlayers / LivingPlayers`.
- **CalendarCompressionFactor** — factor by which game-world/calendar time is accelerated relative to native day length.
- **EffectiveMinutesPerDay** — `BaselineMinutesPerDay / CalendarCompressionFactor`.
- **Awake player** — a living player whose `isAsleep()` is not true.
- **Rested / Well Rested benefit** — optional, non-stacking post-sleep gameplay reward whose qualification and expiry are server-authoritative.


### Behavior

Numbered, testable requirements (`R1`, `R2`, …) that tests, commits, and issues cite. They are grouped by area in the sections below.

### Core clock and sleep behavior

#### R1 — Server authority

Normal proportional-sleep policy is calculated from multiplayer-server state. Server code must not introduce a local `getPlayer()` fallback to emulate standalone behavior.

#### R2 — Respect vanilla sleep eligibility

The mod must not bypass native sleep restrictions. If native server sleep is disabled, normal partial-sleep compression must not create an alternate sleep mechanism.

#### R3 — Capture the runtime baseline

Baseline day length must come from authoritative `GameTime:getMinutesPerDay()`, not a hard-coded sandbox preset mapping.

#### R4 — Inherit native fast-forward policy

Normal partial sleep must read the server's live `FastForwardMultiplier`; it must not assume a fixed value.

#### R5 — Use vanilla-visible living population

The denominator consists only of instantiated living server players returned by `getOnlinePlayers()`. Dead characters are excluded. Loading clients enter only when vanilla exposes an `IsoPlayer`.

#### R6 — Zero sleepers means native baseline

When no living player is asleep, authoritative and client day length must converge to the captured baseline.

#### R7 — Partial sleep is proportional

When `0 < SleepingPlayers < LivingPlayers`:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward × PartialSleepSpeedScale
CalendarCompressionFactor = max(1, EffectivePartialSleepCap × SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

#### R8 — Never slow below native day length

`CalendarCompressionFactor` must never be less than `1`.

#### R9 — Do not globally fast-forward active simulation

Normal partial sleep must not use `GameTime:setMultiplier()` as its acceleration mechanism. Movement, combat, zombies, vehicles, animations, physics, and ordinary timed actions remain on the normal active-simulation path.

#### R10 — All living players asleep hands off to vanilla

When every living player is asleep, Enshrouded Sleep must restore baseline `MinutesPerDay`, synchronize clients to baseline pacing, and leave full-sleep acceleration to vanilla.

#### R11 — Recalculate from current population

Sleep/wake, join, disconnect, death, and respawn changes must affect policy as soon as those changes are visible through server player state. The controller must not accumulate or stack historical sleep fractions.

#### R12 — Fail toward baseline

Disabling the controller or encountering a recoverable clock/configuration failure must not intentionally leave the server at a stale compressed day length.

### Awake-player survival protection

#### R13 — Protection is independently configurable

`AwakePlayerProtectionEnabled` controls survival-state normalization independently of the proportional clock controller. Disabling protection must not disable proportional sleep itself.

#### R14 — Protect only supported awake-player fields

During normal partial sleep, enabled protection may normalize only:

- Hunger;
- Thirst;
- Fatigue;
- Calories;
- Carbohydrates;
- Proteins;
- Lipids;
- Weight progression.

#### R15 — Never correct sleepers or dead players

Sleeping and dead players must remain outside the awake-protection mutation path.

#### R16 — Derive correction from observed compression

The protection factor must be based on the relationship between captured baseline `MinutesPerDay` and current authoritative `MinutesPerDay`, not on an independently guessed sleeping ratio.

#### R17 — Preserve favorable direct effects

For Hunger/Thirst/Fatigue and nutrition stores, the normalizer must reduce only the direction associated with passive worsening/depletion. Opposite-direction favorable effects such as tested eating/drinking changes must not be divided by the compression factor. Weight may be normalized in either direction.

#### R18 — Fail open per player

If a protected-state read or write fails, the affected player's correction reference must be cleared and that player must fall back to vanilla progression rather than receiving a later accumulated catch-up correction.

#### R19 — Protection must not compensate unrelated systems

Acute injury/body-health effects, endurance, sleep physiology, external world objects, and arbitrary modded systems must not be altered by the awake-player protection module unless separately justified by future requirements.

### Client synchronization

#### R20 — Clients mirror authoritative day length

Connected clients must receive and apply the server-selected `MinutesPerDay`; clients must not calculate their own proportional target.

#### R21 — Server remains authoritative

Client synchronization must not substitute independent `setTimeOfDay()` or global multiplier changes for server day-length authority.

#### R22 — Missed transitions converge

A low-frequency authoritative heartbeat is permitted so late/loading clients and missed transitions converge to the current server target.

#### R23 — Publish settled state

Synchronization may defer a population transition briefly so the controller's new authoritative `MinutesPerDay` is applied before clients are told to mirror it.

### Diagnostics and support behavior

#### R24 — Verbose diagnostics are opt-in

High-frequency diagnostic telemetry must be disabled by default. Low-volume operational state transitions may remain enabled during normal play.

#### R25 — Diagnostic forced compression is isolated

A forced diagnostic compression factor greater than `1` may operate only when verbose diagnostics are enabled and exactly one living awake player is connected. It must suspend/restore baseline if that player sleeps or another living player joins, and it must not call the global simulation multiplier.

#### R26 — Diagnostic capability failures degrade safely

Optional diagnostic probes must fail to `N/A`, disable/circuit-break the unavailable probe, or otherwise degrade without producing uncontrolled repeated exceptions or breaking gameplay.

### Persistence and rollback

#### R27 — No required custom persistent sleep database

The mod must not require a custom persistent database or migration merely to disable/remove it.

#### R28 — Removal returns future behavior to vanilla

After clean server stop/removal/restart, future sleep/time behavior must return to vanilla, subject to ordinary save state already produced by elapsed world time.

### Distribution/runtime invariants

#### R29 — One authoritative runtime tree

The only deployable Project Zomboid runtime tree in the repository is:

```text
Contents/mods/pz-enshrouded-sleep/
```

No second root-level runtime `42/`, `common/`, or `mod.info` copy may be maintained.

#### R30 — Stable identities

The Project Zomboid Mod ID remains `pz-enshrouded-sleep`. Steam Workshop publication must continue using the existing permanent Workshop item rather than creating routine replacement items.

### Optional sleep-status notifications

#### R31 — Notifications are independently configurable, administrator-controlled, and opt-in

`SleepNotificationsEnabled` is a server-administrator setting that controls only player-facing sleep-status messages. It must default to `false`, and disabling it must not alter proportional sleep, client clock synchronization, or awake-player protection. Clients must not independently enable notification broadcasts.

#### R32 — Notifications describe settled authoritative state

When enabled, notifications must be derived from the authoritative server's settled `MinutesPerDay` and living/sleeping population rather than independently calculating sleep policy. A sleep/population transition may be deferred briefly so the controller's new day length is visible before the message is sent.

#### R33 — Notifications are transition-based and concise

Notifications must be emitted only when the effective multiplayer sleep state changes, including sleep/wake changes and population changes that alter the active sleep fraction. Routine all-awake startup state must not generate a player-facing message. Normal partial-sleep messages report both the actual living/sleeping count and percentage and must explicitly describe **world time**, not active simulation speed, for example:

```text
[Enshrouded Sleep] 1/2 living players sleeping (50%). World time is 20x faster.
```

When all living players are awake, the message must report normal world time. When all living players are asleep, the message must identify vanilla full-sleep fast-forward rather than claim a specific Enshrouded Sleep compression factor.

A chat/UI bridge failure must degrade independently and must never affect the sleep/time controller.

#### R34 — Multiplayer messages use predefined commands, not executable payloads

Server/client synchronization and optional notifications must use predefined named command handlers and structured data. Runtime code must not depend on dynamic execution APIs such as `loadstring` or `loadstream` for server-supplied code. Project Zomboid 42.20.4 removed those APIs and 42.21.0 restored them; this requirement is a design choice that keeps executable code off the network path regardless of their availability.

### Optional Rested / Well Rested sleep benefits

#### R35 — Sleep benefits are independently configurable and opt-in

`SleepBenefitsEnabled` controls the voluntary-sleep reward system independently of proportional sleep, awake-player protection, and sleep notifications. It must default to `false`. Disabling it must stop the XP/endurance bonuses and clear active Rested / Well Rested benefit state without disabling Enshrouded Sleep clock behavior.

#### R36 — Qualification uses actual game-world sleep duration

The server must determine a sleep attempt from `IsoPlayer:isAsleep()` transitions and measure duration using authoritative game-world time (`GameTime:getWorldAgeHours()`). Qualification is based on game hours slept, not wall-clock time.

The current in-progress sleep attempt must remain session-scoped: disconnecting or restarting the server while a character is asleep must not convert offline elapsed world time into qualifying sleep.

#### R37 — Default tiers and all reward values are administrator-adjustable

The default policy is:

```text
sleep < 8 hours      -> no new benefit
8 <= sleep <= 12    -> Rested
sleep > 12          -> Well Rested

Rested:
  duration = 4 game hours
  XP bonus = 10%

Well Rested:
  duration = 6 game hours
  XP bonus = 10%
  Endurance recovery bonus = 10%
```

The Rested/Well Rested minimum sleep thresholds, durations, XP percentages, and Well Rested Endurance-recovery percentage must be server sandbox options. If the configured Well Rested threshold is below the Rested threshold, runtime behavior must safely clamp the effective Well Rested threshold upward to the Rested threshold.

Well Rested qualification is strictly above its configured threshold. Sleep exactly at that threshold remains Rested when it also meets the Rested minimum. Sleeping beyond the Well Rested threshold must remain Well Rested; oversleeping must not remove the reward.

#### R38 — Benefits do not stack

At most one Rested / Well Rested benefit may be active for a player. A new qualifying sleep replaces or refreshes the current tier rather than stacking multipliers or durations. A sleep attempt below the Rested minimum does not itself cancel an otherwise active, unexpired benefit.

#### R39 — Earned benefit state persists by game-world expiry; death clears it

Once awarded, the benefit type and expiry world hour may be stored in player ModData so an already-earned benefit can survive ordinary reconnect/server restart behavior. Expiry must continue to use game-world hours.

Death must clear the active benefit. Removing/disabling the feature must not require a database migration or leave a gameplay modifier active.

#### R40 — XP bonus is server-authoritative and must not recursively compound

The dedicated server must observe positive Build 42 `AddXP` events and determine the reward from the server-authored active benefit and server sandbox percentage. The event-supplied perk must receive the bonus; the implementation must not maintain a skill allowlist or require the client to request or mint bonus XP.

Bonus XP must be added as flat/no-multiplier XP and protected by a per-player recursion guard so the configured percentage is applied once rather than being multiplied again or recursively re-awarded.

A missing/failing XP bridge must fail open for the reward feature and must not affect sleep/time behavior.

#### R41 — Well Rested boosts recovery, not maximum Endurance or Endurance expenditure

While Well Rested is active, the server may amplify only **positive** observed Endurance deltas by the configured percentage. Negative Endurance deltas must remain untouched. Corrected Endurance must never exceed the normal maximum of `1.0`.

This correction is directional rather than source-specific: positive Endurance changes produced by another mod may also be amplified. This limitation must be documented and validated before release.

#### R42 — Custom Moodle display is self-contained and presentation-only

Rested and Well Rested must be displayable by an Enshrouded Sleep-owned client `ISUIElement`; the gameplay feature must not require an external Moodle framework or another Workshop dependency.

The renderer may reference Project Zomboid's installed vanilla Moodle background/outline textures at runtime and draw original Enshrouded Sleep icon artwork over them. It must follow the player's current Build 42 Moodle-size setting and position itself after visible vanilla moodles rather than patching Project Zomboid Java/core files.

Compatibility logic may read another installed mod's public/runtime state solely to avoid UI overlap—for example, detecting active Lifestyle moodle slots—but must not require, mutate, bundle, or redistribute that mod's code or assets.

A custom-Moodle UI failure must degrade independently: benefit qualification, expiry, XP reward, Endurance reward, proportional sleep, and awake-player protection must remain unaffected.

### Compatibility contracts

Some names outlive the code that defines them, because something outside the current build stores or calls them. Changing one breaks existing worlds, server settings, or other mods even when the new code is correct. List each one here as it is introduced, so a later change can be checked against the list.

| Kind | What depends on it |
| --- | --- |
| Mod ID | Server `Mods=` lines, saved worlds' mod lists, and other mods that declare it in `require=`. A changed ID is a different mod |
| Sandbox option names | Server settings files and saved worlds store values by name; a renamed option loses the value that was set |
| Sandbox option defaults | New worlds, and any setup that never set the option, get the new behavior without being told |
| ModData keys and saved-data layout | Data already saved in worlds and player files; a renamed key orphans it |
| Client/server command module and command names | A client and server on different mod versions during an update, and any other mod that sends or listens for them |
| Item, recipe, and other script full types (`Module.Name`) | Items already in saved inventories and containers, and other mods' recipes and distributions |
| Lua module paths other mods `require` | Add-ons and compatibility patches built on this mod |

| Kind | Name | Defined in | Since version |
| --- | --- | --- | --- |
| Mod ID | `pz-enshrouded-sleep` | `Contents/mods/pz-enshrouded-sleep/mod.info`, `42/mod.info` | 0.0.4 |
| Sandbox option | `EnshroudedSleep.Enabled` (default `true`) | `42/media/sandbox-options.txt` | 0.0.4 |
| Sandbox option | `EnshroudedSleep.PartialSleepSpeedScale` (default `1.0`) | `42/media/sandbox-options.txt` | 0.0.4 |
| Sandbox option | `EnshroudedSleep.DiagnosticsEnabled` (default `false`) | `42/media/sandbox-options.txt` | 0.0.7 |
| Sandbox option | `EnshroudedSleep.DiagnosticForcedCompressionFactor` (default `1.0`) | `42/media/sandbox-options.txt` | 0.0.10 |
| Sandbox option | `EnshroudedSleep.AwakePlayerProtectionEnabled` (default `true`) | `42/media/sandbox-options.txt` | 0.1.0 |
| Sandbox option | `EnshroudedSleep.SleepNotificationsEnabled` (default `false`) | `42/media/sandbox-options.txt` | 0.1.1 |
| Sandbox option | `EnshroudedSleep.SleepBenefitsEnabled` (default `false`) | `42/media/sandbox-options.txt` | 1.0.0 |
| Sandbox option | `EnshroudedSleep.RestedMinimumSleepHours` (default `8.0`), `EnshroudedSleep.RestedDurationHours` (default `4.0`), `EnshroudedSleep.RestedXPBonusPercent` (default `10.0`) | `42/media/sandbox-options.txt` | 1.0.0 |
| Sandbox option | `EnshroudedSleep.WellRestedMinimumSleepHours` (default `12.0`), `EnshroudedSleep.WellRestedDurationHours` (default `6.0`), `EnshroudedSleep.WellRestedXPBonusPercent` (default `10.0`), `EnshroudedSleep.WellRestedEnduranceRecoveryBonusPercent` (default `10.0`) | `42/media/sandbox-options.txt` | 1.0.0 |
| ModData key (player) | `EnshroudedSleepBenefitType`, `EnshroudedSleepBenefitExpiresAtWorldHour`, `EnshroudedSleepBenefitLastQualifyingSleepHours` | `42/media/lua/server/EnshroudedSleep/SleepBenefits_Server.lua` | 1.0.0 |
| Server-to-client command | Module `EnshroudedSleep`, command `ClockState` (`protocolVersion` 1) | `ClockStateSync_Server.lua` / `ClockStateSync_Client.lua` | 0.0.6 |
| Server-to-client command | Module `EnshroudedSleep`, command `SleepNotification` | `SleepNotification_Server.lua` / `SleepNotification_Client.lua` | 0.1.1 |
| Server-to-client command | Module `EnshroudedSleep`, command `SleepBenefitState` | `SleepBenefits_Server.lua` / `SleepBenefits_Client.lua` | 1.0.0 |
| Lua module path (internal) | `EnshroudedSleep/SurvivalStatProbe` | `42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua` | 0.0.10 |
| Lua module path (internal) | `EnshroudedSleep/SleepBenefitMoodle_Client` | `42/media/lua/client/EnshroudedSleep/SleepBenefitMoodle_Client.lua` | 1.0.0 |

The mod defines no item, recipe, or other script modules, and sends no client-to-server commands. The two Lua modules marked internal are `require`d only by the mod itself and are not supported for other mods to build on; moving or renaming one needs a changelog note, not a breaking-change version.

A change to a listed name follows the rules in `AGENTS.md`: only on explicit request, with an `Upgrading` note in [`../CHANGELOG.md`](../CHANGELOG.md) and a version number chosen as [`RELEASING.md`](RELEASING.md#choosing-the-version-number) describes. Mark a retired name `retired in x.y.z` instead of deleting its row, so the history of what saves may still contain stays visible.

## Architecture

Durable decisions with realistic alternatives are recorded as ADRs under [`adr/`](adr/); validation evidence lives in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) and [`spikes/`](spikes/).

### Runtime boundary

Enshrouded Sleep is a Project Zomboid Build 42 multiplayer-server mod. The authoritative runtime tree is:

```text
Contents/mods/pz-enshrouded-sleep/
```

The repository root is also the Steam Workshop item wrapper, but outer documentation/artwork is not part of the runtime mod tree.

### Time model

Partial sleep changes calendar pacing without globally fast-forwarding active simulation.

```text
LivingPlayers   = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
SleepFraction   = SleepingPlayers / LivingPlayers

EffectivePartialSleepCap = FastForwardMultiplier × PartialSleepSpeedScale
CalendarCompressionFactor = max(1, EffectivePartialSleepCap × SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

State behavior:

```text
0 sleepers
    -> baseline MinutesPerDay

some but not all living players asleep
    -> proportional MinutesPerDay compression

all living players asleep
    -> restore baseline MinutesPerDay
    -> vanilla full-sleep acceleration owns the state
```

The controller does not use `GameTime:setMultiplier()` for normal partial sleep. ADR-001 records the `MinutesPerDay` decision; ADR-002 records the vanilla lifecycle/full-sleep handoff.

### Server authority

`EnshroudedSleep_Server.lua` owns normal server policy and authoritative `GameTime:setMinutesPerDay()` writes. It captures the live native baseline rather than deriving day length from a hard-coded sandbox mapping, and it reads the server's native `FastForwardMultiplier` at runtime.

Player population is derived only from server-visible `IsoPlayer` instances. Dead characters are excluded. Loading clients do not enter the denominator until vanilla exposes them through `getOnlinePlayers()`.

Recoverable controller failures fail toward the captured baseline.

### Client clock pacing

The server remains authoritative for world time and proportional policy.

```text
EnshroudedSleep_Server.lua
    -> calculates/applies authoritative MinutesPerDay

ClockStateSync_Server.lua
    -> observes settled server state
    -> publishes ClockState packets

ClockStateSync_Client.lua
    -> validates packets
    -> mirrors authoritative MinutesPerDay locally
```

Clients do not independently recalculate the sleeping fraction or compression target. ADR-003 records this design.

### Command/security boundary

All Enshrouded Sleep multiplayer messages use predefined module/command names and structured argument tables through Project Zomboid's `sendServerCommand` / `OnServerCommand` path. The server does not transmit executable Lua source to clients, and runtime code does not depend on `loadstring` or `loadstream`.

This architecture was unaffected when the Project Zomboid 42.20.4 security change removed those dynamic-code methods, and is unchanged by their return in 42.21.0. Package validation rejects runtime references to either API.

### Awake-player survival protection

`AwakePlayerProtection_Server.lua` is a server-authoritative post-update normalizer used during normal partial sleep when `AwakePlayerProtectionEnabled=true`.

Protected fields:

- Hunger
- Thirst
- Fatigue
- Calories
- Carbohydrates
- Proteins
- Lipids
- Weight

The module runs on `Events.OnTick`, iterates all living server players, and derives the observed compression factor from:

```text
BaselineMinutesPerDay / CurrentMinutesPerDay
```

It never corrects sleeping or dead players. Correction is active only when some-but-not-all living players are asleep and `MinutesPerDay` is actually below baseline, except for the isolated diagnostic forced-compression path.

The correction is directional:

- worsening Hunger/Thirst/Fatigue deltas are reduced to the fraction expected at native day length;
- passive depletion of Calories/Carbohydrates/Proteins/Lipids is reduced similarly;
- opposite-direction favorable effects are accepted in full;
- Weight deltas are normalized in either direction.

Each player's previous corrected snapshot becomes the reference for the next tick. A failed read/write clears that player's reference and fails open rather than applying a later catch-up correction.

Detailed feasibility evidence and limitations belong in [`spikes/SPIKE-006-awake-player-protection.md`](spikes/SPIKE-006-awake-player-protection.md).

### Optional sleep-status notifications

Sleep notifications are deliberately separated from sleep/time policy and are controlled only by the server administrator through `SleepNotificationsEnabled`.

```text
EnshroudedSleep_Server.lua
    -> owns authoritative MinutesPerDay

SleepNotification_Server.lua
    -> observes living/sleeping population
    -> waits one observer pass after a population transition
    -> derives displayed compression from settled BaselineMinutesPerDay / CurrentMinutesPerDay
    -> authors concise count/percentage/compression text
    -> broadcasts a versioned SleepNotification server command

SleepNotification_Client.lua
    -> validates the packet
    -> displays the server-authored text in a self-contained ISUIElement banner
```

`SleepNotificationsEnabled` defaults to `false`. The server notifier does not announce ordinary all-awake startup state and emits only when the effective sleep state changes. Population changes during partial sleep are included because they can change the active sleep fraction and therefore the displayed acceleration.

The client does not use `ChatManager`, which the live Build 42.20.4 Kahlua environment does not expose; package validation rejects reintroducing that bridge. The banner is circuit-broken after a UI failure. A notification failure cannot change `MinutesPerDay`, player sleep state, client clock policy, or awake-player protection.

### Optional Rested / Well Rested benefits

SPIKE-007 adds a separate, opt-in reward layer for servers where sleep itself may be optional. It does not alter vanilla sleep eligibility or the proportional clock controller.

```text
SleepBenefits_Server.lua
    -> observes server IsoPlayer:isAsleep() transitions
    -> records current sleep start in server-session memory
    -> measures sleep in GameTime:getWorldAgeHours()
    -> classifies Rested / Well Rested from server sandbox thresholds
    -> stores awarded benefit type + expiry world hour in player ModData
    -> observes positive AddXP events and awards flat bonus XP to the event perk
    -> amplifies only positive Endurance recovery while Well Rested
    -> sends SleepBenefitState only to the owning client

SleepBenefits_Client.lua
    -> validates server-authored SleepBenefitState
    -> forwards presentation state to the Enshrouded Sleep-owned Moodle renderer

SleepBenefitMoodle_Client.lua
    -> owns one non-stacking ISUIElement status slot
    -> follows the current Build 42 Moodle-size setting
    -> counts visible vanilla moodles and positions below them
    -> draws vanilla runtime background/outline resources plus original project art
    -> provides Rested / Well Rested hover text and remaining game time
```

#### Benefit state ownership

The server owns qualification, tier, expiry, and Endurance-recovery percentage. A client never decides that a sleep attempt qualified.

The Rested minimum is inclusive. The Well Rested threshold is exclusive: sleep exactly at that threshold remains Rested, while sleep longer than it qualifies as Well Rested. If an administrator configures the Well Rested threshold below the Rested minimum, the effective threshold is clamped up to the Rested minimum before classification.

An in-progress sleep attempt is deliberately **not** persisted. If a player disconnects or the server restarts while the character is sleeping, that unfinished attempt is discarded so offline elapsed world time cannot become rewarded sleep.

An already-earned benefit is persisted in player ModData using its absolute world-hour expiry. That permits an earned Rested / Well Rested state to survive normal reconnect/server restart behavior while still expiring according to game-world time.

#### XP boundary

Build 42's installed server `XpSystem/XpUpdate.lua` registers `Events.AddXP` with the `(player, perk, amount)` event shape. `SleepBenefits_Server.lua` observes positive awards, reads the player's authoritative persisted benefit, and adds the configured percentage to the same event-supplied perk with `addXpNoMultiplier()`.

There is no skill enumeration or client award request. A per-player recursion guard prevents the flat bonus award from generating more bonus XP. Missing or failing XP APIs disable only the XP reward for that server session; benefit state, Endurance, sleep, and clock behavior continue. This integration remains a validation target because other XP-altering mods may also observe or modify the event stream.

#### Endurance boundary

`SleepBenefits_Server.lua` resolves `CharacterStat.ENDURANCE` through the same guarded stat-access model used elsewhere in the project. While Well Rested is active, only positive Endurance deltas are amplified:

```text
extra = observedPositiveRecovery × configuredPercent / 100
corrected = min(1.0, currentEndurance + extra)
```

Endurance depletion is never reduced and maximum Endurance is not increased. The correction is directional rather than source-specific, so positive Endurance changes introduced by another mod can also receive the bonus.

#### Moodle/UI boundary

The sleep-benefit Moodle renderer is self-contained. It does not register a custom vanilla `MoodleType`, patch Project Zomboid Java/core files, or require Moodle Framework/Lifestyle.

Build 42's vanilla `MoodlesUI` already exposes the relevant presentation conventions: Moodle sizes of `32/48/64/80/96/128`, a top offset of `120`, a `10`-pixel slot gap, and installed background/outline resources under `media/ui/Moodles/<size>/`. Enshrouded Sleep mirrors those layout conventions in client Lua and references those installed vanilla resources at runtime; it does not redistribute them.

The tier artwork is owned by this project:

```text
media/ui/Moodle_EnshroudedRested.png
media/ui/Moodle_EnshroudedWellRested.png
```

The renderer reserves slots for visible vanilla moodles. If Lifestyle is actually loaded, it may also read the existing `LSMoodleManager` / player `LSMoodles` state to reserve currently visible Lifestyle slots and avoid overlap. That compatibility check is read-only and does not create a Lifestyle dependency or copy its implementation.

The UI is presentation-only. A renderer/texture/compatibility failure must not affect benefit state, XP, Endurance, sleep behavior, or clock behavior.

Detailed feasibility assumptions and the required field test are in [`spikes/SPIKE-007-sleep-benefits.md`](spikes/SPIKE-007-sleep-benefits.md).

### Diagnostic forced compression

`DiagnosticForcedCompressionFactor` is a support/regression mechanism, not normal gameplay tuning. It can compress `MinutesPerDay` with exactly one living awake player only when verbose diagnostics are enabled.

A sleeping player, a second living player, disabling diagnostics, returning the factor to `1.0`, or a recoverable controller failure exits/suspends the forced path toward baseline. The forced path remains separate from normal multiplayer partial sleep.

Operational use belongs in the [configuration reference](../README.md#configuration-reference); test procedures belong in [`TESTING.md`](TESTING.md).

### Observability

Normal operation emits low-volume controller, synchronization, roster, awake-protection, sleep-benefit, and—when explicitly enabled—sleep-notification transitions. High-frequency health/survival/action/world-system telemetry is gated by `DiagnosticsEnabled=true`.

Shared survival-state access is centralized in:

```text
Contents/mods/pz-enshrouded-sleep/42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
```

Diagnostics and presentation bridges are designed to degrade unavailable capabilities rather than break gameplay.

### Time-domain boundary

Changing `MinutesPerDay` intentionally accelerates systems tied to game-world/calendar time. Awake-player protection compensates only its explicit player-survival scope. External systems such as food aging, generator resources, vehicle resources, farming, corpses, weather, and modded world systems remain outside this module.

Rested / Well Rested benefit durations intentionally follow game-world hours, so they expire according to the same accelerated calendar whenever partial sleep advances world time faster.

Evidence for individual time domains belongs in SPIKE-004/SPIKE-005 and `VALIDATION_HISTORY.md`; architecture should not duplicate their measurement tables.

### Design constraints

- no global simulation fast-forward for partial sleep;
- no dynamic execution of server-supplied Lua code;
- no custom readiness/voting registry;
- no local/standalone single-player fallback in server policy;
- no Project Zomboid Java/core patching for ordinary Workshop distribution;
- no broad subsystem compensation without measured evidence;
- sleep-benefit Moodle presentation must remain self-contained and independent of gameplay authority;
- no redistribution of third-party custom-Moodle code or artwork;
- vanilla remains authoritative for sleep eligibility, actual sleep state, and all-living-asleep fast-forward.

### Runtime layout

```text
Contents/mods/pz-enshrouded-sleep/
  mod.info
  common/
    media/
  42/
    mod.info
    poster.png
    icon.png
    media/
      lua/
        client/
        server/
        shared/
          Translate/EN/
      sandbox-options.txt
      ui/
```

Build 42 expects both a `common/` folder and a build-specific `42/` folder beside the root `mod.info`. Git does not track empty directories, so `.gitkeep` placeholders stay under `media/AnimSets/` and `media/actiongroups/` until real content occupies the folders.

Both `mod.info` files carry the same `id=`, `name=`, `description=`, `author=`, `category=`, `modversion=`, and `versionMin=` values. The build-specific `42/mod.info` also references `poster=` and `icon=` artwork. Use `modversion=` for the mod's release version (not `version=`), and set `versionMin=` to the oldest Project Zomboid build the mod has actually been tested on. Keep `modversion=` equal to [`../VERSION`](../VERSION); the package validator checks this.

There is one authoritative runtime tree. Do not create a second root-level `42/`, `common/`, `media/`, or `mod.info` copy.

### Build stamp and version handshake

Recommended from the first multiplayer build. Mixed-version installs — a stale local copy beside the Workshop copy, a client that has not downloaded the update, or a server that has not restarted — are a common cause of confusing test results, and they are invisible unless the mod reports which build is running.

- Define the build version once, in a shared module (for example `42/media/lua/shared/<ModName>/Version.lua` returning `{ BUILD_VERSION = "x.y.z" }`), and `require` it wherever the version is needed. Keep it equal to [`../VERSION`](../VERSION); [`../tools/validate-package.sh`](../tools/validate-package.sh) rejects any `BUILD_VERSION = "..."`, `buildVersion = "..."`, or `Loaded vX.Y.Z` literal in runtime Lua that disagrees.
- **Server:** log the build and the effective configuration once at startup, for example `[<ModName>] CONFIG | build=x.y.z | <key settings>`.
- **Server to client:** include `buildVersion` in the first state message each client receives.
- **Client:** log `[<ModName>] SERVER_BUILD | x.y.z` once on receipt, and log `BUILD_MISMATCH | client=… | server=…` once if it differs from the client's own build.

With this in place, confirming that everyone runs the same package is a log search rather than a guess, and it is the first step in [`TESTING.md`](TESTING.md#before-testing) and in post-release verification.

Current state in Enshrouded Sleep: the handshake is in place. The server logs `CONFIG | build=` from the notification and sleep-benefit configuration modules, the `ClockState` and `SleepBenefitState` messages carry `buildVersion`, and the notification and sleep-benefit clients log `SERVER_BUILD` and `BUILD_MISMATCH`. The version itself is still a literal repeated in each of those Lua files rather than defined once; moving it into `42/media/lua/shared/EnshroudedSleep/Version.lua` is a recorded gap (see [`ROADMAP.md`](ROADMAP.md#later-work)).
