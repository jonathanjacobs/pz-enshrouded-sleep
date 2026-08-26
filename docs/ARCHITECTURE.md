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

Sleep notifications are deliberately separated from sleep/time policy.

```text
EnshroudedSleep_Server.lua
    -> owns authoritative MinutesPerDay

SleepNotification_Server.lua
    -> observes living/sleeping population
    -> waits one observer pass after a population transition
    -> derives displayed compression from settled BaselineMinutesPerDay / CurrentMinutesPerDay
    -> broadcasts a versioned SleepNotification server command

SleepNotification_Client.lua
    -> validates the packet
    -> displays the server-authored text through ChatManager.showServerChatMessage()
```

`SleepNotificationsEnabled` defaults to `false`. The server notifier does not announce ordinary all-awake startup state and emits only when the effective sleep state changes. Population changes during partial sleep are included because they can change the active sleep fraction and therefore the displayed acceleration.

The client chat bridge is circuit-broken after a bridge failure. A notification failure cannot change `MinutesPerDay`, player sleep state, or awake-player protection.

## Diagnostic forced compression

`DiagnosticForcedCompressionFactor` is a support/regression mechanism, not normal gameplay tuning. It can compress `MinutesPerDay` with exactly one living awake player only when verbose diagnostics are enabled.

A sleeping player, a second living player, disabling diagnostics, returning the factor to `1.0`, or a recoverable controller failure exits/suspends the forced path toward baseline. The forced path remains separate from normal multiplayer partial sleep.

Operational use belongs in [`DEPLOYMENT.md`](DEPLOYMENT.md); test procedures belong in [`TESTING.md`](TESTING.md).

## Observability

Normal operation emits low-volume controller, synchronization, roster, awake-protection, and—when explicitly enabled—sleep-notification transitions. High-frequency health/survival/action/world-system telemetry is gated by `DiagnosticsEnabled=true`.

Shared survival-state access is centralized in:

```text
Contents/mods/pz-enshrouded-sleep/42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
```

Diagnostics and optional UI bridges are designed to degrade unavailable capabilities rather than break gameplay.

## Time-domain boundary

Changing `MinutesPerDay` intentionally accelerates systems tied to game-world/calendar time. Awake-player protection compensates only its explicit player-survival scope. External systems such as food aging, generator resources, vehicle resources, farming, corpses, weather, and modded world systems remain outside this module.

Evidence for individual time domains belongs in SPIKE-004/SPIKE-005 and `VALIDATION_HISTORY.md`; architecture should not duplicate their measurement tables.

## Design constraints

- no global simulation fast-forward for partial sleep;
- no custom readiness/voting registry;
- no local/standalone single-player fallback in server policy;
- no Project Zomboid Java/core patching for ordinary Workshop distribution;
- no broad subsystem compensation without measured evidence;
- vanilla remains authoritative for sleep eligibility, actual sleep state, and all-living-asleep fast-forward.
