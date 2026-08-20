# Public Alpha Deployment Guide

Current deployment status: **GO for Public Alpha**  
Current version: `v0.0.10`  
Validated core platform: Project Zomboid `42.20.3`

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player is outside project scope.

[`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) is complete and returned **GO**. Controlled testing found no evidence that partial calendar compression multiplies acute awake-player health damage. Hunger, thirst, fatigue and nutrition do advance with elapsed world/calendar time and are documented as expected behavior.

## Public Alpha configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

`DiagnosticForcedCompressionFactor` is **server-test-only** and must remain at `1.0` during normal Public Alpha play.

`DiagnosticsEnabled=true` produces high-volume clock/sleep, health/body, CharacterStat, Moodle, nutrition and multiplier-context telemetry. Enable it only for controlled troubleshooting/regression sessions.

## Known Public Alpha behavior

World/calendar time genuinely advances faster during partial sleep. As a result, measured hunger, thirst, fatigue, calories and macronutrient stores progressed approximately in proportion to calendar compression.

Measured acute bleeding/body-health loss and resting endurance recovery did not scale with calendar compression under the tested conditions.

Pathological states not directly exercised in SPIKE-004 — active sickness/food poisoning, poison, zombie infection/fever and extreme thermal injury — remain field-characterization targets.

## Server installation

Preferred server folder:

```text
mods/pz-enshrouded-sleep/
```

Server Mod ID:

```text
Mods=pz-enshrouded-sleep
```

If the server does not distribute the mod automatically, every participating player must have the same snapshot.

Typical Windows client location:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

GitHub **Download ZIP** normally extracts `pz-enshrouded-sleep-main`; rename the outer folder to `pz-enshrouded-sleep`.

## Public Alpha deployment procedure

1. Announce the deployment/restart.
2. Stop the server cleanly.
3. Back up world/save and server configuration.
4. Preserve the previous known-good mod package.
5. Install the exact approved v0.0.10 snapshot on server and clients.
6. Configure `Mods=pz-enshrouded-sleep`.
7. Verify `DiagnosticsEnabled=false` and `DiagnosticForcedCompressionFactor=1.0`.
8. Start the server and confirm no Enshrouded Sleep Lua exception.
9. Perform a brief two-player live smoke check before opening normal play if practical.
10. Confirm baseline `MinutesPerDay` is restored when all players are awake.

Expected low-volume prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

## Public Alpha monitoring priorities

Pay particular attention to:

- 3+ player proportional fractions;
- joins/disconnects/deaths/respawns;
- repeated sleep/wake cycles;
- clock continuity and exact baseline restoration;
- normal-speed awake movement/actions;
- unexpected health/survival progression beyond documented world-time behavior;
- client errors or repeated day-length pacing resets;
- non-health world-time systems such as spoilage, crops, generators, corpses, composting and weather;
- interaction with the live WHG mod stack.

A few isolated client `MinutesPerDay` resets were seen during aggressive live sandbox/debug factor changes in SPIKE-004. The authoritative server remained correct and the normal heartbeat restored the client value within roughly a second. Treat repeated occurrences during ordinary play as a bug worth collecting logs for.

## Focused diagnostics

Normal troubleshooting:

```lua
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor = 1.0
```

Only for a controlled one-connected-player server regression may the forced factor be raised above `1.0`.

Relevant prefixes:

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Collect server console/logs and affected client logs, then disable diagnostics after the shortest practical reproduction.

## Rollback

1. Stop the server cleanly.
2. Preserve incident logs.
3. Remove/disable `pz-enshrouded-sleep` through the normal server workflow.
4. Restore prior configuration if needed.
5. Restart and confirm native time/sleep behavior.

The mod does not maintain a custom persistent sleep database. Removing it returns **future** sleep/time behavior to vanilla. World time or time-driven world changes that already occurred can only be undone by restoring a prior save backup.

## Rollback triggers

Roll back and investigate if:

- compressed `MinutesPerDay` persists after baseline should be restored;
- awake simulation globally accelerates;
- clients repeatedly lose clock pacing synchronization during ordinary play;
- recurring Enshrouded Sleep exceptions appear;
- awake health/survival state becomes dangerously accelerated beyond documented SPIKE-004 behavior;
- a time-driven world system causes severe persistent player/world-state damage.
