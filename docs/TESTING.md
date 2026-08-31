# Enshrouded Sleep — Testing Guide

This document owns current regression and field-test procedures. Historical results belong in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); detailed experimental protocols/results belong under [`spikes/`](spikes/).

Enshrouded Sleep is tested as a multiplayer-server mod. Local/standalone single-player is outside scope.

## Tier 1 — startup smoke test

Run after runtime/configuration changes, a new release candidate, or a relevant Project Zomboid update.

1. Start the dedicated server and confirm no Enshrouded Sleep Lua exception.
2. Connect at least one client and confirm no Enshrouded Sleep client exception.
3. Confirm the core controller, client clock sync, roster logger, awake-protection module, sleep-notification modules, and v1.0.0 sleep-benefit modules load.
4. With all living players awake, confirm authoritative/client `MinutesPerDay` remains at the native baseline.
5. Confirm `DiagnosticsEnabled=false` does not produce high-frequency diagnostic telemetry.
6. Confirm `DiagnosticForcedCompressionFactor=1.0` is inert.
7. With `SleepNotificationsEnabled=false`, confirm no Enshrouded Sleep sleep-state chat messages are emitted.
8. With `SleepBenefitsEnabled=false`, confirm no Rested/Well Rested grant occurs and no XP/Endurance modification is applied.

Project Zomboid 42.20.4 (`b0bbce05d5`) passed the startup/baseline/client-sync compatibility checkpoint used as the basis for v0.1.1. See [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md) for the evidence boundary.

## Tier 2 — core two-player sleep regression

Use normal server settings and `AwakePlayerProtectionEnabled=true`.

1. Connect two living players; confirm baseline server/client day length.
2. Put one player to sleep and leave one awake.
3. Confirm proportional calendar compression is applied from the current sleeping fraction.
4. Confirm both clients mirror the authoritative `MinutesPerDay` and clocks remain coherent.
5. Confirm awake movement/actions remain normal-speed.
6. Confirm the awake-protection module enters partial mode for the awake player.
7. Wake the sleeper and confirm exact baseline restoration.
8. Put both living players to sleep and confirm baseline is restored before vanilla full-sleep acceleration owns the state.
9. If practical, disconnect/reconnect a player and confirm population/state recalculation.

The exact expected factor depends on live `FastForwardMultiplier`, `PartialSleepSpeedScale`, and the sleeping fraction; use [`REQUIREMENTS.md`](REQUIREMENTS.md) for the canonical formula rather than duplicating it here.

## v0.1.1 live sleep-notification field test

v0.1.1 intentionally ships the optional notification path for live Public Beta validation on WHG. Run the checks below during normal post-deployment use before marking the notification feature field-validated.

1. Start with `SleepNotificationsEnabled=true`, at least two living players, and no sleepers. Confirm the server emits a notification `CONFIG` line reporting `SleepNotificationsEnabled=true`, and confirm no startup/all-awake player-facing notification is sent.
2. Put one player to sleep. Confirm every connected client receives exactly one concise server-chat message such as `[Enshrouded Sleep] 1/2 living players sleeping (50%). World time is 20x faster.`
3. Change the sleep fraction by sleeping/waking another player or changing the connected living population. Confirm exactly one updated message is sent after the authoritative clock state settles.
4. Wake all players. Confirm one `[Enshrouded Sleep] All living players are awake. World time is normal.` message.
5. Put all living players to sleep. Confirm the message reports the living-player count and identifies vanilla full-sleep fast-forward rather than claiming an Enshrouded Sleep compression multiplier.
6. Confirm there is no per-tick/repeated chat spam and no Enshrouded Sleep Lua exception.
7. Set `SleepNotificationsEnabled=false`; confirm the server `CONFIG` line reflects the change and subsequent sleep-state changes no longer emit messages while proportional sleep continues normally.

The relevant low-volume prefixes are `[EnshroudedSleepNotify][SERVER]` and `[EnshroudedSleepNotify][CLIENT]`. A client chat-bridge failure should circuit-break notification display for that client session without affecting sleep/time behavior. If the notification path causes a live compatibility issue, disable `SleepNotificationsEnabled` first and preserve the server/client logs before changing the core sleep configuration.

