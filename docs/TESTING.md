# Enshrouded Sleep - Test Procedures

This document contains repeatable dedicated-server test procedures for development builds.

## Current Project Zomboid platform baseline

**Project Zomboid 42.20.3 Stable** is the current behaviorally validated runtime baseline for the functionality exercised by the v0.0.6 two-player test.

The successful v0.0.6 run on 42.20.3 confirmed:

```text
mod/server/client load
2 living / 0 sleeping -> native MinutesPerDay=90
2 living / 1 sleeping -> server and both clients MinutesPerDay=4.5
sleeping black-screen clock -> visually smooth
awake HUD/watch clock -> visually smooth
awake movement/actions -> normal-speed
2 living / 2 sleeping -> native MinutesPerDay restored before vanilla full-sleep fast-forward
wake -> correct partial/baseline recalculation
disconnect/population change -> correct denominator/restoration
```

The v0.0.6 run also showed that synchronized client pacing restores sensible vanilla sleep timing: client `AsleepTime` advanced approximately 1:1 with compressed world time and wake occurred near `ForceWakeUpTime`.

The remaining v0.0.6 defect was a repeated client exception in post-apply verification/logging after `setMinutesPerDay()` had already succeeded. v0.0.7 exists to remove that error and perform one clean confirmation run.

Historical 42.20.2 results remain evidence for the versions on which they were actually run; they are not retroactively relabeled as 42.20.3 tests.

## v0.0.7 - clean synchronization regression

### Objective

Confirm that the v0.0.6 behavior remains intact after fixing the client Kahlua multi-return exception and adding the one-observer-pass transition settling guard.

v0.0.7 does **not** change the proportional compression formula, population semantics, or vanilla full-sleep handoff. The test should establish that:

1. server/client clock-state replication remains correct;
2. sleeping and awake clocks remain visually smooth;
3. awake gameplay remains normal-speed;
4. vanilla sleep duration remains sensible;
5. the repeated client `Double` -> `String` `ClassCastException` is gone;
6. transition packets no longer publish a stale baseline value paired with a new partial state.

### Required installation

Use the exact same v0.0.7 snapshot on:

- the dedicated server;
- client A;
- client B.

All three should run Project Zomboid 42.20.3 Stable.

Preferred Windows client folder:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

Preferred server folder:

```text
mods/pz-enshrouded-sleep/
```

Server Mod ID:

```text
pz-enshrouded-sleep
```

