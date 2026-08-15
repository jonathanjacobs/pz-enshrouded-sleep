# Changelog

Human-readable history of notable Enshrouded Sleep changes. Git remains authoritative for exact diffs; this file summarizes behavior, architecture, diagnostics, and documentation by development version.

## [Unreleased]

### Planned
- Run the v0.0.5 client/server clock-synchronization diagnostic with two living players and one sleeper.
- Determine whether clients receive the dynamic `MinutesPerDay` change during partial sleep.
- Determine whether clock snapping originates in replicated GameTime state, multiplayer clock synchronization/interpolation, or UI rendering.
- Resolve GitHub issues #1 and #2 so both sleeping and awake clocks advance smoothly during partial-sleep compression.
- Verify normal awake movement/combat/zombie/vehicle/animation/timed-action speed during compression.
- Investigate world-time-driven systems such as crops, food spoilage, generators, hunger/thirst/fatigue, healing, corpse decay, composting, and weather.
- Evaluate future per-system compensation using `1 / CalendarCompressionFactor` where real-time behavior is preferred.

## [0.0.5] - 2026-08-14

Read-only clock-synchronization diagnostic build following the first successful two-player proportional-sleep test.

### Added
- Client-side clock diagnostic at `42/media/lua/client/EnshroudedSleep/ClockSyncDiagnostic_Client.lua`.
- Server-side clock diagnostic at `42/media/lua/server/EnshroudedSleep/ClockSyncDiagnostic_Server.lua`.
- One-real-second samples of `MinutesPerDay`, `TimeOfDay`, `WorldAgeHours`, `DeltaMinutesPerDay`, `Multiplier`, `TrueMultiplier`, and `ServerMultiplier`.
- Client sampling of public GameTime fields `ServerTimeOfDay`, `ServerLastTimeOfDay`, and raw `TimeOfDay` where exposed through Kahlua.
- Server samples correlated with living/sleeping population and a diagnostic baseline/partial/full-sleep state label.

### Diagnostic safety
- The v0.0.5 instrumentation is observational only.
- It does not call `setMinutesPerDay()`, `setTimeOfDay()`, `setMultiplier()`, `GameServer.syncClock()`, or any sleep/player-state mutation API.
- The proportional server controller remains behaviorally unchanged from v0.0.4 while the client synchronization path is investigated.

### Purpose
The v0.0.4 multiplayer test showed correct server-side `MinutesPerDay=4.5` partial compression but visible jumps in both the sleeping black-screen clock and the awake player's HUD/watch. v0.0.5 is designed to distinguish among three possible causes:

1. the dynamic server `MinutesPerDay` value is not replicated to clients;
2. the underlying client world clock is synchronized in coarse corrections;
3. client world time is correct but the clock UI itself updates/interpolates poorly at high calendar-compression factors.

### Known issues
- #1: sleeping black-screen clock jumps during partial-sleep compression.
- #2: awake player's HUD/watch clock snaps forward during partial-sleep compression.

## [0.0.4] - 2026-08-14

Deployment and naming cleanup following the first multiplayer deployment attempts. The proportional sleep algorithm is unchanged from v0.0.3.

### Changed
- Standardized the stable Project Zomboid Mod ID from the prototype name `EnshroudedSleepClockSpike` to `pz-enshrouded-sleep`.
- Standardized the sandbox namespace from `EnshroudedSleepClockSpike` to `EnshroudedSleep`.
- Renamed the server controller from `ClockSpike_Server.lua` to `EnshroudedSleep_Server.lua`.
- Bumped root and Build 42 metadata to v0.0.4.
- Updated README installation guidance so local folder name, Mod ID, and server `Mods=` configuration are clearly distinguished.
- Clarified that GitHub's `-main` suffix is a source-archive branch suffix and is not part of the stable Project Zomboid Mod ID.

### Multiplayer validation
The first successful two-player v0.0.4 test validated the core server-side architecture on the test server:

```text
2 living / 0 sleeping
-> mode=baseline
-> MinutesPerDay=90.000

2 living / 1 sleeping
-> mode=partial
-> SleepFraction=0.5000
-> CalendarCompressionFactor=20.000
-> EffectiveMinutesPerDay=4.500
-> RealTimeCompensationFactor=0.05000

2 living / 2 sleeping
-> mode=vanilla-full-sleep
-> restore MinutesPerDay=90.000
-> vanilla full-sleep fast-forward owns the state
```