## SPIKE-007 — Rested / Well Rested validation

This procedure covers the unreleased Rested / Well Rested feature accepted from `feature/sleep-benefits` into `main`. Use it for focused checks and for live validation during the next production release. The full multiplayer sequence uses at least two connected living players and the defaults documented in [`spikes/SPIKE-007-sleep-benefits.md`](spikes/SPIKE-007-sleep-benefits.md).

Enable:

```text
EnshroudedSleep.SleepBenefitsEnabled=true
```

Keep normal multiplayer diagnostics settings unless collecting a focused trace:

```text
EnshroudedSleep.DiagnosticsEnabled=false
EnshroudedSleep.DiagnosticForcedCompressionFactor=1.0
```

Minimum smoke sequence:

1. Sleep `< 6` game hours and wake; confirm no new benefit.
2. Sleep `6` to `< 9` game hours; confirm Rested is granted for the configured duration.
3. Produce a repeatable positive XP event and confirm approximately `1.05×` total XP at the default 5% bonus, with a matching server `XP_BONUS` diagnostic and no recursive XP loop.
4. Sleep `>= 9` game hours; confirm Well Rested replaces Rested.
5. Deplete Endurance, then recover under controlled conditions; confirm positive recovery is approximately `1.10×` baseline at the default setting while Endurance expenditure itself is unchanged.
6. Confirm Endurance never exceeds `1.0`.
7. Confirm a sub-threshold nap does not cancel an active unexpired benefit.
8. Confirm a later qualifying sleep refreshes/replaces rather than stacks.
9. Confirm expiry follows game-world hours.
10. Disconnect/reconnect after earning a benefit and confirm its remaining world-time duration persists.
11. Confirm death clears the benefit.
12. Set `SleepBenefitsEnabled=false` and confirm the reward disappears while proportional sleep continues normally.

Built-in Moodle/UI checks:

1. Confirm no additional Moodle/UI Workshop dependency is required.
2. Rested shows only the Rested icon; Well Rested shows only the Well Rested icon.
3. Hover text shows the correct title, server-supplied XP/Endurance percentages, and remaining game time.
4. Confirm the icon tracks at least the default Moodle size and one larger configured Moodle size without overlap or severe scaling artifacts.
5. Create one or more vanilla moodles and confirm the Enshrouded Sleep icon moves below the visible vanilla stack.
6. Confirm benefit expiry, death, and `SleepBenefitsEnabled=false` hide the icon.
7. If Lifestyle is installed for compatibility testing, activate one or more Lifestyle custom moodles and confirm the Enshrouded Sleep icon reserves their occupied slots rather than drawing over them.
8. Confirm a Moodle renderer/texture failure, if induced during development, does not stop XP/Endurance effects or alter sleep/time behavior.

No Lifestyle or other third-party custom-Moodle code/assets are part of the candidate; Lifestyle is only a coexistence test target.

For the focused server-XP feasibility test, a one-player dedicated-server run is sufficient. Set both XP bonus percentages to `100` so the result is unambiguous, keep diagnostics enabled only for the test window, and use a character below the tested perk's maximum level. Record XP immediately before and after a normal XP-producing action such as exercise for Fitness, then repeat with a different ordinary skill action if practical. A successful event should produce one server `XP_BONUS` line whose `bonus` equals its `base`, and the character should receive approximately twice the underlying gain. Restore the intended percentages and disable verbose diagnostics afterward. Because every configured percentage uses the same direct formula and the module has no access-level/admin-mode branch, separate default-`5%` and non-admin feasibility runs are not required.

The server log—not a client `XP_BONUS` line—is authoritative for this retest. Confirm the log names the same perk being trained, contains no repeated XP exception or runaway loop, and that the client continues receiving the Moodle state. Broader two-player behavior is a live-validation target for the next production release.

The detailed acceptance cases, current GO decision, and evidence boundary are maintained in [`spikes/SPIKE-007-sleep-benefits.md`](spikes/SPIKE-007-sleep-benefits.md).

