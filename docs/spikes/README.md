# Spikes

Do not update for: planned test procedures ([`../TESTING.md`](../TESTING.md)), dated test results that are not part of an open question ([`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md)), or release claims.

Use a spike for a bounded feasibility question or uncertain engine behavior: *does this event fire on a dedicated server?*, *can the client read this value without a server round trip?*, *why does this option reset after a restart?* Name it `SPIKE-###-short-topic.md`. Numbers are never reused.

A question you can answer in an hour and explain in a sentence does not need a spike. Write one when the answer will shape a requirement, an architecture choice, or an ADR, or when the reasoning would be expensive to reconstruct later.

A spike is evidence, not a release claim. Promote supported conclusions into requirements, architecture, or an ADR when appropriate; until then, a conclusion recorded only in a spike is not a requirement or a validated behavior.

Write up a NO-GO as carefully as a GO. It records the evidence that ruled the approach out, so the question is not reopened months later by someone, or some agent, with no way of knowing it was already answered.

Spikes are where log excerpts and server details get pasted while work is still informal. Follow [`../PRIVATE_DATA.md`](../PRIVATE_DATA.md): describe the test server by kind and replace IP addresses, Steam IDs, and player names with placeholders.

## Status

| Status | Meaning |
| --- | --- |
| `Open` | Still being investigated |
| `GO` | The evidence supports the approach |
| `GO with conditions` | Supported only within the stated limits |
| `NO-GO` | The evidence does not support the approach |
| `Inconclusive` | Work stopped without a usable answer; the spike says why |
| `Superseded` | A later spike replaced this one; link to it |

Leave a finished spike in place. If later evidence overturns it, write a new spike and mark this one `Superseded`.

## Index

One line per spike with its status, so the state of open questions is visible without opening every file. Spikes written before this index format keep their original status wording.

| Spike | Status | Question |
|---|---|---|
| [`SPIKE-001-minutes-per-day-feasibility.md`](SPIKE-001-minutes-per-day-feasibility.md) | Completed / GO | Can `MinutesPerDay` compress world/calendar time without globally speeding active gameplay? |
| [`SPIKE-002-vanilla-sleep-lifecycle.md`](SPIKE-002-vanilla-sleep-lifecycle.md) | Completed / GO | Can the MVP rely on vanilla instantiated-player/sleep lifecycle and hand all-asleep back to vanilla? |
| [`SPIKE-003-client-clock-synchronization.md`](SPIKE-003-client-clock-synchronization.md) | Completed / GO | Why do client clocks jump, and can client pacing be corrected without changing server authority? |
| [`SPIKE-004-health-time-domains.md`](SPIKE-004-health-time-domains.md) | **Completed / GO for Public Alpha** | Which health/survival systems accelerate with compressed calendar time, and is any effect unsafe for awake players? |
| [`SPIKE-005-world-system-time-domains.md`](SPIKE-005-world-system-time-domains.md) | Open / deferred next-release priority | Which non-health world systems follow calendar time, and which can later be compensated safely? |
| [`SPIKE-006-awake-player-protection.md`](SPIKE-006-awake-player-protection.md) | **Completed / GO; promoted in v0.1.0** | Can awake hunger/thirst/fatigue/nutrition/weight be normalized during partial-sleep calendar compression without distorting vanilla active effects? |
| [`SPIKE-007-sleep-benefits.md`](SPIKE-007-sleep-benefits.md) | **Completed / GO; live WHG evidence reviewed 2026-09-28** | Can voluntary multiplayer sleep grant a configurable, non-stacking, server-authoritative Rested / Well Rested reward without making sleep mandatory? |

Test procedures recorded alongside their spikes:

- [`SPIKE-005-FIRST-TEST.md`](SPIKE-005-FIRST-TEST.md) — first runtime test: food aging and generator fuel at baseline versus 10x;
- [`SPIKE-005-VEHICLE-BATTERY-TEST.md`](SPIKE-005-VEHICLE-BATTERY-TEST.md) — SPIKE-005 vehicle battery drain test;
- [`SPIKE-006-FIRST-TEST.md`](SPIKE-006-FIRST-TEST.md) — idle/passive normalization feasibility;
- [`SPIKE-006-ACTIVE-EFFECTS-TEST.md`](SPIKE-006-ACTIVE-EFFECTS-TEST.md) — eating/drinking/activity/suspension production-readiness regression.

## Record structure

Keep only the sections that help someone judge or repeat the work.

```markdown
# SPIKE-###: <short title>

- Status: Open | GO | GO with conditions | NO-GO | Inconclusive | Superseded
- Started / last updated: YYYY-MM-DD
- Related requirement, ADR, or issue: <links>

## Question

The single question this answers, and what decision depends on it.

## What would settle it

The result that would mean GO, and the result that would mean NO-GO. Write this before running anything, so the answer is not chosen after seeing the logs.

## Environment and procedure

Project Zomboid version and revision, mod build, topology described by kind, and the steps taken, in enough detail for someone else to repeat them.

## Evidence

What was observed, including unexpected, partial, and negative results, with the relevant log lines (private values replaced). Raw logs stay in a local folder outside the repository.

## Outcome

The status, what the evidence supports and what it does not, and the conditions under which the conclusion may not hold.

## Follow-up

The requirement, architecture note, ADR, test, or issue this produced, and any question left open.
```