Reference sandbox block:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
},
```

Reference native configuration for the established test case:

```text
MinutesPerDay runtime baseline = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
```

### Expected startup messages

Server:

```text
[EnshroudedSleep] Loaded v0.0.7 proportional calendar-compression controller.
[EnshroudedSleepSync][SERVER] Loaded v0.0.7 authoritative MinutesPerDay replication.
[EnshroudedSleepDiag][SERVER] Loaded v0.0.7 server clock/sleep diagnostic.
```

Client:

```text
[EnshroudedSleepSync][CLIENT] Loaded v0.0.7 client MinutesPerDay synchronization.
[EnshroudedSleepDiag][CLIENT] Loaded v0.0.7 client clock/sleep diagnostic.
```

Any Enshrouded Sleep Lua exception during startup is a test failure.

### Procedure

1. Fully stop the server and both clients.
2. Install the same v0.0.7 snapshot on the server and both clients.
3. Start the dedicated server and confirm PZ 42.20.3 plus all three server startup messages above.
4. Connect client A and fully instantiate the character.
5. Connect client B and fully instantiate the character.
6. Keep both characters awake for at least 15 real seconds.
7. Confirm server/client baseline `MinutesPerDay=90` and `living=2`, `sleeping=0`.
8. Make client B the sleeping player and keep client A awake.
9. Do not use sleeping pills for the first controlled sleep if vanilla allows client B to sleep normally.
10. Have client B enter normal vanilla sleep.
11. Confirm the server reaches `living=2`, `sleeping=1`, `CalendarCompressionFactor=20`, `EffectiveMinutesPerDay=4.5`.
12. Confirm both clients apply/report `MinutesPerDay=4.5`.
13. Keep exactly one of two players asleep for at least 60 real seconds.
14. Client A should move/interact normally and watch the upper-right HUD/watch clock.
15. Client B should watch the black sleep-screen clock.
16. Both visible clocks should advance rapidly but smoothly; no long holds followed by ~50-minute corrections should appear.
17. Awake movement/actions must remain normal-speed.
18. Let client B wake naturally if practical; record only a rough observed sleep duration and rely on client telemetry for the precise values.
19. Keep both clients awake for at least 15 real seconds after wake and confirm server/clients return to `MinutesPerDay=90`.
20. Put both players to sleep briefly if practical and confirm the server restores native `MinutesPerDay=90` before vanilla full-sleep fast-forward owns the state.
21. Wake one player and confirm the appropriate partial state (`4.5`) returns without a stale baseline ClockState packet being logged as the new partial state.
22. Wake the remaining player and confirm baseline `90` returns everywhere.
23. If practical, disconnect one client while both are awake and confirm the surviving population remains baseline with no lingering compressed client/server value.
24. End the test normally and preserve the exact server/client logs from that run.

### Critical v0.0.7 exception check

The v0.0.6 failure signature must be absent:

```text
java.lang.ClassCastException
java.lang.Double cannot be cast to java.lang.String
BaseLib.tonumber
ClockStateSync_Client.lua
```

The expected client state-change message should now complete successfully, for example:

```text
[EnshroudedSleepSync][CLIENT] APPLY | mode=partial | living=2 | sleeping=1 | beforeMinutesPerDay=90.0000 | targetMinutesPerDay=4.5000 | afterMinutesPerDay=4.5000
```

Routine two-second heartbeats that find the client already synchronized should remain silent and must not increment the UI error counter.

### Transition settling check

On a new partial-sleep transition, the server should publish the settled controller value. We want:

```text
mode=partial | currentServerMinutesPerDay=4.5000 | broadcastMinutesPerDay=4.5000
```

We do not want the v0.0.6 transient pairing:

```text
mode=partial | currentServerMinutesPerDay=90.0000 | broadcastMinutesPerDay=90.0000
```

The one-observer-pass delay is intentional and should be only a fraction of a second.

### Acceptance criteria

v0.0.7 passes if all of the following are true:

- no Enshrouded Sleep client synchronization exceptions;
- server and both clients use `90` at baseline;
- server and both clients use approximately `4.5` during one-of-two partial sleep;
- client `TimeOfDay` progresses at approximately the server's compressed rate without the old sawtooth correction pattern;
- sleeping black-screen clock is visually smooth;
- awake HUD/watch clock is visually smooth;
- awake movement/actions remain normal-speed;
- full-sleep handoff restores native `MinutesPerDay` before vanilla fast-forward;
- wake/disconnect recalculation restores the correct state;
- no stale baseline partial-state packet is observed;
- client `AsleepTime` and `ForceWakeUpTime` remain consistent with sensible vanilla wake behavior.

If this run passes, issues #1 and #2 can be closed as completed. Issue #3 can also be closed if the sleep-duration telemetry again remains normal. The next development phase should then focus on the remaining v0.1.0 acceptance matrix rather than further clock-architecture debugging.

### Logs to collect

Collect:

```text
Dedicated-server DebugLog / log ZIP
Dedicated-server console output if available
Client A console.txt / logs
Client B console.txt / logs
```

The awake client log is desirable for formal issue #2 closure; unlike earlier diagnosis, this confirmation run should collect both clients if practical.

## v0.0.6 - client MinutesPerDay replication and sleep-duration telemetry

### Objective

Test the first targeted fix for the clock-jump defect and collect enough vanilla sleep telemetry to determine why a sleeping character can remain asleep across implausibly large amounts of compressed world time.

v0.0.6 keeps the v0.0.4 proportional server controller intact, but adds two synchronization components:

```text
42/media/lua/server/EnshroudedSleep/ClockStateSync_Server.lua
42/media/lua/client/EnshroudedSleep/ClockStateSync_Client.lua
```

The server broadcasts its current authoritative `MinutesPerDay` when the effective clock state changes and as a two-second heartbeat. The client mirrors only that `MinutesPerDay` value locally. The client does not set `TimeOfDay`, `WorldAgeHours`, or any multiplier.

### Why this experiment existed

v0.0.5 established the following failure mode during two-player partial sleep:

```text
SERVER
MinutesPerDay = 4.5
world time advances smoothly at the expected compressed rate

