# Enshrouded Sleep — Testing Guide

Current status: **Public Alpha**

Current version: `v0.0.7`

Current behaviorally validated Project Zomboid baseline: `42.20.3`

Historical diagnostic procedures and results have been consolidated into [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). This document now focuses on tests that are still useful going forward.

## 1. Test tiers

Enshrouded Sleep uses four practical test tiers.

### Tier 1 — startup smoke test

Use after any source/configuration change or Project Zomboid update.

Goal: prove the mod loads and native baseline behavior is intact.

Minimum checks:

1. Server starts without Enshrouded Sleep Lua errors.
2. Client starts/connects without Enshrouded Sleep Lua errors.
3. `[EnshroudedSleep]` startup/config messages appear.
4. `[EnshroudedSleepSync][SERVER]` and `[EnshroudedSleepSync][CLIENT]` load.
5. With all connected players awake, server/client `MinutesPerDay` remains at the native baseline.
6. With `DiagnosticsEnabled=false`, continuous `[EnshroudedSleepDiag] SAMPLE` lines do not appear.

### Tier 2 — core multiplayer regression

Use before a public deployment after any change to controller or synchronization code.

Reference validated configuration:

```text
Baseline MinutesPerDay = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
PartialSleepSpeedScale = 1.0
```

Procedure:

1. Connect two living players.
2. Keep both awake for at least 15 seconds.
3. Confirm server/client baseline `MinutesPerDay=90`.
4. Put one player to sleep and keep one awake.
5. Confirm server controller reports:

```text
living=2
sleeping=1
SleepFraction=0.5
CalendarCompressionFactor=20
EffectiveMinutesPerDay=4.5
```

6. Confirm both clients adopt/report `MinutesPerDay=4.5`.
7. Keep partial sleep active for at least 60 real seconds.
8. Confirm sleeping black-screen clock is rapid but visually smooth.
9. Confirm awake HUD/watch clock is rapid but visually smooth.
10. Have the awake player move/interact and confirm normal simulation speed.
11. Wake the sleeper and confirm server/clients return to `90`.
12. Put both players to sleep and confirm the mod restores `90` before vanilla full-sleep fast-forward owns the state.
13. Wake one player and confirm partial `4.5` returns.
14. Wake the final sleeper and confirm baseline `90` returns.
15. Disconnect one player and confirm denominator/state recalculation remains correct.

Failure signatures include:

- client/server day-length disagreement;
- large periodic clock jumps;
- global awake gameplay acceleration;
- compressed value persisting after wake/full-sleep handoff;
- recurring Enshrouded Sleep exception/error flood;
- stale partial-state packet paired with a prior baseline value.

This complete sequence passed in the v0.0.7 regression on PZ 42.20.3.

## 2. Public Alpha field test

Public Alpha intentionally shifts emphasis from synthetic two-player reproduction to real server behavior.

### Alpha observation targets

Collect evidence around:

- 3–12+ living players;
- one sleeper among many awake players;
- multiple simultaneous sleepers;
- players joining while partial sleep is active;
- players disconnecting while partial sleep is active;
- death/respawn while others sleep;
- repeated sleep/wake cycles across long sessions;
- unusual latency or reconnect scenarios;
- normal interaction with the server's existing mod stack.

### What players should report

High-value observations:

- sleeping clock freezes/jumps;
- awake HUD/watch freezes/jumps;
- awake movement/combat/actions speed up;
- character sleeps for implausibly many world hours;
- world remains compressed after sleepers wake;
- unexpected time jump after join/disconnect/death;
- PZ error counter increases around a sleep transition;
- severe world-time side effect involving spoilage, crops, generator fuel, hunger/thirst/fatigue, healing, weather, corpses, or another mod.

A useful report includes:

```text
approximate real-world time of incident
players online
players asleep if known
reporting player awake/asleep
what was observed
whether error counter increased
whether behavior cleared after wake/reconnect
```

## 3. Public Alpha scale/proportionality checks

The formula should work for any number of living players.

