# Validation History

This document is the concise chronology of what Enshrouded Sleep testing established. Detailed measurements and procedures belong in [`spikes/`](spikes/); current procedures belong in [`TESTING.md`](TESTING.md); future validation targets belong in [`ROADMAP.md`](ROADMAP.md).

## Core architecture chronology

### v0.0.1 — calendar-compression feasibility

Changing server `MinutesPerDay` from a native `90` to `4.5` produced approximately 20x world/calendar progression while `TrueMultiplier` remained `1` and awake gameplay did not visibly globally accelerate.

Decision: use `MinutesPerDay` as the partial-sleep primitive. See SPIKE-001 and ADR-001.

### v0.0.2 / v0.0.2b — vanilla lifecycle and full sleep

Testing established that server `IsoPlayer:isAsleep()` reflects sleep/wake state, dead character objects must be excluded from the living denominator, loading clients do not count until an `IsoPlayer` exists, and vanilla all-asleep acceleration uses a path separate from `MinutesPerDay`.

Decision: use vanilla-visible player state and restore baseline before handing all-asleep behavior to vanilla. See SPIKE-002 and ADR-002.

### v0.0.3 / v0.0.4 — proportional controller

The first successful two-player regression established all-awake baseline, proportional one-sleeper compression, all-asleep baseline restoration/vanilla handoff, wake restoration, and disconnect recalculation.

### v0.0.5–v0.0.7 — client clock synchronization

Diagnostics identified that server `MinutesPerDay` changes were not automatically mirrored as stable client pacing. Explicit server-to-client ClockState synchronization plus a convergence heartbeat corrected the visible client clock mismatch. The subsequent regression showed server and both clients converging on the same compressed day length with normal-speed awake gameplay. See SPIKE-003 and ADR-003.

## Health and survival time domains — SPIKE-004

v0.0.8–v0.0.10 instrumentation separated vanilla full-sleep acceleration from Enshrouded partial-sleep calendar compression and measured several awake-player systems.

Controlled B42.20.3 evidence supported:

**Approximately simulation/real-time bound under tested conditions**

- awake bleeding/body-health loss;
- measured bleeding/scratch timers;
- resting endurance recovery.

**World/calendar-time bound without protection**

- Hunger;
- Thirst;
- Fatigue;
- Calories;
- Carbohydrates;
- Proteins;
- Lipids.

At forced calendar factors around 5x/10x, the world-time-bound survival fields scaled correspondingly while body-health loss remained approximately 1x. `TrueMultiplier` remained `1.0` during the calendar-compression tests.

Decision: SPIKE-004 returned GO for the original Public Alpha architecture. Detailed ratios/capability counts remain in [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md).

## Workshop-distributed Public Alpha validation

Public Alpha v0.0.10 was published under Workshop item `3786842301`, acquired by the dedicated server and client, and passed a live two-player regression including Workshop loading, baseline inheritance on a non-reference day length, live `FastForwardMultiplier` inheritance, proportional compression, client synchronization, and exact baseline restoration without an Enshrouded Sleep runtime exception.

## External world systems — SPIKE-005

Controlled forced-compression testing established that the following track elapsed game-world/calendar time under the tested conditions:

- generator fuel consumption;
- ambient food aging/spoilage;
- refrigerated food aging, with the vanilla refrigeration modifier preserved;
- vehicle fuel consumption while idling;
- vehicle battery drain under a stable engine-off load.

Generator wear/condition, frozen food, farming/crops, unloaded catch-up behavior, and compensation feasibility remain subsystem-specific open questions. Detailed measurements belong only in [`spikes/SPIKE-005-world-system-time-domains.md`](spikes/SPIKE-005-world-system-time-domains.md).

## Awake-player protection — SPIKE-006

### Callback failure

The first server prototype used `Events.OnPlayerUpdate`. It loaded but produced no callback/correction telemetry on the dedicated server while tick-driven diagnostics continued. The hook was rejected for this purpose.

### Tick-driven passive feasibility

