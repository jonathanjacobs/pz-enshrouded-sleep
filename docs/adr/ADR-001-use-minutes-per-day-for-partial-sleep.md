# ADR-001 — Use `MinutesPerDay` for Partial-Sleep Calendar Compression

Status: **Accepted**  
Decision established: v0.0.1/v0.0.3  
ADR written retrospectively: 2026-08-17

## Context

Enshrouded Sleep needs world/calendar time to progress faster when some multiplayer survivors are asleep while awake players continue playing normally.

A global Project Zomboid fast-forward mechanism would risk accelerating movement, combat, zombies, vehicles, animations, physics, and timed actions. The project therefore needed a clock-control primitive that changes the real-world duration of the in-game day without globally accelerating active simulation.

SPIKE-001 demonstrated that changing server `GameTime:MinutesPerDay` from a native baseline of 90 to 4.5 advanced world/calendar time and `WorldAgeHours` at approximately 20x while `TrueMultiplier` remained 1 and active gameplay did not visibly speed up.

## Decision

Partial sleep will be implemented by dynamically changing authoritative server `GameTime:MinutesPerDay`.

The authoritative controller will **not** call `GameTime:setMultiplier()` for partial sleep.

The core policy is:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = FastForwardMultiplier * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

## Alternatives considered

### Global simulation multiplier

Rejected because it would couple sleeping convenience to active gameplay speed and violate the requirement that awake players continue interacting normally.

### Cosmetic clock-only acceleration

Rejected because the goal is for actual Project Zomboid world/calendar time to pass, not merely for the clock UI to animate faster.

### Custom replacement world clock

Rejected as unnecessarily invasive and likely to create compatibility problems with vanilla systems that already depend on GameTime.

## Consequences

Positive:

- awake active simulation can remain normal-speed;
- vanilla/world systems see genuine elapsed calendar time;
- the mechanism scales continuously with sleeping fraction.

Tradeoff:

- any system tied to game minutes or `WorldAgeHours` may also progress faster in real time during partial sleep;
- those time-domain effects must be measured and, where necessary, documented or compensated individually.

SPIKE-004 exists specifically to characterize the player-health/survival consequences of this tradeoff before Public Alpha deployment.

## Validation evidence

- [`../spikes/SPIKE-001-minutes-per-day-feasibility.md`](../spikes/SPIKE-001-minutes-per-day-feasibility.md)
- [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md)
- [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