CLIENT
MinutesPerDay = 90
client advances slowly at native day length
periodic multiplayer clock correction
~51 in-game minute visible jump
repeat
```

v0.0.6 tested whether explicitly mirroring the server's `MinutesPerDay` on each connected client eliminates those large corrections.

### Result

The v0.0.6 two-player test on PZ 42.20.3 passed the behavioral synchronization hypothesis:

- server and both clients reached `MinutesPerDay=4.5` during one-of-two partial sleep;
- both clients' underlying clocks advanced at approximately 5.33 game-minutes per real second;
- the previous ~51-minute sawtooth corrections disappeared;
- the sleeping black-screen clock was visually smooth;
- the awake HUD/watch clock was visually smooth;
- awake gameplay remained normal-speed;
- full-sleep vanilla handoff and wake/baseline restoration worked;
- client `AsleepTime` advanced with compressed world time and wake occurred near `ForceWakeUpTime`.

The test also exposed a post-apply client logging exception caused by passing the two-return-value `safeMethod()` expression directly to Kahlua `tonumber()`. The actual `setMinutesPerDay()` had already succeeded, so the error flood did not invalidate the synchronization result. v0.0.7 fixes that defect.

### Historical v0.0.6 procedure

1. Start the dedicated server with Project Zomboid 42.20.3 Stable and v0.0.6.
2. Confirm the server log reports 42.20.3 and all three Enshrouded Sleep server modules load without Lua errors.
3. Connect client A, confirm it reports 42.20.3, and fully load its character.
4. Connect client B, confirm it reports 42.20.3, and fully load its character.
5. Keep both characters alive and awake for at least 15 real seconds.
6. Confirm the server reaches `living=2`, `sleeping=0`, and native `MinutesPerDay=90`; confirm both clients also report `90`.
7. Have client B enter normal vanilla sleep while client A remains awake.
8. Confirm the server reaches one-of-two partial state and client ClockState replication applies the same effective `MinutesPerDay` locally.
9. Keep exactly one of two players asleep for at least 60 real seconds.
10. Client A watches the upper-right HUD/watch clock and moves/interacts normally.
11. Client B watches the sleeping black-screen clock.
12. Do not manually wake client B during the first 60 seconds unless safety requires it.
13. After at least 60 seconds, wake client B if vanilla has not already done so.
14. Keep both awake for at least 15 additional seconds and confirm return to native baseline.
15. Put both players to sleep briefly if practical and verify native `MinutesPerDay=90` before vanilla full-sleep fast-forward.
16. Wake one player and confirm appropriate partial/baseline state.
17. If practical, disconnect one client and confirm population recalculation.
18. End the test and collect server and client logs.

## v0.0.5 - client/server clock synchronization diagnostic

### Objective

Determine why the sleeping black-screen clock and awake HUD/watch clock advance in visible jumps during otherwise-correct partial-sleep calendar compression.

This test was diagnostic only. v0.0.5 did not intentionally change the v0.0.4 proportional controller.

### Required configuration

Use the same v0.0.5 GitHub snapshot on the dedicated server and on every test client from which client diagnostic logs are required.

Preferred local folder:

```text
pz-enshrouded-sleep/
```

Server Mod ID:

```text
pz-enshrouded-sleep
```

Server sandbox block:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
},
```

Reference test-server native configuration:

```text
MinutesPerDay runtime baseline = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
```

### Diagnostic log prefixes

Server:

```text
[EnshroudedSleep]
[EnshroudedSleepDiag][SERVER]
```

Client:

```text
[EnshroudedSleepDiag][CLIENT]
```

The diagnostic samplers run approximately once per real second.

### Procedure

1. Start the dedicated server with v0.0.5 installed.
2. Confirm the server log contains the normal Enshrouded Sleep startup/configuration messages and the v0.0.5 server diagnostic startup line.
3. Connect client A and allow the character to finish loading into the world.
4. Connect client B and allow the character to finish loading into the world.
5. Keep both characters alive and awake for at least 15 real seconds.
6. Confirm the server reaches `living=2`, `sleeping=0`, `MinutesPerDay=90`.
7. Have client B enter normal vanilla sleep while client A remains awake.
8. Keep this state for at least 45 real seconds.
9. Client A moves/interacts normally while observing the HUD/watch clock.
10. Client B observes the sleeping black-screen clock.
11. Record approximately when either player sees a visible clock hold/jump.
12. Wake client B and keep both players awake for at least 15 real seconds.
13. Optionally repeat once.
14. End the test without changing admin status, switching characters, or intentionally dying.

### Result established by v0.0.5

The server correctly changed to `MinutesPerDay=4.5`, but the collected sleeping-client console remained at `MinutesPerDay=90`. Client `TimeOfDay` advanced slowly and then received recurring corrections of roughly 51 in-game minutes. This established that runtime server `MinutesPerDay` changes are not automatically mirrored to the client and motivated the v0.0.6 explicit ClockState implementation.

The same test showed the long-sleep symptom later explained by synchronized client sleep telemetry in v0.0.6.
