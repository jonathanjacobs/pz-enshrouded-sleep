# Changelog

Human-readable history of notable Enshrouded Sleep changes. Git remains authoritative for exact diffs. Detailed experimental evidence lives in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md); focused investigations and decisions live under [`docs/spikes/`](docs/spikes/) and [`docs/adr/`](docs/adr/).

## [Unreleased]

### Public Alpha characterization targets

- 3–12+ player proportional fractions and long-session stability.
- joins/disconnects/deaths/respawns under live population changes.
- non-health world-time systems: spoilage, farming, generators, corpses, composting and weather.
- pathological survival states not exercised in SPIKE-004: active sickness/food poisoning, poison, zombie infection/fever, and extreme thermal injury.
- client clock robustness during live admin/sandbox reconfiguration.

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
- `docs/STEAM_WORKSHOP.md` for first upload/update procedures and permanent Workshop-ID handling;
- `.gitignore` and release-checklist guidance to exclude `.git/`, local logs, credentials, private test artifacts, and scratch files from the Workshop authoring copy;
- installation/deployment instructions for the new Workshop wrapper versus inner PZ mod tree;
- public README table of contents, simplified Public Alpha landing-page content, and removal of detailed SPIKE-004 evidence from the README;
- explicit The Indie Stone and Keen Games non-affiliation/disclaimer language in public/legal/provenance documentation;
- Public Alpha v0.0.10 Lua headers, startup banners, and inline architecture/function documentation across the controller, synchronization, and diagnostic modules without changing normal sleep policy.

Workshop artwork (`preview.png`, and any versioned `poster.png`/`icon.png` chosen for the in-game mod manager) remains a publication-time asset step and must be validated against the current Build 42 `ModTemplate` before the first upload.

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
