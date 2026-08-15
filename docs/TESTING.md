# Enshrouded Sleep - Test Procedures

This document contains repeatable dedicated-server test procedures for development builds.

## v0.0.6 - client MinutesPerDay replication and sleep-duration telemetry

### Objective

Test the first targeted fix for the clock-jump defect and collect enough vanilla sleep telemetry to determine why a sleeping character can remain asleep across implausibly large amounts of compressed world time.

v0.0.6 keeps the v0.0.4 proportional server controller intact, but adds two new synchronization components:

```text
42/media/lua/server/EnshroudedSleep/ClockStateSync_Server.lua
42/media/lua/client/EnshroudedSleep/ClockStateSync_Client.lua
```

The server broadcasts its current authoritative `MinutesPerDay` when the effective clock state changes and as a two-second heartbeat. The client mirrors only that `MinutesPerDay` value locally. The client does not set `TimeOfDay`, `WorldAgeHours`, or any multiplier.

### Why this experiment exists

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

v0.0.6 tests whether explicitly mirroring the server's `MinutesPerDay` on each connected client eliminates those large corrections.

### Required installation

Use the exact same v0.0.6 snapshot on:

- the dedicated server;
- client A;
- client B.

Preferred folder on each Windows client:

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

Reference test-server native configuration:

```text
MinutesPerDay runtime baseline = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
```

### Expected startup messages

Server:

```text
[EnshroudedSleep] Loaded v0.0.6 proportional calendar-compression prototype.
[EnshroudedSleepSync][SERVER] Loaded v0.0.6 authoritative MinutesPerDay replication experiment.
[EnshroudedSleepDiag][SERVER] Loaded v0.0.6 server clock/sleep diagnostic.
```

Client:

```text
[EnshroudedSleepSync][CLIENT] Loaded v0.0.6 client MinutesPerDay synchronization experiment.
[EnshroudedSleepDiag][CLIENT] Loaded v0.0.6 client clock/sleep diagnostic.
```

If `Events.OnServerCommand` is not available in the client Lua environment, the client sync module should log an explicit error and the test should stop there.

### Procedure

1. Start the server with v0.0.6.
2. Connect client A and fully load its character.
3. Connect client B and fully load its character.
4. Keep both characters alive and awake for at least 15 real seconds.
5. Confirm both clients report `MinutesPerDay=90`.
6. Have client B enter normal vanilla sleep while client A remains awake.
7. Keep exactly one of two players asleep for at least 60 real seconds.
8. Client A should watch the upper-right HUD/watch clock and move/interact normally.
9. Client B should watch the sleeping black-screen clock.
10. Do not manually wake client B during the first 60 seconds unless safety requires it; we want to observe vanilla `AsleepTime`, `ForceWakeUpTime`, fatigue, and pill state.
11. After at least 60 seconds, wake client B if vanilla has not already done so.
12. Keep both awake for at least 15 additional seconds.
13. Optionally put both players to sleep briefly to verify the transition back to native `MinutesPerDay=90` before vanilla full-sleep fast-forward.
14. End the test and collect the server debug log plus the local `console.txt` from at least the sleeping client. The awake client's console remains desirable but is no longer required to establish the original v0.0.5 bug.

### Expected partial-sleep server state

For two living players and one sleeper with baseline 90 / native FF 40 / scale 1.0:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

Expected controller line:

```text
[EnshroudedSleep] STATE | mode=partial | living=2 | sleeping=1 | sleepFraction=0.5000 | CalendarCompressionFactor=20.000 | EffectiveMinutesPerDay=4.500
```

Expected server replication line on the transition:

```text
[EnshroudedSleepSync][SERVER] STATE | mode=partial | living=2 | sleeping=1 | authoritativeMinutesPerDay=4.5000 | broadcast ClockState
```

Expected client replication line:

```text
[EnshroudedSleepSync][CLIENT] APPLY | mode=partial | ... | beforeMinutesPerDay=90.0000 | targetMinutesPerDay=4.5000 | afterMinutesPerDay=4.5000
```

### Clock acceptance checks

During the stable one-of-two-sleeping interval:

