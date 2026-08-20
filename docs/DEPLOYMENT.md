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

v0.0.10 corrects survival-state observability using current Build 42 `CharacterStat`, `MoodleType` and Nutrition APIs.

It also adds a diagnostics-only single-player forced-compression path so the remaining causal question can be tested on one **awake** character without requiring a second sleeper.

Test-only activation requires:

```text
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
```

With a 90-minute baseline and factor `5`, expected `MinutesPerDay` is approximately `18`.

The test override does not call the global simulation multiplier. If any observed living player sleeps, the override is suspended and baseline `MinutesPerDay` is restored before vanilla sleep acceleration proceeds.

## Pre-deployment gate

Before WHG Public Alpha deployment:

1. Confirm v0.0.10 loads cleanly in standalone single-player/debug mode.
2. Confirm `CAPABILITIES` records show corrected CharacterStat/Moodle access, or explicitly characterize any remaining exposure gap.
3. Run the one-character baseline / forced factor-5 / restored-baseline test for 60–90 seconds per phase.
4. Classify hunger/thirst/fatigue/endurance and other practical high-severity variables.
5. Confirm no unacceptable rapid starvation/dehydration, infection, temperature or comparable awake-player hazard, or validate a mitigation/configuration bound.
6. Record GO / CONDITIONAL GO / NO-GO in SPIKE-004.
7. Run a short core two-player sleep regression before public deployment.

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

`DiagnosticForcedCompressionFactor` is **test-only**. Public Alpha must run at `1.0` except during an explicitly controlled diagnostic session.

`DiagnosticsEnabled=true` produces clock/sleep, broad health/body, CharacterStat, Moodle, nutrition and multiplier-context telemetry. It can generate large logs and should be restricted to controlled diagnostics.

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
7. Verify `DiagnosticsEnabled=false` and `DiagnosticForcedCompressionFactor=1.0`.
8. Start the server and confirm no Enshrouded Sleep Lua exception.
9. Perform a brief two-player live smoke check before opening normal play.

Expected low-volume prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

The diagnostic modules may print startup lines, but continuous one-second output must not appear with diagnostics disabled.

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
DiagnosticForcedCompressionFactor = 1.0
```

Only raise the forced factor above `1.0` when deliberately reproducing a time-domain condition with an awake test character.

Relevant prefixes include:

```text
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
[EnshroudedSleepStandaloneHealthDiag][SERVER]
```

Collect server/game console, DebugLog/log ZIP and affected client logs as applicable, then disable diagnostics after the shortest practical reproduction.

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
