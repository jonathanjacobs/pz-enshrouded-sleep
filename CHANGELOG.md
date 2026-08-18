# Changelog

Human-readable history of notable Enshrouded Sleep changes. Git remains authoritative for exact diffs. Detailed experimental evidence lives in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md), while focused investigations and decisions live under [`docs/spikes/`](docs/spikes/) and [`docs/adr/`](docs/adr/).

## [Unreleased]

### Next decision

- Complete [`SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression`](docs/spikes/SPIKE-004-health-time-domains.md).
- Use the resulting evidence to make a **GO / CONDITIONAL GO / NO-GO** decision for WHG Public Alpha deployment.
- If the health spike passes, run a short v0.0.8 core regression and proceed to larger-population field testing.

## [0.0.8] - 2026-08-17

Pre-Public-Alpha health/time-domain diagnostic build.

### Why this build exists

After v0.0.7 passed the clean two-player clock/sleep regression, pre-deployment review identified a separate safety risk: calendar compression may accelerate some player health/survival systems in real time even though active movement/combat simulation remains normal-speed.

The immediate example is an awake wounded/bleeding player while another player sleeps. If blood loss follows world/calendar time, high compression could make an otherwise survivable injury lethal much faster in real time. The same question applies to hunger, thirst, fatigue, healing, sickness, zombie infection, temperature, and related systems.

Public Alpha deployment is therefore paused until this behavior is measured.

### Added — broad server health/time-domain diagnostic

Added:

```text
42/media/lua/server/EnshroudedSleep/HealthTimeDomainDiagnostic_Server.lua
```

When `DiagnosticsEnabled=true`, the server samples every instantiated living player once per real second and records:

- clock/experiment context: phase, living/sleeping counts, sleep fraction, `MinutesPerDay`, observed baseline, compression factor, `TimeOfDay`, `WorldAgeHours`;
- sleep state: asleep flag, `AsleepTime`, `ForceWakeUpTime`, sleeping-pill count;
- health/body state: health, overall body health, injury counts and flags;
- survival stats: hunger, thirst, fatigue, endurance, stress, panic, pain, boredom, sickness, drunkenness, fear, sanity;
- health modifiers: unhappiness, food sickness, poison, infection/apparent infection/fake infection, temperature, wetness, cold progression;
- nutrition: weight, calories, carbohydrates, proteins, lipids;
- detailed injured-body-part telemetry including bleeding, wound timers, cuts, scratches, bites, deep wounds, stitches, fractures, splints, burns, wound infection, bandages, glass/bullets, temperature/wetness, and stiffness.

The diagnostic is read-only and uses guarded API calls so an unavailable Lua-exposed getter is recorded as `N/A` rather than failing the gameplay session.

### Added — client health/time-domain diagnostic

Added:

```text
42/media/lua/client/EnshroudedSleep/HealthTimeDomainDiagnostic_Client.lua
```

The owning client records the corresponding local player metrics. This is deliberate because prior sleep diagnostics established that some useful timing values can be exposed differently or more meaningfully on the owning client than on the server.

### Diagnostic safety

- Both new health diagnostics are dormant unless `DiagnosticsEnabled=true`.
- Sampling is once per real second, not every simulation tick.
- Diagnostics do not heal, injure, feed, fatigue, infect, sleep/wake, or otherwise mutate players.
- Existing low-volume controller/synchronization state logging remains independent of verbose diagnostics.
- The v0.0.6 Kahlua multi-return `tonumber()` failure pattern is explicitly avoided by converting only a separately captured method return value.

### Documentation / engineering records

- Added formal [`SPIKE-004`](docs/spikes/SPIKE-004-health-time-domains.md) with scope, telemetry, controlled procedure, analysis method, and deployment go/no-go criteria.
- Retroactively documented the three completed investigations that established the current architecture as SPIKE-001 through SPIKE-003.
- Added ADR-001 through ADR-003 for the durable decisions to use `MinutesPerDay`, extend vanilla lifecycle/full-sleep semantics, and explicitly mirror authoritative `MinutesPerDay` to clients.
- Reframed the repository status from active Public Alpha to **Public Alpha candidate / pre-deployment validation** until SPIKE-004 is resolved.
- Updated README, requirements, testing, architecture, roadmap, deployment guidance, validation history, and documentation indexes accordingly.

### Versioning

- Bumped repository and PZ metadata to `0.0.8` because the diagnostic code surface materially changed after the exact v0.0.7 build had already been validated.
- The proportional controller and clock-synchronization algorithms remain behaviorally unchanged from v0.0.7.

