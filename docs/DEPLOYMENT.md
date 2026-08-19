# Public Alpha Deployment Guide

Current deployment status: **PAUSED pending SPIKE-004 health/time-domain validation**

Current development version: `v0.0.9`

The core two-player sleep/clock architecture passed dedicated-server regression testing on Project Zomboid 42.20.3. However, pre-deployment review identified a separate player-safety question: some health/survival systems may progress faster in real time when `MinutesPerDay` is compressed.

Do **not** deploy the current development build to the WHG public server until [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) records a GO or acceptable CONDITIONAL GO decision.

## Why deployment is gated

Partial sleep intentionally makes world/calendar time pass faster. Awake active simulation remains normal-speed, but health/survival systems may use different PZ time domains.

The blocking questions include whether partial sleep materially accelerates:

- active bleeding and resulting health loss;
- hunger/thirst;
- fatigue/endurance;
- wound healing/injury timers;
- sickness/poison;
- zombie infection progression;
- temperature/cold effects.

### Preliminary solo reference

The v0.0.8 diagnostic successfully captured broad health/injury telemetry. During a solo sleep test, a character with four active bleeding injuries died within roughly five real seconds after sleep began. In that state Enshrouded Sleep had restored baseline `MinutesPerDay=90` and **vanilla full-sleep fast-forward** owned the acceleration.

This is not evidence that Enshrouded Sleep partial compression causes rapid bleed-out. It is evidence that sleep/time-domain effects can be severe enough that the awake-player partial-sleep case must be measured before public deployment.

v0.0.9 improves the read-only diagnostic with guarded raw public-field fallbacks, Moodle levels, and direct multiplier/delta telemetry.

## Pre-deployment gate

Before WHG Public Alpha deployment:

1. Confirm v0.0.9 server/client diagnostics load without Enshrouded Sleep errors.
2. Complete SPIKE-004 baseline/partial/restored-baseline health monitoring with Player A awake and Player B sleeping during the partial phase.
3. Record a per-metric time-domain classification where measurable.
4. Confirm no unacceptable high-severity awake-player health hazard, or validate a mitigation/configuration bound.
5. Record GO / CONDITIONAL GO / NO-GO in SPIKE-004.
6. Run the short core two-player regression to ensure the diagnostic additions did not disturb validated sleep/clock behavior.

The recommended first safety run uses native `FastForwardMultiplier=10`. With a 90-minute baseline, two living players and one sleeper should produce approximately factor `5` / `MinutesPerDay=18`, giving a strong experimental signal with more operator reaction time than factor 20.

Only after the gate passes should the deployment steps below be used.

## Intended Public Alpha configuration

Unless SPIKE-004 recommends otherwise:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
},
```

`DiagnosticsEnabled=true` produces one-second clock, sleep, health, raw-stat/Moodle, nutrition, injury and multiplier-context telemetry. It can generate very large logs and should only be used for controlled diagnostics, not normal Public Alpha play.

## Server installation

Preferred local server folder:

```text
mods/pz-enshrouded-sleep/
```

Server Mod ID:

```text
Mods=pz-enshrouded-sleep
```

If the server is not distributing the mod through Workshop or another automated mechanism, every participating player must have the same local snapshot.

Typical Windows client location:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

GitHub **Download ZIP** usually extracts `pz-enshrouded-sleep-main`. Rename the outer folder to `pz-enshrouded-sleep`. The authoritative Mod ID remains the `id=` value in `mod.info`.

## Public Alpha deployment procedure (after gate passes)

1. Announce the alpha deployment and planned restart.
2. Stop the public server cleanly.
3. Back up the world/save and server configuration.
4. Preserve the previous known-good mod package for rollback.
5. Install the exact approved Enshrouded Sleep snapshot on the server.
6. Ensure participating clients use the same snapshot.
7. Configure `Mods=pz-enshrouded-sleep`.
8. Keep verbose diagnostics disabled for normal play.
9. Start the server.
10. Confirm normal Enshrouded Sleep startup/state prefixes and no Lua exception.
11. Perform a brief live smoke check with at least two players before declaring the server open.

Expected low-volume prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

Diagnostic modules may print one startup message, but continuous one-second diagnostic lines should not appear with `DiagnosticsEnabled=false`.

## What to monitor during Public Alpha

Pay particular attention to:

- 3+ player proportional fractions;
- multiple simultaneous sleepers;
- joins/disconnects while others sleep;
- death/respawn during partial sleep;
- repeated sleep/wake cycles;
- clock continuity;
- normal-speed awake movement/combat/actions;
- abnormal sleep duration;
- player health/survival symptoms identified during SPIKE-004;
- client error-counter increases;
- non-health world-time systems: spoilage, crops, generators, corpses, composting, weather;
- interaction with mods using `EveryOneMinute`, `WorldAgeHours`, or custom sleep/recovery logic.

## Expected proportional behavior

With native `FastForwardMultiplier=40` and `PartialSleepSpeedScale=1.0`:

```text
1 of 12 sleeping -> factor ~3.33
3 of 12 sleeping -> factor 10
6 of 12 sleeping -> factor 20
9 of 12 sleeping -> factor 30
12 of 12 sleeping -> restore baseline; vanilla full-sleep fast-forward takes over
```

Actual `MinutesPerDay` also depends on the server's native baseline day length.

## Player-facing alpha bug reports

Useful reports answer:

1. How many players were online?
2. Approximately how many were asleep?
3. Was the affected player awake or asleep?
4. What happened?
5. Did health/hunger/thirst/fatigue or another timed system change unexpectedly?
6. Did the PZ error counter increase?
7. Did the behavior clear after wake/reconnect?
8. Approximately when did it occur?

High-value symptoms include:

- clock freeze/jump;
- awake gameplay speeding up;
- implausibly long sleep;
- world remaining compressed after wake;
- rapid or surprising health loss while another player sleeps;
- unexpected hunger/thirst/fatigue progression;
- severe non-health world-system effects;
- Enshrouded Sleep Lua/Java exceptions.

## Focused diagnostics

For a reproducible issue, temporarily enable:

```lua
DiagnosticsEnabled = true
```

Reproduce the problem for the shortest practical interval and collect:

```text
server DebugLog / log ZIP
server console
at least the affected client's console.txt / log ZIP
```

For health/survival questions, the affected player's owning-client log is especially useful. Disable diagnostics after the reproduction.

## Rollback procedure

1. Announce the restart.
2. Stop the server cleanly.
3. Preserve logs from the incident.
4. Remove `pz-enshrouded-sleep` from `Mods=` or disable it through the normal server workflow.
5. Restore the prior sandbox/configuration if needed.
6. Restart.
7. Confirm native time/sleep behavior.

The mod does not maintain a custom persistent sleep database. Removing it returns **future** clock/sleep behavior to vanilla. World time and world-system changes that already occurred while the mod was active cannot be undone except by restoring a pre-deployment save backup.

## Public Alpha rollback triggers

Roll back and investigate if:

- compressed `MinutesPerDay` persists after the state should return to baseline;
- awake simulation globally accelerates;
- clients repeatedly lose clock pacing synchronization;
- recurring Enshrouded Sleep exceptions appear;
- an awake player's health/survival state becomes dangerously accelerated beyond the SPIKE-004 accepted behavior;
- a time-driven system causes severe persistent world/player-state damage beyond the documented alpha model.
