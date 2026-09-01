# SPIKE-006 — Active-Effects Regression Test

Purpose: determine whether the tick-driven awake-player normalizer preserves legitimate player-driven and state-driven survival changes while world/calendar time is compressed.

Status: **Completed — the regression supported the production GO recorded in `SPIKE-006-awake-player-protection.md`.**

This procedure followed the successful passive SPIKE-006 validation and served as the production-readiness blocker at that time.

## Branch

Use:

```text
spike-006-awake-player-protection
```

Install the current branch manually on both dedicated server and test client. Restart both after updating files.

## Test population

Start with exactly:

```text
1 living connected player
0 sleeping players
```

Use a disposable/test character or a backed-up test save. Do not run this procedure on the public production server.

## Required settings

```text
DiagnosticsEnabled=true
DiagnosticAwakeProtectionPrototype=true
DiagnosticForcedCompressionFactor=1.0
```

After a short baseline/arming period, use:

```text
DiagnosticForcedCompressionFactor=20.0
```

For a native 90-minute day, confirm:

```text
MinutesPerDay=4.5
TrueMultiplier=1.0
```

Before interpreting any physiology result, confirm the server emits:

```text
[EnshroudedSleepAwakeProtect][SERVER] HEARTBEAT
[EnshroudedSleepAwakeProtect][SERVER] STATUS | prototype-active
[EnshroudedSleepAwakeProtect][SERVER] CORRECTION
```

The general clock and health diagnostics should label the compressed phase as `diagnostic-forced`, not ordinary `baseline` or `partial`.

## Automatic action/activity telemetry

The current SPIKE-006 branch contains transition-based diagnostics on both the dedicated server and owning client:

```text
[EnshroudedSleepActionDiag][SERVER]
[EnshroudedSleepActionDiag][CLIENT]
```

These log only when relevant player activity changes rather than once per tick. The stream records:

- idle / walking / running / sprinting;
- resting;
- sitting on ground/furniture when exposed by the runtime;
- sleeping/waking;
- `IsoPlayer:isPerformingAnAction()`;
- raw network `NetworkCharacterAI:getPerformingAction()`;
- current `LuaTimedActionNew:getMetaType()` and table `Type` when available;
- a best-effort action item identifier for common timed-action table fields;
- player position at the transition;
- `MinutesPerDay`, `TimeOfDay`, and `TrueMultiplier` at the transition.

B42.20.3 source confirms that `NetworkCharacterAI` exposes `getPerformingAction()` and `LuaTimedActionNew` exposes `getMetaType()`/`getTable()`. The logger records those raw values rather than inferring eating or drinking solely from physiology changes.

The owning-client stream is expected to be the strongest evidence for ordinary Lua timed actions such as eating/drinking, while the server stream provides authoritative movement/sleep/network-action corroboration.

Before starting the measured sequence, perform one harmless short action and move/run briefly. Confirm at least one `ACTION` transition appears. If the action type is not semantically identifiable in either stream, preserve the logs anyway; the physiological discontinuity and raw action metadata can still be correlated by epoch.

**Manual wall-clock notes are no longer required for the standard test.** Only note something manually if a specific action fails to appear in both action diagnostic streams.

## Prepare nutrition away from clamps

The successful passive test began with Carbohydrates and Lipids already at the vanilla lower clamp (`-500`), so their correction could not be measured.

Before the measurement sequence, use normal gameplay food or a disposable-character/admin-safe setup to place:

```text
Carbohydrates > -400
Lipids        > -400
```

Prefer values comfortably inside the range rather than close to either clamp.

Record the starting values in the server `SURVIVAL` stream before proceeding.

## Test design principle

Each behavior should be compared against a native 1x control where practical.

For a state or action that naturally changes the protected field at baseline, the protected 20x phase should preserve approximately the **same real-time magnitude/semantics**, not simply suppress the change.

The key risk is directionality. The current prototype scales:

```text
Hunger / Thirst / Fatigue increases -> 1 / compression
Calories / Carbs / Proteins / Lipids decreases -> 1 / compression
Weight changes -> 1 / compression
```

Opposite-direction changes are accepted in full.

That is expected to preserve direct eating/drinking improvements, but same-direction effects require explicit regression testing.

## Phase A — native baseline controls

Set:

```text
DiagnosticForcedCompressionFactor=1.0
```

Allow at least 30 real seconds after the prototype reports:

```text
STATUS | prototype-armed-at-baseline
```

Then perform the following control actions, leaving enough time between actions to identify their effects in the one-second `SURVIVAL` stream and transition-based `ACTION` stream.

### A1. Eat

Eat a known food portion that produces a visible hunger/nutrition change.

Use the action diagnostics to identify the action interval, then compare:

- Hunger immediately before and after;
- Calories;
- Carbohydrates;
- Proteins;
- Lipids;
- Weight if it changes;
- relevant Moodle/Well Fed state.

### A2. Drink

Drink a known quantity of water.

Use the action diagnostics to identify the interval and compare Thirst immediately before and after.

### A3. Sustained movement

Run or sprint continuously for approximately **30 real seconds** in a safe area.

