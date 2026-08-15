# Enshrouded Sleep - Test Procedures

This document contains repeatable dedicated-server test procedures for development builds.

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

### Expected authoritative server behavior

For two living players and one sleeper with baseline 90 / native FF 40 / scale 1.0:

```text
SleepFraction = 0.5
CalendarCompressionFactor = 20
EffectiveMinutesPerDay = 4.5
```

The normal controller should emit:

```text
STATE | mode=partial | living=2 | sleeping=1 | sleepFraction=0.5000 | CalendarCompressionFactor=20.000 | EffectiveMinutesPerDay=4.500
```

### Data to collect

Collect the dedicated-server debug log covering the complete test.

Also collect each participating client's log/console output containing:

```text
[EnshroudedSleepDiag][CLIENT] SAMPLE
```

The most important comparison is the same real-time interval across server and client samples.

### Primary diagnostic questions

1. Does the server report `MinutesPerDay=4.5` during partial sleep?
2. Does each client also report `MinutesPerDay=4.5`, or does it remain at `90`?
3. Does client `TimeOfDay` advance continuously between samples?
4. Do `ServerTimeOfDay` and `ServerLastTimeOfDay` move differently from local `TimeOfDay`?
5. Do large changes in client `TimeOfDay` line up with the visible watch/sleep-screen jumps?
6. Is the defect present on both the awake and sleeping clients under the same authoritative server interval?

### Interpretation

If the server reports `4.5` but the client remains at `90`, investigate explicit replication of the current compression/day-length state.

If the client reports `4.5` but its underlying `TimeOfDay` advances in coarse jumps, investigate multiplayer clock synchronization/interpolation.

If client GameTime advances smoothly while only the visible clocks jump, isolate the fix to the sleeping-screen and HUD/watch presentation paths.

Do not introduce a synchronization or interpolation fix until the diagnostic data distinguishes these cases.

### Safety invariant

The v0.0.5 diagnostics must not mutate time or sleep state. They must not call:

```text
setMinutesPerDay()
setTimeOfDay()
setMultiplier()
GameServer.syncClock()
```

Any future experimental synchronization change should be a separate, explicitly documented development version.