With native FF `40` and scale `1.0`:

```text
SleepFraction = sleeping / living
CalendarCompressionFactor = max(1, 40 * SleepFraction)
```

Examples:

```text
12 living / 1 sleeping -> factor ~3.333
12 living / 3 sleeping -> factor 10
12 living / 6 sleeping -> factor 20
12 living / 9 sleeping -> factor 30
12 living / 12 sleeping -> restore baseline; vanilla owns full sleep
```

Public Alpha does not require deliberately arranging every fraction. Normal server usage should be recorded when useful transitions naturally occur.

If a suspicious state appears, compare the observed controller log against the formula before assuming a synchronization bug.

## 4. World-time systems characterization

Changing `MinutesPerDay` intentionally accelerates calendar/world time. Public Alpha should establish which systems follow that clock and whether their behavior is acceptable.

Priority systems:

- food aging/spoilage;
- generator fuel consumption;
- crops/farming;
- hunger/thirst/fatigue;
- healing;
- weather;
- corpse decay;
- composting;
- other installed mods driven by game minutes or `WorldAgeHours`.

### Recommended method

For each system:

1. Record baseline behavior with no one sleeping.
2. Observe behavior during a known partial compression factor.
3. Determine whether progression follows world time, real/simulation time, or another clock.
4. Decide whether that result is desirable, acceptable/documentable, or requires a future policy/compensation feature.

Do not implement compensation based on assumption alone.

## 5. Configuration acceptance tests still pending

These should be run on the controlled test server rather than improvised on the public server.

### Alternate day length

Change native DayLength so the live baseline is not `90`.

Pass criteria:

- mod captures the new live baseline automatically;
- no code/config constant needs editing;
- zero sleepers restore the new baseline;
- all-sleepers handoff restores the new baseline.

### Alternate FastForwardMultiplier

Change native `FastForwardMultiplier`.

Pass criteria:

- proportional compression changes automatically according to the formula;
- no duplicate mod fast-forward setting needs editing.

### PartialSleepSpeedScale

Test at least one non-default scale, such as `0.5` or `2.0`.

Pass criteria:

- compression changes proportionally;
- baseline and vanilla full-sleep handoff remain unchanged.

### Disable/fail-safe

Test `Enabled=false` and at least one safe recoverable error path if practical.

Pass criteria:

- exact baseline is restored;
- no compressed value remains on server/clients.

## 6. Verbose diagnostics

Normal Public Alpha play should use:

```text
DiagnosticsEnabled=false
```

When a reproducible problem needs investigation, temporarily enable:

```text
DiagnosticsEnabled=true
```

This activates one-second clock/sleep telemetry on server and clients.

Because the sampler can generate large logs, use it only for the shortest practical reproduction window.

Collect:

```text
server log ZIP / DebugLog
server console output
at least one affected client's console.txt / log ZIP
```

For a client-specific display/sleep problem, the affected client's log is more useful than collecting every player's logs.

## 7. Project Zomboid update regression

When PZ releases a new B42 build:

1. Review official release notes for changes near multiplayer networking, GameTime, Lua events, sleep/fatigue, mod loading, or player lifecycle.
2. Run Tier 1 startup smoke testing.
3. If the update touches any dependency used by the mod, run Tier 2 core multiplayer regression.
4. Do not discard historical evidence unless the update actually changes the relevant behavior.
5. Record the new validated platform baseline only after successful testing.

## 8. Public Beta transition evidence

Before calling the mod Public Beta, testing should establish:

- stable operation with more than two players;
- multiple proportional fractions observed/validated;
- no recurrence of issues #1–#3;
- alternate native day length and FastForwardMultiplier inheritance;
- at least one non-default `PartialSleepSpeedScale` test;
- explicit disable/fail-safe restoration;
- acceptable public-server log/error behavior;
- major world-time-driven effects understood and documented;
- no known high-severity defect requiring rollback from ordinary multiplayer use.

See [`ROADMAP.md`](ROADMAP.md) for the phase-level release criteria.