## Tier 3 — Public Beta multiplayer protection field test

This remains the principal released-Beta awake-protection validation path.

Recommended normal configuration is maintained in [`DEPLOYMENT.md`](DEPLOYMENT.md).

Exercise, where practical:

- 3+ living players with one or more sleepers;
- multiple awake players protected simultaneously;
- changing sleep fractions;
- eating and drinking while another player sleeps;
- walking/running/sprinting/resting during partial sleep;
- repeated sleep/wake cycles;
- joins/disconnects;
- death/respawn transitions;
- longer sessions with the normal server mod stack.

Record whether protection status follows the actual awake/sleeping roster and whether any player shows implausible Hunger/Thirst/Fatigue/Nutrition/Weight changes, snapping, oscillation, or stale correction after a lifecycle change.

## Focused diagnostics window

Leave verbose diagnostics off during routine operation. If an anomaly is reproducible:

1. preserve the ordinary server/client logs around the event;
2. enable `DiagnosticsEnabled=true` for the shortest practical reproduction window;
3. keep `DiagnosticForcedCompressionFactor=1.0` for natural multiplayer partial-sleep testing;
4. reproduce once if safe;
5. disable verbose diagnostics again;
6. collect server console/DebugLog and affected owning-client DebugLogs where available.

Useful prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
[EnshroudedSleepAwakeProtect][SERVER]
[EnshroudedSleepNotify][SERVER]
[EnshroudedSleepNotify][CLIENT]
[EnshroudedSleepBenefits][SERVER]
[EnshroudedSleepBenefits][CLIENT]
[EnshroudedSleepBenefits][MOODLE]
[EnshroudedSleepActionDiag][SERVER]
[EnshroudedSleepActionDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

## Isolated forced-compression regression

`DiagnosticForcedCompressionFactor>1` is reserved for controlled support/regression work with exactly one living awake player and verbose diagnostics enabled. It should not be used to generate normal multiplayer Beta evidence.

Expected safety behavior:

```text
player sleeps        -> restore baseline; suspend forced override
second player joins  -> restore baseline; suspend forced override
factor returns to 1  -> normal server policy resumes
```

Detailed historical SPIKE-006 procedures remain in:

- [`spikes/SPIKE-006-FIRST-TEST.md`](spikes/SPIKE-006-FIRST-TEST.md)
- [`spikes/SPIKE-006-ACTIVE-EFFECTS-TEST.md`](spikes/SPIKE-006-ACTIVE-EFFECTS-TEST.md)

Do not reproduce those long experimental procedures here.

## Awake-protection soft-rollback test

When compatibility behavior needs isolation:

1. establish a normal partial-sleep state;
2. set `AwakePlayerProtectionEnabled=false` using the normal administrative workflow;
3. confirm proportional calendar compression continues;
4. confirm protection status reports disabled and no supported survival correction is applied;
5. re-enable protection only if the server state remains stable and the comparison is needed.

This distinguishes protection-layer defects from core sleep/clock defects without immediately removing the mod.

## Full rollback test

For a release candidate or major runtime change, verify the documented rollback path from [`DEPLOYMENT.md`](DEPLOYMENT.md): clean stop, preserve logs/save, disable/remove the mod, restart, and confirm future sleep/time behavior is vanilla.

## Workshop/package release test

Packaging/publication checks are intentionally not duplicated here. Use:

- [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md) for Workshop authoring/update mechanics;
- [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) for the release gate;
- this document for the multiplayer smoke/regression appropriate to the change.

## Project Zomboid build regression

For a new Build 42 release:

1. review changes affecting `GameTime`, multiplayer sleep/lifecycle, CharacterStats, Nutrition, XP, Endurance, networking/command APIs, Moodle UI conventions, and any subsystem touched by the release;
2. check runtime Lua for removed/restricted APIs introduced by the game update;
3. run Tier 1;
4. run Tier 2 if clock/sleep/network behavior may have changed;
5. run Tier 3 or a focused SPIKE only when the changed engine area justifies it;
6. update validation claims only after evidence is collected.