The action logger should mark the running/sprinting transition automatically. Measure the per-real-second rates of:

- Hunger;
- Thirst;
- Fatigue;
- Calories;
- Carbohydrates;
- Proteins;
- Lipids.

Endurance is useful corroborating telemetry but is **not** a protected SPIKE-006 field.

### A4. Rest / sit

Rest or sit for approximately **30 real seconds** after movement.

The action logger should mark the transition automatically. Record the same protected fields plus Endurance for context.

### A5. Well Fed / rate-modifier state

If the food used in A1 creates a Well Fed state, retain a short stable interval and record Hunger progression while the modifier is active.

If practical, repeat with another reproducible trait/state modifier that affects a protected rate. Do not introduce unsafe injuries or toxic exposure merely to create a test condition.

## Phase B — protected 20x repeat

Set:

```text
DiagnosticForcedCompressionFactor=20.0
```

Wait until the server confirms:

```text
MinutesPerDay=4.5
STATUS | prototype-active
```

Repeat the same action sequence as closely as possible:

1. comparable food portion;
2. comparable water amount;
3. approximately 30 real seconds of running/sprinting;
4. approximately 30 real seconds resting/sitting;
5. comparable Well Fed/rate-modifier observation if available.

## Expected behavior

### Eating

Direct improvements should be preserved rather than divided by 20. In particular, a food-driven Hunger decrease and increases in Calories/macros should remain materially comparable to the baseline action.

### Drinking

A direct Thirst decrease should remain materially comparable to the baseline action.

### Movement / running

Protected survival rates should remain approximately comparable to their baseline real-time rates for the same activity, even though world/calendar time is approximately 20x.

Because some vanilla activity modifiers are inside world-time-scaled formulas, a 1/20 normalization of the resulting delta may be correct. The evidence question is the observed final real-time rate, not whether the code path was categorized as "active" or "passive."

### Same-direction direct effects

If a safe, reproducible effect directly changes Hunger/Thirst/Fatigue in the same direction as passive progression, compare its 1x and protected-20x magnitude carefully. This is the main theoretical weakness of the directional normalizer: a direct same-direction delta that is **not** calendar-scaled could be incorrectly divided by the compression factor.

Do not create a dangerous injury, poisoning, or overdose solely for this test.

## Phase C — safety boundaries

After the active-effect sequence, keep factor 20 enabled and verify the two suspension boundaries.

### C1. Sleep transition

Have the only connected player enter vanilla sleep.

The action logger should provide the sleep/wake epoch automatically.

Expected:

```text
prototype correction stops
STATUS reports a suspended population/player state
forced diagnostic compression restores native MinutesPerDay
sleeping-player physiology is not normalized
```

Wake the player and restore a stable factor-1 state before the next boundary test if needed.

### C2. Second-player join

With the test player awake, arm factor 20 and have a second living player connect.

The existing roster logger plus action diagnostic `PLAYER_ACTIVE` transition should identify the population change without a handwritten timestamp.

Expected:

```text
prototype correction stops
forced diagnostic compression restores native MinutesPerDay
STATUS reports suspended-population / player-count condition
```

No protected-state write should be attempted while two living players are present in the diagnostics-only prototype.

## Abort conditions

Immediately restore factor 1 and disable the prototype if:

- `TrueMultiplier` changes from normal active simulation;
- `MinutesPerDay` does not restore when a safety boundary is crossed;
- a repeated `write-failure-fail-open` appears;
- an Enshrouded Sleep Lua exception occurs;
- a protected value visibly oscillates or jumps without a corresponding gameplay action;
- eating/drinking effects are clearly cancelled or severely attenuated;
- a second player is present while the prototype continues mutating state.

## Send back

Collect:

```text
server console
server Logs/DebugLog
client console/DebugLog for the owning test player
```

For the second-player suspension check, include the second player's client log only if that client reports a visible anomaly or Enshrouded error.

No routine manual action timestamps are required. The analysis should use the `EnshroudedSleepActionDiag` transitions, roster transitions, controller state, and survival telemetry on their common epoch timestamps. If an action unexpectedly fails to appear in both action streams, mention only that missing action when sending the logs.

## Acceptance criteria

At the time of this test, SPIKE-006 could move toward production implementation only if:

- passive protected rates remain approximately 1x under 20x calendar compression;
- eating and drinking retain their normal direct magnitude/semantics;
- activity-modified real-time survival rates remain approximately comparable to baseline for the same activity;
- Carbohydrates and Lipids are confirmed away from their clamps and normalize correctly;
- no material same-direction direct-effect distortion is found, or any affected field/effect can be explicitly excluded safely;
- sleep transitions suspend correction before sleeping physiology is altered;
- a second living player suspends the diagnostics-only mutation path and restores baseline clock pacing;
- server and owning-client protected values remain coherent;
- no Enshrouded Sleep Lua errors or repeated write failures occur.

A failure in one field does not automatically invalidate the entire approach. Record whether the result supports **GO**, **PARTIAL GO**, or **NO-GO** and narrow the production protection set if necessary.
