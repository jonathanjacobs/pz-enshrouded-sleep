# SPIKE-003 — Client Clock Synchronization During Partial Compression

Status: **Completed / GO**  
Historical implementations: v0.0.5 through v0.0.7  
Validated platform: Project Zomboid Build 42.20.3

## Question

Why do sleeping and awake client clocks visibly jump during otherwise-correct server-side `MinutesPerDay` compression, and can the problem be corrected without changing server authority or globally accelerating gameplay?

## Trigger

The first successful two-player proportional test showed the server correctly running one-of-two partial sleep at `MinutesPerDay=4.5`, but both the sleeping black-screen clock and the awake HUD/watch clock appeared to hold and then jump.

## Diagnostic phase — v0.0.5

Read-only server/client telemetry showed a direct pacing mismatch:

```text
SERVER during partial sleep
MinutesPerDay = 4.5
world time advances smoothly

CLIENT during same interval
MinutesPerDay = 90
client advances at native day length
periodic multiplayer time correction
~51 in-game-minute visible jump
```

This established that a runtime server `MinutesPerDay` change is not automatically mirrored into the tested client's local GameTime pacing value.

## Synchronization experiment — v0.0.6

A narrowly scoped server/client synchronization path was added:

- server observes the authoritative `MinutesPerDay` produced by the proportional controller;
- server broadcasts an `EnshroudedSleep / ClockState` command on effective state changes plus a two-second heartbeat;
- client mirrors only the authoritative `MinutesPerDay` locally;
- client does not set `TimeOfDay`, `WorldAgeHours`, or any global simulation multiplier.

The first v0.0.6 run showed both clients adopting `MinutesPerDay=4.5`. Underlying client `TimeOfDay` then advanced at approximately the expected 5.33 game-minutes per real second and the prior ~51-minute sawtooth corrections disappeared.

Both visible clock paths were reported smooth and awake movement/actions remained normal-speed.

## v0.0.6 defect and v0.0.7 cleanup

The synchronization setter succeeded but post-apply logging used a Kahlua-unsafe `tonumber(safeMethod(...))` multi-return expression, causing repeated `Double` -> `String` `ClassCastException` errors on heartbeat packets.

v0.0.7 separated method return values before numeric conversion and also added a one-observer-pass transition settling guard so a new population state is not paired with a stale previous `MinutesPerDay` value.

The clean v0.0.7 regression passed:

- no Enshrouded Sleep client exceptions;
- server/client `90 -> 4.5 -> 90` transitions remained correct;
- sleeping black-screen clock remained smooth;
- awake HUD/watch clock remained smooth;
- awake gameplay remained normal-speed;
- vanilla full-sleep handoff and disconnect recalculation remained correct;
- sleep/wake timing remained consistent with vanilla `ForceWakeUpTime`.

## Decision

**GO.** Explicit client mirroring of authoritative server `MinutesPerDay` is required for coherent partial-sleep clock pacing.

The synchronization layer remains subordinate to server authority and does not independently calculate the proportional target.

## Follow-up

- ADR-003 records the client synchronization decision.
- Issues #1, #2, and #3 were closed after the clean v0.0.7 regression.
- SPIKE-004 investigates a different remaining risk: which health/survival systems accelerate in real time when calendar time is compressed.
