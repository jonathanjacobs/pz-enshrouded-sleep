# Public Beta Deployment Guide

This document owns server installation, normal configuration, monitoring, diagnostics, and rollback. Product semantics belong in [`REQUIREMENTS.md`](REQUIREMENTS.md); test evidence belongs in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

Current release: `v0.1.1`  
Project Zomboid Mod ID: `pz-enshrouded-sleep`  
Steam Workshop ID: `3786842301`  
Current validated compatibility checkpoint: Project Zomboid `42.20.4` (`b0bbce05d5`)

The Rested / Well Rested sleep-benefit system described below currently exists on `feature/sleep-benefits` and is **not yet part of the released v0.1.1 package**.

## Normal server configuration

```text
EnshroudedSleep.Enabled=true
EnshroudedSleep.PartialSleepSpeedScale=1.0
EnshroudedSleep.AwakePlayerProtectionEnabled=true
EnshroudedSleep.SleepNotificationsEnabled=false
EnshroudedSleep.SleepBenefitsEnabled=false
EnshroudedSleep.DiagnosticsEnabled=false
EnshroudedSleep.DiagnosticForcedCompressionFactor=1.0
```

Administrator meaning:

- `Enabled` — master Enshrouded Sleep controller switch.
- `PartialSleepSpeedScale` — scales normal proportional partial-sleep calendar acceleration; `1.0` is neutral.
- `AwakePlayerProtectionEnabled` — protects supported awake-player survival/metabolism fields during partial sleep; disable this first when isolating a compatibility problem in the protection layer.
- `SleepNotificationsEnabled` — server-administrator switch for concise player-facing sleep-state messages. Disabled by default and has no effect on sleep/time policy, client clock synchronization, or awake-player protection.
- `SleepBenefitsEnabled` — optional Rested / Well Rested reward layer. Disabled by default; when enabled it does not change sleep eligibility or proportional time compression.
- `DiagnosticsEnabled` — enables high-volume troubleshooting telemetry; leave off during routine play.
- `DiagnosticForcedCompressionFactor` — isolated one-player regression tool; keep at `1.0` during normal multiplayer operation.

When notifications are enabled, partial-sleep messages use the settled authoritative compression factor and current living-player denominator, for example:

```text
[Enshrouded Sleep] 1/2 living players sleeping (50%). World time is 20x faster.
```

All-awake and all-asleep transitions use short special messages rather than claiming a misleading multiplier during vanilla full-sleep handoff.

The in-game sandbox tooltips contain fuller option descriptions. The canonical clock/protection/benefit behavior is in [`REQUIREMENTS.md`](REQUIREMENTS.md).

## Sleep-benefit configuration — feature branch

Default candidate settings:

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

Default classification:

```text
< 6 game hours     -> no new benefit
6 to < 9 hours     -> Rested: +5% XP for 12 game hours
>= 9 game hours    -> Well Rested: +5% XP and +10% Endurance recovery for 24 game hours
```

Sleeping beyond 12 hours still qualifies as Well Rested; oversleeping does not remove the reward. A qualifying sleep replaces/refreshes the current tier rather than stacking. A sub-threshold nap does not cancel an otherwise active benefit.

### Optional custom Moodle UI

The gameplay bonuses do not require a UI dependency. To display the custom Rested / Well Rested moodles, install the current Build 42 **Moodle Framework** by Tchernobill:

```text
Workshop ID: 3396446795
Mod ID: MoodleFramework
```

Enshrouded Sleep treats this as a soft integration. If Moodle Framework is missing or its client API fails, the sleep-benefit gameplay state continues and only the custom Moodle display is unavailable.

## Steam Workshop server setup

Released Enshrouded Sleep package:

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

If/when the Rested feature is promoted and the server wants the custom Moodle UI, add Moodle Framework using the host's normal Workshop/mod configuration mechanism. Do not create or redistribute a bundled copy of Moodle Framework.

Players joining a Workshop-configured server should use the Workshop-distributed copy rather than maintaining a second manual copy.

## Update/deploy procedure

1. Announce the restart/update.
2. Stop the server cleanly.
3. Back up the world/save and server configuration.
4. Preserve the previous known-good package/configuration when practical.
5. Update the existing Workshop item/server package.
6. Verify the normal configuration above unless the release notes explicitly require otherwise.
7. Start the server and confirm the controller, clock sync, roster logger, awake-protection module, notification modules, and—when present in the candidate—sleep-benefit modules load without an Enshrouded Sleep Lua exception.
8. Confirm native baseline `MinutesPerDay` while all living players are awake.
9. During the first natural partial-sleep event, confirm partial mode appears and later returns to baseline.
10. If `SleepNotificationsEnabled=true`, confirm one concise chat message appears per effective sleep-state change without repeated spam.
11. If testing the feature branch with `SleepBenefitsEnabled=true`, perform the SPIKE-007 reward/XP/Endurance/Moodle smoke test before treating it as production-ready.
12. Preserve early session logs after a material runtime update.

