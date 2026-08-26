# Changelog

Human-readable history of notable Enshrouded Sleep changes. Git remains authoritative for exact diffs. Detailed experimental evidence lives in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md); focused investigations and decisions live under [`docs/spikes/`](docs/spikes/) and [`docs/adr/`](docs/adr/).

## [Unreleased]

### Public Beta field targets

- 3–12+ player proportional fractions and long-session stability with awake-player protection enabled.
- joins/disconnects/deaths/respawns while protection is active.
- representative live mod-stack interaction and performance.
- uncommon/pathological survival states and same-direction gameplay effects not covered by controlled SPIKE-006 runs.
- continued external world-system characterization under SPIKE-005.

## [0.1.0] - 2026-08-26

**Public Beta.** v0.1.0 promotes the SPIKE-006 awake-player survival normalizer from a one-player diagnostic prototype into the normal multiplayer partial-sleep gameplay path.

### Awake-player protection

Added `AwakePlayerProtectionEnabled=true` as the Public Beta default. During normal partial sleep, all awake living players are normalized toward native-day-length progression for:

- Hunger;
- Thirst;
- Fatigue;
- Calories;
- Carbohydrates;
- Proteins;
- Lipids;
- Weight progression.

Sleeping players are never corrected. All-living-asleep still restores native `MinutesPerDay` and leaves vanilla full-sleep acceleration authoritative.

The correction remains server-authoritative and directional: worsening Hunger/Thirst/Fatigue and depleting nutrition deltas are scaled by the observed calendar-compression factor, favorable opposite-direction effects are retained in full, and Weight is normalized in either direction. A per-player read/write failure fails open and clears that player's reference snapshot rather than applying a later catch-up correction.

`AwakePlayerProtectionEnabled=false` is the first-line compatibility rollback: it restores the older Alpha survival behavior while leaving proportional partial-sleep calendar compression active.

### SPIKE-006 validation supporting Beta promotion

Controlled dedicated-server testing on PZ 42.20.3 established:

- native 90-minute day forced to `MinutesPerDay=4.5` with world/calendar time near 20x while `TrueMultiplier=1.0`;
- passive awake Hunger/Thirst/Fatigue/Calories/Protein/Weight progression approximately near native 1x in the first successful correction run;
- later Carbohydrates/Lipids testing away from their lower clamps also remained near native pacing;
- eating and drinking favorable effects were preserved;
- running/sprinting retained active effects including endurance loss and increased expenditure;
- sleeping immediately suspended awake correction and returned the one-player forced test to native day length for vanilla sleep;
- waking reinitialized the correction snapshot before protection resumed;
- no relevant Enshrouded Sleep Lua exception occurred in the successful controlled run.

These are feasibility/regression results, not a claim that every larger multiplayer population or mod combination is already proven. Public Beta intentionally moves those remaining questions into normal field validation.

### Diagnostics and administrator UX

- Added low-volume server/client action/activity transition diagnostics for correlating timed actions with survival telemetry.
- Fixed an early action-diagnostic Java/Kahlua bridge probe that could emit an error every tick; optional bridge capabilities are now circuit-broken after one failed probe.
- Added/expanded sandbox tooltips explaining proportional sleep math, awake-player protection, verbose log volume, and the one-player-only forced-compression diagnostic.
- Removed the SPIKE-only `DiagnosticAwakeProtectionPrototype` sandbox switch from the production UI.
- `DiagnosticForcedCompressionFactor` remains a one-player support/regression tool and should stay at `1.0` during normal multiplayer operation.
- Deployment documentation now distinguishes protection-only soft rollback from full mod rollback.

### Public Beta configuration

```text
EnshroudedSleep.Enabled=true
EnshroudedSleep.PartialSleepSpeedScale=1.0
EnshroudedSleep.AwakePlayerProtectionEnabled=true
EnshroudedSleep.DiagnosticsEnabled=false
EnshroudedSleep.DiagnosticForcedCompressionFactor=1.0
```

### Scope boundary

v0.1.0 does not compensate external world systems. Food aging/spoilage, generators, farming/crops, vehicle resources, corpses, weather, and other world-time-driven or modded systems continue following vanilla game-world time unless separately addressed in future evidence-backed work.

## [0.0.10] - 2026-08-19

**Public Alpha.** v0.0.10 completed the final pre-deployment health/survival investigation and SPIKE-004 returned **GO**.

### Steam Workshop publication preparation

The repository was restructured so a clean copy of the repository root can serve directly as the Project Zomboid Workshop item without a generated deployment package.

The single authoritative runtime mod tree is now:

```text
Contents/mods/pz-enshrouded-sleep/
```

The former root-level runtime copies (`42/`, `common/`, and `mod.info`) were removed to prevent source/release drift. The outer repository/Workshop item intentionally retains public project documentation, licensing/provenance files, `workshop.txt`, and related release material.

Added/updated:

- root `workshop.txt` with the permanent Steam ID intentionally blank until first publication;
- root `preview.png` as the 256x256 Steam Workshop preview image;
- versioned `42/poster.png` (256x256) and `42/icon.png` (32x32) for Build 42 mod-manager artwork;
- versioned `42/mod.info` references `poster=poster.png` and `icon=icon.png`;
- package validation checks artwork presence, PNG dimensions, preview file-size ceiling, metadata references, version agreement, and Public Alpha defaults;
- `docs/STEAM_WORKSHOP.md` for first upload/update procedures and permanent Workshop-ID handling;
- `.gitignore` and release-checklist guidance to exclude `.git/`, local logs, credentials, private test artifacts, and scratch files from the Workshop authoring copy;
- installation/deployment instructions for the new Workshop wrapper versus inner PZ mod tree;
- public README table of contents, simplified Public Alpha landing-page content, and removal of detailed SPIKE-004 evidence from the README;
- explicit The Indie Stone and Keen Games non-affiliation/disclaimer language in public/legal/provenance documentation;
- Public Alpha v0.0.10 Lua headers, startup banners, and inline architecture/function documentation across the controller, synchronization, and diagnostic modules without changing normal sleep policy.

