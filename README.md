# Enshrouded Sleep

**Proportional multiplayer sleeping for Project Zomboid Build 42.**

Status: **Public Alpha candidate — pre-deployment health/time-domain validation in progress**  
Current development version: **v0.0.8**  
Current behaviorally validated PZ baseline: **42.20.3**

Enshrouded Sleep lets some players sleep without requiring every survivor on a multiplayer server to go to bed at the same time.

When part of the living player population is asleep, the mod proportionally compresses **world/calendar time**. Awake players continue moving, fighting, driving, crafting, and interacting at normal active-game speed. When every living player is asleep, Enshrouded Sleep restores the native day length and lets vanilla Project Zomboid full-sleep fast-forward take over.

## What it does

Vanilla Project Zomboid already owns sleep eligibility, fatigue, sleeping pills, traits, waking, death/respawn, and full-sleep fast-forward. Enshrouded Sleep adds the missing multiplayer case:

```text
no one asleep
-> normal day length

some, but not all, living players asleep
-> proportionally compress world/calendar time
-> awake active gameplay remains normal-speed

all living players asleep
-> restore normal day length
-> vanilla full-sleep fast-forward takes over
```

For example, on the validated test configuration using a 90-real-minute day and native fast-forward setting of 40:

```text
2 living / 0 sleeping -> 90 min/day
2 living / 1 sleeping -> 4.5 min/day
2 living / 2 sleeping -> restore 90; vanilla owns full sleep
```

The same formula scales continuously with larger player populations.

## Current status

The core server/client sleep and clock architecture has passed controlled two-player multiplayer testing on Project Zomboid 42.20.3.

Validated behavior includes:

- proportional partial-sleep calendar compression;
- synchronized server/client day-length pacing;
- smooth sleeping black-screen clock;
- smooth awake HUD/watch clock;
- normal-speed awake movement/actions while calendar time is compressed;
- exact return to native day length when sleepers wake;
- correct handoff to vanilla when all living players sleep;
- correct recalculation after disconnects;
- normal vanilla wake timing once client/server clock pacing is synchronized;
- clean regression without the earlier client error flood.

The original clock-jump and pathological-long-sleep bugs are closed.

### Why Public Alpha deployment is temporarily paused

Pre-deployment review identified a separate safety question: **world/calendar time really is passing faster**, so player health and survival systems may not all progress on the same time domain.

For example, if one awake player is bleeding while another player sleeps, we need to know whether blood loss remains tied to normal active-simulation time or accelerates with compressed world time. The same question applies to hunger, thirst, fatigue, healing, sickness, infection, temperature, and related systems.

v0.0.8 therefore adds a broad, read-only health/time-domain diagnostic and formalizes [`SPIKE-004`](docs/spikes/SPIKE-004-health-time-domains.md). Public Alpha deployment is a **GO candidate**, but remains blocked until that controlled test establishes that partial sleep does not create an unacceptable awake-player health hazard.

## v0.0.8 health/time-domain diagnostics

When verbose diagnostics are explicitly enabled, v0.0.8 samples all instantiated living players on the server once per real second and records a broad set of metrics including:

- health and overall body health;
- hunger, thirst, fatigue, endurance;
- stress, panic, pain, boredom, unhappiness;
- sickness, poison, food sickness and infection state;
- temperature, wetness and cold progression;
- nutrition/weight metrics;
- vanilla sleep counters;
- detailed timers and state for injured body parts, including bleeding, cuts, scratches, bites, deep wounds, fractures, burns, bandages and wound infection.

The owning client records the corresponding local state because previous sleep diagnostics showed that some useful player timing values can be exposed differently on client and server.

This instrumentation is observational only. It does not alter health, injuries, sleep, fatigue, or time behavior.

## Important design caveat: world time really is passing faster

Enshrouded Sleep does not merely animate the clock faster. During partial sleep, Project Zomboid world/calendar minutes genuinely elapse faster in real time.

