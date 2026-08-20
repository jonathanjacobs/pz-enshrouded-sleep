# Public Alpha Deployment Guide

Current deployment status: **PAUSED pending completion of SPIKE-004**  
Current development version: `v0.0.10`  
Validated core platform: Project Zomboid `42.20.3`

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player is outside project scope.

The core two-player sleep/clock architecture is validated. The remaining deployment gate is to finish classification of survival values that v0.0.9 could not observe with its outdated Stats/Moodle access paths.

Do **not** deploy the current development build to the WHG public server until [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) records a GO or acceptable CONDITIONAL GO decision.

## Evidence already established

The v0.0.9 two-player run showed:

- awake active-bleeding health loss remained approximately `1x` during ~5x calendar compression;
- measured bleeding and scratch timers remained approximately `1x`;
- no rapid awake-player bleed-out proportional to partial compression was observed;
- calories, carbohydrates, proteins and lipids tracked calendar compression almost exactly at ~5x and ~10x;
- server/client `MinutesPerDay` synchronization and baseline restoration remained correct;
- `TrueMultiplier` remained `1.0` during partial compression.

The remaining questions are hunger, thirst, fatigue, endurance, and other practical high-severity survival state.

## Why v0.0.10 requires one more controlled server test

v0.0.10 corrects survival-state observability using current Build 42 `CharacterStat`, `MoodleType` and Nutrition APIs.

It also adds a diagnostics-only forced-compression path that works on a normal multiplayer server with **exactly one living player connected and awake**. This reproduces the relevant `MinutesPerDay` condition without requiring a second sleeping client.

Activation requires:

```text
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
living = 1
sleeping = 0
```

With a 90-minute baseline and factor `5`, expected `MinutesPerDay` is approximately `18`.

If the player sleeps or another living player connects, the override is suspended and baseline is restored.

## Pre-deployment gate

Before WHG Public Alpha deployment:

1. Confirm v0.0.10 loads cleanly on the multiplayer test server and one connected client.
2. Confirm `CAPABILITIES` records show corrected CharacterStat/Moodle access, or explicitly characterize any remaining exposure gap.
3. Run the one-connected-player baseline / forced factor-5 / restored-baseline test for 60–90 seconds per phase.
4. Classify hunger/thirst/fatigue/endurance and other practical high-severity variables.
5. Confirm no unacceptable rapid starvation/dehydration, infection, temperature or comparable awake-player hazard, or validate a mitigation/configuration bound.
6. Record GO / CONDITIONAL GO / NO-GO in SPIKE-004.
7. Run a short normal two-player sleep regression before public deployment.

The bleeding experiment does not need to be deliberately repeated unless a regression appears.

## Intended Public Alpha configuration

Unless SPIKE-004 recommends otherwise:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

`DiagnosticForcedCompressionFactor` is **server-test-only**. Public Alpha must run at `1.0` except during an explicitly controlled diagnostic session with exactly one connected living player.

`DiagnosticsEnabled=true` produces clock/sleep, broad health/body, CharacterStat, Moodle, nutrition and multiplier-context telemetry and can generate large logs.

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

## Public Alpha deployment procedure — after gate passes

1. Announce the deployment/restart.
2. Stop the server cleanly.
3. Back up world/save and server configuration.
4. Preserve the previous known-good mod package.
5. Install the exact approved Enshrouded Sleep snapshot on server and clients.
6. Configure `Mods=pz-enshrouded-sleep`.
7. Verify `DiagnosticsEnabled=false` and `DiagnosticForcedCompressionFactor=1.0`.
8. Start the server and confirm no Enshrouded Sleep Lua exception.
9. Perform a brief two-player live smoke check before opening normal play.

Expected low-volume prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

## Public Alpha monitoring priorities

Pay particular attention to 3+ player proportional fractions, joins/disconnects/deaths/respawns, repeated sleep/wake cycles, clock continuity, exact baseline restoration, normal-speed awake actions, unexpected survival-state progression, client errors, and non-health world-time systems such as spoilage, crops, generators, corpses, composting and weather.

## Focused diagnostics

Normal troubleshooting:

```lua
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor = 1.0
```

For the SPIKE-004 forced-time test only, raise the factor above `1.0` **after confirming exactly one living player is connected and awake**.

Relevant prefixes:

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Collect server console/logs and the connected test player's client logs, then disable diagnostics after the shortest practical reproduction.

## Rollback

1. Stop the server cleanly.
2. Preserve incident logs.
3. Remove/disable `pz-enshrouded-sleep` through the normal server workflow.
4. Restore prior configuration if needed.
5. Restart and confirm native time/sleep behavior.

The mod does not maintain a custom persistent sleep database. Removing it returns **future** sleep/time behavior to vanilla. World time or time-driven world changes that already occurred can only be undone by restoring a prior save backup.

## Public Alpha rollback triggers

Roll back and investigate if compressed `MinutesPerDay` persists after baseline should be restored, awake simulation globally accelerates, clients repeatedly lose clock pacing synchronization, recurring Enshrouded Sleep exceptions appear, awake health/survival state becomes dangerously accelerated beyond accepted SPIKE-004 behavior, or a time-driven system causes severe persistent player/world-state damage.
