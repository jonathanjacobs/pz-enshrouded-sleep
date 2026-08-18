# Changelog

Human-readable history of notable Enshrouded Sleep changes. Git remains authoritative for exact diffs. Detailed experimental evidence lives in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md).

## [Unreleased / Public Alpha hardening] - 2026-08-17

### Status

- Promoted the project from controlled test-server development into **Public Alpha** field testing.
- Project Zomboid `42.20.3` remains the current behaviorally validated platform baseline.
- Issues #1, #2, and #3 are closed after the successful v0.0.7 regression.

### Changed

- Redesigned the top-level README for players/server operators rather than development-history readers.
- Added a dedicated Public Alpha deployment/rollback guide.
- Added a roadmap with Public Alpha, Public Beta, and v1.0 exit criteria.
- Added a standalone architecture overview.
- Consolidated v0.0.1–v0.0.7 experimental evidence into `docs/VALIDATION_HISTORY.md`.
- Refactored `docs/REQUIREMENTS.md` into a current normative MVP specification and acceptance matrix.
- Refactored `docs/TESTING.md` around current smoke/regression/public-alpha testing instead of historical procedures.
- Added documentation conventions under `docs/spikes/` and `docs/adr/`.

### Public-server hardening

- Added sandbox option:

```text
DiagnosticsEnabled = false
```

- One-second `[EnshroudedSleepDiag]` server/client telemetry is now opt-in rather than always active.
- Low-volume controller and synchronization state-transition logging remains enabled.
- This change does **not** alter the proportional compression formula, client synchronization behavior, population semantics, or vanilla full-sleep handoff.

### Public Alpha focus

Field testing now targets:

- 3–12+ player populations;
- multiple partial-sleep fractions;
- joins/disconnects/deaths/respawns during sleep states;
- long-session stability;
- real mod-stack interactions;
- world-time-driven systems such as spoilage, farming, generators, hunger/thirst/fatigue, healing, weather, corpses, and composting.

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
- vanilla sleep wake behavior remained sensible, including a pill-influenced sleep waking near `ForceWakeUpTime`.

### Issue resolution

- #1 sleeping black-screen clock jumps — closed/completed.
- #2 awake HUD/watch clock snaps forward — closed/completed.
- #3 pathological long world-time sleep — closed/completed; root cause was the same client/server `MinutesPerDay` pacing mismatch.

## [0.0.6] - 2026-08-15

First explicit server-to-client day-length synchronization experiment.

### Added

- `ClockStateSync_Server.lua` to broadcast authoritative runtime `MinutesPerDay`.
- `ClockStateSync_Client.lua` to mirror the server's day-length pacing value locally.
- Two-second heartbeat so late-loading clients converge after missed transition packets.
- Client/server sleep telemetry for `AsleepTime`, `ForceWakeUpTime`, fatigue, and sleeping-pill count.

### Established

Two-player testing on PZ 42.20.3 showed that client synchronization fixed the underlying clock drift:

```text
SERVER MinutesPerDay = 4.5
CLIENT A MinutesPerDay = 4.5
CLIENT B MinutesPerDay = 4.5
```

Both visible clocks became smooth and awake gameplay remained normal-speed.

The same run showed client `AsleepTime` tracking compressed world time and waking near vanilla `ForceWakeUpTime`, explaining the earlier long-sleep symptom.

### Known defect

The actual client `setMinutesPerDay()` succeeded, but post-apply verification generated repeated exceptions due to the `tonumber(safeMethod(...))` multi-return bridge bug. Fixed in v0.0.7.

## [0.0.5] - 2026-08-14

Read-only client/server clock diagnosis.

### Established

During one-of-two partial sleep:

```text
SERVER MinutesPerDay = 4.5
CLIENT MinutesPerDay = 90
```

The client advanced at native day length between normal multiplayer corrections, producing recurring visible jumps of roughly 51 in-game minutes. This established that server runtime `MinutesPerDay` changes were not automatically mirrored to client GameTime.

The same test exposed the long-sleep symptom later explained by the same client pacing mismatch.

## [0.0.4] - 2026-08-14

Deployment/naming cleanup and first successful two-player proportional-sleep validation.

### Changed

- Standardized Mod ID to `pz-enshrouded-sleep`.
- Standardized sandbox namespace to `EnshroudedSleep`.
- Standardized server controller filename to `EnshroudedSleep_Server.lua`.

### Validated

```text
2 living / 0 sleeping -> MinutesPerDay=90
2 living / 1 sleeping -> factor 20 -> MinutesPerDay=4.5
2 living / 2 sleeping -> restore 90 -> vanilla owns full sleep
```

Wake restoration and disconnect denominator recalculation also passed.

## [0.0.3] - 2026-08-13

First functional proportional-sleep controller.

### Added

- Proportional `SleepFraction` model.
- Runtime baseline capture/restoration.
- Native `FastForwardMultiplier` inheritance.
- `PartialSleepSpeedScale` option.
- Living/sleeping population based on instantiated non-dead `IsoPlayer` objects.
- Per-tick observation with deduplicated `MinutesPerDay` writes.
- Fail-safe restoration toward native baseline.

### Architecture

Partial sleep changes `MinutesPerDay` only. It does not call `GameTime:setMultiplier()`.

At 100% living players asleep, the mod restores native `MinutesPerDay` and lets vanilla full-sleep fast-forward take over.

## [0.0.2b] - 2026-08-13

Expanded vanilla full-sleep and connection-state probe.

### Established

- loading clients may exist before an `IsoPlayer` appears;
- vanilla full sleep leaves `MinutesPerDay` unchanged;
- vanilla full sleep instead drove `GameTime:getMultiplier()` to roughly 575 on the test configuration;
- no hard-coded relationship between configured `FastForwardMultiplier` and effective vanilla all-sleep rate was adopted.

## [0.0.2] - 2026-08-13

Player lifecycle/sleep-state diagnostic.

### Established

- server-side `isAsleep()` reliably reflects sleep/wake state;
- dead player objects may remain in `getOnlinePlayers()` during respawn;
- dead players must be excluded from the proportional denominator;
- earlier inability to sleep was traced to native server sleep settings, not admin status.

## [0.0.1] - 2026-08-13

Initial `MinutesPerDay` proof of concept.

### Established

- baseline `MinutesPerDay=90` could be temporarily changed to `4.5`;
- this produced approximately 20x world/calendar progression;
- `TrueMultiplier` remained `1`;
- active gameplay did not visibly globally accelerate;
- the exact baseline could be restored.

This established the project's central premise: **compress world/calendar time during partial sleep rather than globally fast-forward the simulation**.

## Repository initialization - 2026-08-13

- Added basic repository structure, CI placeholder, license, and Build 42 media-scanner directory placeholders.

---

For detailed test evidence, chronology, and rationale, see [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md). For current release goals, see [`docs/ROADMAP.md`](docs/ROADMAP.md).
