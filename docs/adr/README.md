# Architecture Decision Records

Formal architecture decisions belong in this directory when a decision is significant enough that future maintainers should understand the alternatives and rationale.

The current architecture is summarized in [`../ARCHITECTURE.md`](../ARCHITECTURE.md), and normative behavior is defined in [`../REQUIREMENTS.md`](../REQUIREMENTS.md). No retroactive ADR is required merely to duplicate those documents.

Future ADRs should use a stable numbered filename such as:

```text
ADR-001-short-title.md
ADR-002-short-title.md
```

Recommended sections:

- Status
- Context
- Decision
- Alternatives considered
- Consequences / tradeoffs
- Validation evidence
- Related issues/spikes/commits

ADRs should record durable architectural choices, not transient debugging notes.
