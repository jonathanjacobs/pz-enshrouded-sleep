# ADR-002 — Extend Vanilla Sleep/Lifecycle Semantics Instead of Replacing Them

Status: **Accepted**  
Decision established: v0.0.2/v0.0.3  
ADR written retrospectively: 2026-08-17

## Context

A multiplayer sleep mod could maintain its own registry of connected clients, loading states, readiness votes, respawn states, and sleep intentions. That approach would add substantial state-management complexity and risk diverging from Project Zomboid's own lifecycle semantics.

SPIKE-002 showed that server-side `getOnlinePlayers()`, `isDead()`, and `isAsleep()` provide enough authoritative instantiated-character state for the MVP, while also revealing that dead characters can remain present during respawn and loading clients may not yet have an `IsoPlayer`.

The same spike showed that vanilla all-asleep fast-forward uses a mechanism distinct from `MinutesPerDay`, so Enshrouded Sleep must not stack partial calendar compression on top of vanilla full-sleep behavior.

## Decision

The MVP will extend vanilla rather than replace it.

Population semantics:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

The mod will not maintain a separate pre-spawn/readiness registry for loading clients, respawn screens, spectators, or character-selection sessions.

When all currently instantiated living players are asleep, Enshrouded Sleep will restore the exact captured native `MinutesPerDay` and stop applying partial compression so vanilla Project Zomboid owns full-sleep fast-forward.

## Alternatives considered

### Custom connection/readiness registry

Rejected for MVP because it duplicates vanilla lifecycle state and adds synchronization/failure modes without evidence that it is required.

### Custom sleep eligibility / fatigue rules

Rejected because vanilla already owns sleep permission, fatigue, sleeping pills, traits, and waking behavior.

### Continue partial compression while everyone sleeps

Rejected because it would intentionally stack `MinutesPerDay` compression with vanilla full-sleep fast-forward and produce an uncontrolled combined time scale.

## Consequences

Positive:

- smaller, easier-to-reason-about state machine;
- compatibility with vanilla sleep eligibility and wake behavior;
- fewer custom lifecycle synchronization paths;
- exact baseline restoration before vanilla full-sleep handoff.

Tradeoff:

- a loading client does not affect the denominator until vanilla instantiates an `IsoPlayer`;
- death/respawn can temporarily change the denominator as vanilla changes instantiated character state;
- stricter readiness semantics would require a future architecture change if real Public Alpha usage proves this insufficient.

## Validation evidence

- [`../spikes/SPIKE-002-vanilla-sleep-lifecycle.md`](../spikes/SPIKE-002-vanilla-sleep-lifecycle.md)
- [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md)
- [`../REQUIREMENTS.md`](../REQUIREMENTS.md)
