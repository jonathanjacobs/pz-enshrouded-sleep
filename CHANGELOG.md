# Changelog

Human-readable history of notable Enshrouded Sleep changes. Git remains authoritative for exact diffs. Detailed experimental evidence lives in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md); focused investigations and decisions live under [`docs/spikes/`](docs/spikes/) and [`docs/adr/`](docs/adr/).

## [Unreleased]

### Next decision

- Run the focused v0.0.10 baseline/partial/restored-baseline CharacterStat/Moodle test for SPIKE-004.
- Classify hunger, thirst, fatigue, endurance and other practical high-severity survival values.
- Record a **GO / CONDITIONAL GO / NO-GO** decision for WHG Public Alpha deployment.

## [0.0.10] - 2026-08-19

Focused SPIKE-004 diagnostic correction after analysis of the successful v0.0.9 two-player run.

### v0.0.9 evidence incorporated

The two-player controlled run established that partial `MinutesPerDay` compression does not affect all player systems equally.

Awake bleeding/injury behavior remained approximately real-time bound during ~5x calendar compression:

- overall health loss from active bleeding: baseline ~`-0.07869/s`, partial ~`-0.07810/s`, ratio ~`0.993x`;
- `BleedingTime` progression remained ~`1x`;
- `ScratchTime` progression remained ~`1x`;
- no rapid awake-player bleed-out proportional to calendar compression was observed.

Nutrition was strongly world/calendar-time bound:

- Calories: ~`5.01x` at 5x compression and ~`10.00x` at 10x;
- Carbohydrates: ~`5.00x / 10.00x`;
- Proteins: ~`5.00x / 10.01x`;
- Lipids: ~`5.00x / 10.00x`.

The run also preserved correct server/client `MinutesPerDay` convergence and `TrueMultiplier=1.0` during partial compression.

### Root cause of remaining v0.0.9 N/A fields

Current Build 42.20.3 vanilla Lua uses registered `CharacterStat` objects rather than legacy named Stats getters/fields for core survival state:

```lua
player:getStats():get(CharacterStat.HUNGER)
```

Current Build 42.20.3 Moodles are keyed by `MoodleType` objects:

```lua
player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
```

The v0.0.9 numeric Moodle enumeration assumption did not match the current `Moodles` class. This explains the persistent `N/A` Moodle stream.

### Added — shared survival-state probe

Added:

```text
42/media/lua/shared/EnshroudedSleep/SurvivalStatProbe.lua
```

The probe uses guarded Build 42 access for registered CharacterStats, explicit MoodleTypes, direct Nutrition getters, and selected BodyDamage context. It includes one-time capability reporting so future unavailable fields can be localized to class/global resolution, enum resolution, object access, or method invocation.

### Added — focused server/client survival diagnostics

Added:

```text
42/media/lua/server/EnshroudedSleep/SurvivalStatDiagnostic_Server.lua
42/media/lua/client/EnshroudedSleep/SurvivalStatDiagnostic_Client.lua
```

New diagnostic prefixes:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Each side emits a one-time `CAPABILITIES` record and one-second `SURVIVAL` samples only while `DiagnosticsEnabled=true`.

### Scope

- No proportional-sleep formula change.
- No health/survival compensation.
- No sleep eligibility/wake-policy change.
- No global multiplier change.
- Existing broad injury/body diagnostics remain available.
- New instrumentation is read-only.

### Documentation

- Updated SPIKE-004 with the v0.0.9 classification results and focused v0.0.10 test.
- Updated issue #4 with completed and remaining work.
- Updated requirements and testing guidance for `CharacterStat`/`MoodleType` APIs.
- Made `docs/ROADMAP.md` the single canonical roadmap; removed the duplicate roadmap section from the top-level README.
- Updated repository and Build 42 metadata to `0.0.10`.

## [0.0.9] - 2026-08-19

Follow-up SPIKE-004 diagnostic build after the first successful solo health/injury telemetry run.