Workshop authoring/publication mechanics are maintained separately in [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md).

## Routine monitoring

With verbose diagnostics disabled, low-volume controller/roster/protection/benefit transitions should provide enough context to identify normal sleep-state changes without generating large logs.

Pay attention to:

- baseline restoration after sleepers wake;
- protection status matching the actual awake/sleeping roster;
- joins/disconnects/deaths/respawns during partial sleep;
- recurring client clock corrections;
- notification `CONFIG` state matching the intended administrator setting;
- repeated or missing sleep-status notifications when the option is enabled;
- `SleepBenefits` grants/clears matching actual sleep duration when the feature is enabled;
- runaway/repeated XP bonus messages or implausible XP gains;
- Well Rested reducing Endurance expenditure rather than only increasing recovery;
- Moodle Framework errors or moodles remaining visible after expiry/death;
- `WRITE_FAILURE_FAIL_OPEN` messages;
- recurring Enshrouded Sleep Lua exceptions;
- unusual server responsiveness or log volume;
- conflicts with mods that alter sleep, time, CharacterStats, nutrition, timed actions, XP, Endurance, or chat/UI.

## Focused diagnostics

If a problem is reproducible, enable `DiagnosticsEnabled=true` only for the shortest useful window, reproduce once if safe, then disable it again.

For normal multiplayer evidence, keep:

```text
DiagnosticForcedCompressionFactor=1.0
```

Collect:

```text
server console
server DebugLog / Logs
affected owning-client DebugLog when available
```

Useful prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
[EnshroudedSleepAwakeProtect][SERVER]
[EnshroudedSleepNotify][SERVER]
[EnshroudedSleepNotify][CLIENT]
[EnshroudedSleepBenefits][SERVER]
[EnshroudedSleepBenefits][CLIENT]
[EnshroudedSleepActionDiag][SERVER]
[EnshroudedSleepActionDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Detailed controlled test procedure belongs in [`TESTING.md`](TESTING.md), not here.

## Soft rollback — awake protection only

Use this when proportional sleep/clock behavior appears correct but awake Hunger/Thirst/Fatigue/Nutrition/Weight behavior appears wrong or conflicts with another mod:

```text
EnshroudedSleep.AwakePlayerProtectionEnabled=false
```

This disables the survival-state normalizer while leaving proportional partial-sleep calendar compression and vanilla all-asleep handoff active. Preserve logs and compare behavior before removing the entire mod.

## Notification-only rollback

If the sleep/time mechanic is correct but chat notifications are unwanted or conflict with another chat/UI mod, disable only:

```text
EnshroudedSleep.SleepNotificationsEnabled=false
```

This has no effect on time compression, client clock synchronization, or awake-player protection.

## Sleep-benefit-only rollback

If the feature-branch reward system causes XP, Endurance, Moodle, or compatibility problems, disable only:

```text
EnshroudedSleep.SleepBenefitsEnabled=false
```

The server clears active Rested / Well Rested benefit state. Proportional sleep, awake-player protection, and notification behavior remain independently configured.

If the gameplay bonuses work but Moodle Framework causes UI errors, remove/disable Moodle Framework instead; Enshrouded Sleep is designed to retain the benefits without the optional custom Moodle UI.

## Full rollback

Use a full rollback for core clock/controller/synchronization failures, recurring Enshrouded Sleep exceptions, serious server instability, or player/world-state problems that cannot be isolated to an optional layer.

1. Stop the server cleanly.
2. Preserve incident logs and the affected save/configuration.
3. Remove/disable `pz-enshrouded-sleep` and/or Workshop item `3786842301` through the normal server workflow.
4. Restore the prior package/configuration if needed.
5. Restart and confirm native future sleep/time behavior.

The mod does not maintain a custom persistent sleep database. The feature-branch Rested system stores only small per-character ModData fields for an earned benefit and expiry; disabling/removing the mod stops using those values. World-time-driven changes that already occurred require a prior save backup if they need to be undone.

## Operational boundary

Awake-player protection does not stop external world/calendar systems from advancing with compressed game time. Food aging, generators, vehicles, farming, corpses, weather, and other vanilla/modded world systems remain outside the protection layer unless separately addressed in a future release.

Rested / Well Rested durations intentionally expire in game-world hours, so partial-sleep world-time acceleration also advances the remaining benefit duration faster in real time.