### v0.0.10 survival-state test result

The focused diagnostics successfully resolved/read:

```text
CharacterStatsResolved=24/24
CharacterStatsReadable=24/24
MoodlesResolved=25/25
MoodlesReadable=25/25
NutritionReadable=10/10
```

The one-connected-player multiplayer-server forced-compression test exercised baseline, 5x, 10x and 20x calendar compression while the monitored character remained awake. `TrueMultiplier` remained `1.0` during forced compression.

Clean baseline-versus-5x comparisons produced approximately:

- Hunger: `4.85x`;
- Thirst: `4.67x`;
- Fatigue: `5.46x`;
- Carbohydrates: `4.99x`;
- Proteins: `4.99x`;
- Lipids: `4.99x`.

A short adjacent 10x-versus-baseline control produced roughly `9.5x` changes for hunger, thirst, fatigue, proteins and lipids while ongoing body-health loss remained about `0.95x`.

Resting endurance recovery remained approximately unchanged when calendar compression doubled from 10x to 20x, supporting a simulation/real-time-bound classification for that tested recovery condition.

Temperature remained physiologically stable and no thermal Moodle hazard appeared during the test. Active sickness, poisoning, zombie infection/fever and extreme thermal injury were not present and remain Public Alpha characterization targets rather than release blockers.

### Safety conclusion

Combined v0.0.9/v0.0.10 evidence shows different player systems use different time domains:

**Simulation/real-time bound under tested conditions**

- awake bleeding/body-health loss;
- measured bleeding/scratch injury timers;
- resting endurance recovery.

**World/calendar-time bound**

- hunger;
- thirst;
- fatigue;
- calories;
- carbohydrates;
- proteins;
- lipids.

No evidence showed acute awake-player health damage scaling with calendar compression. SPIKE-004 therefore returned **GO — Public Alpha** with faster survival-need progression accepted as a documented consequence of genuinely faster world/calendar time.

### Diagnostic override safety

The v0.0.10 one-player server test path also passed its sleep-suspension check: when the connected player slept while a forced factor was armed, the controller restored baseline `MinutesPerDay` and suspended the override so it could not stack with vanilla full-sleep acceleration.

### Client synchronization observation

During aggressive live admin/sandbox factor changes, a few isolated client samples temporarily reverted to baseline `MinutesPerDay`; the authoritative server remained compressed and the normal synchronization heartbeat restored the client value within roughly a second. This is documented as a Public Alpha robustness observation, not a release blocker, because the test repeatedly rewrote sandbox/admin settings in a way normal play does not.

### Public Alpha configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

The diagnostic machinery is retained for support/regression testing but remains dormant by default.

### Earlier v0.0.10 implementation work

v0.0.10 corrected survival-state observability using current Build 42 `CharacterStat`, `MoodleType` and Nutrition APIs and added a tightly gated one-connected-player multiplayer-server forced-compression test path. An intermediate standalone/local-game fallback was removed before runtime validation; Enshrouded Sleep remains server-only.

## [0.0.9] - 2026-08-19

Follow-up SPIKE-004 diagnostic build after the first successful health/injury telemetry run.

The two-player controlled run established that partial `MinutesPerDay` compression does not affect all player systems equally. Awake active-bleeding health loss remained approximately real-time bound during ~5x calendar compression:

- baseline ~`-0.07869/s`;
- partial ~`-0.07810/s`;
- ratio ~`0.993x`;
- measured `BleedingTime` and `ScratchTime` remained ~`1x`.

Nutrition was strongly world/calendar-time bound:

- Calories: ~`5.01x` at 5x compression and ~`10.00x` at 10x;
- Carbohydrates: ~`5.00x / 10.00x`;
- Proteins: ~`5.00x / 10.01x`;
- Lipids: ~`5.00x / 10.00x`.

The run also preserved correct server/client `MinutesPerDay` convergence and `TrueMultiplier=1.0` during partial compression.

## [0.0.8] - 2026-08-17

Added broad read-only server/client health/time-domain diagnostics for SPIKE-004, including general health, detailed injured-body-part state/timers, nutrition, sleep context, and guarded health probes. A one-player-on-server vanilla-full-sleep reference showed extremely rapid bleeding death and accelerated healing/recovery while vanilla all-asleep fast-forward owned the state. This demonstrated the need for a separate awake-player partial-compression test.

Also added formal SPIKE-004 and retroactively documented SPIKE-001 through SPIKE-003 plus ADR-001 through ADR-003.

## [0.0.7] - 2026-08-17

Fixed the v0.0.6 Kahlua multi-return `tonumber()` diagnostic exception and added a one-observer-pass synchronization settling guard.

Clean two-player regression on PZ 42.20.3 confirmed server/client `90 <-> 4.5` transitions, smooth sleeping and awake clocks, normal-speed awake gameplay, correct baseline/full-sleep handoff, correct wake/disconnect recalculation, no stale partial-state packet paired with baseline 90, and sensible vanilla sleep/wake behavior. Issues #1, #2, and #3 were closed after this regression.

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
