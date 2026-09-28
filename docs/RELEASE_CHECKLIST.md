# Release checklist

Use this checklist before a public GitHub release or Steam Workshop update. Tick items only where recorded evidence supports them; the evidence lives in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).

Current release: `v1.0.1`, the full release of the v1.0.0 package (release labels and version only; no gameplay or configuration change). v1.0.0 was published to the existing Steam Workshop item on 2026-08-31.

## General gate

- [x] `VERSION`, `CHANGELOG.md`, runtime version strings, and both `mod.info` files agree.
- [x] Public status, compatibility, configuration, and behavior claims match tested evidence and state the remaining validation boundaries.
- [x] The smoke test and two-player sleep test in [`TESTING.md`](TESTING.md) were run (normal-session logs count) and recorded in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). (Project Zomboid 42.21.0, 2026-09-28.)
- [x] No known high-severity save, world, player, client, or server defect is being silently shipped.
- [x] The Workshop package has one authoritative runtime tree and contains no logs, saves, credentials, private configuration, source-control metadata, backups, or unintended assets.
- [x] Provenance, licensing, policy review, attribution, and public disclosures are current under [`COMPLIANCE.md`](../COMPLIANCE.md).
- [x] Installation, update, monitoring, soft rollback, and full rollback instructions are current in [`DEPLOYMENT.md`](DEPLOYMENT.md).
- [x] Workshop identifiers, package layout, artwork, and publication metadata pass [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md).

## Stable release gate

- [x] Server and at least one client log from normal play show coherent baseline, partial-sleep, and wake transitions without a recurring Enshrouded Sleep error or client clock defect. (42.21.0 server and sleeping-client logs. All-asleep handoff is supported by 156 server-side handoffs in the v1.0.0 WHG window rather than a client log; accepted for the full release.)
- [x] Major world-time interactions and compatibility limits are documented and accepted for the release.
- [x] The optional Rested / Well Rested feature passed its focused server-authority gate and WHG live multiplayer validation. All 301 live sleep decisions matched the active configuration, and durations, expiry, and restart persistence were correct with no errors; this evidence is accepted for the `8`/`12`-hour defaults. The feature remains disabled by default. Death/disable clearing and Moodle presentation were not observed live.

Watch during normal play rather than staging dedicated tests; record anything notable in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md), and treat a real problem here as a blocker for the next release:

- joins, disconnects, deaths, and respawns during partial sleep leaving stale population or awake-protection state;
- eating, drinking, activity, or sleeping-player behavior looking distorted during partial sleep;
- notification banners missing, repeated, or spammy when the option is enabled;
- CPU cost or normal log volume becoming a problem for the server.

Rollback steps are documented in [`DEPLOYMENT.md`](DEPLOYMENT.md); they are not rehearsed as a release gate.

## Deployment gate

- [ ] Stop the server cleanly and back up world, save, and configuration before updating.
- [ ] Upload v1.0.1 to Workshop item `3786842301` and paste [`../workshop-description.bbcode`](../workshop-description.bbcode) into the item description.
- [ ] Confirm the server and every participating client log `SERVER_BUILD | 1.0.1` / `build=1.0.1` after deployment.
- [ ] Preserve early release logs and use the documented rollback if a problem appears.

Release decision: **GO — v1.0.1 full release**

Review date: **2026-09-28**

History: v1.0.0 was deployed on 2026-08-31 under a conditional Release Candidate decision. WHG live logs from 2026-09-01 to 2026-09-28 and the 2026-09-28 Project Zomboid 42.21.0 checkpoint satisfied the stable gate above.
