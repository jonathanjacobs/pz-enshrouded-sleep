# Public Beta Deployment Guide

This document owns server installation, normal configuration, monitoring, diagnostics, and rollback. Product semantics belong in [`REQUIREMENTS.md`](REQUIREMENTS.md); test evidence belongs in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

Project Zomboid Mod ID: `pz-enshrouded-sleep`  
Steam Workshop ID: `3786842301`

## Normal server configuration

```text
EnshroudedSleep.Enabled=true
EnshroudedSleep.PartialSleepSpeedScale=1.0
EnshroudedSleep.AwakePlayerProtectionEnabled=true
EnshroudedSleep.DiagnosticsEnabled=false
EnshroudedSleep.DiagnosticForcedCompressionFactor=1.0
```

Administrator meaning:

- `Enabled` — master Enshrouded Sleep controller switch.
- `PartialSleepSpeedScale` — scales normal proportional partial-sleep calendar acceleration; `1.0` is neutral.
- `AwakePlayerProtectionEnabled` — protects supported awake-player survival/metabolism fields during partial sleep; disable this first when isolating a compatibility problem in the protection layer.
- `DiagnosticsEnabled` — enables high-volume troubleshooting telemetry; leave off during routine play.
- `DiagnosticForcedCompressionFactor` — isolated one-player regression tool; keep at `1.0` during normal multiplayer operation.

The in-game sandbox tooltips contain fuller option descriptions. The canonical clock/protection behavior is in [`REQUIREMENTS.md`](REQUIREMENTS.md).

## Steam Workshop server setup

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

Players joining a Workshop-configured server should use the Workshop-distributed copy rather than maintaining a second manual copy.

## Update/deploy procedure

1. Announce the restart/update.
2. Stop the server cleanly.
3. Back up the world/save and server configuration.
4. Preserve the previous known-good package/configuration when practical.
5. Update the existing Workshop item/server package.
6. Verify the normal configuration above unless the release notes explicitly require otherwise.
7. Start the server and confirm the controller, clock sync, roster logger, and awake-protection module load without an Enshrouded Sleep Lua exception.
8. Confirm native baseline `MinutesPerDay` while all living players are awake.
9. During the first natural partial-sleep event, confirm partial mode appears and later returns to baseline.
10. Preserve early session logs after a material runtime update.

Workshop authoring/publication mechanics are maintained separately in [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md).

## Routine monitoring

With verbose diagnostics disabled, low-volume controller/roster/protection transitions should provide enough context to identify normal sleep-state changes without generating large logs.

Pay attention to:

- baseline restoration after sleepers wake;
- protection status matching the actual awake/sleeping roster;
- joins/disconnects/deaths/respawns during partial sleep;
- recurring client clock corrections;
- `WRITE_FAILURE_FAIL_OPEN` messages;
- recurring Enshrouded Sleep Lua exceptions;
- unusual server responsiveness or log volume;
- conflicts with mods that alter sleep, time, CharacterStats, nutrition, or timed actions.

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

## Full rollback

Use a full rollback for core clock/controller/synchronization failures, recurring Enshrouded Sleep exceptions, serious server instability, or player/world-state problems that cannot be isolated to awake protection.

1. Stop the server cleanly.
2. Preserve incident logs and the affected save/configuration.
3. Remove/disable `pz-enshrouded-sleep` and/or Workshop item `3786842301` through the normal server workflow.
4. Restore the prior package/configuration if needed.
5. Restart and confirm native future sleep/time behavior.

The mod does not maintain a custom persistent sleep database. Removing it returns future sleep/time behavior to vanilla. World-time-driven changes that already occurred require a prior save backup if they need to be undone.

## Operational boundary

Awake-player protection does not stop external world/calendar systems from advancing with compressed game time. Food aging, generators, vehicles, farming, corpses, weather, and other vanilla/modded world systems remain outside the protection layer unless separately addressed in a future release.
