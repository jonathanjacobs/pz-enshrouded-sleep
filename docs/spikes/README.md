# Spikes

Exploratory investigations and proof-of-concept work belong in this directory.

The early Enshrouded Sleep development builds (`v0.0.1` through `v0.0.7`) functioned as a sequence of spike-style investigations while the multiplayer time model was being established. Their consolidated results are recorded in [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md) and the repository [`CHANGELOG.md`](../../CHANGELOG.md).

Future focused investigations should use a durable document such as:

```text
SPIKE-001-short-title.md
SPIKE-002-short-title.md
```

A spike document should capture:

- question/hypothesis;
- scope and non-goals;
- test environment;
- procedure;
- evidence/results;
- conclusion;
- go/no-go or follow-up decision;
- links to any resulting issues, ADRs, or implementation changes.

Spikes are evidence records, not normative product requirements. Final behavior belongs in [`../REQUIREMENTS.md`](../REQUIREMENTS.md), and architectural decisions should be reflected in [`../ARCHITECTURE.md`](../ARCHITECTURE.md) or a formal ADR when appropriate.
