# Validation History

This document preserves the technical evidence behind the current Enshrouded Sleep architecture. It is intentionally separate from the top-level README.

For current procedures, see [`TESTING.md`](TESTING.md). For focused investigations, see [`spikes/`](spikes/). For durable design decisions, see [`adr/`](adr/).

## Summary

The project progressed through four major evidence questions:

1. can `MinutesPerDay` compress world/calendar time without globally accelerating active simulation? — **yes**;
2. can the MVP rely on vanilla-instantiated player/sleep lifecycle and hand full sleep back to vanilla? — **yes**;
3. can clients be paced coherently with the authoritative compressed day length? — **yes**;
4. do health/survival subsystems create unsafe awake-player effects under calendar compression? — **currently under investigation in SPIKE-004**.

The core sleep/clock architecture is behaviorally validated on Project Zomboid 42.20.3 with two players. WHG Public Alpha deployment is paused only for the fourth safety question, not because the earlier clock architecture regressed.

## v0.0.1 — calendar-compression feasibility

Goal: determine whether world/calendar time can be accelerated without globally accelerating active simulation.

Result:

- live baseline `MinutesPerDay=90`;
- temporary `4.5` produced approximately 20x world/calendar progression;
- `TrueMultiplier` remained `1`;
- awake gameplay did not visibly accelerate;
- exact baseline restoration worked.

Decision: use `MinutesPerDay` as the partial-sleep primitive. See [`spikes/SPIKE-001-minutes-per-day-feasibility.md`](spikes/SPIKE-001-minutes-per-day-feasibility.md) and ADR-001.

## v0.0.2 — player lifecycle/sleep-state investigation

Results:

- server-side `IsoPlayer:isAsleep()` reliably reflected actual sleep/wake state;
- dead player objects can remain in `getOnlinePlayers()` during respawn;
- dead characters must be excluded from the living denominator;
- clients may authenticate/load before an `IsoPlayer` appears;
- MVP should use instantiated living players rather than a custom readiness registry.

## v0.0.2b — vanilla full-sleep probe

With baseline `MinutesPerDay=90` and configured `FastForwardMultiplier=40`:

```text
MinutesPerDay -> remains 90
GameTime multiplier -> roughly 4.8 to roughly 575
TrueMultiplier -> remains 1
observed calendar rate -> roughly 120x baseline
```

Conclusion: vanilla full sleep uses a mechanism distinct from `MinutesPerDay`; restore baseline and step aside rather than stacking mechanisms. See [`spikes/SPIKE-002-vanilla-sleep-lifecycle.md`](spikes/SPIKE-002-vanilla-sleep-lifecycle.md) and ADR-002.

## v0.0.3 — functional proportional controller

Introduced:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = NativeFastForward * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

The controller captures the live baseline, excludes dead players, applies compression only during partial sleep, restores baseline otherwise, never uses `GameTime:setMultiplier()` for partial sleep, and fails toward baseline.

## v0.0.4 — first successful two-player proportional test

Validated on B42.20.2:

```text
2 living / 0 sleeping -> MinutesPerDay=90
2 living / 1 sleeping -> factor 20 -> MinutesPerDay=4.5
2 living / 2 sleeping -> restore 90 -> vanilla full-sleep takeover
```

Wake restoration and disconnect denominator recalculation also passed.

A client presentation problem remained: both sleeping and awake clocks visibly jumped.

## v0.0.5 — client clock diagnosis

Read-only server/client diagnostics showed:

```text
SERVER MinutesPerDay = 4.5
CLIENT MinutesPerDay = 90
```

The client advanced using native day length and periodically received large multiplayer corrections, typically about 51 in-game minutes. This established that runtime server `MinutesPerDay` changes were not automatically mirrored to the tested client.

The same test exposed a character remaining asleep across more than 30 authoritative world-hours.

## v0.0.6 — explicit client day-length synchronization

Added server `ClockState` publication and client local `MinutesPerDay` mirroring.

