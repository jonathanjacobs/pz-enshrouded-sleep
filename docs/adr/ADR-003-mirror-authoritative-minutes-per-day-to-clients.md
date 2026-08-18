# ADR-003 — Mirror Authoritative `MinutesPerDay` to Connected Clients

Status: **Accepted**  
Decision established: v0.0.6/v0.0.7  
ADR written retrospectively: 2026-08-17

## Context

The first successful multiplayer partial-sleep run proved that the server-side proportional controller was correct but exposed a client presentation defect: both sleeping and awake clocks appeared to freeze and then jump forward.

SPIKE-003 showed that the server was running at `MinutesPerDay=4.5` while the client remained at `MinutesPerDay=90`. Client `TimeOfDay` therefore advanced too slowly between normal multiplayer time corrections, producing repeated jumps of roughly 51 in-game minutes.

The server must remain authoritative for actual world time and for the proportional sleep decision.

## Decision

Connected clients will mirror the authoritative effective server `MinutesPerDay` during multiplayer sessions.

The synchronization architecture is intentionally narrow:

1. the server proportional controller alone decides/applies the authoritative `MinutesPerDay`;
2. a server synchronization observer publishes the resulting value on state changes plus a low-frequency heartbeat;
3. the client accepts only the Enshrouded Sleep clock-state message and calls local `GameTime:setMinutesPerDay(target)`;
4. the client does **not** independently calculate the proportional target;
5. the client does **not** set `TimeOfDay`, `WorldAgeHours`, or the global simulation multiplier.

A one-observer-pass settling guard is used when visible player/sleep population changes so the synchronization observer publishes the controller's settled value instead of a stale previous value paired with the new state.

## Alternatives considered

### Rely only on native multiplayer clock correction

Rejected because the tested client continued to pace its local clock using the native 90-minute day and therefore repeatedly drifted between corrections.

### Force server clock synchronization more frequently

Not selected because it would treat the symptom by increasing correction frequency rather than making client local pacing agree with the server.

### Client-side `setTimeOfDay()` interpolation

Rejected because it would create a second client-side source of world-time authority and risk conflict with normal PZ multiplayer synchronization.

### Client independently calculates compression

Rejected because population/sleep policy belongs to the authoritative server and independent calculations could diverge.

## Consequences

Positive:

- sleeping black-screen and awake HUD/watch clocks progress smoothly;
- underlying client GameTime advances at approximately the same rate as the server between native multiplayer corrections;
- awake gameplay remains normal-speed;
- vanilla client sleep counters remain meaningful relative to compressed world time.

Tradeoff:

- the mod now requires a small client component as well as server code;
- clients need the same local mod snapshot while distribution remains manual;
- synchronization APIs and client `setMinutesPerDay()` remain integration points to regression-test when Project Zomboid changes.

## Validation evidence

- [`../spikes/SPIKE-003-client-clock-synchronization.md`](../spikes/SPIKE-003-client-clock-synchronization.md)
- GitHub issues #1, #2, and #3 (closed after v0.0.7 regression)
- [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md)