Added guarded raw-stat/public-field probes, attempted Moodle telemetry, and direct `DeltaMinutesPerDay`/multiplier context. The build remained observational only. Runtime testing later showed that the legacy raw-stat access and numeric Moodle-enumeration assumptions did not match current Build 42.20.3 APIs; this is corrected in v0.0.10.

The v0.0.9 controlled two-player run nevertheless produced decisive bleeding and nutrition evidence now recorded under the v0.0.10 entry and SPIKE-004.

## [0.0.8] - 2026-08-17

Added broad read-only server/client health/time-domain diagnostics for SPIKE-004, including general health, detailed injured-body-part state/timers, nutrition, sleep context, and guarded health probes. A solo vanilla-full-sleep reference showed extremely rapid bleeding death and accelerated healing/recovery while vanilla all-asleep fast-forward owned the state. This demonstrated the need for a separate awake-player partial-compression test.

Also added formal SPIKE-004 and retroactively documented SPIKE-001 through SPIKE-003 plus ADR-001 through ADR-003.

## [0.0.7] - 2026-08-17

Fixed the v0.0.6 Kahlua multi-return `tonumber()` diagnostic exception and added a one-observer-pass synchronization settling guard.

Clean two-player regression on PZ 42.20.3 confirmed:

- server/client `90 <-> 4.5` transitions;
- smooth sleeping and awake clocks;
- normal-speed awake gameplay;
- correct baseline/full-sleep handoff;
- correct wake/disconnect recalculation;
- no stale partial-state packet paired with baseline 90;
- sensible vanilla sleep/wake behavior.

Issues #1, #2, and #3 were closed after this regression.

## [0.0.6] - 2026-08-15

Added explicit server-to-client day-length synchronization and a low-frequency convergence heartbeat. Two-player testing showed both clients adopting the server's compressed `MinutesPerDay=4.5`, eliminating the visible clock sawtooth. A diagnostic-only Kahlua conversion error remained and was fixed in v0.0.7.

## [0.0.5] - 2026-08-14

Read-only client/server diagnosis established that the server used `MinutesPerDay=4.5` during partial sleep while clients remained at `90`, explaining recurring visible clock corrections.

## [0.0.4] - 2026-08-14

First successful two-player proportional-sleep validation:

```text
2 living / 0 sleeping -> MinutesPerDay=90
2 living / 1 sleeping -> factor 20 -> MinutesPerDay=4.5
2 living / 2 sleeping -> restore 90 -> vanilla owns full sleep
```

Wake restoration and disconnect denominator recalculation also passed.

## [0.0.3] - 2026-08-13

First functional proportional-sleep controller. Added `SleepFraction`, runtime baseline capture/restoration, native `FastForwardMultiplier` inheritance, `PartialSleepSpeedScale`, living-player population semantics, deduplicated writes, and fail-safe restoration. Partial sleep changes `MinutesPerDay` only; it does not call `GameTime:setMultiplier()`.

## [0.0.2b] - 2026-08-13

Expanded vanilla full-sleep and connection-state probe. Established that loading clients may exist before an `IsoPlayer` appears and that vanilla full sleep leaves `MinutesPerDay` unchanged while using a separate multiplier path.

## [0.0.2] - 2026-08-13

Player lifecycle/sleep-state diagnostic. Established reliable server-side `isAsleep()`, dead-player persistence during respawn, and the need to exclude dead characters from the proportional denominator.

## [0.0.1] - 2026-08-13

Initial `MinutesPerDay` proof of concept. Changing baseline `90` to `4.5` produced approximately 20x world/calendar progression while `TrueMultiplier` remained `1` and active gameplay did not visibly globally accelerate.

This established the project's central premise: **compress world/calendar time during partial sleep rather than globally fast-forward the simulation**.

---

For detailed chronology and evidence, see [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md). For current test/decision work, see [`docs/spikes/`](docs/spikes/) and [`docs/ROADMAP.md`](docs/ROADMAP.md).
