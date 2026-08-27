# Enshrouded Sleep — Runtime Requirements

This document owns normative product/runtime behavior. It intentionally excludes validation history, current roadmap status, detailed test procedures, and Workshop publication mechanics; those belong in their respective canonical documents.

Enshrouded Sleep is a multiplayer-server mod. Local/standalone single-player support is outside scope.

## Definitions

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

## Core clock and sleep behavior

### R1 — Server authority

Normal proportional-sleep policy is calculated from multiplayer-server state. Server code must not introduce a local `getPlayer()` fallback to emulate standalone behavior.

### R2 — Respect vanilla sleep eligibility

The mod must not bypass native sleep restrictions. If native server sleep is disabled, normal partial-sleep compression must not create an alternate sleep mechanism.

### R3 — Capture the runtime baseline

Baseline day length must come from authoritative `GameTime:getMinutesPerDay()`, not a hard-coded sandbox preset mapping.

### R4 — Inherit native fast-forward policy

Normal partial sleep must read the server's live `FastForwardMultiplier`; it must not assume a fixed value.

### R5 — Use vanilla-visible living population

The denominator consists only of instantiated living server players returned by `getOnlinePlayers()`. Dead characters are excluded. Loading clients enter only when vanilla exposes an `IsoPlayer`.

### R6 — Zero sleepers means native baseline

When no living player is asleep, authoritative and client day length must converge to the captured baseline.

### R7 — Partial sleep is proportional

