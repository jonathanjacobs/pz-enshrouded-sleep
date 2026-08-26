# Changelog

Human-readable history of notable Enshrouded Sleep release changes. Git remains authoritative for exact diffs.

This file records **what changed between releases**. Detailed test evidence belongs in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) and [`docs/spikes/`](docs/spikes/); current/future work belongs in [`docs/ROADMAP.md`](docs/ROADMAP.md); durable design rationale belongs in [`docs/adr/`](docs/adr/).

## [Unreleased]

### Added

- Added opt-in, administrator-controlled `SleepNotificationsEnabled` server setting, disabled by default.
- When enabled, effective multiplayer sleep-state changes broadcast concise server-chat notifications with the living/sleeping count, percentage, and settled calendar acceleration, for example: `[Enshrouded Sleep] 1/2 living players sleeping (50%). Time is 20x faster.`
- All-awake and all-asleep transitions use short special messages; vanilla full-sleep handoff does not claim an Enshrouded Sleep multiplier.

### Changed

- Recorded a Project Zomboid 42.20.4 (`b0bbce05d5`) compatibility checkpoint from dedicated-server and connected-client logs. Startup, native baseline capture, normal all-awake operation, and authoritative `ClockState` synchronization completed without a relevant Enshrouded Sleep Lua exception.
- Documented that Enshrouded Sleep does not use the `loadstring` or `loadstream` APIs removed by the 42.20.4 security hotfix; multiplayer synchronization and notifications use predefined named commands with structured arguments.
- Normalized current runtime/release documentation on Public Beta v0.1.0 terminology and added package-validation guards against reintroducing stale Public Alpha startup banners.
- Tightened sleep-notification wording to identify the living-player denominator directly.

### Safety

- Notification timing is derived from settled authoritative `MinutesPerDay` and cannot alter sleep/time or awake-player protection behavior.
- Client chat display is circuit-broken after a bridge failure so notification/UI problems cannot create repeated error spam or affect gameplay.
- Package validation rejects runtime Lua references to `loadstring` or `loadstream` so future changes cannot accidentally regress the 42.20.4 security-compatible command architecture.

### Validation boundary

- The 42.20.4 checkpoint establishes startup/baseline/client-sync compatibility, not a new claim that every optional feature or mod-stack interaction has completed full regression.
- The opt-in sleep-notification path remains unreleased until its dedicated multiplayer smoke test in `docs/TESTING.md` is completed.

## [0.1.0] - 2026-08-26

**Public Beta.** Promoted the SPIKE-006 awake-player survival normalizer from a controlled diagnostic prototype into normal multiplayer partial-sleep gameplay.

### Added

- Added `AwakePlayerProtectionEnabled`, enabled by default for Public Beta.
- Protects awake living players' Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, and Weight progression from the extra calendar-time acceleration created by partial-sleep `MinutesPerDay` compression.
- Added low-volume action/activity diagnostics to support targeted survival-state troubleshooting.
- Expanded administrator-facing sandbox labels/tooltips for proportional sleep, awake protection, verbose diagnostics, and the one-player forced-compression regression tool.

### Changed

- Awake-player protection is server-authoritative and directional: worsening/depleting protected deltas are normalized by the observed calendar-compression factor while favorable opposite-direction effects such as eating/drinking are retained in full; Weight is normalized in either direction.
- Sleeping and dead players are never corrected. All-living-asleep still restores native `MinutesPerDay` and hands full-sleep acceleration to vanilla.
- Read/write failures fail open for the affected player and clear that player's correction snapshot rather than applying delayed catch-up correction.
- Removed the SPIKE-only `DiagnosticAwakeProtectionPrototype` sandbox option from the production UI.
- Retained `DiagnosticForcedCompressionFactor` only as an isolated one-player support/regression tool.
- Fixed an action-diagnostic Java/Kahlua bridge probe that could repeatedly error; failed optional bridge capabilities are now circuit-broken.

### Operations

- `AwakePlayerProtectionEnabled=false` provides a protection-only soft rollback while leaving proportional sleep/calendar compression active.
- Deployment guidance now distinguishes that soft rollback from full mod removal/rollback.
- External world systems remain unmodified; v0.1.0 does not compensate spoilage, generators, farming/crops, vehicle resources, corpses, weather, or arbitrary modded world-time systems.

### Validation basis

Controlled SPIKE-006 testing established sufficient passive, active-effect, sleep-transition, wake-reinitialization, and restoration behavior to proceed to Public Beta field validation. Exact measurements and evidence are intentionally maintained in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) and [`docs/spikes/SPIKE-006-awake-player-protection.md`](docs/spikes/SPIKE-006-awake-player-protection.md), not duplicated here.

## [0.0.10] - 2026-08-19