Two-player testing on PZ 42.20.3 showed:

```text
SERVER MinutesPerDay = 4.5
CLIENT A MinutesPerDay = 4.5
CLIENT B MinutesPerDay = 4.5
```

Results:

- client clock rate approximately 5.33 game-minutes per real second;
- prior ~51-minute sawtooth corrections disappeared;
- sleeping and awake clocks were visually smooth;
- awake movement/actions remained normal-speed;
- baseline/full-sleep handoff remained correct;
- client `AsleepTime` tracked compressed world time and wake occurred near vanilla `ForceWakeUpTime`.

A post-apply diagnostic expression still produced repeated Kahlua `Double` -> `String` exceptions after the setter had succeeded.

## v0.0.7 — clean regression

v0.0.7 fixed the multi-return numeric-conversion error and added one-observer-pass synchronization settling.

The clean PZ 42.20.3 regression confirmed:

- no recurrence of the exception flood;
- correct server/client `90 <-> 4.5` transitions;
- no stale partial-state packet paired with baseline 90;
- client clock rate remained approximately theoretical;
- sleeping and awake clocks remained smooth;
- awake gameplay remained normal-speed;
- full-sleep handoff and disconnect recalculation remained correct;
- pill-influenced sleep woke within a few game minutes of vanilla `ForceWakeUpTime`.

Issues #1, #2, and #3 were closed.

See [`spikes/SPIKE-003-client-clock-synchronization.md`](spikes/SPIKE-003-client-clock-synchronization.md) and ADR-003.

## Public Alpha hardening after v0.0.7

The one-second clock/sleep samplers were gated behind:

```text
DiagnosticsEnabled = false
```

by default to keep live-server log volume manageable. This did not change the controller or synchronization policy.

## v0.0.8 — health/survival time-domain diagnostic stage

### Trigger

Before WHG Public Alpha deployment, review raised a critical question: what happens to an awake wounded or physiologically stressed player when another player triggers calendar compression?

The existing evidence proves that active movement/combat simulation remains normal-speed, but it does **not** prove that bleeding, hunger, thirst, healing, infection, or other health systems use the same time domain.

### Added instrumentation

v0.0.8 added:

```text
HealthTimeDomainDiagnostic_Server.lua
HealthTimeDomainDiagnostic_Client.lua
```

When `DiagnosticsEnabled=true`:

- server records a broad health/survival/nutrition snapshot for every instantiated living player once per real second;
- owning client records corresponding local values;
- detailed `BODY` lines are emitted for injured/non-pristine body parts;
- each sample is correlated with `MinutesPerDay`, observed baseline, compression factor, `TimeOfDay`, `WorldAgeHours`, population and sleep phase.

The diagnostic is read-only and deliberately avoids the Kahlua multi-return conversion pattern that caused the v0.0.6 error flood.

### First integration run — solo, 2026-08-19

The v0.0.8 health diagnostic successfully loaded and sampled on PZ 42.20.3. The reviewed logs contained hundreds of server/client player samples and thousands of detailed body-part samples with no recurring Enshrouded Sleep diagnostic exception.

Useful telemetry included:

- overall health / overall body health;
- injury counts and detailed body-part state;
- bleeding, scratch, deep-wound and related timers;
- sleep state/counters;
- nutrition/weight values;
- cold-related values;
- apparent infection and several wound-infection values.

Server and owning-client overall health values generally agreed closely during the run.

### Vanilla full-sleep reference from the solo run

The solo experiment included a deliberately injured character entering sleep. Because there was only one living player, Enshrouded Sleep correctly restored native `MinutesPerDay=90`; **vanilla full-sleep fast-forward owned the sleep interval**.

Immediately before the first sleep, the client diagnostic reported approximately:

```text
Health = 81.16
NumBleeding = 4
NumScratched = 4
MinutesPerDay = 90
asleep = false
```

