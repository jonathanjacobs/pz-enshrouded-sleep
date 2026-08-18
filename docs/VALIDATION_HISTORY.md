# Validation History

This document preserves the technical evidence behind the current Enshrouded Sleep architecture. It is intentionally separate from the top-level README so new users do not need to read the development history to understand or install the mod.

For current test procedures, see [`TESTING.md`](TESTING.md). For release-level change history, see [`../CHANGELOG.md`](../CHANGELOG.md).

## Summary

The project progressed from a `MinutesPerDay` proof of concept to a server-authoritative proportional-sleep controller, then to explicit client day-length synchronization after multiplayer testing exposed client clock drift.

The current architecture has been behaviorally validated on Project Zomboid 42.20.3 with two players. Public Alpha expands validation to larger real-world multiplayer populations and the normal WHG mod stack.

## v0.0.1 — clock-compression spike

Goal: determine whether Project Zomboid world/calendar time could be accelerated without globally accelerating the active simulation.

Result:

- live baseline `MinutesPerDay=90`;
- temporary test value `4.5` produced approximately 20x world/calendar progression;
- `TrueMultiplier` remained `1`;
- awake movement/gameplay did not visibly accelerate;
- baseline restoration worked.

This established the core premise: partial sleep could be implemented as calendar compression rather than global fast-forward.

## v0.0.2 — player lifecycle/sleep-state spike

Goal: establish reliable multiplayer population and sleep-state semantics.

Results:

- server-side `IsoPlayer:isAsleep()` reliably reflected actual sleep/wake state;
- dead player objects can remain in `getOnlinePlayers()` during respawn;
- dead characters therefore must be excluded from the living denominator;
- clients may authenticate/load before an `IsoPlayer` appears;
- the MVP should use instantiated living players rather than inventing a separate readiness registry.

## v0.0.2b — vanilla full-sleep probe

Goal: characterize vanilla all-players-asleep behavior before adding proportional sleep.

Observed with baseline `MinutesPerDay=90` and configured `FastForwardMultiplier=40`:

```text
MinutesPerDay -> remains 90
GameTime multiplier -> roughly 4.8 to roughly 575
TrueMultiplier -> remains 1
observed calendar rate -> roughly 120x baseline
```

Conclusion: vanilla full sleep uses a mechanism distinct from `MinutesPerDay`. Enshrouded Sleep should restore baseline and step aside when all living players are asleep rather than stacking its own compression with vanilla fast-forward.

## v0.0.3 — functional proportional controller

Introduced the current server-side model:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

The controller:

- captures the exact live baseline;
- uses `getOnlinePlayers()` and excludes dead players;
- applies compression only when some, but not all, living players are asleep;
- restores baseline at zero sleepers or all sleepers;
- never uses `GameTime:setMultiplier()` for partial sleep;
- fails toward baseline on recoverable errors.

## v0.0.4 — first successful two-player proportional test

Validated on B42.20.2:

```text
2 living / 0 sleeping
-> MinutesPerDay=90

2 living / 1 sleeping
-> SleepFraction=0.5
-> CalendarCompressionFactor=20
-> MinutesPerDay=4.5

2 living / 2 sleeping
-> restore MinutesPerDay=90
-> vanilla full-sleep fast-forward takes over
```

Also validated:

- return from full sleep to partial when one player wakes;
- return to baseline when the last sleeper wakes;
- denominator recalculation on disconnect.

A client presentation problem remained: both the sleeping black-screen clock and awake HUD/watch clock advanced in large visible jumps.

## v0.0.5 — client clock diagnosis

Read-only server/client diagnostics established the root cause of the clock jumps.

During one-of-two partial sleep:

```text
SERVER MinutesPerDay = 4.5
CLIENT MinutesPerDay = 90
```

The server advanced compressed world time smoothly while the client advanced using the native 90-minute day and periodically received large multiplayer time corrections. Typical visible corrections were about 51 in-game minutes.

This established that runtime server `MinutesPerDay` changes are not automatically mirrored into client GameTime.

The same test also exposed a sleeping character remaining asleep across more than 30 authoritative world-hours. At that point the sleep-duration cause was unresolved.

## v0.0.6 — explicit client day-length synchronization

Added a narrow server-to-client `ClockState` path:

```text
server controller applies authoritative MinutesPerDay
-> server sync observer broadcasts it
-> client mirrors that MinutesPerDay locally
```

Two-player testing on Project Zomboid 42.20.3 showed:

```text
SERVER MinutesPerDay = 4.5
CLIENT A MinutesPerDay = 4.5
CLIENT B MinutesPerDay = 4.5
```

Results:

- client `TimeOfDay` advanced at approximately 5.33 game-minutes per real second;
- the prior ~51-minute sawtooth corrections disappeared;
- sleeping black-screen clock was visually smooth;
- awake HUD/watch clock was visually smooth;
- awake movement/actions remained normal-speed;
- baseline and vanilla full-sleep handoff remained correct.

The same test clarified the long-sleep issue. Once client `MinutesPerDay` matched the server, client `AsleepTime` advanced with compressed world time and wake occurred near vanilla `ForceWakeUpTime`, including a later sleeping-pill-influenced sleep.

v0.0.6 did contain a client logging bug: a post-apply `tonumber(safeMethod(...))` expression passed both Lua return values into Kahlua and generated repeated `Double` -> `String` `ClassCastException` errors after the actual `setMinutesPerDay()` had already succeeded.

## v0.0.7 — clean regression

v0.0.7 fixed the multi-return logging exception and added a one-observer-pass synchronization settling guard so a new population/sleep state is published only after the authoritative controller has settled `MinutesPerDay`.

The clean regression on Project Zomboid 42.20.3 confirmed:

- no recurrence of the v0.0.6 `ClassCastException` error flood;
- server and client transitions between `90` and `4.5` remained correct;
- no stale `mode=partial` packet paired with baseline `MinutesPerDay=90` was observed;
- client clock progression remained approximately the theoretical 5.33 game-minutes per real second at `MinutesPerDay=4.5`;
- visual clock behavior remained smooth;
- awake gameplay remained normal-speed;
- full-sleep handoff and disconnect/population recalculation remained correct;
- a pill-influenced sleep woke within a few game minutes of the recorded vanilla `ForceWakeUpTime`.

Issues #1, #2, and #3 were closed after this regression.

## Public Alpha hardening

After the successful v0.0.7 regression, the remaining one-second diagnostic samplers were changed to be opt-in through:

```text
DiagnosticsEnabled = false
```

by default.

This does not change the sleep/compression algorithm. It prevents normal public multiplayer sessions from generating large volumes of development telemetry while preserving focused diagnostics for support/reproduction sessions.

## Current evidence boundary

The following are well supported by controlled testing:

- two-player proportional compression;
- client/server `MinutesPerDay` synchronization;
- smooth sleeping and awake clock presentation;
- normal-speed awake simulation;
- baseline restoration;
- vanilla full-sleep handoff;
- wake/disconnect recalculation;
- sensible vanilla sleep duration when client pacing is synchronized.

The following are the main Public Alpha validation targets:

- 3–12+ player proportional fractions;
- repeated real-world join/disconnect/death/respawn behavior;
- long-session stability;
- interactions with the WHG mod stack;
- world-time-driven systems such as spoilage, farming, generators, hunger/thirst/fatigue, healing, weather, corpses, and composting;
- behavior after future Project Zomboid B42 updates.
