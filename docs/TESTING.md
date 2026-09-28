# Enshrouded Sleep — Testing Guide

Short, repeatable checks for a multiplayer-server mod. Record results in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); expected behavior and formulas are in [`REQUIREMENTS.md`](REQUIREMENTS.md); long experimental procedures live in [`spikes/`](spikes/).

## Contents

- [Before testing](#before-testing)
- [Smoke test](#smoke-test)
- [Two-player sleep test](#two-player-sleep-test)
- [Field test (normal play)](#field-test-normal-play)
- [Feature checks](#feature-checks)
- [Rollback checks](#rollback-checks)
- [Chasing a problem](#chasing-a-problem)
- [After a Project Zomboid update](#after-a-project-zomboid-update)
- [Recording results](#recording-results)

## Before testing

- Server and clients show the same Project Zomboid `version=` / `revision=` line and the same Enshrouded Sleep build (server `CONFIG`, client `SERVER_BUILD`).
- Only one copy of the mod is installed (no duplicate local/Workshop copies with the same Mod ID).
- Note the server `CONFIG` lines; expected results use the active settings, not the shipped defaults.
- Keep `DiagnosticsEnabled=false` and `DiagnosticForcedCompressionFactor=1.0` unless you are deliberately collecting a trace.

## Smoke test

Run after any change, new release, or Project Zomboid update.

1. Server starts and a client joins with no Enshrouded Sleep Lua errors on either side.
2. The Enshrouded Sleep modules log that they loaded on both server and client.
3. With everyone awake, server and client `MinutesPerDay` stay at the baseline.
4. Disabled features stay quiet: no banners with notifications off, no Rested/Well Rested with benefits off, no diagnostic spam.

## Two-player sleep test

Run when clock, sleep, network, or awake-protection behavior may have changed.

1. One player sleeps, one stays awake: time speeds up in proportion to the sleeping fraction, and both clients follow the server's `MinutesPerDay`.
2. The awake player moves and acts at normal speed, and awake protection switches to partial mode.
3. The sleeper wakes: day length returns exactly to baseline.
4. Both players sleep: baseline is restored and vanilla full-sleep fast-forward takes over.
5. If practical, disconnect/reconnect a player and confirm the roster and time speed update.

## Field test (normal play)

For awake protection and anything that needs a real population. During normal sessions, watch for:

- protection status following who is actually awake or asleep;
- odd Hunger/Thirst/Fatigue/Nutrition/Weight jumps, snapping, or stale correction after joins, disconnects, deaths, or respawns;
- repeated errors or noisy logs with the normal server mod stack.

## Feature checks

**Sleep notifications** (`SleepNotificationsEnabled=true`):

- Each sleep-state change shows one banner on every client, for example `[Enshrouded Sleep] 1/2 living players sleeping (50%). World time is 20x faster.`
- Everyone awake shows one "World time is normal" message; everyone asleep mentions vanilla fast-forward rather than a multiplier.
- No repeated spam. Turning the option off stops messages without affecting sleep.

**Rested / Well Rested** (`SleepBenefitsEnabled=true`; thresholds are the active sandbox values):

- A short sleep gives nothing; reaching the Rested threshold (up to and including the Well Rested threshold) gives Rested; sleeping past the Well Rested threshold gives Well Rested.
- XP gains show the configured bonus, with one server `XP_BONUS` line per event and no runaway loop. Well Rested speeds Endurance recovery only, never above `1.0`.
- Benefits refresh rather than stack, survive reconnect, expire on world time, and clear on death or when the option is turned off.
- The Moodle icon shows the right tier and tooltip, sits below vanilla moodles, and makes room for Lifestyle moodles when Lifestyle is installed (client logs `[EnshroudedSleepBenefits][MOODLE] COMPAT`).

To isolate the server XP path, set both XP percentages to `100` on a one-player server for a short diagnostics window and confirm each `XP_BONUS` line's `bonus` equals its `base`. Background: [`adr/ADR-004-award-sleep-benefit-xp-on-server.md`](adr/ADR-004-award-sleep-benefit-xp-on-server.md).

## Rollback checks

- **Awake protection off:** set `AwakePlayerProtectionEnabled=false` during partial sleep; time compression continues and no survival corrections are applied.
- **Full rollback:** follow [`DEPLOYMENT.md`](DEPLOYMENT.md) and confirm sleep/time behavior returns to vanilla.

## Chasing a problem

1. Save the normal server and client logs around the event.
2. Turn on `DiagnosticsEnabled=true`, reproduce once, then turn it off.
3. Collect the server console/DebugLog and the affected client's DebugLog.

Log prefixes start with `[EnshroudedSleep`. `DiagnosticForcedCompressionFactor>1` is only for a one-player server with diagnostics on (see R25 in [`REQUIREMENTS.md`](REQUIREMENTS.md)); don't use it as evidence for normal multiplayer.

## After a Project Zomboid update

1. Skim the patch notes and modding news for changes to game time, sleep, player stats, XP, networking, anti-cheat, or moodle UI.
2. Run the smoke test; run the two-player sleep test if clock, sleep, or networking changed.
3. Check the server log for anti-cheat warnings or kicks around sleep.
4. Update "tested with" claims only after recording the result.

## Recording results

Add a short entry to [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md): date, game version/revision, mod build, notable settings, players, what was checked, what was seen, and what it does not prove.
