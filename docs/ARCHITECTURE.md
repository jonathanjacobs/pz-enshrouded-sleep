# Architecture

This document owns the current technical design of Enshrouded Sleep. Normative behavior belongs in [`REQUIREMENTS.md`](REQUIREMENTS.md), validation evidence in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) and [`spikes/`](spikes/), and durable decisions in [`adr/`](adr/).

## Runtime boundary

Enshrouded Sleep is a Project Zomboid Build 42 multiplayer-server mod. The authoritative runtime tree is:

```text
Contents/mods/pz-enshrouded-sleep/
```

The repository root is also the Steam Workshop item wrapper, but outer documentation/artwork is not part of the runtime mod tree.

## Time model

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

## Server authority

`EnshroudedSleep_Server.lua` owns normal server policy and authoritative `GameTime:setMinutesPerDay()` writes. It captures the live native baseline rather than deriving day length from a hard-coded sandbox mapping, and it reads the server's native `FastForwardMultiplier` at runtime.

Player population is derived only from server-visible `IsoPlayer` instances. Dead characters are excluded. Loading clients do not enter the denominator until vanilla exposes them through `getOnlinePlayers()`.

Recoverable controller failures fail toward the captured baseline.

## Client clock pacing

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

## Command/security boundary

All Enshrouded Sleep multiplayer messages use predefined module/command names and structured argument tables through Project Zomboid's `sendServerCommand` / `OnServerCommand` path. The server does not transmit executable Lua source to clients, and runtime code does not depend on `loadstring` or `loadstream`.

This architecture is intentionally compatible with the Project Zomboid 42.20.4 security change that removed those dynamic-code methods. Package validation rejects future runtime references to either API.

## Awake-player survival protection

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

## Optional sleep-status notifications

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
    -> displays the server-authored text through ChatManager.showServerChatMessage()
```

`SleepNotificationsEnabled` defaults to `false`. The server notifier does not announce ordinary all-awake startup state and emits only when the effective sleep state changes. Population changes during partial sleep are included because they can change the active sleep fraction and therefore the displayed acceleration.

The client chat bridge is circuit-broken after a bridge failure. A notification failure cannot change `MinutesPerDay`, player sleep state, client clock policy, or awake-player protection.

## Optional Rested / Well Rested benefits

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

### Benefit state ownership

The server owns qualification, tier, expiry, and Endurance-recovery percentage. A client never decides that a sleep attempt qualified.

An in-progress sleep attempt is deliberately **not** persisted. If a player disconnects or the server restarts while the character is sleeping, that unfinished attempt is discarded so offline elapsed world time cannot become rewarded sleep.

An already-earned benefit is persisted in player ModData using its absolute world-hour expiry. That permits an earned Rested / Well Rested state to survive normal reconnect/server restart behavior while still expiring according to game-world time.

### XP boundary

Build 42's installed server `XpSystem/XpUpdate.lua` registers `Events.AddXP` with the `(player, perk, amount)` event shape. `SleepBenefits_Server.lua` observes positive awards, reads the player's authoritative persisted benefit, and adds the configured percentage to the same event-supplied perk with `addXpNoMultiplier()`.

There is no skill enumeration or client award request. A per-player recursion guard prevents the flat bonus award from generating more bonus XP. Missing or failing XP APIs disable only the XP reward for that server session; benefit state, Endurance, sleep, and clock behavior continue. This integration remains a validation target because other XP-altering mods may also observe or modify the event stream.

### Endurance boundary

`SleepBenefits_Server.lua` resolves `CharacterStat.ENDURANCE` through the same guarded stat-access model used elsewhere in the project. While Well Rested is active, only positive Endurance deltas are amplified:

```text
extra = observedPositiveRecovery × configuredPercent / 100
corrected = min(1.0, currentEndurance + extra)
```

Endurance depletion is never reduced and maximum Endurance is not increased. The correction is directional rather than source-specific, so positive Endurance changes introduced by another mod can also receive the bonus.

### Moodle/UI boundary

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

## Diagnostic forced compression

`DiagnosticForcedCompressionFactor` is a support/regression mechanism, not normal gameplay tuning. It can compress `MinutesPerDay` with exactly one living awake player only when verbose diagnostics are enabled.

A sleeping player, a second living player, disabling diagnostics, returning the factor to `1.0`, or a recoverable controller failure exits/suspends the forced path toward baseline. The forced path remains separate from normal multiplayer partial sleep.

Operational use belongs in [`DEPLOYMENT.md`](DEPLOYMENT.md); test procedures belong in [`TESTING.md`](TESTING.md).

## Observability

Normal operation emits low-volume controller, synchronization, roster, awake-protection, sleep-benefit, and—when explicitly enabled—sleep-notification transitions. High-frequency health/survival/action/world-system telemetry is gated by `DiagnosticsEnabled=true`.

Shared survival-state access is centralized in:

```text
Contents/mods/pz-enshrouded-sleep/42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
```

Diagnostics and presentation bridges are designed to degrade unavailable capabilities rather than break gameplay.

## Time-domain boundary

Changing `MinutesPerDay` intentionally accelerates systems tied to game-world/calendar time. Awake-player protection compensates only its explicit player-survival scope. External systems such as food aging, generator resources, vehicle resources, farming, corpses, weather, and modded world systems remain outside this module.

Rested / Well Rested benefit durations intentionally follow game-world hours, so they expire according to the same accelerated calendar whenever partial sleep advances world time faster.

Evidence for individual time domains belongs in SPIKE-004/SPIKE-005 and `VALIDATION_HISTORY.md`; architecture should not duplicate their measurement tables.

## Design constraints

- no global simulation fast-forward for partial sleep;
- no dynamic execution of server-supplied Lua code;
- no custom readiness/voting registry;
- no local/standalone single-player fallback in server policy;
- no Project Zomboid Java/core patching for ordinary Workshop distribution;
- no broad subsystem compensation without measured evidence;
- sleep-benefit Moodle presentation must remain self-contained and independent of gameplay authority;
- no redistribution of third-party custom-Moodle code or artwork;
- vanilla remains authoritative for sleep eligibility, actual sleep state, and all-living-asleep fast-forward.