When `0 < SleepingPlayers < LivingPlayers`:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward × PartialSleepSpeedScale
CalendarCompressionFactor = max(1, EffectivePartialSleepCap × SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

### R8 — Never slow below native day length

`CalendarCompressionFactor` must never be less than `1`.

### R9 — Do not globally fast-forward active simulation

Normal partial sleep must not use `GameTime:setMultiplier()` as its acceleration mechanism. Movement, combat, zombies, vehicles, animations, physics, and ordinary timed actions remain on the normal active-simulation path.

### R10 — All living players asleep hands off to vanilla

When every living player is asleep, Enshrouded Sleep must restore baseline `MinutesPerDay`, synchronize clients to baseline pacing, and leave full-sleep acceleration to vanilla.

### R11 — Recalculate from current population

Sleep/wake, join, disconnect, death, and respawn changes must affect policy as soon as those changes are visible through server player state. The controller must not accumulate or stack historical sleep fractions.

### R12 — Fail toward baseline

Disabling the controller or encountering a recoverable clock/configuration failure must not intentionally leave the server at a stale compressed day length.

## Awake-player survival protection

### R13 — Protection is independently configurable

`AwakePlayerProtectionEnabled` controls survival-state normalization independently of the proportional clock controller. Disabling protection must not disable proportional sleep itself.

### R14 — Protect only supported awake-player fields

During normal partial sleep, enabled protection may normalize only:

- Hunger;
- Thirst;
- Fatigue;
- Calories;
- Carbohydrates;
- Proteins;
- Lipids;
- Weight progression.

### R15 — Never correct sleepers or dead players

Sleeping and dead players must remain outside the awake-protection mutation path.

### R16 — Derive correction from observed compression

The protection factor must be based on the relationship between captured baseline `MinutesPerDay` and current authoritative `MinutesPerDay`, not on an independently guessed sleeping ratio.

### R17 — Preserve favorable direct effects

For Hunger/Thirst/Fatigue and nutrition stores, the normalizer must reduce only the direction associated with passive worsening/depletion. Opposite-direction favorable effects such as tested eating/drinking changes must not be divided by the compression factor. Weight may be normalized in either direction.

### R18 — Fail open per player

If a protected-state read or write fails, the affected player's correction reference must be cleared and that player must fall back to vanilla progression rather than receiving a later accumulated catch-up correction.

### R19 — Protection must not compensate unrelated systems

Acute injury/body-health effects, endurance, sleep physiology, external world objects, and arbitrary modded systems must not be altered by the awake-player protection module unless separately justified by future requirements.

## Client synchronization

### R20 — Clients mirror authoritative day length

Connected clients must receive and apply the server-selected `MinutesPerDay`; clients must not calculate their own proportional target.

### R21 — Server remains authoritative

Client synchronization must not substitute independent `setTimeOfDay()` or global multiplier changes for server day-length authority.

### R22 — Missed transitions converge

A low-frequency authoritative heartbeat is permitted so late/loading clients and missed transitions converge to the current server target.

### R23 — Publish settled state

Synchronization may defer a population transition briefly so the controller's new authoritative `MinutesPerDay` is applied before clients are told to mirror it.

## Diagnostics and support behavior

### R24 — Verbose diagnostics are opt-in

High-frequency diagnostic telemetry must be disabled by default. Low-volume operational state transitions may remain enabled during normal play.

### R25 — Diagnostic forced compression is isolated

A forced diagnostic compression factor greater than `1` may operate only when verbose diagnostics are enabled and exactly one living awake player is connected. It must suspend/restore baseline if that player sleeps or another living player joins, and it must not call the global simulation multiplier.

### R26 — Diagnostic capability failures degrade safely

Optional diagnostic probes must fail to `N/A`, disable/circuit-break the unavailable probe, or otherwise degrade without producing uncontrolled repeated exceptions or breaking gameplay.

## Persistence and rollback

### R27 — No required custom persistent sleep database

The mod must not require a custom persistent database or migration merely to disable/remove it.

### R28 — Removal returns future behavior to vanilla

After clean server stop/removal/restart, future sleep/time behavior must return to vanilla, subject to ordinary save state already produced by elapsed world time.

## Distribution/runtime invariants

### R29 — One authoritative runtime tree

The only deployable Project Zomboid runtime tree in the repository is:

```text
Contents/mods/pz-enshrouded-sleep/
```

No second root-level runtime `42/`, `common/`, or `mod.info` copy may be maintained.

### R30 — Stable identities

The Project Zomboid Mod ID remains `pz-enshrouded-sleep`. Steam Workshop publication must continue using the existing permanent Workshop item rather than creating routine replacement items.

## Optional sleep-status notifications

### R31 — Notifications are independently configurable, administrator-controlled, and opt-in

`SleepNotificationsEnabled` is a server-administrator setting that controls only player-facing sleep-status messages. It must default to `false`, and disabling it must not alter proportional sleep, client clock synchronization, or awake-player protection. Clients must not independently enable notification broadcasts.

### R32 — Notifications describe settled authoritative state

When enabled, notifications must be derived from the authoritative server's settled `MinutesPerDay` and living/sleeping population rather than independently calculating sleep policy. A sleep/population transition may be deferred briefly so the controller's new day length is visible before the message is sent.

### R33 — Notifications are transition-based and concise

Notifications must be emitted only when the effective multiplayer sleep state changes, including sleep/wake changes and population changes that alter the active sleep fraction. Routine all-awake startup state must not generate a player-facing message. Normal partial-sleep messages report both the actual living/sleeping count and percentage and must explicitly describe **world time**, not active simulation speed, for example:

```text
[Enshrouded Sleep] 1/2 living players sleeping (50%). World time is 20x faster.
```

When all living players are awake, the message must report normal world time. When all living players are asleep, the message must identify vanilla full-sleep fast-forward rather than claim a specific Enshrouded Sleep compression factor.

A chat/UI bridge failure must degrade independently and must never affect the sleep/time controller.

### R34 — Multiplayer messages use predefined commands, not executable payloads

Server/client synchronization and optional notifications must use predefined named command handlers and structured data. Runtime code must not depend on dynamic execution APIs such as `loadstring` or `loadstream` for server-supplied code. This preserves the command architecture required by Project Zomboid 42.20.4 and later security behavior.

## Optional Rested / Well Rested sleep benefits

### R35 — Sleep benefits are independently configurable and opt-in

`SleepBenefitsEnabled` controls the voluntary-sleep reward system independently of proportional sleep, awake-player protection, and sleep notifications. It must default to `false`. Disabling it must stop the XP/endurance bonuses and clear active Rested / Well Rested benefit state without disabling Enshrouded Sleep clock behavior.

### R36 — Qualification uses actual game-world sleep duration

The server must determine a sleep attempt from `IsoPlayer:isAsleep()` transitions and measure duration using authoritative game-world time (`GameTime:getWorldAgeHours()`). Qualification is based on game hours slept, not wall-clock time.

The current in-progress sleep attempt must remain session-scoped: disconnecting or restarting the server while a character is asleep must not convert offline elapsed world time into qualifying sleep.

### R37 — Default tiers and all reward values are administrator-adjustable

The default policy is:

```text
sleep < 6 hours      -> no new benefit
6 <= sleep < 9      -> Rested
sleep >= 9          -> Well Rested

Rested:
  duration = 12 game hours
  XP bonus = 5%

Well Rested:
  duration = 24 game hours
  XP bonus = 5%
  Endurance recovery bonus = 10%
```

The Rested/Well Rested minimum sleep thresholds, durations, XP percentages, and Well Rested Endurance-recovery percentage must be server sandbox options. If the configured Well Rested threshold is below the Rested threshold, runtime behavior must safely clamp the effective Well Rested threshold upward to the Rested threshold.

Sleeping beyond the Well Rested threshold must remain Well Rested; oversleeping must not remove the reward.

### R38 — Benefits do not stack

At most one Rested / Well Rested benefit may be active for a player. A new qualifying sleep replaces or refreshes the current tier rather than stacking multipliers or durations. A sleep attempt below the Rested minimum does not itself cancel an otherwise active, unexpired benefit.

### R39 — Earned benefit state persists by game-world expiry; death clears it

Once awarded, the benefit type and expiry world hour may be stored in player ModData so an already-earned benefit can survive ordinary reconnect/server restart behavior. Expiry must continue to use game-world hours.

Death must clear the active benefit. Removing/disabling the feature must not require a database migration or leave a gameplay modifier active.

### R40 — XP bonus uses server-supplied percentages and must not recursively compound

The owning client may apply the XP reward through Build 42's positive `AddXP` event because that event is exposed client-side. The active tier and percentage must come from server-authored state; the client must not independently decide that sleep qualified.

Bonus XP must be added as flat/no-multiplier XP and protected by a recursion guard so a configured 5% reward remains approximately 5% rather than being multiplied again or recursively re-awarded.

A missing/failing XP bridge must fail open for the reward feature and must not affect sleep/time behavior.

### R41 — Well Rested boosts recovery, not maximum Endurance or Endurance expenditure

While Well Rested is active, the server may amplify only **positive** observed Endurance deltas by the configured percentage. Negative Endurance deltas must remain untouched. Corrected Endurance must never exceed the normal maximum of `1.0`.

This correction is directional rather than source-specific: positive Endurance changes produced by another mod may also be amplified. This limitation must be documented and validated before release.

### R42 — Custom Moodle display is a soft UI integration

Rested and Well Rested may be displayed through Tchernobill's Build 42 Moodle Framework (`Workshop 3396446795`, Mod ID `MoodleFramework`) using that framework's documented public API and `30×30` alpha-enabled `Moodle_*.png` convention.

Moodle Framework must remain optional for gameplay: if it is absent or its UI API fails, the Rested/Well Rested gameplay benefits must remain functional and only the custom Moodle presentation may be unavailable. No third-party Moodle Framework or Lifestyle code/assets may be redistributed.

## Out of scope

- local/standalone single-player support;
- custom fatigue or sleep eligibility;
- ready/not-ready voting or lobby readiness tracking;
- global active-simulation fast-forward during partial sleep;
- broad automatic compensation of unmeasured world systems;
- guaranteed compatibility with every sleep, survival, time-altering, XP, endurance, or chat/UI mod;
- Project Zomboid Java/core-file patching for ordinary Workshop distribution.

Current validation status belongs in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); future work belongs in [`ROADMAP.md`](ROADMAP.md); operational defaults belong in [`DEPLOYMENT.md`](DEPLOYMENT.md).