The prototype moved to `Events.OnTick` and explicitly iterated `getOnlinePlayers()`. Under a controlled native `MinutesPerDay=90`, forced factor `20`, compressed `MinutesPerDay=4.5`, and `TrueMultiplier=1.0`, the world/calendar clock remained approximately 20x while measurable protected Hunger/Thirst/Fatigue/Calories/Protein/Weight progression remained approximately native 1x. The owning client tracked the corrected server state.

Decision: post-update server-authoritative normalization was feasible.

### Active-effects and safety regression

Follow-up controlled testing moved Carbohydrates and Lipids away from their lower clamps and exercised normal player actions. Evidence supported:

- Carbohydrates and Lipids remaining near native pacing under protection;
- favorable eating effects preserved;
- favorable drinking effects preserved;
- running/sprinting retaining active consequences such as endurance loss and increased expenditure;
- sleeping immediately suspending awake correction and returning the isolated forced test to native day length;
- waking reinitializing the reference snapshot before correction resumed;
- clean final baseline restoration;
- no relevant Enshrouded Sleep Lua exception in the successful controlled run.

Decision: SPIKE-006 controlled feasibility returned GO for Public Beta field validation. Detailed evidence remains in [`spikes/SPIKE-006-awake-player-protection.md`](spikes/SPIKE-006-awake-player-protection.md) and its linked test procedures.

## Public Beta v0.1.0

The validated SPIKE-006 mechanism was promoted from a one-player diagnostic prototype into normal multiplayer partial sleep. The production path protects all awake living players during partial sleep while never correcting sleepers/dead players. `AwakePlayerProtectionEnabled` provides an independent soft rollback; the one-player forced-compression mechanism remains diagnostic-only.

Public Beta does not claim that larger populations, every lifecycle transition, every mod stack, or every direct survival effect is already proven. Those remaining questions are tracked exclusively in [`ROADMAP.md`](ROADMAP.md).

## Project Zomboid 42.20.4 compatibility checkpoint — 2026-08-26

Dedicated-server and connected-client logs from Project Zomboid `42.20.4` revision `b0bbce05d5` established the compatibility checkpoint used for the v0.1.1 release and Workshop item `3786842301`.

Observed evidence included:

- both server and client running `42.20.4 b0bbce05d5`;
- the Workshop item installed and loaded through the normal multiplayer path;
- authoritative baseline capture at `MinutesPerDay=240`;
- normal all-awake controller state with one living/awake player;
- server publication of a baseline `ClockState` packet;
- connected-client application of the authoritative `MinutesPerDay=240` state;
- no relevant Enshrouded Sleep Lua exception in the supplied compatibility-session logs.

The 42.20.4 security hotfix removed the Lua `loadstring` and `loadstream` methods. Enshrouded Sleep does not use either method. Its networking architecture uses predefined `sendServerCommand` / `OnServerCommand` command names and structured argument tables for clock synchronization and optional notifications, so no dynamic server-supplied code execution migration was required.

**Validation boundary:** the supplied 42.20.4 logs establish startup, baseline, and server/client synchronization compatibility. They do not contain a complete logged natural two-player partial-sleep/all-asleep regression and therefore do not replace Tier 2.

## Public Beta v0.1.1 — live WHG field release

v0.1.1 packages the 42.20.4 compatibility maintenance plus the optional administrator-controlled sleep-status notification path for live Public Beta testing on the WHG server.

The notification implementation is intentionally isolated from sleep/time policy:

- `SleepNotificationsEnabled` defaults to `false` and is controlled by the server administrator;
- notification state is derived from settled authoritative `MinutesPerDay` plus the living/sleeping roster;
- messages are transported through the predefined `EnshroudedSleep/SleepNotification` server command with structured arguments;
- the client only displays server-authored text and does not calculate or alter sleep policy;
- a client chat-bridge failure is circuit-broken for that session;
- disabling `SleepNotificationsEnabled` is the first-line notification-only rollback and does not disable proportional sleep, client clock synchronization, or awake-player protection.

**Live-validation status:** v0.1.1 is being deployed specifically so the notification path can be exercised under normal WHG multiplayer conditions. Publication is not being represented as prior proof that notification delivery is already field-validated. The post-deployment checks and success criteria are maintained in [`TESTING.md`](TESTING.md).