**Public Alpha.** Completed the pre-deployment health/survival investigation, prepared the repository for direct Steam Workshop publication, and published the first Public Alpha Workshop build.

### Workshop/package preparation

- Consolidated the deployable runtime into the single authoritative tree at `Contents/mods/pz-enshrouded-sleep/` and removed duplicate root-level runtime copies.
- Added/updated Workshop descriptor, preview/artwork, Build 42 metadata references, package-validation checks, publication documentation, and distribution-hygiene guidance.
- Added explicit The Indie Stone and Keen Games non-affiliation/provenance language across public and legal documentation.
- Updated runtime headers/startup banners and documentation for Public Alpha without changing the core proportional-sleep policy.

### Diagnostics and safety work

- Updated survival-state observability to current Build 42 `CharacterStat`, `MoodleType`, and Nutrition APIs.
- Added a tightly gated one-connected-awake-player forced-compression regression path; removed an intermediate standalone/local-game fallback before release.
- Confirmed the diagnostic override restores baseline and suspends when its test player sleeps, preventing overlap with vanilla full-sleep acceleration.
- SPIKE-004 established the tested player-system time-domain split and returned **GO — Public Alpha**.

Exact capability counts, compression-rate measurements, time-domain classifications, and client synchronization observations are maintained in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) and [`docs/spikes/SPIKE-004-health-time-domains.md`](docs/spikes/SPIKE-004-health-time-domains.md).

## [0.0.9] - 2026-08-19

Follow-up SPIKE-004 diagnostic build. Two-player controlled testing established that awake bleeding/injury behavior and nutrition/survival needs do not share one time domain: acute health loss remained approximately real-time bound under tested partial compression while nutrition tracked accelerated world/calendar time. Server/client pacing remained coherent and `TrueMultiplier` remained `1.0`.

Detailed measurements are preserved in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) and [`docs/spikes/SPIKE-004-health-time-domains.md`](docs/spikes/SPIKE-004-health-time-domains.md).

## [0.0.8] - 2026-08-17

Added broad read-only server/client health/time-domain diagnostics for SPIKE-004, including general health, detailed injured-body-part state/timers, nutrition, sleep context, and guarded health probes. A one-player-on-server vanilla-full-sleep reference demonstrated that vanilla full-sleep acceleration must be analyzed separately from Enshrouded partial calendar compression.

Also formalized SPIKE-004 and retroactively documented SPIKE-001 through SPIKE-003 plus ADR-001 through ADR-003.

## [0.0.7] - 2026-08-17

Fixed the v0.0.6 Kahlua multi-return `tonumber()` diagnostic exception and added a synchronization-settling guard.

A clean two-player regression confirmed coherent server/client compressed day length, smooth sleeping/awake clocks, normal-speed awake gameplay, correct baseline/full-sleep handoff, wake/disconnect recalculation, and sensible vanilla sleep/wake behavior. Issues #1, #2, and #3 were closed after this regression.

## [0.0.6] - 2026-08-15

Added explicit server-to-client day-length synchronization and a low-frequency convergence heartbeat, eliminating the recurring visible client clock sawtooth. A diagnostic-only Kahlua conversion error remained and was fixed in v0.0.7.

## [0.0.5] - 2026-08-14

Read-only client/server diagnostics established that server `MinutesPerDay` changes were not automatically mirrored as stable client pacing, explaining recurring visible clock corrections.

## [0.0.4] - 2026-08-14

First successful two-player proportional-sleep validation: all-awake baseline, one-sleeper proportional compression, all-asleep baseline restoration/vanilla handoff, wake restoration, and disconnect denominator recalculation all worked.

## [0.0.3] - 2026-08-13

First functional proportional-sleep controller. Added sleep-fraction calculation, runtime baseline capture/restoration, native `FastForwardMultiplier` inheritance, `PartialSleepSpeedScale`, living-player population semantics, deduplicated writes, and fail-safe restoration. Partial sleep changes `MinutesPerDay` only; it does not call `GameTime:setMultiplier()`.

## [0.0.2b] - 2026-08-13

Expanded vanilla full-sleep and connection-state probing. Established that loading clients may exist before an `IsoPlayer` appears and that vanilla full sleep uses an acceleration path separate from `MinutesPerDay`.

## [0.0.2] - 2026-08-13

Added player lifecycle/sleep-state diagnostics. Established reliable server-side `isAsleep()`, dead-player persistence during respawn, and the need to exclude dead characters from the proportional denominator.

## [0.0.1] - 2026-08-13

Initial `MinutesPerDay` proof of concept established the project's central architecture: compress world/calendar time during partial sleep without globally fast-forwarding active simulation.

---

For evidence chronology, see [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md). For detailed investigations, see [`docs/spikes/`](docs/spikes/). For current/future work, see [`docs/ROADMAP.md`](docs/ROADMAP.md).