After vanilla sleep began, successive approximately one-second health samples were:

```text
69.68
47.74
25.83
6.03
0.00
```

The character therefore died within about five real seconds of entering vanilla full sleep while four active bleeds remained.

A later controlled sleep with bleeding no longer driving health loss showed rapid health recovery and accelerated wound/healing timer progression.

Nutrition stores such as carbohydrates, proteins and lipids also accelerated strongly during vanilla sleep relative to awake baseline. Calories did not behave like a simple single-clock metric, consistent with additional metabolic/activity inputs.

This is important reference evidence: Project Zomboid health and recovery systems can react very strongly to **vanilla multiplier-driven full sleep**.

It does **not** answer the SPIKE-004 safety question. Enshrouded Sleep partial sleep does not engage vanilla full-sleep fast-forward; it changes `MinutesPerDay` while at least one living player remains awake.

### v0.0.8 Lua/Kahlua exposure boundary

The getter-only diagnostic returned `N/A` for many desired continuous values on both server/client, including hunger, thirst, fatigue, endurance, stress, panic, general pain, boredom, unhappiness, sickness, drunkenness, fear, sanity, food sickness, poison and several aggregate infection/temperature/wetness values.

This did not crash the diagnostic. It showed that public Java API documentation cannot be assumed to map one-for-one to Lua/Kahlua method exposure.

## v0.0.9 — enhanced health-state probes

v0.0.9 is the follow-up diagnostic build for the decisive two-player SPIKE-004 test.

Changes are observational only:

- selected raw values now attempt the normal getter and then a guarded documented public Java field fallback;
- relevant Project Zomboid Moodles are sampled by index as a discrete fallback/secondary signal;
- a compact full Moodle summary is included per health sample;
- `DeltaMinutesPerDay`, game multiplier, true multiplier and server multiplier are logged directly with health samples;
- the client diagnostic labels a local sleeping-at-baseline state as vanilla full sleep rather than generic baseline, making solo/full-sleep reference data easier to separate from partial compression.

No health compensation, proportional formula change, sleep-policy change, or global multiplier manipulation was introduced.

### Next required test

The decisive test uses:

```text
Player A: awake, monitored, deliberately injured/stressed
Player B: asleep
```

The recommended first run lowers native `FastForwardMultiplier` to `10`. With two living players and one sleeper at baseline `MinutesPerDay=90`, expected partial behavior is approximately:

```text
CalendarCompressionFactor = 5
MinutesPerDay = 18
```

This gives a large enough signal to classify time-domain behavior while providing more operator reaction time than the earlier factor-20 configuration.

The result must classify actual awake-player bleeding/health loss first, then hunger/thirst/fatigue/healing/sickness/infection/temperature where measurable, and produce a GO / CONDITIONAL GO / NO-GO decision for WHG Public Alpha.

## Current decision

**WHG Public Alpha deployment remains paused pending the two-player SPIKE-004 partial-compression comparison.**

This is a new evidence boundary, not a reversal of the validated v0.0.7 clock architecture.

## Current evidence boundary

Well supported:

- two-player proportional compression;
- client/server `MinutesPerDay` synchronization;
- smooth sleeping/awake clock presentation;
- normal-speed awake active simulation;
- baseline restoration;
- vanilla full-sleep handoff;
- wake/disconnect recalculation;
- sensible vanilla sleep duration when client pacing is synchronized;
- v0.0.8 broad health/body diagnostic integration;
- strong vanilla full-sleep effects on bleeding/recovery/nutrition as reference behavior.

Current pre-alpha blocker:

- **awake-player** health/survival time-domain safety under **partial** `MinutesPerDay` compression.

Public Alpha targets after that gate:

- 3–12+ player proportional fractions;
- real join/disconnect/death/respawn behavior;
- long-session stability;
- WHG mod-stack interaction;
- non-health world-time systems such as spoilage, farming, generators, weather, corpses and composting;
- future B42 update regressions.
