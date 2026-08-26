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

The validated SPIKE-006 mechanism was promoted from a one-player diagnostic prototype into normal multiplayer partial sleep. The production path now protects all awake living players during partial sleep while never correcting sleepers/dead players. `AwakePlayerProtectionEnabled` provides an independent soft rollback; the one-player forced-compression mechanism remains diagnostic-only.

Public Beta does not claim that larger populations, every lifecycle transition, every mod stack, or every direct survival effect is already proven. Those remaining questions are tracked exclusively in [`ROADMAP.md`](ROADMAP.md).

## Evidence boundary

The architecture is strongly supported for proportional calendar compression, server/client day-length synchronization, baseline restoration, vanilla full-sleep handoff, normal-speed awake simulation, the measured SPIKE-004 time domains, the confirmed SPIKE-005 world-system examples, and controlled SPIKE-006 awake-protection feasibility.

Do not infer compatibility or compensation for untested systems from this summary. Use the detailed SPIKE record when a claim needs exact test conditions or measured ratios.
