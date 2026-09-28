# Enshrouded Sleep — Testing Guide

Short checks for a multiplayer-server mod. Logs from normal play count as evidence; staged tests are only needed when normal play does not cover a change. Record results in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); expected behavior is in [`REQUIREMENTS.md`](REQUIREMENTS.md); long experimental procedures live in [`spikes/`](spikes/).

## Contents

- [Before testing](#before-testing)
- [Smoke test](#smoke-test)
- [Two-player sleep test](#two-player-sleep-test)
- [Feature checks](#feature-checks)
- [After a Project Zomboid update](#after-a-project-zomboid-update)
- [Chasing a problem](#chasing-a-problem)

## Before testing

- Server and clients show the same Project Zomboid `version=` / `revision=` line and the same Enshrouded Sleep build (server `CONFIG`, client `SERVER_BUILD`).
- Only one copy of the mod is installed (no duplicate local/Workshop copies with the same Mod ID).
- Note the server `CONFIG` lines; expected results use the active settings, not the shipped defaults.

## Smoke test

Run after any change, new release, or Project Zomboid update.

1. Server starts and a client joins with no Enshrouded Sleep Lua errors on either side.
2. With everyone awake, server and client `MinutesPerDay` stay at the baseline.
3. Disabled features stay quiet: no banners with notifications off, no Rested/Well Rested with benefits off, no diagnostic spam.

## Two-player sleep test

Run when clock, sleep, network, or awake-protection behavior may have changed. A normal session where someone sleeps while someone else is awake counts.

1. One player sleeps, one stays awake: time speeds up in proportion to the sleeping fraction, both clients follow the server's `MinutesPerDay`, and the awake player acts at normal speed.
2. The sleeper wakes: day length returns exactly to baseline.
3. Everyone sleeps: baseline is restored and vanilla full-sleep fast-forward takes over.

## Feature checks

Only when that feature changes.

- **Sleep notifications:** one banner per sleep-state change on each client (for example `[Enshrouded Sleep] 1/2 living players sleeping (50%). World time is 20x faster.`), no spam, and turning the option off stops messages.
- **Rested / Well Rested:** sleep length gives the expected tier for the active thresholds, XP gains show the configured bonus with one server `XP_BONUS` line per event, and the Moodle icon shows without overlapping other moodles.

## After a Project Zomboid update

1. Skim the patch notes and modding news for changes to game time, sleep, player stats, XP, networking, anti-cheat, or moodle UI.
2. Run the smoke test; run the two-player sleep test if clock, sleep, or networking changed.
3. Check the server log for anti-cheat warnings or kicks around sleep.
4. Update "tested with" claims only after recording the result: date, game version/revision, mod build, and what was seen.

## Chasing a problem

1. Save the normal server and client logs around the event.
2. Turn on `DiagnosticsEnabled=true`, reproduce once, then turn it off.
3. Collect the server console/DebugLog and the affected client's DebugLog. Log prefixes start with `[EnshroudedSleep`.

If an optional layer is the suspect, turn it off first using the rollback steps in [`DEPLOYMENT.md`](DEPLOYMENT.md).
