# Enshrouded Sleep — Testing Guide

This document owns current regression and field-test procedures. Historical results belong in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md); detailed experimental protocols/results belong under [`spikes/`](spikes/).

Enshrouded Sleep is tested as a multiplayer-server mod. Local/standalone single-player is outside scope.

## Tier 1 — startup smoke test

Run after runtime/configuration changes, a new release candidate, or a relevant Project Zomboid update.

1. Start the dedicated server and confirm no Enshrouded Sleep Lua exception.
2. Connect at least one client and confirm no Enshrouded Sleep client exception.
3. Confirm the core controller, client clock sync, roster logger, awake-protection module, and sleep-notification modules load.
4. With all living players awake, confirm authoritative/client `MinutesPerDay` remains at the native baseline.
5. Confirm `DiagnosticsEnabled=false` does not produce high-frequency diagnostic telemetry.
6. Confirm `DiagnosticForcedCompressionFactor=1.0` is inert.
7. With `SleepNotificationsEnabled=false`, confirm no Enshrouded Sleep sleep-state chat messages are emitted.

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

1. Start with `SleepNotificationsEnabled=true`, at least two living players, and no sleepers. Confirm no startup/all-awake notification is sent.
2. Put one player to sleep. Confirm every connected client receives exactly one concise server-chat message such as `[Enshrouded Sleep] 1/2 living players sleeping (50%). Time is 20x faster.`
3. Change the sleep fraction by sleeping/waking another player or changing the connected living population. Confirm exactly one updated message is sent after the authoritative clock state settles.
4. Wake all players. Confirm one `[Enshrouded Sleep] All living players are awake. Time is normal.` message.
5. Put all living players to sleep. Confirm the message reports the living-player count and identifies vanilla full-sleep fast-forward rather than claiming an Enshrouded Sleep compression multiplier.
6. Confirm there is no per-tick/repeated chat spam and no Enshrouded Sleep Lua exception.
7. Set `SleepNotificationsEnabled=false` and confirm subsequent sleep-state changes no longer emit messages while proportional sleep continues normally.

The relevant low-volume prefixes are `[EnshroudedSleepNotify][SERVER]` and `[EnshroudedSleepNotify][CLIENT]`. A client chat-bridge failure should circuit-break notification display for that client session without affecting sleep/time behavior. If the notification path causes a live compatibility issue, disable `SleepNotificationsEnabled` first and preserve the server/client logs before changing the core sleep configuration.

## Tier 3 — Public Beta multiplayer protection field test

This is the principal Beta validation path.

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

1. review changes affecting `GameTime`, multiplayer sleep/lifecycle, CharacterStats, Nutrition, networking/command APIs, and any subsystem touched by the release;
2. check runtime Lua for removed/restricted APIs introduced by the game update;
3. run Tier 1;
4. run Tier 2 if clock/sleep/network behavior may have changed;
5. run Tier 3 or a focused SPIKE only when the changed engine area justifies it;
6. update validation claims only after evidence is collected.