## Public Beta v0.1.1 — week-long server field evidence

A server-data archive covering routine v0.1.1 operation was reviewed on 2026-08-30. Across 38 dedicated-server sessions, the controller recorded 879 state transitions:

- 87 proportional partial-sleep states;
- 46 vanilla-full-sleep handoffs;
- living populations up to seven players;
- partial-sleep populations from two through six living players, with several sleeping fractions;
- repeated restoration to the captured native `MinutesPerDay` baseline; and
- no explicit Enshrouded Sleep-prefixed runtime error in the reviewed server DebugLogs.

This is representative field evidence for the released core controller, server clock-state publication, awake-player protection, population recalculation, baseline restoration, and vanilla full-sleep handoff under the server's normal mod stack.

**Evidence boundary:** the archive contains server logs, not affected owning-client DebugLogs. It does not establish client presentation/clock continuity throughout every transition, deliberate death/respawn safety, measured CPU cost, rollback, or compatibility outside the observed mod stack. Every recorded notification configuration had `SleepNotificationsEnabled=false`, so notification delivery and notification-only rollback remain unvalidated. The archive ran released v0.1.1 and contained no sleep-benefit module banners; it provides no evidence for the separate Rested / Well Rested experiment.

## SPIKE-007 preliminary one-player evidence — 2026-08-31

Three focused feature-branch dedicated-server sessions provided preliminary evidence for the optional Rested / Well Rested experiment:

- server sleep-duration classification produced Rested and Well Rested at the intended default thresholds and did not let a short sleep replace an active benefit;
- earned Well Rested state persisted across reconnect;
- `4,818` logged positive Endurance corrections followed the configured `10%` and `75%` arithmetic, left non-positive changes untouched, and did not exceed the normal maximum;
- the original owning-client XP bridge produced no `XP_BONUS` diagnostic at `5%`, `10%`, or `75%`, even though the tested character's Fitness and Strength were below maximum;
- literal `%` characters in four sandbox tooltips caused client-side Java formatter warnings.

The failed XP observation was a NO-GO for the original client award design, not for the complete feature. The feature branch moved the award to a server `AddXP` observer with flat server XP and escaped the tooltip percentages.

The subsequent `0.1.1+sleep-benefits-server-xp-dev` retest passed the focused server-XP checkpoint. A `7.695`-hour sleep granted Rested, after which the canonical server DebugLog recorded `35` awards across Carving, Fitness, Sprinting, and Strength. The observed base total was `52.9` XP and the bonus total was `52.9` XP at the configured `100%`; all event arithmetic matched, no client award path ran, and no recursion, relevant Lua error, or server anti-cheat rejection appeared.

A client `WARN:MISSING in SettingsTable: AntiCheatXP` line was part of a larger vanilla `ServerSettingsScreen.lua` UI-metadata list that also included `Mods`, `Map`, `SteamVAC`, and many unrelated settings. It does not report an anti-cheat violation or rejected XP award.

**Evidence boundary:** these were one-player runs. They establish the revised server XP mechanism and configurable percentage arithmetic: the same formula handles `100%`, the default `5%`, and other administrator-selected values, and the module has no access-level/admin-mode branch. They do not yet validate broader two-player operation, death clearing, feature-disable rollback, expiry, or wider Moodle coexistence behavior. Those are live-validation targets for the next production release rather than blockers to integration into `main`.

## Evidence boundary

The architecture is strongly supported for proportional calendar compression, server/client day-length synchronization, baseline restoration, vanilla full-sleep handoff, normal-speed awake simulation, the measured SPIKE-004 time domains, the confirmed SPIKE-005 world-system examples, and controlled plus field SPIKE-006 awake-protection evidence. Project Zomboid 42.20.4 additionally has a recorded startup/baseline/client-sync compatibility checkpoint.

The v0.1.1 notification system is a live Public Beta field-validation feature until WHG evidence is collected. Do not infer compatibility or compensation for untested systems from this summary. Use the detailed SPIKE record when a claim needs exact test conditions or measured ratios.
