# SPIKE-007 — Rested / Well Rested voluntary-sleep benefits

Status: **GO FOR MAIN INTEGRATION — LIVE MULTIPLAYER VALIDATION DEFERRED TO THE NEXT PRODUCTION RELEASE**

Tracking issue: [GitHub issue #10](https://github.com/jonathanjacobs/pz-enshrouded-sleep/issues/10)

Development branch: `feature/sleep-benefits` (accepted for integration into `main`)

## Question

Can Enshrouded Sleep make voluntary multiplayer sleep meaningfully beneficial without making sleep mandatory, while keeping the reward configurable, non-stacking, multiplayer-safe, and visually legible as a Project Zomboid-style Moodle?

## Proposed default behavior

| Sleep completed | Benefit | Default effect | Default duration |
| --- | --- | --- | --- |
| `< 8` game hours | None | No new benefit | — |
| `8` to `12` game hours (inclusive) | Rested | `+10%` XP gain | `4` game hours |
| `> 12` game hours | Well Rested | `+10%` XP gain; `+10%` Endurance recovery | `6` game hours |

Sleeping beyond the Well Rested threshold remains Well Rested; oversleeping does not remove the reward.

A qualifying sleep replaces/refreshes the current benefit. Benefits never stack. A short sleep below the Rested threshold does not cancel an otherwise active benefit.

## Administrator controls

The feature is independently disabled by default and uses server sandbox values:

```text
EnshroudedSleep.SleepBenefitsEnabled=false
EnshroudedSleep.RestedMinimumSleepHours=8.0
EnshroudedSleep.RestedDurationHours=4.0
EnshroudedSleep.RestedXPBonusPercent=10.0
EnshroudedSleep.WellRestedMinimumSleepHours=12.0
EnshroudedSleep.WellRestedDurationHours=6.0
EnshroudedSleep.WellRestedXPBonusPercent=10.0
EnshroudedSleep.WellRestedEnduranceRecoveryBonusPercent=10.0
```

If `WellRestedMinimumSleepHours` is configured below `RestedMinimumSleepHours`, the runtime clamps the effective Well Rested threshold upward to the Rested threshold. Well Rested qualification is strictly above that effective threshold; sleep exactly at it remains Rested when it meets the Rested minimum.

## Development-package deployment preflight

A SPIKE-007 result is valid only when the dedicated server and owning client are both running the same development package from the feature branch or its integrated `main` successor.

Project Zomboid can discover more than one copy of a mod with the same Mod ID from local and Workshop locations. In particular, a public Workshop `pz-enshrouded-sleep` copy can supply stale `sandbox-options.txt` data even when another copy supplies runtime Lua. For development-package testing, keep **one effective copy of Mod ID `pz-enshrouded-sleep` on the test client**. Temporarily remove/unsubscribe the released Workshop copy or otherwise eliminate the duplicate before loading the development package; restore the normal Workshop deployment after testing.

Before testing sleep qualification, verify all of the following in the logs/UI:

- client loads `[EnshroudedSleepBenefits][CLIENT]` and `[EnshroudedSleepBenefits][MOODLE]`;
- server loads `[EnshroudedSleepBenefits][SERVER]` and prints the development `CONFIG` line;
- client/server development build strings report `0.1.1+sleep-benefits-server-xp-dev` when the corresponding packet path is exercised;
- the admin Sandbox page shows the Rested / Well Rested options with translated labels;
- there are no `ERROR unknown SandboxOption "EnshroudedSleep.SleepBenefits..."` messages.

Raw labels such as `Sandbox_SleepBenefitsEnabled`, missing benefit options, unknown-option errors, or absent benefit client load banners mean the deployment is mixed/stale. Stop the gameplay portion of the SPIKE and correct the package deployment first.

## Build 42.20 feasibility basis

### Sleep duration and persistence

`GameTime:getWorldAgeHours()` provides a monotonic game-world clock suitable for both sleep-duration measurement and benefit expiry. This intentionally means the benefit lasts in **game hours**, not wall-clock hours.

The server detects `IsoPlayer:isAsleep()` transitions. The start of the current sleep attempt is kept in server-session memory rather than persisted, so a disconnect or server restart while asleep cannot convert offline elapsed world time into a reward.

The awarded benefit type and expiry world hour are stored in player ModData so an already-earned benefit can survive an ordinary reconnect/server restart.

### XP bonus

Build 42's installed server `XpSystem/XpUpdate.lua` registers the `AddXP` Lua event with `(player, perk, amount)`. The implementation listens on the dedicated server for positive XP events, verifies the server-authored benefit, and adds the configured percentage to the event-supplied perk as flat bonus XP. No skill list is required: each qualifying event identifies the affected perk.

A per-player recursion guard prevents bonus XP from recursively generating additional bonus XP if the underlying call also reaches the event path. The flat-XP function is used specifically so the added percentage is not run through ordinary XP multipliers a second time.

The owning client does not award or request XP. This reduces the cheat surface and aligns the reward with the server's persisted benefit state, but the path still requires a live dedicated-server retest and interaction checks with other XP-altering mods.

### Endurance-recovery bonus

Build 42.20 exposes Endurance through `CharacterStat.ENDURANCE` on `Stats`. The server observes Endurance each tick while Well Rested is active. Only positive deltas are amplified:

```text
VanillaRecovery = CurrentEndurance - PreviousEndurance
ExtraRecovery = VanillaRecovery × (ConfiguredPercent / 100)
CorrectedEndurance = min(1.0, CurrentEndurance + ExtraRecovery)
```

Negative deltas are never reduced. Therefore Well Rested does **not** increase maximum Endurance and does **not** make running/combat consume less Endurance.

As with awake-player survival protection, this correction is directional rather than source-specific: a positive Endurance change produced by another mod could also receive the configured bonus.

### Moodle UI

The original candidate used an optional external Moodle Framework integration. That dependency has been removed.

Build 42.20.3's vanilla Moodle implementation provides enough stable presentation information for a narrow Enshrouded Sleep-owned renderer:

- vanilla Moodle sizes are `32`, `48`, `64`, `80`, `96`, and `128`, with the automatic option following the configured font-size index;
- the vanilla stack begins at a `120`-pixel top offset and uses a `10`-pixel gap between Moodle slots;
- vanilla Moodle background and outline textures are available at runtime under `media/ui/Moodles/<size>/`;
- vanilla `MoodleType`/`Moodles` state can be read to count currently visible vanilla moodles without modifying them.

`SleepBenefitMoodle_Client.lua` therefore owns one `ISUIElement` slot and renders Rested or Well Rested directly. It references the installed vanilla background/outline textures at runtime and overlays original Enshrouded Sleep artwork. It does not patch Java/core files, register a custom vanilla Moodle type, or require another Workshop mod.

The Lifestyle Lua supplied for this project was reviewed as implementation prior art. Its source confirms that custom Moodle-style `ISUIElement` rendering and vanilla-stack-aware placement are practical in B42. Enshrouded Sleep does **not** copy or redistribute Lifestyle code or artwork. The implementation is independently written for one non-stacking status.

For coexistence only, when Lifestyle is actually loaded the renderer may read the existing `LSMoodleManager` and player `LSMoodles` state to count active Lifestyle slots. This is read-only and is used solely to place the Enshrouded Sleep icon below the Lifestyle stack rather than on top of it.

### Custom artwork

Two original Enshrouded Sleep assets were generated specifically for this project:

```text
Contents/mods/pz-enshrouded-sleep/42/media/ui/Moodle_EnshroudedRested.png
Contents/mods/pz-enshrouded-sleep/42/media/ui/Moodle_EnshroudedWellRested.png
```

The visual language is intentionally playful/colorful and generally Moodle-like, but no Lifestyle, Project Zomboid, or other third-party icon artwork is copied. The client renderer scales the artwork to the player's configured Moodle size.

## Preliminary one-player evidence — 2026-08-31

Three dedicated-server sessions established useful preliminary evidence but do not satisfy the multiplayer GO gate:

- matching feature packages loaded on client and server;
- approximately `6.280` and `6.994` hours produced Rested, approximately `10.029` hours produced Well Rested, and an approximately `2.610`-hour sleep did not replace an active benefit;
- an earned Well Rested state remained present across reconnect;
- the second run logged `4,818` directional Endurance corrections at configured `10%` and `75%` values, with the expected arithmetic, no amplification of non-positive deltas, and no value above `1.0`;
- XP settings of `5%`, `10%`, and `75%` produced no `XP_BONUS` diagnostic on the initial owning-client implementation, including while exercising a character whose Fitness and Strength were both below maximum;
- client sandbox rendering emitted Java formatter warnings for literal `%` characters in four translated tooltips.

Decision from the first two sessions: preserve the validated classification/persistence/Endurance paths, replace the unproven client XP bridge with the server-authoritative event path described above, and escape the affected tooltip percentages.

### Server-authoritative XP retest — PASS

The third session ran matching client/server build `0.1.1+sleep-benefits-server-xp-dev`. After a `7.695`-hour sleep granted Rested, the server recorded `35` XP bonus events at the deliberately unambiguous `100%` setting:

| Perk | Events | Base XP | Bonus XP |
| --- | ---: | ---: | ---: |
| Carving | 9 | 22.5 | 22.5 |
| Fitness | 5 | 5.0 | 5.0 |
| Sprinting | 10 | 10.0 | 10.0 |
| Strength | 11 | 15.4 | 15.4 |
| **Total** | **35** | **52.9** | **52.9** |

All `35` server calculations matched `bonus = base × 100 / 100`; no client `XP_BONUS` award occurred, no recursive/runaway award was observed, and no relevant Enshrouded Sleep Lua error or server anti-cheat rejection appeared. Coverage across four event-supplied perks supports the generic, no-allowlist design in ADR-004.

The client printed vanilla `ServerSettingsScreen.lua` `WARN:MISSING in SettingsTable` messages for many server settings, including `AntiCheatXP`, `Mods`, `Map`, and `SteamVAC`. Build 42 emits that bulk warning when a server option lacks an entry in the screen's UI metadata table. It is not an anti-cheat violation and was not correlated with any rejected XP award.

Decision: the focused server-authoritative XP checkpoint is **PASS**. The `100%` run exercised the same configurable formula now used at the default `10%`, and the implementation has no access-level or admin-mode branch. A separate default-percentage or non-admin run is not required to validate this mechanism. The feature is accepted for `main`; broader two-player and lifecycle coverage will be collected during the next production release.

The classification evidence above used the earlier `6`/`9`-hour defaults and inclusive Well Rested comparison. It does not by itself validate the later `8`/`12`-hour defaults or the exclusive Well Rested boundary; those revised policy details require the Tier A runtime regression below.

## Required validation

### Tier A — reward classification

With `SleepBenefitsEnabled=true`:

1. Sleep less than 8 game hours → no new benefit.
2. Sleep at least 8 but less than 12 game hours → Rested.
3. Sleep exactly 12 game hours → still Rested.
4. Sleep longer than 12 hours → Well Rested.
5. A qualifying sleep while already buffed replaces/refreshes the benefit rather than stacking.
6. A sub-threshold nap does not cancel an active benefit.

### Tier B — duration/persistence

1. Rested expires after approximately the configured game-world duration.
2. Well Rested expires after approximately the configured game-world duration.
3. Reconnect during an already-earned benefit preserves its remaining world-time duration.
4. Disconnect/restart while actively asleep does not award offline elapsed time as sleep.
5. Death clears the benefit.
6. `SleepBenefitsEnabled=false` clears/disables active effects without affecting Enshrouded Sleep clock behavior.

### Tier C — XP

1. For a focused one-player retest, set both XP percentages to `100%`, enable diagnostics, and use a character below the tested perk's maximum.
2. Record the perk XP immediately before and after a normal XP-producing action.
3. Confirm one server `XP_BONUS` line reports that perk and `bonus` approximately equal to `base`; confirm the observed total is approximately `2×` the underlying award.
4. Repeat with a second perk if practical to confirm the event-supplied perk path is generic rather than Fitness-specific.
5. Confirm there is no client `XP_BONUS` award path, repeated Lua exception, or runaway XP loop.
6. Restore the intended production percentage after the focused diagnostic run. A default `10%` sample may be collected as an ordinary smoke check when the increments are large enough to measure reliably, but it is not a separate feasibility gate.
7. When a second player becomes available, include XP in the broader dedicated-server regression; no distinct account-access-level path exists in this module.

### Tier D — Endurance

1. Measure Endurance recovery from a controlled depleted state without a benefit.
2. Repeat while Well Rested.
3. Confirm positive recovery is approximately `1.10×` baseline with the default setting.
4. Confirm Endurance expenditure while running/sprinting is not reduced.
5. Confirm Endurance never exceeds `1.0`.
6. Repeat with a non-default sandbox percentage.

### Tier E — built-in Moodle UI

1. Confirm no external Moodle/UI Workshop dependency is needed.
2. Rested displays only the Rested icon.
3. Well Rested displays only the Well Rested icon.
4. Hover text reflects the current server-supplied XP/endurance percentages and remaining game time.
5. Test the default Moodle-size setting and at least one larger configured size; confirm the icon remains legible and tracks the right-side vanilla stack.
6. Trigger visible vanilla moodles and confirm the Enshrouded Sleep icon moves below them rather than overlapping them.
7. Benefit expiry hides the moodle.
8. Death hides the moodle.
9. If Lifestyle is installed for coexistence testing, activate one or more Lifestyle moodles and confirm the Enshrouded Sleep icon reserves their occupied slots rather than overlapping them.
10. Confirm no recurring renderer/texture exception; if the presentation layer fails, XP/Endurance and server sleep/time behavior must continue.

## GO / NO-GO decision

A clean one-player run established configuration, reward classification, XP arithmetic, Endurance recovery, persistence, and UI feasibility. Server authority, independent disablement, and the default-off sandbox setting bound the remaining deployment risk.

Decision: **GO for integration into `main`**. The next production release may carry the opt-in feature and collect broader two-player evidence during live operation rather than blocking integration on a separate pre-release multiplayer session. Keep `SleepBenefitsEnabled=false` as the package default, retain feature-only rollback, monitor reward classification/XP/Endurance/expiry/Moodle behavior, and keep tracking issue #10 open until the planned live validation is reviewed.
