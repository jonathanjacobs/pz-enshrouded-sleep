# Release checklist

Use this checklist before a public GitHub release or Steam Workshop update. Do not mark a release ready until each applicable item is complete and supported by evidence.

Current candidate: `v1.0.0`. Preparing and pushing the candidate to `origin/main` does not itself complete the deployment gate or publish the Steam Workshop item.

## General gate

- [x] `VERSION`, `CHANGELOG.md`, runtime version strings, and both `mod.info` files agree.
- [ ] Public status, compatibility, configuration, and behavior claims match tested evidence.
- [ ] The required procedures in [`TESTING.md`](TESTING.md) were run and observed outcomes were recorded in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md).
- [ ] No known high-severity save, world, player, client, or server defect is being silently shipped.
- [ ] The Workshop package has one authoritative runtime tree and contains no logs, saves, credentials, private configuration, source-control metadata, backups, or unintended assets.
- [ ] Provenance, licensing, policy review, attribution, and public disclosures are current under [`COMPLIANCE.md`](../COMPLIANCE.md).
- [ ] Installation, update, monitoring, soft rollback, and full rollback instructions are current in [`DEPLOYMENT.md`](DEPLOYMENT.md).
- [ ] Workshop identifiers, package layout, artwork, and publication metadata pass [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md).

## Stable / v1.0 candidate gate

- [ ] Representative server and owning-client logs show coherent baseline, partial-sleep, wake, and vanilla-full-sleep transitions without a recurring Enshrouded Sleep error or client clock defect.
- [ ] Join, disconnect, death, and respawn transitions during partial sleep leave no stale population or awake-protection state.
- [ ] Normal eating, drinking, activity, sleep/wake, and sleeping-player behavior show no material distortion under the representative server configuration.
- [ ] Opt-in sleep notifications pass their dedicated smoke test without repeated spam and pass notification-only rollback.
- [ ] Awake-protection soft rollback and full-mod rollback have been exercised against a preserved server/save state.
- [ ] CPU cost and normal log volume are operationally acceptable at the representative tested population.
- [ ] Major world-time interactions and compatibility limits are documented and accepted for the release.
- [ ] No optional experimental feature is included unless its dedicated validation gate has passed.

## Deployment gate

- [ ] Stop the server cleanly and back up world, save, and configuration before updating.
- [ ] Confirm server/client package consistency after deployment.
- [ ] Confirm the native all-awake baseline, one partial-sleep transition, and exact baseline restoration.
- [ ] Preserve early release logs and use the documented rollback if a gate fails.

Release decision: **GO / CONDITIONAL GO / NO-GO**

Reviewer/date: ____________________
