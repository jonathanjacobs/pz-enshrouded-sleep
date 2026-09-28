# Release checklist

Use this checklist before a public GitHub release or Steam Workshop update. Do not mark a stable release ready until each applicable item is complete and supported by evidence. A conditional Release Candidate deployment may proceed only when every open item is explicitly retained as a deployment or live-validation condition.

Current candidate: `v1.0.0`, published to the existing Steam Workshop item on 2026-08-31. Items below are ticked only where recorded evidence supports them. The WHG live-log review is in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

## General gate

- [x] `VERSION`, `CHANGELOG.md`, runtime version strings, and both `mod.info` files agree.
- [x] Public status, compatibility, configuration, and behavior claims match tested evidence and state the remaining validation boundaries.
- [ ] The required procedures in [`TESTING.md`](TESTING.md) were run and observed outcomes were recorded in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).
- [x] No known high-severity save, world, player, client, or server defect is being silently shipped.
- [x] The Workshop package has one authoritative runtime tree and contains no logs, saves, credentials, private configuration, source-control metadata, backups, or unintended assets.
- [x] Provenance, licensing, policy review, attribution, and public disclosures are current under [`COMPLIANCE.md`](../COMPLIANCE.md).
- [x] Installation, update, monitoring, soft rollback, and full rollback instructions are current in [`DEPLOYMENT.md`](DEPLOYMENT.md).
- [x] Workshop identifiers, package layout, artwork, and publication metadata pass [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md).

## Stable / v1.0 candidate gate

- [ ] Representative server and owning-client logs show coherent baseline, partial-sleep, wake, and vanilla-full-sleep transitions without a recurring Enshrouded Sleep error or client clock defect.
- [ ] Join, disconnect, death, and respawn transitions during partial sleep leave no stale population or awake-protection state.
- [ ] Normal eating, drinking, activity, sleep/wake, and sleeping-player behavior show no material distortion under the representative server configuration.
- [ ] Opt-in sleep notifications pass their dedicated smoke test without repeated spam and pass notification-only rollback.
- [ ] Awake-protection soft rollback and full-mod rollback have been exercised against a preserved server/save state.
- [ ] CPU cost and normal log volume are operationally acceptable at the representative tested population.
- [x] Major world-time interactions and compatibility limits are documented and accepted for the release.
- [x] The optional Rested / Well Rested feature passed its focused server-authority gate and WHG live multiplayer validation. All 301 live sleep decisions matched the active configuration, and durations, expiry, and restart persistence were correct with no errors; this evidence is accepted for the `8`/`12`-hour defaults. The feature remains disabled by default. Death/disable clearing and Moodle presentation were not observed live.

## Deployment gate

- [ ] Stop the server cleanly and back up world, save, and configuration before updating.
- [ ] Confirm server/client package consistency after deployment.
- [x] Confirm the native all-awake baseline, one partial-sleep transition, and exact baseline restoration. (WHG v1.0.0 server logs: baseline and every vanilla handoff at `MinutesPerDay=240`, 189 partial-sleep states.)
- [x] Preserve early release logs and use the documented rollback if a gate fails. (WHG server logs from 2026-09-01 onward preserved and reviewed; no gate failed.)

Release decision: **CONDITIONAL GO — v1.0.0 Release Candidate Workshop deployment**

Review date: **2026-08-31**

Conditions carried into deployment and live validation:

- stop the server cleanly and back up the world, save, and configuration before updating;
- confirm the server and every participating client load the same v1.0.0 package;
- keep `SleepBenefitsEnabled=false` unless the server administrator intentionally enables the optional reward layer;
- preserve early server and owning-client logs;
- continue the unchecked representative-client, lifecycle, notification-rollback, rollback, and CPU/log-volume checks above;
- use the documented soft/full rollback if a high-severity defect or recurring Enshrouded Sleep error appears.

Completed since the decision (2026-09-28): v1.0.0 was published on 2026-08-31. WHG live logs confirmed the post-deployment baseline, partial-sleep, and restoration checks, and satisfied the sleep-benefit classification/duration condition for the default policy.

This conditional decision does not represent the unchecked stable-release evidence gates as passed.
