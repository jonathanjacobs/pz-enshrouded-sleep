# SPIKE-005 — First Runtime Test

Purpose: validate the new non-mutating world-system diagnostic collector and obtain the first baseline-versus-10x measurements for food aging and generator fuel use.

## Setup

Use branch:

```text
spike-005-world-time-domains
```

Use exactly one connected living player and keep the character awake.

Place within three tiles of the player:

- one perishable food item in player inventory;
- one perishable food item in a refrigerator if practical;
- one running generator;
- a stable electrical load on the generator if practical.

## Baseline — 5 real minutes

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor=1.0
```

Verify server logs include:

```text
[EnshroudedSleepWorldDiag][SERVER] SAMPLE
[EnshroudedSleepWorldDiag][SERVER] FOOD
[EnshroudedSleepWorldDiag][SERVER] GENERATOR
```

Remain awake and near the objects for 5 real minutes.

## 10x — 5 real minutes

Set:

```text
DiagnosticForcedCompressionFactor=10.0
```

Verify:

```text
[EnshroudedSleep] TEST OVERRIDE ACTIVE
```

and verify `MinutesPerDay = baseline / 10`.

Remain awake and near the same objects for 5 real minutes. Do not move/refuel/replace the observed objects.

## End

Restore:

```text
DiagnosticForcedCompressionFactor=1.0
DiagnosticsEnabled=false
```

Verify native `MinutesPerDay` returns.

Collect and provide:

- server console log;
- server `Logs/DebugLog`.

Client logs are not required for this first test unless a client-side error occurs.

## Abort

Restore factor `1.0` immediately if a second living player joins, the test player sleeps, the expected `MinutesPerDay` is wrong, or an Enshrouded Sleep Lua/runtime error appears.
