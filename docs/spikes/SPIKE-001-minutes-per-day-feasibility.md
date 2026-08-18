# SPIKE-001 — `MinutesPerDay` Calendar-Compression Feasibility

Status: **Completed / GO**  
Historical implementation: v0.0.1  
Test platform: Project Zomboid Build 42.20.2

## Question

Can a dedicated Project Zomboid server shorten the real-world duration of a PZ day by changing `GameTime:MinutesPerDay` without globally accelerating active gameplay simulation?

## Why this mattered

The Enshrouded Sleep concept requires world/calendar time to move faster while some players sleep, but awake players must still move, fight, drive, craft, and interact at normal speed. A global `GameTime:setMultiplier()` solution would not meet that requirement.

## Scope

The spike tested only the clock-control primitive. It did not attempt multiplayer sleep-state logic, client synchronization, or production configuration.

## Method

The v0.0.1 diagnostic:

1. captured the live server `MinutesPerDay` baseline;
2. temporarily set `MinutesPerDay` to `baseline / 20`;
3. observed world/calendar progression and gameplay behavior;
4. restored the exact captured baseline;
5. did not call `GameTime:setMultiplier()`.

The test server baseline was `MinutesPerDay=90`; the spike target was `4.5`.

## Result

World/calendar time and `WorldAgeHours` advanced at approximately the intended 20x calendar-compression rate while `TrueMultiplier` remained `1` and active gameplay did not visibly fast-forward.

## Decision

**GO.** `MinutesPerDay` is a viable primitive for partial-sleep calendar compression.

This result established the central project distinction:

> Enshrouded Sleep dynamically changes the real-world duration of a 24-hour PZ day; it does not speed up the active simulation.

## Follow-up

- SPIKE-002 investigated vanilla player/sleep lifecycle semantics and full-sleep handoff.
- ADR-001 records the decision to use `MinutesPerDay` rather than a global multiplier.
- Current normative behavior is defined in [`../REQUIREMENTS.md`](../REQUIREMENTS.md).
