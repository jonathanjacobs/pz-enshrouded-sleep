# Testing

Status: **Current for v1.0.2**

Do not update for: a test that was run (record it in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md)), or a change in what the mod should do (change the requirements in [`DESIGN.md`](DESIGN.md#requirements) first).

Short checks for a multiplayer-server mod. Logs from normal play count as evidence; staged tests are only needed when normal play does not cover a change. Record results in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); expected behavior is in the [requirements](DESIGN.md#requirements); long experimental procedures live in [`spikes/`](spikes/).

## Contents

- [Before testing](#before-testing)
- [Smoke test](#smoke-test)
- [Two-player sleep test](#two-player-sleep-test)
- [Feature checks](#feature-checks)
- [After a Project Zomboid update](#after-a-project-zomboid-update)
- [Routine monitoring](#routine-monitoring)
- [Chasing a problem](#chasing-a-problem)
- [Engine logging note](#engine-logging-note)
- [Local files and automation](#local-files-and-automation)

## Before testing

Staged tests run on a remote dedicated server with 2 players; normal play on a live server also counts as evidence.

- `bash tools/validate-package.sh` passes for the build under test, and so does `bash tools/check-lua-syntax.sh` (or the "Check Lua syntax" CI job, where no Lua 5.1 compiler is installed locally).
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
- **Package metadata or the Version module:** the mod appears in the server's and client's mod lists; every server `Loaded v…` banner and `CONFIG | build=` line shows the new version; each client logs `SERVER_BUILD |` with that version and no `BUILD_MISMATCH`; and neither side logs a Lua error mentioning `EnshroudedSleep/Version`. The smoke test covers the rest.

## After a Project Zomboid update

1. Skim the patch notes and modding news for changes to game time, sleep, player stats, XP, networking, anti-cheat, or moodle UI.
2. Run the smoke test; run the two-player sleep test if clock, sleep, or networking changed.
3. Check the server log for anti-cheat warnings or kicks around sleep.
4. Update "tested with" claims only after recording the result: date, game version/revision, mod build, and what was seen.

## Routine monitoring

With verbose diagnostics disabled, low-volume controller/roster/protection/benefit transitions should provide enough context to identify normal sleep-state changes without generating large logs.

Pay attention to:

- baseline restoration after sleepers wake;
- protection status matching the actual awake/sleeping roster;
- joins/disconnects/deaths/respawns during partial sleep;
- recurring client clock corrections;
- notification `CONFIG` state matching the intended administrator setting;
- repeated or missing sleep-status notifications when the option is enabled;
- `SleepBenefits` grants/clears matching actual sleep duration when the feature is enabled;
- runaway/repeated XP bonus messages or implausible XP gains;
- Well Rested reducing Endurance expenditure rather than only increasing recovery;
- sleep-benefit Moodle UI errors, stale icons, or overlap with vanilla/Lifestyle moodles;
- `WRITE_FAILURE_FAIL_OPEN` messages;
- recurring Enshrouded Sleep Lua exceptions;
- unusual server responsiveness or log volume;
- conflicts with mods that alter sleep, time, CharacterStats, nutrition, timed actions, XP, Endurance, or chat/UI.

## Chasing a problem

1. Save the normal server and client logs around the event.
2. Turn on `DiagnosticsEnabled=true`, reproduce once, then turn it off.
3. Collect the server console/DebugLog and the affected client's DebugLog. Log prefixes start with `[EnshroudedSleep`.

For a reproducible problem, enable `DiagnosticsEnabled=true` only for the shortest useful window, reproduce once if safe, then disable it again.

For normal multiplayer evidence, keep:

```text
DiagnosticForcedCompressionFactor=1.0
```

Collect:

```text
server console
server DebugLog / Logs
affected owning-client DebugLog when available
```

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

Server logs record IP addresses, Steam IDs, and player names. Keep the raw logs in a local folder outside the repository (see [Local files and automation](#local-files-and-automation)), and quote only the lines that matter, with those values replaced, in validation history, spikes, or issues ([`PRIVATE_DATA.md`](PRIVATE_DATA.md)).

If an optional layer is the suspect, turn it off first using the rollback steps in [`RELEASING.md`](RELEASING.md#rollback).

## Engine logging note

Project Zomboid's client debug log is capped in place with no rotation (observed around 4.3MB on one machine): once a session's log volume crosses that line, the engine silently drops its own oldest lines rather than archiving them. A long or verbose diagnostic session can lose its early evidence this way. Keep per-event diagnostics off by default, and if a session needs verbose logging over a long run, snapshot the client log between test phases rather than relying on its final state.

## Local files and automation

Keep test logs, decompiled game source, and research material (saved wiki or Javadoc pages, other mods studied for ideas) in local folders outside the repository. Logs carry private details, and decompiled source and other mods may be studied but never redistributed ([`PZ_MODDING_POLICY.md`](PZ_MODDING_POLICY.md)). `.gitignore` still ignores `Logs/`, `decompiled/`, `research-source/`, and Java files, in case copies end up inside the repository anyway.

A coding agent cannot see those folders by default. In Claude Code, `/add-dir <path>` grants access for one session, and `permissions.additionalDirectories` in `.claude/settings.local.json` grants it every session on that computer without committing the path.

Once the same test cycle repeats, scripts for its non-gameplay steps save time. Put them in `tools/` and document them in [`../tools/README.md`](../tools/README.md). Useful ones:

- **Deploy:** mirror `Contents/mods/<mod-id>/` into the local Project Zomboid mods folder, and optionally to a remote test server. Do not clear the game's logs first: Project Zomboid archives each session's logs into a dated `logs_<date>` folder at startup, and clearing them destroys that archive.
- **Collect:** after a session, archive the client logs, and the remote server's logs if configured, into the local logs folder.
- **Snapshot:** copy the current client log into a timestamped folder mid-session without stopping anything, for the log cap described above.

For a remote test server, keep its connection details in an ignored `.env.server` file and commit a placeholder copy such as `server.env.example`:

```text
SFTP_HOST=
SFTP_PORT=
SFTP_USERNAME=
SFTP_PASSWORD=
SFTP_HOST_FINGERPRINT_SHA256=
REMOTE_MOD_PATH=
REMOTE_LOGS_PATH=
```

Have scripts skip the remote steps until the real file exists with real values. Verify the server's host key fingerprint once and record it in that file, since some SFTP clients refuse to connect without it. Scripts should print a label such as "remote test server" instead of the address or credentials, which are otherwise easy to paste into an issue or a chat. `tools/check-sensitive-content.sh` fails on a tracked `.env` file or a filled-in `*PASSWORD=` line; see [`PRIVATE_DATA.md`](PRIVATE_DATA.md).
