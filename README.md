# Enshrouded Sleep - Player/Connection State Probe v0.0.2b

Diagnostic instrumentation build for Project Zomboid Build 42.20+.

## Purpose

This build validates the remaining multiplayer lifecycle and vanilla sleep-fast-forward information needed by the eventual Enshrouded-style sleep mechanic.

It intentionally **does not modify** `MinutesPerDay`, `GameTime` multipliers, or simulation speed.

## What it logs

The server scans once per real second and logs two domains:

### Instantiated players

From `getOnlinePlayers()`:

- in-world player count
- player object additions/removals
- username and display name
- online ID
- Lua/Java object identity
- asleep/awake state via `isAsleep()`
- dead/alive state via `isDead()`
- access level/admin state
- god mode state
- coordinates

### Network connections

From `GameServer.udpEngine.connections`:

- connection count
- connection add/remove/state changes
- username
- Steam ID / owner ID
- connection GUID/object identity
- access-level byte
- `isFullyConnected()`
- `wasInLoadingQueue`
- connection type
- whether the connection currently has an instantiated `IsoPlayer`

This is specifically intended to identify the authenticated/loading interval before a player appears in `getOnlinePlayers()`.

## Vanilla sleep telemetry

While any player is asleep, or while `GameServer.bFastForward` is true, the probe logs once per real second:

- world clock
- connection count
- in-world/living/sleeping/dead counts
- `GameServer.bFastForward`
- configured server `FastForwardMultiplier`
- `MinutesPerDay`
- `getMultiplier()`
- `getServerMultiplier()`
- `getTrueMultiplier()`
- `WorldAgeHours`

This should show exactly how vanilla B42 full-sleep fast-forward behaves on the dedicated server.

## Log filter

Search the server console/log for:

`[EnshroudedSleep:Probe]`

Important event types include:

- `CONNECTION COUNT CHANGED`
- `CONNECTION ADDED`
- `CONNECTION STATE CHANGED`
- `CONNECTION REMOVED`
- `CONNECTION HEARTBEAT`
- `PLAYER COUNT CHANGED`
- `PLAYER ADDED`
- `PLAYER STATE CHANGED`
- `PLAYER REMOVED`
- `HEARTBEAT`
- `SLEEP TELEMETRY`
- `SLEEP TELEMETRY END`

## Recommended v0.0.2b solo test

1. Restart the server with this build.
2. Connect normally as the existing admin account; do not use `-debug` for the first run.
3. Leave God Mode off.
4. Ensure `SleepAllowed=true` and `SleepNeeded=true`.
5. Fully spawn and remain awake for roughly 20 seconds.
6. Become tired naturally and sleep.
7. Remain asleep until vanilla wakes the character, or at least long enough to capture 20-30 seconds of sleep telemetry.
8. Remain awake for another 10 seconds.
9. Log out normally.
10. Save the normal server console and connection log.

A second player is not required for this diagnostic.

## Failure behavior

All Java/network API access is wrapped defensively. If a B42 field is not Lua-accessible on the dedicated server, the probe should log `N/A`, `ERROR`, or `CONNECTION TELEMETRY UNAVAILABLE` rather than modifying or interrupting gameplay.

## Mod ID

The diagnostic Mod ID remains:

`EnshroudedSleepClockSpike`

This is intentionally unchanged so the development server does not need its `Mods=` configuration edited.

## Version

`0.0.2b`
