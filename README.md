# Enshrouded Sleep - Player State Probe v0.0.2

Diagnostic instrumentation build for Project Zomboid Build 42.20+.

## Purpose

This build validates the multiplayer player-lifecycle and sleep/death state information needed by the eventual Enshrouded-style sleep mechanic.

It intentionally **does not modify** `MinutesPerDay`, `GameTime` multipliers, or any simulation speed.

## What it logs

The server scans `getOnlinePlayers()` once per real second and logs:

- changes in instantiated in-world player count
- player object additions and removals
- username and display name
- online ID
- Lua/Java object identity
- asleep/awake state via `isAsleep()`
- dead/alive state via `isDead()`
- access level / admin state
- god mode state
- player coordinates

Every 10 seconds by default it also emits a complete heartbeat snapshot of all instantiated players.

## Log filter

Search the server console/log for:

`[EnshroudedSleep:Probe]`

Important event types include:

- `PLAYER COUNT CHANGED`
- `PLAYER ADDED`
- `PLAYER STATE CHANGED`
- `PLAYER REMOVED`
- `HEARTBEAT`
- `PLAYER SNAPSHOT`

## Recommended lifecycle test

Keep one stable admin character online while a second player performs this sequence:

1. Connect and fully spawn.
2. Run around for approximately 30 seconds.
3. Die.
4. Remain connected through the death / new-character flow.
5. Create and spawn a replacement character.
6. Run around for approximately 30 seconds.
7. Die again.
8. Remain in the post-death state for 20-30 seconds.
9. Disconnect completely.

Record approximate real-world timestamps for the first spawn, first death, replacement spawn, second death, and logout.

Collect both the normal server console and the connection log. Together they let us correlate authenticated/network-connected sessions with instantiated `IsoPlayer` objects.

## Sleep-state test

With a single player, also test entering and leaving sleep if convenient. The probe should emit `PLAYER STATE CHANGED` when `isAsleep()` changes.

## Mod ID

The diagnostic Mod ID remains:

`EnshroudedSleepClockSpike`

This is intentionally unchanged from v0.0.1 so an existing development server does not need its `Mods=` configuration edited.

## Version

`0.0.2`
