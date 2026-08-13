# Changelog

All notable changes to Enshrouded Sleep are documented here. Git remains the authoritative source for exact diffs; this file summarizes the behavioral, architectural, diagnostic, and documentation changes that matter to users and maintainers.

## [Unreleased]

### Planned

- Dedicated-server validation of the first functional proportional calendar-compression implementation.
- Two-player testing at multiple sleeping fractions.
- Validation that awake movement, combat, zombies, vehicles, animations, inventory actions, timed actions, and crafting remain at normal active-game simulation speed during partial sleep.
- Validation of the transition from partial compression to vanilla full-sleep fast-forward when the final living player falls asleep.
- System-by-system investigation of world-time-driven mechanics such as crops, food spoilage, generator fuel, hunger/thirst/fatigue, healing, corpse decay, composting, and weather.
- Possible future per-system compensation using `RealTimeCompensationFactor = 1 / CalendarCompressionFactor` where real-time behavior is preferred over compressed world time.

## [0.0.3] - 2026-08-13

First functional proportional-sleep prototype.

### Added

- Implemented proportional calendar/world-time compression for partial sleep.
- Added the core model based on `SleepFraction`, native `FastForwardMultiplier`, `PartialSleepSpeedScale`, `CalendarCompressionFactor`, and `EffectiveMinutesPerDay`.
- Added `RealTimeCompensationFactor = 1 / CalendarCompressionFactor` as a documented future-use value for systems that may eventually need to remain tied to real/simulation time.
- Added `PartialSleepSpeedScale`, default `1.0`, as the only new gameplay tuning option.
- Added startup logging of native and computed timing configuration.
- Added state-transition logging for baseline, partial compression, vanilla handoff, disabled state, and recoverable error conditions.
- Added a root `VERSION` marker.
- Added extensive professional inline documentation throughout the Lua controller, including function contracts, invariants, control-flow rationale, loop comments, and failure-mode documentation.

### Changed

- Reframed the mechanic from generic "time acceleration" to **calendar/world-time compression**.
- Replaced the v0.0.2b diagnostic probe with the first functional server-authoritative controller.
- Simplified the MVP to follow vanilla Project Zomboid lifecycle semantics instead of maintaining a separate READY/NOT READY state machine.
- Removed pre-spawn/loading-player readiness tracking, the proposed client/server readiness handshake, and custom death/respawn gating from the MVP.
- Defined the proportional population as currently instantiated `IsoPlayer` objects from `getOnlinePlayers()` where `isDead() == false`.
- Defined sleeping players as living instantiated players where `isAsleep() == true`.
- At 100% living players asleep, the mod restores the exact captured native `MinutesPerDay` and hands control to vanilla full-sleep fast-forward.
- Removed the diagnostic-only `HeartbeatSeconds` sandbox option.
- Updated sandbox labels/tooltips, root metadata, Build 42 metadata, README, and requirements for the functional prototype.

### Design and compatibility notes

- Native Project Zomboid settings remain authoritative: live `MinutesPerDay`, `SleepAllowed`, `SleepNeeded`, and `FastForwardMultiplier`.
- The mod deliberately does not call `GameTime:setMultiplier()` for partial sleep.
- The theoretical full-sleep compressed day length is not applied because vanilla independently engages full-sleep fast-forward.
- `BaselineMinutesPerDay` is captured once and retained as the exact restoration target.
- Review of TrueSleep reinforced the same vanilla-extension player-population model.
- Review of Sleep With Friends reinforced the distinction between world time and sleep-recovery/stat progression.
- Because runtime `MinutesPerDay` changes, game-minute-driven callbacks and `WorldAgeHours`-driven systems may progress faster in real time during compression even though active simulation is not globally fast-forwarded.

### Known limitations

- v0.0.3 has not yet completed dedicated-server functional validation.
- At 100% asleep, vanilla owns full-sleep fast-forward rather than the mod continuing its own proportional formula.
- Loading clients do not affect the denominator until an `IsoPlayer` exists.
- Dead players are excluded from the living-player denominator and vanilla death/respawn semantics are accepted.
- No per-system compensation exists yet for world-time-driven systems.

### Included commits

- `eac821c` - Document v0.0.3 Lua controller for maintainability.
- `2e93e56` - Update root mod metadata for v0.0.3.
- `75ca853` - Update v0.0.3 Build 42 metadata.
- `7bd4bdc` - Add version marker.
- `ba5ae91` - Update README for v0.0.3 calendar compression prototype.
- `d0fb825` - Revise MVP requirements for calendar compression v0.0.3.
- `1db2d93` - Update sandbox labels for v0.0.3.
- `4fc7f66` - Add partial sleep speed scale option for v0.0.3.
- `173fba4` - Implement proportional calendar compression v0.0.3.
- `887850f` - Align README with vanilla-extension MVP design.
- `28fbc76` - Simplify MVP requirements to vanilla sleep semantics.
- `3bb9736` - Rewrite README with current MVP requirements.
- `0797042` - Document updated MVP requirements.
