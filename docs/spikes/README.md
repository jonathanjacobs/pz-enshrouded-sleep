# Spikes

Focused exploratory investigations and proof-of-concept work live in this directory.

The initial directory README was only scaffolding. That was incomplete once the project had already accumulated several material spike-style investigations. The early work has now been formalized retrospectively so future maintainers can trace each evidence question separately from the consolidated validation history.

## Spike index

| Spike | Status | Question |
|---|---|---|
| [`SPIKE-001-minutes-per-day-feasibility.md`](SPIKE-001-minutes-per-day-feasibility.md) | Completed / GO | Can `MinutesPerDay` compress world/calendar time without globally speeding active gameplay? |
| [`SPIKE-002-vanilla-sleep-lifecycle.md`](SPIKE-002-vanilla-sleep-lifecycle.md) | Completed / GO | Can the MVP rely on vanilla instantiated-player/sleep lifecycle and hand all-asleep back to vanilla? |
| [`SPIKE-003-client-clock-synchronization.md`](SPIKE-003-client-clock-synchronization.md) | Completed / GO | Why do client clocks jump, and can client pacing be corrected without changing server authority? |
| [`SPIKE-004-health-time-domains.md`](SPIKE-004-health-time-domains.md) | **Completed / GO for Public Alpha** | Which health/survival systems accelerate with compressed calendar time, and is any effect unsafe for awake players? |
| [`SPIKE-005-world-system-time-domains.md`](SPIKE-005-world-system-time-domains.md) | Open / deferred next-release priority | Which non-health world systems follow calendar time, and which can later be compensated safely? |
| [`SPIKE-006-awake-player-protection.md`](SPIKE-006-awake-player-protection.md) | **In progress — passive normalization GO; active-effects regression next** | Can awake hunger/thirst/fatigue/nutrition/weight be normalized during partial-sleep calendar compression without distorting vanilla active effects? |

SPIKE-006 test procedures:

- [`SPIKE-006-FIRST-TEST.md`](SPIKE-006-FIRST-TEST.md) — idle/passive normalization feasibility;
- [`SPIKE-006-ACTIVE-EFFECTS-TEST.md`](SPIKE-006-ACTIVE-EFFECTS-TEST.md) — eating/drinking/activity/suspension production-readiness regression.

## Required spike structure

Future spikes should use stable numbered filenames:

```text
SPIKE-007-short-title.md
SPIKE-008-short-title.md
```

Each spike should capture:

- status;
- question/hypothesis;
- why the question matters;
- scope and non-goals;
- instrumentation/test environment;
- procedure;
- evidence/results;
- conclusion;
- GO / CONDITIONAL GO / NO-GO or follow-up decision;
- links to resulting issues, ADRs, requirements, or implementation changes.

Spikes are evidence records, not normative product requirements. Final required behavior belongs in [`../REQUIREMENTS.md`](../REQUIREMENTS.md). Durable architectural choices belong in [`../ARCHITECTURE.md`](../ARCHITECTURE.md) and, when significant, an ADR.

The consolidated chronology remains in [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md).
