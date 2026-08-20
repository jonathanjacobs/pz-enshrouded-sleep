# Public Alpha Deployment Guide

Current deployment status: **Steam Workshop Public Alpha published; Workshop-distributed server validation pending**  
Current version: `v0.0.10`  
Validated core platform: Project Zomboid `42.20.3`  
Project Zomboid Mod ID: `pz-enshrouded-sleep`  
Steam Workshop ID: `3786842301`

Workshop page:

```text
https://steamcommunity.com/sharedfiles/filedetails/?id=3786842301
```

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player is outside project scope.

[`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md) is complete and returned **GO**. Detailed test evidence remains in the spike/validation documentation rather than the public README.

For Workshop publication/update mechanics, see [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md).

## Public Alpha configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

`DiagnosticForcedCompressionFactor` is **server-test-only** and must remain at `1.0` during normal Public Alpha play.

`DiagnosticsEnabled=true` produces high-volume clock/sleep, health/body, CharacterStat, Moodle, nutrition and multiplier-context telemetry. Enable it only for controlled troubleshooting/regression sessions.

## Steam Workshop installation

A Workshop-backed dedicated server uses both identifiers:

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

The Workshop ID identifies the Steam package to download. `pz-enshrouded-sleep` is the stable Project Zomboid Mod ID loaded by the game.

Players should use the Workshop-distributed copy when joining a Workshop-configured server rather than maintaining a separate manual copy of the same mod.

## Authoritative runtime tree

The repository itself is intentionally structured as a Project Zomboid Workshop package. There is one authoritative deployable mod tree:

```text
Contents/mods/pz-enshrouded-sleep/
```

Do not create or maintain a second root-level `42/`, `common/`, or `mod.info` runtime copy.

The repository/Workshop wrapper may also contain public engineering documentation such as `README.md`, `docs/`, licensing/notices, the changelog, `workshop-description.bbcode`, and Workshop artwork. Source-control metadata (`.git/`), private logs, credentials, local test artifacts, and other non-public material must not be copied into the local Workshop authoring directory.

## Manual installation

For manual installation from the Git repository, copy only the **inner deployable mod directory**:

```text
Contents/mods/pz-enshrouded-sleep/
```

### Client

Copy it so the resulting path is:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

### Dedicated server

Copy it into the server's normal mod directory so the resulting path is equivalent to:

```text
mods/pz-enshrouded-sleep/
```

Then configure:

```text
Mods=pz-enshrouded-sleep
```

Do **not** place the whole repository/Workshop wrapper into `Zomboid\mods`; the repository root is the Workshop item/project wrapper, not the runtime mod root.

## Current Workshop validation gate

The initial Workshop item has been uploaded and the permanent ID has been recorded. Before treating the Workshop-distributed package as fully deployment-validated:

1. Subscribe/download Workshop item `3786842301`.
2. Inspect the delivered payload and confirm the expected runtime tree and artwork.
3. Configure the dedicated test server with:

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

4. Run the Tier 1 startup smoke test using the Workshop-distributed copy.
5. Run a short two-player partial-sleep regression if practical.
6. Verify disable/rollback behavior when practical.
7. Confirm intended Workshop visibility and the canonical public description from `workshop-description.bbcode`.

GitHub issue #5 tracks these remaining Workshop-distribution checks.

## Public Alpha deployment procedure

Once the Workshop-distributed copy has passed the startup smoke test:

1. Announce the deployment/restart.
2. Stop the server cleanly.
3. Back up world/save and server configuration.
4. Preserve the previous known-good mod package/configuration.
5. Configure `WorkshopItems=3786842301` and `Mods=pz-enshrouded-sleep`.
6. Verify `DiagnosticsEnabled=false` and `DiagnosticForcedCompressionFactor=1.0`.
7. Start the server and confirm no Enshrouded Sleep Lua exception.
8. Confirm server/client package/version consistency.
9. Perform a brief two-player live smoke check before opening normal play if practical.
10. Confirm baseline `MinutesPerDay` is restored when all players are awake.

Expected low-volume prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

## Known Public Alpha behavior

World/calendar time genuinely advances faster during partial sleep. Measured hunger, thirst, fatigue, calories and macronutrient stores therefore progressed with elapsed world/calendar time during controlled validation.

Measured acute bleeding/body-health loss and resting endurance recovery did not scale with calendar compression under the tested conditions.

Pathological states not directly exercised in SPIKE-004 — active sickness/food poisoning, poison, zombie infection/fever and extreme thermal injury — remain field-characterization targets.

See [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md) for the evidence and exact measured ratios.

## Public Alpha monitoring priorities

Pay particular attention to:

- 3+ player proportional fractions;
- joins/disconnects/deaths/respawns;
- repeated sleep/wake cycles;
- clock continuity and exact baseline restoration;
- normal-speed awake movement/actions;
- unexpected health/survival progression beyond documented world-time behavior;
- client errors or repeated day-length pacing resets;
- non-health world-time systems such as spoilage, crops, generators, corpses, composting and weather;
- interaction with the live server mod stack.

A few isolated client `MinutesPerDay` resets were seen during aggressive live sandbox/debug factor changes in SPIKE-004. The authoritative server remained correct and the normal heartbeat restored the client value within roughly a second. Treat repeated occurrences during ordinary play as a bug worth collecting logs for.

## Focused diagnostics

Normal troubleshooting:

```lua
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor = 1.0
```

Only for a controlled one-connected-player multiplayer-server regression may the forced factor be raised above `1.0`.

Relevant prefixes:

```text
[EnshroudedSleepDiag][SERVER]
[EnshroudedSleepDiag][CLIENT]
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Collect server console/logs and affected client logs, then disable diagnostics after the shortest practical reproduction.

## Rollback

1. Stop the server cleanly.
2. Preserve incident logs.
3. Remove/disable `pz-enshrouded-sleep` and/or Workshop item `3786842301` through the normal server workflow.
4. Restore prior configuration if needed.
5. Restart and confirm native time/sleep behavior.

The mod does not maintain a custom persistent sleep database. Removing it returns **future** sleep/time behavior to vanilla. World time or time-driven world changes that already occurred can only be undone by restoring a prior save backup.

## Rollback triggers

Roll back and investigate if:

- compressed `MinutesPerDay` persists after baseline should be restored;
- awake simulation globally accelerates;
- clients repeatedly lose clock pacing synchronization during ordinary play;
- recurring Enshrouded Sleep exceptions appear;
- awake health/survival state becomes dangerously accelerated beyond documented SPIKE-004 behavior;
- a time-driven world system causes severe persistent player/world-state damage.
