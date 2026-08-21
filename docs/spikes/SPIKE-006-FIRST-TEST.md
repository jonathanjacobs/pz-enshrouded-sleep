# SPIKE-006 — First Awake-Player Protection Prototype Test

Purpose: determine whether the diagnostics-only post-update normalizer can reduce passive awake-player survival progression from approximately 20x back toward baseline real-time pacing.

This is **not** a normal gameplay configuration.

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
```

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
```

The `CORRECTION` record includes before/after values for:

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

### Phase C — restore

Set:

```text
DiagnosticForcedCompressionFactor=1.0
```

Remain connected for approximately **1 real minute** and confirm native `MinutesPerDay` is restored.

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

A client DebugLog is optional unless the client reports an error or visibly strange survival state.

## Analysis

Compare the ordinary focused survival stream at baseline and 20x.

Without protection, SPIKE-004 observed hunger/thirst/fatigue/nutrition scaling approximately with the calendar-compression factor.

With the prototype active, the target is:

```text
20x world/calendar progression
~1x awake passive survival progression
```

The prototype's own before/after records will also show whether the correction is actually being applied every player update.

## Immediate abort conditions

Restore factor 1 and disable the prototype if:

- a second living player joins;
- the character falls asleep;
- `MinutesPerDay` does not match the intended target;
- `TrueMultiplier` changes from normal active simulation;
- an Enshrouded Sleep Lua error occurs;
- hunger/thirst/fatigue/nutrition visibly jump or oscillate;
- a `write-failure-fail-open` status appears repeatedly.

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