Systems tied to game minutes or `WorldAgeHours` may therefore progress faster while someone sleeps. Current investigation priorities include:

- player health/survival effects — **SPIKE-004, pre-alpha blocker**;
- food spoilage;
- farming/crops;
- generator fuel consumption;
- corpse decay and composting;
- weather;
- other mods driven by world/game time.

This is distinct from globally accelerating active gameplay. Controlled tests have shown awake movement/actions remain normal-speed.

## Installation

Stable Project Zomboid Mod ID:

```text
pz-enshrouded-sleep
```

Preferred folder name:

```text
pz-enshrouded-sleep/
```

Typical Windows client installation:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

Typical local dedicated-server mod folder:

```text
mods/pz-enshrouded-sleep/
```

Server configuration:

```text
Mods=pz-enshrouded-sleep
```

GitHub **Download ZIP** normally creates `pz-enshrouded-sleep-main`; rename that outer folder to `pz-enshrouded-sleep` before installation. The `-main` suffix is a Git archive/branch name, not part of the PZ Mod ID.

Until an automated distribution mechanism is used, participating clients need the same mod snapshot installed locally.

## Configuration

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
},
```

`Enabled` turns the mechanic on/off.

`PartialSleepSpeedScale` scales the server's native `FastForwardMultiplier` for **partial sleep only**. `1.0` is the neutral/default value.

`DiagnosticsEnabled` controls verbose development/support telemetry:

```text
false -> normal operation; low-volume state-transition logs only
true  -> one-second clock, sleep, health, survival and injury telemetry
```

Leave diagnostics off except during controlled testing or focused troubleshooting; the expanded health diagnostic can generate large logs.

## How proportional sleep is calculated

The server uses the currently instantiated living player population:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

During partial sleep:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = FastForwardMultiplier * PartialSleepSpeedScale
CalendarCompressionFactor = max(1.0,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay =
    BaselineMinutesPerDay / CalendarCompressionFactor
```

The server remains authoritative. Clients receive the resulting effective `MinutesPerDay` so their local clocks pace smoothly between normal multiplayer synchronization updates.

For the technical design and rationale, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and the architecture decision records under [`docs/adr/`](docs/adr/).

## Roadmap

### Pre-Public-Alpha — current

- complete SPIKE-004 health/survival time-domain characterization;
- make a GO / CONDITIONAL GO / NO-GO decision for live WHG deployment;
- run a short v0.0.8 startup/core regression after the diagnostic additions.

### Public Alpha — next, if SPIKE-004 passes

- validate real 3–12+ player populations;
- exercise joins, disconnects, deaths, respawns and repeated sleep cycles;
- monitor long-session stability and client errors;
- characterize non-health world-time systems such as spoilage, farming, generators and weather;
- test interaction with the normal multiplayer mod stack.

### Public Beta / v0.1.x

- complete the remaining configuration/acceptance matrix;
- document or address important world-time side effects;
- build a compatibility matrix for important B42 mods;
- improve distribution and administrator experience;
- establish regression practice for future PZ B42 releases.

### Stable / v1.0

- representative multiplayer scale validated;
- no known high-severity save/world/player-state risk;
- world-time behavior clearly documented;
- reliable install/upgrade/disable/rollback workflow;
- compatibility claims limited to combinations actually tested.

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the full roadmap and release-stage criteria.

## Documentation

Detailed engineering material is intentionally kept out of this landing page.

- [`docs/README.md`](docs/README.md) — documentation index
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — deployment/rollback guidance and current deployment gate
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — roadmap and phase criteria
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical architecture
- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — canonical MVP requirements
- [`docs/TESTING.md`](docs/TESTING.md) — current test procedures
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — detailed validation chronology
- [`docs/spikes/`](docs/spikes/) — formal exploratory investigations, including the current health/time-domain spike
- [`docs/adr/`](docs/adr/) — architecture decision records
- [`CHANGELOG.md`](CHANGELOG.md) — version/change history

## License

See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
