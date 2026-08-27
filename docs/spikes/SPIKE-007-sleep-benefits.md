# SPIKE-007 — Rested / Well Rested voluntary-sleep benefits

Status: **IMPLEMENTED ON FEATURE BRANCH — IN-GAME VALIDATION REQUIRED**

Branch: `feature/sleep-benefits`

## Question

Can Enshrouded Sleep make voluntary multiplayer sleep meaningfully beneficial without making sleep mandatory, while keeping the reward configurable, non-stacking, multiplayer-safe, and visually legible as a Project Zomboid-style Moodle?

## Proposed default behavior

| Sleep completed | Benefit | Default effect | Default duration |
| --- | --- | --- | --- |
| `< 6` game hours | None | No new benefit | — |
| `6` to `< 9` game hours | Rested | `+5%` XP gain | `12` game hours |
| `>= 9` game hours | Well Rested | `+5%` XP gain; `+10%` Endurance recovery | `24` game hours |

Sleeping beyond the Well Rested threshold remains Well Rested; oversleeping does not remove the reward.

A qualifying sleep replaces/refreshes the current benefit. Benefits never stack. A short sleep below the Rested threshold does not cancel an otherwise active benefit.

## Administrator controls

The feature is independently disabled by default and uses server sandbox values:

```text
EnshroudedSleep.SleepBenefitsEnabled=false
EnshroudedSleep.RestedMinimumSleepHours=6.0
EnshroudedSleep.RestedDurationHours=12.0
EnshroudedSleep.RestedXPBonusPercent=5.0
EnshroudedSleep.WellRestedMinimumSleepHours=9.0
EnshroudedSleep.WellRestedDurationHours=24.0
EnshroudedSleep.WellRestedXPBonusPercent=5.0
EnshroudedSleep.WellRestedEnduranceRecoveryBonusPercent=10.0
```

If `WellRestedMinimumSleepHours` is configured below `RestedMinimumSleepHours`, the runtime clamps the effective Well Rested threshold upward to the Rested threshold.

## Build 42.20 feasibility basis

### Sleep duration and persistence

`GameTime:getWorldAgeHours()` provides a monotonic game-world clock suitable for both sleep-duration measurement and benefit expiry. This intentionally means the benefit lasts in **game hours**, not wall-clock hours.

The server detects `IsoPlayer:isAsleep()` transitions. The start of the current sleep attempt is kept in server-session memory rather than persisted, so a disconnect or server restart while asleep cannot convert offline elapsed world time into a reward.

The awarded benefit type and expiry world hour are stored in player ModData so an already-earned benefit can survive an ordinary reconnect/server restart.

### XP bonus

Build 42 exposes the `AddXP` Lua event on the owning client and the standard `addXpNoMultiplier(player, perk, amount)` Lua global. The implementation listens only to positive XP events for the local player and adds the configured percentage as flat bonus XP.

A recursion guard prevents bonus XP from recursively generating additional bonus XP if the underlying call also reaches the event path. The flat-XP function is used specifically so the added percentage is not run through ordinary XP multipliers a second time.

This client path still requires live multiplayer validation for synchronization and interaction with other XP-altering mods.

### Endurance-recovery bonus

Build 42.20 exposes Endurance through `CharacterStat.ENDURANCE` on `Stats`. The server observes Endurance each tick while Well Rested is active. Only positive deltas are amplified:

```text
VanillaRecovery = CurrentEndurance - PreviousEndurance
ExtraRecovery = VanillaRecovery × (ConfiguredPercent / 100)
CorrectedEndurance = min(1.0, CurrentEndurance + ExtraRecovery)
```

Negative deltas are never reduced. Therefore Well Rested does **not** increase maximum Endurance and does **not** make running/combat consume less Endurance.

As with awake-player survival protection, this correction is directional rather than source-specific: a positive Endurance change produced by another mod could also receive the configured bonus.

### Moodle UI

The Build 42 Moodle Framework by Tchernobill documents a `30×30` alpha-enabled `Moodle_*.png` asset convention and a public `MF.createMoodle` / `MF.getMoodle(...):setValue(...)` API.

Enshrouded Sleep treats Moodle Framework as a **soft UI integration**, not a gameplay dependency:

- if Moodle Framework is installed, Rested / Well Rested appear as custom positive moodles;
- if it is absent or its API cannot be used, the XP/endurance benefits remain active and only the custom Moodle UI is unavailable;
- no Moodle Framework code or artwork is copied or redistributed.

Workshop reference: Moodle Framework `3396446795`, Mod ID `MoodleFramework`.

## Custom artwork

Two original Enshrouded Sleep assets were generated specifically for this project and reduced to the Moodle Framework runtime requirement:

```text
Contents/mods/pz-enshrouded-sleep/42/media/ui/Moodle_EnshroudedRested.png
Contents/mods/pz-enshrouded-sleep/42/media/ui/Moodle_EnshroudedWellRested.png
```

Both runtime files are `30×30` RGBA PNGs with transparent corners. The visual language is intentionally playful/colorful and generally Moodle-like, but no Lifestyle or other third-party icon artwork is copied.

## Required validation

### Tier A — reward classification

With `SleepBenefitsEnabled=true`:

1. Sleep less than 6 game hours → no new benefit.
2. Sleep at least 6 but less than 9 game hours → Rested.
3. Sleep at least 9 game hours → Well Rested.
4. Sleep longer than 12 hours → still Well Rested.
5. A qualifying sleep while already buffed replaces/refreshes the benefit rather than stacking.
6. A sub-threshold nap does not cancel an active benefit.

### Tier B — duration/persistence

1. Rested expires after approximately the configured game-world duration.
2. Well Rested expires after approximately the configured game-world duration.
3. Reconnect during an already-earned benefit preserves its remaining world-time duration.
4. Disconnect/restart while actively asleep does not award offline elapsed time as sleep.
5. Death clears the benefit.
6. `SleepBenefitsEnabled=false` clears/disables active effects without affecting Enshrouded Sleep clock behavior.

### Tier C — XP

1. Record a repeatable XP-producing action without a benefit.
2. Repeat while Rested with default `5%` XP bonus.
3. Repeat while Well Rested with default `5%` XP bonus.
4. Confirm observed total gain is approximately `1.05×` baseline rather than recursively compounding.
5. Confirm no repeated Lua exception or runaway XP loop.
6. Repeat with a non-default sandbox percentage.

### Tier D — Endurance

1. Measure Endurance recovery from a controlled depleted state without a benefit.
2. Repeat while Well Rested.
3. Confirm positive recovery is approximately `1.10×` baseline with the default setting.
4. Confirm Endurance expenditure while running/sprinting is not reduced.
5. Confirm Endurance never exceeds `1.0`.
6. Repeat with a non-default sandbox percentage.

### Tier E — Moodle integration

With Build 42 Moodle Framework installed:

1. Rested displays only the Rested icon.
2. Well Rested displays only the Well Rested icon.
3. Icon artwork is crisp/readable at the required `30×30` runtime size.
4. Tooltip reflects the current server-supplied XP/endurance percentages and remaining game time.
5. Benefit expiry hides the moodle.
6. Death hides the moodle.

Without Moodle Framework installed:

1. no recurring Lua error is produced;
2. XP/endurance effects still operate;
3. server sleep/time behavior is unaffected.

## GO / NO-GO gate

Do not promote this feature from the branch into a released Beta solely on static/API inspection. Require at least one clean two-player dedicated-server test covering reward classification, XP, Endurance recovery, expiry, and Moodle display, with no recurring Enshrouded Sleep Lua errors.
