# Public Beta Deployment Guide

Current deployment status: **Public Beta v0.1.0 / multiplayer field validation**  
Validated core platform: Project Zomboid `42.20.3`  
Project Zomboid Mod ID: `pz-enshrouded-sleep`  
Steam Workshop ID: `3786842301`

Enshrouded Sleep is a multiplayer-server mod. Local/standalone single-player is outside project scope.

## Recommended Public Beta configuration

```text
EnshroudedSleep.Enabled=true
EnshroudedSleep.PartialSleepSpeedScale=1.0
EnshroudedSleep.AwakePlayerProtectionEnabled=true
EnshroudedSleep.DiagnosticsEnabled=false
EnshroudedSleep.DiagnosticForcedCompressionFactor=1.0
```

`AwakePlayerProtectionEnabled=true` is the new Beta gameplay default. During normal partial sleep it protects awake living players' Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, and Weight progression from the extra calendar-time acceleration introduced by compressed `MinutesPerDay`. Sleeping players are never corrected.

`DiagnosticsEnabled=true` produces high-volume clock/sleep, health/body, CharacterStat, Moodle, nutrition, action/activity, and awake-protection telemetry. With several players the logs can grow very quickly. Leave it off for routine operation and enable it only for focused troubleshooting/data-collection windows.

`DiagnosticForcedCompressionFactor` is a one-player regression tool. Keep it at `1.0` during normal multiplayer operation.

## Steam Workshop server setup

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

Players should use the Workshop-distributed copy when joining a Workshop-configured server rather than maintaining a second manual copy.

The authoritative runtime tree in the repository is:

```text
Contents/mods/pz-enshrouded-sleep/
```

## Upgrade to v0.1.0

1. Announce the restart/update.
2. Stop the server cleanly.
3. Back up the world/save and server configuration.
4. Preserve the previous known-good v0.0.10 Workshop/package state if practical.
5. Update the Workshop item/server package to v0.1.0.
6. Verify `AwakePlayerProtectionEnabled=true`, `DiagnosticsEnabled=false`, and `DiagnosticForcedCompressionFactor=1.0` for routine Beta play.
7. Start the server and confirm the core controller, client sync, roster logger, and `[EnshroudedSleepAwakeProtect][SERVER]` module load without a Lua exception.
8. Confirm baseline `MinutesPerDay` while everyone is awake.
9. During the first natural partial-sleep event, confirm the roster/controller enters partial mode and later returns exactly to baseline.
10. Preserve the first several multiplayer session logs for review.

## What to monitor in Beta

Pay particular attention to:

- multiple awake players being protected simultaneously during partial sleep;
- sleepers remaining unmodified by the awake-protection path;
- joins/disconnects/deaths/respawns during partial sleep;
- repeated sleep/wake cycles and changing player ratios;
- eating/drinking/activity behavior while another player sleeps;
- clock continuity and exact baseline restoration;
- CPU/server responsiveness during larger populations;
- repeated `WRITE_FAILURE_FAIL_OPEN`, Lua exceptions, or unusual protection status churn;
- conflicts with mods that alter sleep, time, CharacterStats, nutrition, or timed actions;
- external world-time systems advancing as expected with compressed calendar time.

## Logging strategy

With `DiagnosticsEnabled=false`, retain the low-volume controller/roster/protection transition logs during ordinary play. This gives useful population/mode evidence without the large diagnostic stream.

If a problem occurs and is reproducible, enable `DiagnosticsEnabled=true` for the shortest practical window, reproduce once, then disable it again. Collect:

```text
server console
server DebugLog / Logs
owning client console / DebugLog for affected players when available
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

Do not raise `DiagnosticForcedCompressionFactor` on the public multiplayer server during normal operation; it is intentionally gated for an isolated one-player regression.

## Soft rollback: awake protection only

If the clock/sleep mechanic is behaving correctly but awake Hunger/Thirst/Fatigue/Nutrition/Weight behavior appears wrong or conflicts with another mod:

```text
EnshroudedSleep.AwakePlayerProtectionEnabled=false
```

This is the preferred first rollback. It disables survival-state correction but leaves proportional partial-sleep calendar compression and vanilla full-sleep handoff intact. Preserve logs and compare behavior before removing the whole mod.

## Full rollback

Use a full rollback if compressed `MinutesPerDay` persists incorrectly, awake simulation globally accelerates, client clock synchronization repeatedly fails, recurring Enshrouded Sleep exceptions occur, or a serious player/world-state problem cannot be isolated to awake protection.

1. Stop the server cleanly.
2. Preserve incident logs.
3. Remove/disable `pz-enshrouded-sleep` and/or Workshop item `3786842301` through the normal server workflow.
4. Restore previous configuration/package if needed.
5. Restart and confirm native time/sleep behavior.

The mod does not maintain a custom persistent sleep database. Removing it returns future sleep/time behavior to vanilla. World-time-driven changes that already occurred require a prior save backup if they need to be undone.

## Known Beta boundaries

Controlled SPIKE-006 testing passed the single-player forced 20x feasibility path, including passive normalization, Carbohydrates/Lipids away from clamps, eating/drinking, running/sprinting, sleep suspension, wake reinitialization, and clean restoration. The purpose of Public Beta is to obtain the broader multiplayer evidence that controlled tests cannot provide.

External world systems remain world/calendar-time driven. v0.1.0 does not compensate every system in the game or in other mods.
