# SPIKE-005 — Vehicle Battery Time-Domain Test

Purpose: classify vehicle battery drain under Enshrouded Sleep calendar compression using a controlled, stationary vehicle with the engine off and headlights on.

This follows the completed stationary-idle fuel test, which classified vehicle fuel consumption as **WORLD/CALENDAR-TIME BOUND**.

## Why this test is isolated

Vanilla Build 42 vehicle logic applies headlight battery drain using the vehicle update `elapsedMinutes` value when the engine is off. The first vehicle diagnostic incorrectly tried to read battery charge from the battery inventory item with `getUsedDelta()` and returned `N/A`.

The SPIKE-005 diagnostic now records the canonical vehicle-level value:

```text
BaseVehicle:getBatteryCharge()
```

and also records:

```text
batteryItemCharge
headlightsOn
lightbarLightsMode
lightbarSirenMode
engine running state
fuel
RPM
```

This is still observation-only instrumentation. It does not alter battery state.

## Setup

Use the latest branch:

```text
spike-005-world-time-domains
```

Restart the dedicated server and client after deploying the updated development copy.

Use exactly one connected living player and remain awake.

A vanilla police cruiser is acceptable and convenient. Use the same vehicle for both phases.

Before measurement:

1. Park the vehicle safely and leave it stationary.
2. Sit in the driver's seat so the diagnostic can observe the vehicle.
3. Turn the **engine OFF**.
4. Turn the **headlights ON**.
5. Keep the **lightbar OFF**.
6. Keep the **siren OFF**.
7. Keep radio/heater/other electrical accessories OFF where practical.
8. Do not start the engine during either measurement interval, because engine-running logic charges the battery.

## Instrumentation sanity check

Set:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor=1.0
```

Confirm server logs contain a line similar to:

```text
[EnshroudedSleepWorldDiag][SERVER] VEHICLE | ... | running=false | batteryCharge=0.xxxxxxxx | ... | headlightsOn=true | lightbarLightsMode=0 | lightbarSirenMode=0
```

### Stop immediately if

- `batteryCharge=N/A`;
- `running=true`;
- `headlightsOn` is not `true`;
- lightbar or siren mode is non-zero;
- a second living player joins;
- the test player sleeps;
- Enshrouded Sleep emits a Lua/runtime error.

If `batteryItemCharge=N/A` but `batteryCharge` is numeric, continue; `batteryCharge` is the authoritative measurement for this test.

## Phase A — baseline 1x

Keep:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor=1.0
```

With the engine off and headlights on, remain in the stationary vehicle for **10 real minutes**.

Do not toggle lights, leave/re-enter, or start the engine.

## Phase B — 20x

Change only:

```text
DiagnosticForcedCompressionFactor=20.0
```

For the reference 90-minute native day, verify:

```text
MinutesPerDay=4.5
TrueMultiplier=1.0
```

Remain in the same stationary vehicle with engine off and headlights on for **5 real minutes**.

Do not toggle any vehicle state.

## End

Restore:

```text
DiagnosticForcedCompressionFactor=1.0
DiagnosticsEnabled=false
```

Then turn the headlights off.

Confirm native `MinutesPerDay` is restored.

Collect:

- server console log;
- server `Logs/DebugLog`.

Client logs are needed only if a client-side error occurs.

## Analysis

For each stable interval calculate:

```text
battery charge lost / real second
battery charge lost / elapsed world minute
```

Interpretation:

### WORLD/CALENDAR-TIME BOUND

If the 20x phase loses battery charge approximately 20x faster per real second while charge loss per elapsed world minute remains approximately constant.

### SIMULATION/REAL-TIME BOUND

If charge loss per real second remains approximately unchanged between 1x and 20x.

### HYBRID / INCONCLUSIVE

If scaling is intermediate, discontinuous, accessory-dependent, or affected by unexpected charging/drain behavior.

## Expected vanilla signal

Current Build 42 vanilla Lua applies headlight drain only when the headlights are active and the engine is not running, using a decrement proportional to `elapsedMinutes`. This test determines whether that elapsed-minutes source follows Enshrouded Sleep's compressed world/calendar time in the live dedicated-server runtime.
