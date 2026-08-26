# SPIKE-006 — First Awake-Player Protection Prototype Test

Purpose: determine whether the diagnostics-only tick-driven normalizer can reduce passive awake-player survival progression from approximately 20x back toward baseline real-time pacing.

This is **not** a normal gameplay configuration.

## Current prototype revision

The first dedicated-server attempt loaded the SPIKE-006 module correctly, but its original `Events.OnPlayerUpdate` callback never fired on the tested B42.20.3 dedicated server. The forced 20x calendar-compression path worked, while the player's world-time-bound survival state remained unprotected and progressed at approximately the expected 20x rate.

The prototype now uses a server `Events.OnTick` callback and explicitly iterates `getOnlinePlayers()`. A diagnostics-only heartbeat was added so callback execution can be confirmed independently of whether any correction is needed.

## Branch

Use:

```text
spike-006-awake-player-protection
```

Install the branch manually on both dedicated server and test client using the existing development-branch procedure. Do not test this prototype from the public Workshop v0.0.10 package.

Restart the server and client after updating the files.

## Test population

Use exactly:

```text
1 living connected player
0 sleeping players
```

Keep the player awake for the entire compressed measurement.

For the first run:

- remain stationary;
- do not eat;
- do not drink;
- do not exercise;
- do not use medication;
- avoid temperature extremes, toxic buildings, injuries, combat, and other unusual effects.

The first run is designed to characterize passive normalization only.

## Settings

### Phase A — baseline / arm prototype

Set:

```text
DiagnosticsEnabled=true
DiagnosticAwakeProtectionPrototype=true
DiagnosticForcedCompressionFactor=1.0
```

Remain awake and stationary for **3 real minutes**.

Confirm the server log contains:

```text
[EnshroudedSleepAwakeProtect][SERVER] BASELINE
[EnshroudedSleepAwakeProtect][SERVER] STATUS | prototype-armed-at-baseline
[EnshroudedSleepAwakeProtect][SERVER] HEARTBEAT
```

The heartbeat should report increasing `tickCalls`, `living=1`, `sleeping=0`, `forcedFactor=1`, and native `MinutesPerDay`.

The ordinary focused survival diagnostic should continue to emit:

```text
[EnshroudedSleepSurvivalDiag][SERVER] SURVIVAL
```

No state normalization should occur at factor 1.

### Phase B — 20x protected prototype

Set:

```text
DiagnosticForcedCompressionFactor=20.0
```

For a native 90-minute day, confirm:

```text
MinutesPerDay=4.5
TrueMultiplier=1.0
```

Remain awake and stationary for **5 real minutes**.

Confirm the server emits:

```text
[EnshroudedSleepAwakeProtect][SERVER] STATUS | prototype-active
[EnshroudedSleepAwakeProtect][SERVER] CORRECTION
[EnshroudedSleepAwakeProtect][SERVER] HEARTBEAT
```

The `CORRECTION` record includes `TickCalls` plus before/after values for:

```text
Hunger
Thirst
Fatigue
Calories
Carbohydrates
Proteins
Lipids
Weight
```

The heartbeat should continue approximately every 30 real seconds while diagnostics are enabled. If the module loads but heartbeat/tick counts do not appear, stop the test because the correction callback is not executing.

### Phase C — restore

Set:

```text
DiagnosticForcedCompressionFactor=1.0
```

Remain connected for approximately **1 real minute** and confirm native `MinutesPerDay` is restored and the prototype returns to:

```text
STATUS | prototype-armed-at-baseline
```

Then set:

```text
DiagnosticAwakeProtectionPrototype=false
DiagnosticsEnabled=false
```

## Send back

Collect:

```text
server console
server Logs/DebugLog
```

For the first successful tick-driven correction run, also collect the test player's client DebugLog so server-authoritative corrected values can be compared with the owning client's observed state.

## Analysis

Compare the ordinary focused survival stream at baseline and 20x.

Without protection, SPIKE-004 and the first unsuccessful SPIKE-006 callback run observed hunger/thirst/fatigue/nutrition scaling approximately with the calendar-compression factor.

With the prototype active, the target is:

```text
20x world/calendar progression
~1x awake passive survival progression
```

The prototype's own before/after records will show whether the correction is actually being applied from successive server-tick snapshots.

## Immediate abort conditions

Restore factor 1 and disable the prototype if:

- a second living player joins;
- the character falls asleep;
- `MinutesPerDay` does not match the intended target;
- `TrueMultiplier` changes from normal active simulation;
- an Enshrouded Sleep Lua error occurs;
- hunger/thirst/fatigue/nutrition visibly jump or oscillate;
- a `write-failure-fail-open` status appears repeatedly;
- diagnostics are enabled but the `HEARTBEAT`/`tickCalls` stream does not appear.

## What this test does *not* prove

A successful idle test does not make the implementation production-ready.

The next regression must deliberately exercise legitimate state changes while compressed:

- eating;
- drinking;
- walking/running/sprinting;
- Well Fed;
- resting/sitting;
- other modifiers that can alter the same fields.

Only after those tests can SPIKE-006 decide whether post-update normalization is safe enough for v0.0.11.