## [0.0.7] - 2026-08-17

Cleanup/verification build following the successful v0.0.6 client synchronization experiment.

### Fixed

- Fixed the repeated client post-apply Kahlua/Java bridge exception caused by passing the two-return-value `safeMethod()` expression directly into `tonumber()`.
- Fixed the equivalent unsafe conversion pattern in client disconnect restoration.
- Added a one-observer-pass server synchronization settling guard so a newly observed partial/full/baseline population state is broadcast after the authoritative controller has applied its matching `MinutesPerDay`.

### Clean regression result

The v0.0.7 two-player regression on Project Zomboid 42.20.3 confirmed:

- no recurrence of the v0.0.6 `Double` -> `String` `ClassCastException` error flood;
- baseline server/client `MinutesPerDay=90`;
- one-of-two partial sleep server/client `MinutesPerDay=4.5`;
- client clock progression at approximately 5.33 game-minutes per real second;
- smooth sleeping black-screen clock;
- smooth awake HUD/watch clock;
- normal-speed awake gameplay;
- correct native baseline restoration before vanilla full-sleep fast-forward;
- correct wake/disconnect denominator recalculation;
- no stale `mode=partial` + baseline-90 transition packet;
- vanilla sleep/wake behavior remained sensible, including a pill-influenced sleep waking near `ForceWakeUpTime`.

Issues #1, #2, and #3 were closed after this regression.

## [0.0.6] - 2026-08-15

First explicit server-to-client day-length synchronization experiment.

Added `ClockStateSync_Server.lua`, `ClockStateSync_Client.lua`, a two-second convergence heartbeat, and sleep telemetry. Two-player testing on PZ 42.20.3 showed both tested clients adopting the server's compressed `MinutesPerDay=4.5`; both visible clocks became smooth and awake gameplay remained normal-speed.

The run also showed client `AsleepTime` tracking compressed world time and waking near vanilla `ForceWakeUpTime`, explaining the earlier long-sleep symptom.

The actual client setter worked, but post-apply verification generated repeated exceptions due to a Kahlua multi-return `tonumber(safeMethod(...))` bug. Fixed in v0.0.7.

## [0.0.5] - 2026-08-14

Read-only client/server clock diagnosis established that, during one-of-two partial sleep, the server used `MinutesPerDay=4.5` while the client remained at `90`. The client advanced at native day length between multiplayer corrections, causing recurring visible jumps of roughly 51 in-game minutes.

## [0.0.4] - 2026-08-14

Deployment/naming cleanup and first successful two-player proportional-sleep validation.

Validated:

```text
2 living / 0 sleeping -> MinutesPerDay=90
2 living / 1 sleeping -> factor 20 -> MinutesPerDay=4.5
2 living / 2 sleeping -> restore 90 -> vanilla owns full sleep
```

Wake restoration and disconnect denominator recalculation also passed.

## [0.0.3] - 2026-08-13

First functional proportional-sleep controller.

Added the proportional `SleepFraction` model, runtime baseline capture/restoration, native `FastForwardMultiplier` inheritance, `PartialSleepSpeedScale`, instantiated non-dead player population semantics, per-tick observation with deduplicated writes, and fail-safe restoration toward native baseline.

Partial sleep changes `MinutesPerDay` only; it does not call `GameTime:setMultiplier()`.

## [0.0.2b] - 2026-08-13

Expanded vanilla full-sleep and connection-state probe. Established that loading clients may exist before an `IsoPlayer` appears and that vanilla full sleep leaves `MinutesPerDay` unchanged while using another multiplier path.

## [0.0.2] - 2026-08-13

Player lifecycle/sleep-state diagnostic. Established reliable server-side `isAsleep()`, dead-player persistence during respawn, and the need to exclude dead characters from the proportional denominator.

## [0.0.1] - 2026-08-13

Initial `MinutesPerDay` proof of concept. Baseline `90` was temporarily changed to `4.5`, producing approximately 20x world/calendar progression while `TrueMultiplier` remained `1` and active gameplay did not visibly globally accelerate.

This established the project's central premise: **compress world/calendar time during partial sleep rather than globally fast-forward the simulation**.

---

For detailed chronology and evidence, see [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md). For current test/decision work, see [`docs/spikes/`](docs/spikes/) and [`docs/ROADMAP.md`](docs/ROADMAP.md).
