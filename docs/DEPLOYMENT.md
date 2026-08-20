# Public Alpha Deployment Guide

Current deployment status: **PAUSED pending completion of SPIKE-004**  
Current development version: `v0.0.10`  
Validated core platform: Project Zomboid `42.20.3`

The core two-player sleep/clock architecture is validated. The remaining deployment gate is narrower: finish classification of survival values that v0.0.9 could not observe with its outdated Stats/Moodle access paths.

Do **not** deploy the current development build to the WHG public server until [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) records a GO or acceptable CONDITIONAL GO decision.

## Evidence already established

The v0.0.9 two-player run showed:

- awake active-bleeding health loss remained approximately `1x` during ~5x calendar compression;
- measured bleeding and scratch timers remained approximately `1x`;
- no rapid awake-player bleed-out proportional to partial compression was observed;
- calories, carbohydrates, proteins and lipids tracked calendar compression almost exactly at ~5x and ~10x;
- server/client `MinutesPerDay` synchronization and baseline restoration remained correct;
- `TrueMultiplier` remained `1.0` during partial compression.

The acute bleeding concern therefore passed. The remaining questions are hunger, thirst, fatigue, endurance, and other practical high-severity survival state.

## Why v0.0.10 requires one more controlled test

v0.0.9 still returned `N/A` for many continuous survival values and for Moodle fallback telemetry. Source review showed that Build 42.20.3 uses:

```lua
player:getStats():get(CharacterStat.HUNGER)
player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
```

rather than the legacy named Stats getter/public-field and numeric Moodle enumeration assumptions used by v0.0.9.

v0.0.10 adds corrected, read-only CharacterStat/MoodleType/Nutrition diagnostics plus one-time capability records.

## Pre-deployment gate

Before WHG Public Alpha deployment:

1. Confirm v0.0.10 server/client diagnostics load without new Enshrouded Sleep errors.
2. Confirm `CAPABILITIES` records show corrected CharacterStat/Moodle access, or explicitly characterize any remaining side-specific exposure gap.
3. Run the focused 60–90 s baseline / 60–90 s ~5x partial / 60–90 s restored-baseline test.
4. Classify hunger/thirst/fatigue/endurance and other practical high-severity variables.
5. Confirm no unacceptable rapid starvation/dehydration, infection, temperature or comparable awake-player hazard, or validate a mitigation/configuration bound.
6. Record GO / CONDITIONAL GO / NO-GO in SPIKE-004.
7. Run a short core two-player sleep regression after the diagnostic test.

Recommended focused-test native setting:

```text
FastForwardMultiplier = 10
Baseline MinutesPerDay = 90
2 living / 1 sleeping -> expected factor ~5 -> MinutesPerDay ~18
```

The bleeding experiment does not need to be deliberately repeated unless a regression appears.

## Intended Public Alpha configuration

Unless SPIKE-004 recommends otherwise:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
}
```

`DiagnosticsEnabled=true` now produces clock/sleep, broad health/body, CharacterStat, Moodle, nutrition and multiplier-context telemetry. It can generate large logs and should be restricted to controlled diagnostics.

## Server installation

Preferred local server folder:

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

## Public Alpha deployment procedure — after gate passes

1. Announce the deployment/restart.
2. Stop the server cleanly.
3. Back up world/save and server configuration.
4. Preserve the previous known-good mod package.
5. Install the exact approved Enshrouded Sleep snapshot on server and clients.
6. Configure `Mods=pz-enshrouded-sleep`.
7. Keep verbose diagnostics disabled for normal play.
8. Start the server and confirm no Enshrouded Sleep Lua exception.
9. Perform a brief two-player live smoke check before opening normal play.

Expected low-volume prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

The survival diagnostic modules may print a startup line, but continuous one-second output must not appear with `DiagnosticsEnabled=false`.

## Public Alpha monitoring priorities

Pay particular attention to:

- 3+ player proportional fractions and multiple sleepers;
- joins/disconnects/deaths/respawns while compression is active;
- repeated sleep/wake cycles;
- clock continuity and exact baseline restoration;
- normal-speed awake movement/combat/actions;
- unexpected hunger/thirst/fatigue or health-state progression;
- client error-counter increases;
- non-health world-time systems such as spoilage, crops, generators, corpses, composting and weather;
- mods driven by `EveryOneMinute`, `WorldAgeHours`, or custom sleep/recovery logic.

## Focused diagnostics

For a reproducible issue, temporarily set:

```lua
DiagnosticsEnabled = true
```

Relevant v0.0.10 prefixes include:

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Collect server console/DebugLog and affected client logs, then disable diagnostics after the shortest practical reproduction.

## Rollback

1. Stop the server cleanly.
2. Preserve incident logs.
3. Remove/disable `pz-enshrouded-sleep` through the normal server workflow.
4. Restore prior configuration if needed.
5. Restart and confirm native time/sleep behavior.

The mod does not maintain a custom persistent sleep database. Removing it returns **future** sleep/time behavior to vanilla. World time or time-driven world changes that already occurred can only be undone by restoring a prior save backup.

## Public Alpha rollback triggers

Roll back and investigate if:

- compressed `MinutesPerDay` persists after baseline should be restored;
- awake simulation globally accelerates;
- clients repeatedly lose clock pacing synchronization;
- recurring Enshrouded Sleep exceptions appear;
- awake health/survival state becomes dangerously accelerated beyond the accepted SPIKE-004 behavior;
- a time-driven system causes severe persistent world/player-state damage beyond the documented alpha model.
