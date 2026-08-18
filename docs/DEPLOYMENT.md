# Public Alpha Deployment Guide

Enshrouded Sleep v0.0.7 is entering **Public Alpha** field testing on multiplayer servers. The core two-player clock/sleep architecture has passed dedicated-server regression testing on Project Zomboid 42.20.3. Public alpha expands testing to larger populations, longer sessions, real player behavior, and a broader mod ecosystem.

This is an alpha deployment. Back up the server and preserve an easy rollback path.

## Before deployment

1. Stop the server cleanly.
2. Back up the world/save and server configuration.
3. Install the same Enshrouded Sleep snapshot on the server and all participating clients.
4. Confirm the stable Mod ID is `pz-enshrouded-sleep`.
5. Confirm the server is running a compatible Build 42 version. The current behaviorally validated baseline is **42.20.3**.
6. Keep `PartialSleepSpeedScale=1.0` for the initial public-alpha deployment unless intentionally testing another value.
7. Keep verbose diagnostics disabled for normal play.

Recommended sandbox settings:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
},
```

`DiagnosticsEnabled=true` produces one-second server/client clock and sleep telemetry and can generate very large logs on an active multiplayer server. Enable it only for focused troubleshooting, then turn it back off.

## Server installation

Preferred local server folder:

```text
mods/pz-enshrouded-sleep/
```

Server Mod ID:

```text
Mods=pz-enshrouded-sleep
```

If the server is not distributing the mod through Workshop or another automated mechanism, every player must have the same local mod snapshot installed before joining.

A typical Windows client location is:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

GitHub's **Download ZIP** usually extracts a folder named `pz-enshrouded-sleep-main`. Rename the outer folder to `pz-enshrouded-sleep` before deployment to avoid ambiguity. The authoritative Mod ID remains the `id=` value in `mod.info`.

## First public-alpha startup

After starting the server, confirm the normal low-volume Enshrouded Sleep messages appear and no Enshrouded Sleep Lua exception is present.

Expected server prefixes:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
```

Expected client prefix:

```text
[EnshroudedSleepSync][CLIENT]
```

The diagnostic modules may emit a single startup line explaining that verbose telemetry is disabled. Continuous `[EnshroudedSleepDiag] SAMPLE` output should **not** appear while `DiagnosticsEnabled=false`.

## What to monitor during public alpha

The public alpha is intended to expose scale and ecosystem behavior that synthetic two-player tests cannot reproduce efficiently.

Pay particular attention to:

- multiple simultaneous sleepers with 3+ living players;
- players joining or disconnecting while others sleep;
- death/respawn while partial sleep is active;
- repeated sleep/wake cycles over long sessions;
- clock continuity for both sleepers and awake players;
- normal-speed awake movement, combat, vehicles, timed actions, and zombies;
- abnormal or unexpectedly long sleep duration;
- any player-side error counter increase associated with Enshrouded Sleep;
- food spoilage, crops, generators, hunger/thirst/fatigue, healing, weather, and other systems tied to world/game time;
- interaction with other installed mods that use `EveryOneMinute`, `WorldAgeHours`, or sleep/recovery logic.

## Expected proportional behavior

The formula scales continuously with the fraction of living players asleep.

For example, with native `FastForwardMultiplier=40` and `PartialSleepSpeedScale=1.0`:

```text
1 of 12 sleeping -> factor ~3.33
3 of 12 sleeping -> factor 10
6 of 12 sleeping -> factor 20
9 of 12 sleeping -> factor 30
12 of 12 sleeping -> mod restores baseline; vanilla full-sleep fast-forward takes over
```

The actual `MinutesPerDay` target also depends on the server's native baseline day length.

## Player-facing alpha bug reports

Useful reports answer these questions:

1. How many players were online?
2. Approximately how many were asleep?
3. What did the player observe?
4. Was the reporting player awake or asleep?
5. Did the problem stop after waking/disconnecting/reconnecting?
6. Did the PZ error counter increase?
7. Approximately when did it happen?

High-value symptoms include:

- the HUD/watch or sleeping clock freezing and jumping;
- awake gameplay visibly speeding up;
- a sleeper remaining asleep for an implausible number of world hours;
- the world staying compressed after everyone wakes;
- the clock failing to return to native behavior after population changes;
- severe world-system side effects during partial sleep;
- Enshrouded Sleep Lua/Java exceptions.

## Focused diagnostics

If a reproducible problem appears, temporarily enable:

```lua
DiagnosticsEnabled = true
```

Restart as required by the server configuration workflow, reproduce the issue for the shortest practical interval, then collect:

```text
server DebugLog / log ZIP
server console output
at least one affected client's console.txt / logs
```

If the issue is client-specific, the affected player's log is more valuable than collecting logs from every player.

Disable diagnostics again after the reproduction session.

## Rollback procedure

The safest rollback is a clean server restart without the mod.

1. Announce the restart to players.
2. Stop the server cleanly.
3. Preserve the current logs before restarting.
4. Remove `pz-enshrouded-sleep` from the server `Mods=` configuration, or disable it through the server's normal mod-management workflow.
5. Restore the pre-deployment sandbox/configuration file if necessary.
6. Restart the server.
7. Confirm native time progression and vanilla sleep behavior.

The mod does not maintain a custom persistent sleep state or custom world database. Removing it should return future clock behavior to vanilla. Time/world-system progression that already occurred while the mod was active is, naturally, already part of the saved world; that is why a pre-deployment backup is recommended for the alpha.

## Public-alpha go/no-go criteria

Continue field testing while:

- clocks remain coherent;
- awake simulation remains normal-speed;
- baseline/full-sleep handoff remains reliable;
- no recurring Enshrouded Sleep exceptions occur;
- no severe world-system side effect makes normal play unsafe.

Roll back and investigate if:

- compressed `MinutesPerDay` persists after the state should have returned to baseline;
- awake simulation globally accelerates;
- clients repeatedly lose synchronization;
- the mod produces a recurring exception/error flood;
- a time-driven system causes severe persistent world damage or resource loss beyond the intended calendar compression model.
