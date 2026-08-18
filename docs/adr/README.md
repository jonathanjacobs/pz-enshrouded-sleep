# Architecture Decision Records

Formal architecture decisions live in this directory when a decision is important enough that future maintainers should understand the alternatives, rationale, and consequences.

The initial directory README was only scaffolding. That was incomplete because the project already had several durable architectural decisions established through controlled spikes. Those decisions are now documented retrospectively as ADR-001 through ADR-003.

## ADR index

| ADR | Status | Decision |
|---|---|---|
| [`ADR-000-record-format.md`](ADR-000-record-format.md) | Accepted / process | Defines the ADR format, status vocabulary, and numbering convention. |
| [`ADR-001-use-minutes-per-day-for-partial-sleep.md`](ADR-001-use-minutes-per-day-for-partial-sleep.md) | Accepted | Use `GameTime:MinutesPerDay` for partial-sleep calendar compression rather than global simulation fast-forward. |
| [`ADR-002-extend-vanilla-sleep-lifecycle.md`](ADR-002-extend-vanilla-sleep-lifecycle.md) | Accepted | Use vanilla instantiated-player/sleep lifecycle semantics and restore baseline before vanilla full-sleep handoff. |
| [`ADR-003-mirror-authoritative-minutes-per-day-to-clients.md`](ADR-003-mirror-authoritative-minutes-per-day-to-clients.md) | Accepted | Explicitly mirror the authoritative server `MinutesPerDay` to clients for coherent local clock pacing. |

No ADR-004 exists yet. [`SPIKE-004`](../spikes/SPIKE-004-health-time-domains.md) is deliberately an investigation first; an ADR should be created only if its evidence leads to a new durable policy, such as targeted compensation or a deployment-time compression cap.

## ADR convention

Future architectural decisions should use stable numbered filenames:

```text
ADR-004-short-title.md
ADR-005-short-title.md
```

Recommended sections:

- Status
- Context
- Decision
- Alternatives considered
- Consequences / tradeoffs
- Validation evidence
- Related issues/spikes/commits

ADRs record durable architectural choices, not transient debugging notes. Current architecture is summarized in [`../ARCHITECTURE.md`](../ARCHITECTURE.md), while normative required behavior is defined in [`../REQUIREMENTS.md`](../REQUIREMENTS.md).