The test also observed correct return to partial sleep when one player woke, correct denominator recalculation when a player disconnected, and exact restoration to the 90-minute baseline when compression ended.

No Enshrouded Sleep controller exception or fail-safe event was observed during these transitions.

### Client-display defect discovered
Although server-side proportional behavior passed, both clients showed visibly discontinuous clock presentation during partial compression:

- the sleeping player's black-screen clock appeared to hold and then jump forward;
- the awake player's upper-right HUD/watch time also advanced in visible leaps rather than smooth rapid progression.

At `MinutesPerDay=4.5`, world time advances about 5.33 in-game minutes per real second. Rapid display progression is therefore expected; long holds followed by large corrections are not. These observations are tracked as GitHub issues #1 and #2.

### Migration notes
- Recommended local folder: `pz-enshrouded-sleep/`.
- Server Mod ID: `pz-enshrouded-sleep`.
- Sandbox configuration block is now:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
},
```

- Remove old `EnshroudedSleepClockSpike` entries from the test-server `Mods=` and SandboxVars configuration before testing v0.0.4 or later.

### Included commits
- `85ec2bc` Align requirements with v0.0.4 deployment identity.
- `d1e0df9` Document v0.0.4 naming and deployment migration.
- `82cec2b` Document standardized v0.0.4 deployment identity.
- `036cd5b` Remove legacy ClockSpike server filename.
- `33b459d` Rename and migrate server controller for v0.0.4.
- `a98575d` Align sandbox translation keys for v0.0.4.
- `d6a4252` Standardize sandbox namespace for v0.0.4.
- `6f16d2b` Bump version to 0.0.4.
- `1a4baab` Standardize Build 42 mod ID for v0.0.4.
- `d1b1bde` Standardize mod ID and metadata for v0.0.4.

## [0.0.3] - 2026-08-13

First functional proportional-sleep prototype.

### Added
- Proportional calendar/world-time compression for partial sleep.
- Core model using `SleepFraction`, native `FastForwardMultiplier`, `PartialSleepSpeedScale`, `CalendarCompressionFactor`, and `EffectiveMinutesPerDay`.
- `RealTimeCompensationFactor = 1 / CalendarCompressionFactor` documented for possible future compensation work.
- `PartialSleepSpeedScale` sandbox option, default `1.0`.
- Startup configuration logging and state-transition logging.
- Root `VERSION` marker.
- Extensive inline Lua documentation: design invariants, function contracts, loop/control-flow comments, and failure-mode rationale.

### Changed
- Reframed the mechanic from generic "acceleration" to **calendar/world-time compression**.
- Replaced the v0.0.2b diagnostic probe with a functional server-authoritative controller.
- Simplified the MVP to follow vanilla lifecycle semantics instead of maintaining READY/NOT READY state.
- Removed pre-spawn readiness tracking, the proposed client/server readiness handshake, and custom respawn gating from the MVP.
- Population now means instantiated `IsoPlayer` objects from `getOnlinePlayers()` where `isDead() == false`.
- Sleeping players are living instantiated players where `isAsleep() == true`.
- At 100% living players asleep, restore the exact baseline `MinutesPerDay` and let vanilla own full-sleep fast-forward.
- Removed diagnostic-only `HeartbeatSeconds`.
- Updated sandbox UI text, metadata, README, and requirements.

### Design notes
- Native `MinutesPerDay`, `SleepAllowed`, `SleepNeeded`, and `FastForwardMultiplier` remain authoritative.
- Partial sleep never calls `GameTime:setMultiplier()`.
- Full-sleep theoretical compression is not applied because vanilla independently engages fast-forward.
- Baseline `MinutesPerDay` is captured once and retained as the exact restoration target.
- Review of TrueSleep reinforced the same vanilla-extension population model.
- Review of Sleep With Friends reinforced the distinction between world time and sleep-recovery/stat progression.
- Game-minute/`WorldAgeHours`-driven systems may progress faster in real time while compression is active even though active simulation is not globally fast-forwarded.

### Included commits
- `eac821c` Document v0.0.3 Lua controller for maintainability.
- `2e93e56` Update root mod metadata for v0.0.3.
- `75ca853` Update v0.0.3 metadata.
- `7bd4bdc` Add version marker.
- `ba5ae91` Update README for v0.0.3 calendar compression prototype.
- `d0fb825` Revise MVP requirements for calendar compression v0.0.3.
- `1db2d93` Update sandbox labels for v0.0.3.
- `4fc7f66` Add partial sleep speed scale option for v0.0.3.
- `173fba4` Implement proportional calendar compression v0.0.3.
- `887850f` Align README with vanilla-extension MVP design.
- `28fbc76` Simplify MVP requirements to vanilla sleep semantics.
- `3bb9736` Rewrite README with current MVP requirements.
- `0797042` Document updated MVP requirements.

## [0.0.2b] - 2026-08-13

Expanded diagnostic for vanilla multiplayer sleep and connection behavior.

### Added / learned
- Added attempted connection-state telemetry before an `IsoPlayer` exists.
- Added telemetry for `MinutesPerDay`, multipliers, `TrueMultiplier`, `WorldAgeHours`, configured fast-forward, and player-state counts.
- Confirmed direct `GameServer.udpEngine.connections` was not exposed to dedicated-server Lua despite existing in Java API.
- Confirmed clients may remain authenticated/loading for tens of seconds before appearing in `getOnlinePlayers()`.
- Observed vanilla full-sleep with `MinutesPerDay` unchanged, `GameTime:getMultiplier()` rising from roughly `4.8` to roughly `575`, and `TrueMultiplier` remaining `1`.
- Observed an effective calendar rate near 120x on the test server even though configured `FastForwardMultiplier` was `40.0`; no hard-coded relationship was adopted.

### Included commits
- `1ef38a1` Update sandbox labels for v0.0.2b probe.
- `8da00ef` Document v0.0.2b solo diagnostic.
- `2a5502f` Update root metadata for v0.0.2b probe.
- `e22b0fd` Bump diagnostic metadata to v0.0.2b.
- `65ef17f` Add v0.0.2b connection and vanilla sleep telemetry.

## [0.0.2] - 2026-08-13

Player lifecycle/state diagnostic replacing the clock-spike test.

### Added / learned
- Replaced active clock manipulation with pure `getOnlinePlayers()` instrumentation.
- Logged player object identity, username/display name, online ID, sleep state, death state, access level, god mode, position, add/remove, state changes, and counts.
- Confirmed server-side `isAsleep()` reliably reflects sleep/wake state when native sleep is enabled.
- Confirmed dead character objects can remain in `getOnlinePlayers()` during recreation and replacement characters use a new object identity.
- Confirmed dead characters should not count in the living-player denominator.
- Traced earlier sleep/fatigue problems to native `SleepAllowed=false` and `SleepNeeded=false`, not admin status.

### Included commits
- `815ba2b` Document v0.0.2 player lifecycle test.
- `31cf046` Update translations for v0.0.2 probe.
- `0919837` Update sandbox options for v0.0.2 probe.
- `7a7eae4` Update root metadata for v0.0.2.
- `b7d951f` Bump diagnostic mod to v0.0.2.
- `b21b38a` Replace clock spike with v0.0.2 player-state probe.

## [0.0.1] - 2026-08-13

Initial Build 42 proof of concept for the `MinutesPerDay` technique.

### Added / learned
- Added the dedicated-server clock-spike diagnostic, mod metadata, sandbox options, translations, and initial README.
- Added required B42 `AnimSets` and `actiongroups` directory placeholders under `common/media` and `42/media` to avoid media-scanner errors.
- Captured live baseline `MinutesPerDay`, temporarily set it to `baseline / 20`, then restored the exact baseline without using `GameTime:setMultiplier()`.
- On the test server, baseline was `90`; test value `4.5` produced approximately 20x calendar/world-age progression while `TrueMultiplier` stayed `1` and active gameplay did not visibly speed up.
- Established the core project premise: world/calendar time can be compressed through `MinutesPerDay` without globally accelerating active gameplay simulation.

### Included commits
- `cdd64b1`, `433030d`, `535dcf9`, `e2a5c14` Add required B42 media directories.
- `cdf8ad2` Add v0.0.1 clock spike server diagnostic.
- `8075ba0` Add sandbox translations.
- `78e1d29` Add diagnostic sandbox options.
- `9e5a2a3` Add B42 mod metadata.
- `7ee0cdd` Add root mod metadata.
- `f7f66ad` Add v0.0.1 diagnostic clock spike README.

## Repository initialization - 2026-08-13

- `8cd4542` Create basic CI workflow with GitHub Actions.
- `79cd9c2` Initial commit.

---

For exact source-level history, consult the Git commit history. This changelog is intentionally grouped by meaningful development version rather than one section per commit.
