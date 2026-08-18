# Enshrouded Sleep

**Proportional multiplayer sleeping for Project Zomboid Build 42.**

Status: **Public Alpha**  
Current version: **v0.0.7**  
Current behaviorally validated PZ baseline: **42.20.3**

Enshrouded Sleep lets some players sleep without requiring every connected survivor to go to bed at the same time.

When part of the living player population is asleep, the mod proportionally accelerates **world/calendar time**. Awake players continue playing at normal movement, combat, animation, vehicle, zombie, and timed-action speed. When every living player is asleep, the mod steps aside and lets vanilla Project Zomboid full-sleep fast-forward take over.

## What it does

Vanilla Project Zomboid already knows:

- whether a character is allowed/tired enough to sleep;
- when a character actually enters or leaves sleep;
- how fatigue, sleeping pills, traits, death, respawn, and other native systems behave;
- how to fast-forward when all living players are asleep.

Enshrouded Sleep does not replace those systems. It adds the missing multiplayer case:

```text
no one asleep
-> normal day length

some, but not all, living players asleep
-> proportionally compress world/calendar time
-> awake gameplay remains normal-speed

all living players asleep
-> restore normal day length
-> vanilla full-sleep fast-forward takes over
```

For example, on a server using a 90-real-minute day and native fast-forward setting of 40:

```text
2 living / 0 sleeping -> 90 min/day
2 living / 1 sleeping -> 4.5 min/day
2 living / 2 sleeping -> restore 90; vanilla full-sleep behavior owns the state
```

The same calculation scales continuously with larger player populations.

## Current status — Public Alpha

The core server/client architecture has passed controlled two-player multiplayer testing on Project Zomboid 42.20.3.

Validated behavior includes:

- proportional partial-sleep compression;
- synchronized server/client day-length pacing;
- smooth sleeping black-screen clock;
- smooth awake HUD/watch clock;
- normal-speed awake movement/actions while calendar time is compressed;
- correct return to native day length when sleepers wake;
- correct handoff to vanilla when all living players sleep;
- correct recalculation after player disconnects;
- normal vanilla wake timing once client/server clock pacing is synchronized;
- clean regression without the earlier client error flood.

The original clock-jump and pathological-long-sleep bugs are closed.

Public Alpha now moves testing onto real multiplayer servers with larger populations and normal mod stacks. The main unknown is no longer the basic clock architecture; it is how the mechanic behaves at scale and how other **world-time-driven systems** interact with compressed calendar time.

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) before deploying to a live server.

## Important alpha caveat: world time really is passing faster

Enshrouded Sleep does not merely animate the clock faster. During partial sleep, Project Zomboid world/calendar minutes genuinely elapse faster in real time.

That means systems tied to game minutes or `WorldAgeHours` may also progress faster while someone sleeps. Public Alpha is specifically intended to characterize effects on systems such as:

- food spoilage;
- crops/farming;
- generator fuel consumption;
- hunger/thirst/fatigue;
- healing;
- corpse decay;
- composting;
- weather;
- other mods driven by world/game time.

This is different from globally speeding up gameplay. Controlled testing has shown that awake movement/actions remain normal-speed.

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

If you download the repository using GitHub's **Download ZIP**, GitHub normally creates an outer folder named:

```text
pz-enshrouded-sleep-main
```

Rename that outer folder to `pz-enshrouded-sleep` before installation. The `-main` suffix is a Git branch/archive name; it is not part of the Project Zomboid Mod ID.

Until an automated distribution mechanism is used, participating clients need the same mod snapshot installed locally.

## Configuration

The public-alpha configuration is intentionally small:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
},
```

### `Enabled`

Enables/disables Enshrouded Sleep.

### `PartialSleepSpeedScale`

Scales the server's native `FastForwardMultiplier` for **partial sleep only**.

```text
1.0 -> neutral/default
0.5 -> half the normal partial-sleep compression
2.0 -> twice the normal partial-sleep compression
```

For initial Public Alpha deployment, `1.0` is recommended.

### `DiagnosticsEnabled`

Development/support telemetry.

```text
false -> normal public-alpha operation
true  -> one-second server/client clock and sleep telemetry
```

Leave this `false` unless diagnosing a specific problem. On an active multiplayer server, verbose diagnostics can generate very large logs.

Low-volume startup and state-transition logging remains enabled independently.

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

The server remains authoritative. Clients receive the resulting effective `MinutesPerDay` so their local clocks pace smoothly between normal multiplayer time synchronization updates.

For the technical design, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Roadmap

The current roadmap is evidence-driven.

### Public Alpha — now

- validate real 3–12+ player populations;
- exercise joins, disconnects, deaths, respawns, and repeated sleep cycles;
- monitor long-session stability and client errors;
- characterize spoilage, farming, generators, hunger/thirst/fatigue, healing, weather, and other world-time-driven systems;
- test interaction with the normal multiplayer mod stack.

### Public Beta / v0.1.x

- complete the remaining configuration/acceptance matrix;
- document or address important world-time side effects;
- build a compatibility matrix for important B42 mods;
- improve distribution and administrator experience;
- remove development instrumentation that is no longer useful;
- establish regression practice for future PZ B42 releases.

### Stable / v1.0

- representative multiplayer scale validated;
- no known high-severity save/world-state risk;
- world-time behavior clearly documented;
- reliable install/upgrade/disable/rollback workflow;
- compatibility claims limited to combinations actually tested.

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the full roadmap and exit criteria.

## Reporting Public Alpha problems

The most useful reports include:

```text
approximate real-world time of the incident
players online
players asleep if known
whether the reporting player was awake or asleep
what happened
whether the PZ error counter increased
whether waking/reconnecting cleared the behavior
```

Particularly important symptoms are:

- clock freezing/jumping;
- awake gameplay speeding up;
- implausibly long sleep;
- world remaining compressed after everyone wakes;
- incorrect behavior after join/disconnect/death/respawn;
- recurring Enshrouded Sleep errors;
- severe world-time side effects.

For focused reproduction/log collection, see [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) and [`docs/TESTING.md`](docs/TESTING.md).

## Documentation

Detailed engineering material is intentionally kept out of this README.

- [`docs/README.md`](docs/README.md) — documentation index
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — Public Alpha deployment and rollback
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — roadmap and release-stage criteria
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical architecture
- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — canonical MVP requirements
- [`docs/TESTING.md`](docs/TESTING.md) — current testing strategy
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — detailed development/test evidence
- [`docs/spikes/`](docs/spikes/) — future spike investigations
- [`docs/adr/`](docs/adr/) — architecture decision records
- [`CHANGELOG.md`](CHANGELOG.md) — version/change history

## License

See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