1. Server diagnostic must report `MinutesPerDay=4.5`.
2. Sleeping-client diagnostic must also report `MinutesPerDay=4.5` after receiving the ClockState packet.
3. Awake client should also report `4.5` if its console is collected.
4. Client `TimeOfDay` should advance at approximately the same rate as the server between normal multiplayer synchronization corrections.
5. The previous recurring ~50-minute correction pattern should disappear or become much smaller.
6. Both the sleeping black-screen clock and awake HUD/watch clock should appear to advance rapidly but continuously enough to follow visually.
7. Awake movement, zombies, combat, vehicle behavior, animations, inventory actions, and timed actions must remain normal-speed.

A successful v0.0.6 clock experiment does not require zero numerical correction between server and client. It requires removal of the large sawtooth drift caused by the client using `MinutesPerDay=90` while the server uses `4.5`.

### Sleep-duration diagnostic fields

v0.0.6 additionally records the following for each living player while anyone is asleep:

```text
player / OnlineID
isAsleep
AsleepTime
ForceWakeUpTime
Fatigue
SleepingPillsTaken
```

The sleeping client's local diagnostic records the same fields.

### Sleep-duration questions

The test should determine:

1. Does `AsleepTime` increase in proportion to compressed world time or ordinary real/simulation time?
2. How does `ForceWakeUpTime` relate to `TimeOfDay` while partial compression is active?
3. Does fatigue fall at the expected rate while `WorldAgeHours` advances 20x?
4. Does `SleepingPillsTaken` explain the observed wake target, or does the character remain asleep far beyond it?
5. Are server and sleeping-client sleep counters consistent with each other?

Do not add sleep-recovery compensation until these values establish which time domain vanilla actually uses.

### Failure interpretation

If the client never logs an `APPLY` line, inspect `Events.OnServerCommand` registration and server `sendServerCommand()` delivery before changing the clock model.

If the client logs `APPLY` and reports `MinutesPerDay=4.5`, but visible clocks still make ~50-minute jumps, compare the client/server `TimeOfDay` samples to determine whether another internal clock calculation ignores local MinutesPerDay.

If the clock becomes smooth but sleep duration remains extreme, treat issue #3 as an independent sleep-recovery time-domain problem.

If setting local client `MinutesPerDay` causes movement, action speed, or other active-simulation behavior to change, stop the experiment and revert; v0.0.6 is intended to alter local calendar pacing only.

## v0.0.5 - client/server clock synchronization diagnostic

### Objective

Determine why the sleeping black-screen clock and awake HUD/watch clock advance in visible jumps during otherwise-correct partial-sleep calendar compression.

This test is diagnostic only. v0.0.5 does not intentionally change the v0.0.4 proportional controller.

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
2. Confirm the server log contains the normal Enshrouded Sleep startup/configuration messages and:

```text
[EnshroudedSleepDiag][SERVER] Loaded v0.0.5 read-only server clock synchronization diagnostic.
```

3. Connect client A and allow the character to finish loading into the world.
4. Connect client B and allow the character to finish loading into the world.
5. Keep both characters alive and awake for at least 15 real seconds.
6. Confirm the server reaches:

```text
living=2
sleeping=0
MinutesPerDay=90
```

7. Have client B enter normal vanilla sleep while client A remains awake.
8. Keep this state for at least 45 real seconds. Do not have client A sleep during this interval.
9. Client A should move around and interact normally while observing the upper-right watch/HUD clock.
10. Client B should observe the sleeping black-screen clock.
11. Record approximately when either player sees a visible clock hold/jump.
12. Wake client B and keep both players awake for at least 15 real seconds.
13. Optionally repeat the one-sleeper interval once to confirm reproducibility.
14. End the test without changing admin status, switching characters, or intentionally dying.

### Result established by v0.0.5

The server correctly changed to `MinutesPerDay=4.5`, but the collected sleeping-client console remained at `MinutesPerDay=90`. Client `TimeOfDay` advanced slowly and then received recurring corrections of roughly 51 in-game minutes. This established that runtime server `MinutesPerDay` changes are not automatically mirrored to the client and motivated the v0.0.6 explicit ClockState experiment.

The same test also revealed a separate long-sleep defect: a player remained asleep while more than 30 authoritative world-hours elapsed. v0.0.5 did not record enough sleep counters to identify why.
