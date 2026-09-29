# Architecture decision records

Do not update for: a routine implementation choice, or a change to an accepted decision (write a new ADR that supersedes it, and mark the old one `Superseded`).

Create an ADR when a consequential technical decision has realistic alternatives and should remain understandable after the immediate implementation work is over. Do not create ADRs for routine implementation details.

## Format

Name each file `ADR-###-short-decision-name.md`. ADR numbers are stable and never reused; decisions start at `ADR-001`. [`ADR-000`](ADR-000-record-format.md) is reserved for the format note itself.

Each ADR includes:

- Status
- Context
- Decision
- Alternatives considered
- Consequences and tradeoffs
- Validation evidence
- Related spike, issue, or commit references where applicable

Status values: `Proposed`, `Accepted`, `Rejected`, `Deprecated`, `Superseded`. A superseded ADR stays in the repository and links to its replacement rather than being deleted.

## Index

Maintain a running list here as ADRs are added, one line each with its status and a short description. This gives an at-a-glance view of project decisions without opening every file.

| ADR | Status | Decision |
|---|---|---|
| [`ADR-000-record-format.md`](ADR-000-record-format.md) | Accepted / process | Defines the ADR format, status vocabulary, and numbering convention. |
| [`ADR-001-use-minutes-per-day-for-partial-sleep.md`](ADR-001-use-minutes-per-day-for-partial-sleep.md) | Accepted | Use `GameTime:MinutesPerDay` for partial-sleep calendar compression rather than global simulation fast-forward. |
| [`ADR-002-extend-vanilla-sleep-lifecycle.md`](ADR-002-extend-vanilla-sleep-lifecycle.md) | Accepted | Use vanilla instantiated-player/sleep lifecycle semantics and restore baseline before vanilla full-sleep handoff. |
| [`ADR-003-mirror-authoritative-minutes-per-day-to-clients.md`](ADR-003-mirror-authoritative-minutes-per-day-to-clients.md) | Accepted | Explicitly mirror the authoritative server `MinutesPerDay` to clients for coherent local clock pacing. |
| [`ADR-004-award-sleep-benefit-xp-on-server.md`](ADR-004-award-sleep-benefit-xp-on-server.md) | Accepted | Observe standard XP events and award Rested / Well Rested flat bonus XP on the authoritative server. |

[`SPIKE-004`](../spikes/SPIKE-004-health-time-domains.md) remains deliberately an investigation first; a separate ADR should be created only if its evidence leads to a new durable policy, such as targeted compensation or a deployment-time compression cap.

Current architecture is summarized in the [architecture section of `DESIGN.md`](../DESIGN.md#architecture), while normative required behavior is defined in its [requirements](../DESIGN.md#requirements).
