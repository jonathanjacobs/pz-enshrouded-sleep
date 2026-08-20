<p align="center">
  <img src="docs/images/enshrouded-sleep-banner.png"
       alt="Enshrouded Sleep - Project Zomboid sleep and rest mod"
       width="100%">
</p>

# Enshrouded Sleep

**Proportional multiplayer sleeping for Project Zomboid Build 42 servers.**

Status: **Public Alpha**  
Current version: **v0.0.10**  
Behaviorally validated PZ baseline: **42.20.3**

Enshrouded Sleep is a **multiplayer-server mod**. It lets some players sleep without requiring every survivor on the server to go to bed at the same time. Local/standalone single-player gameplay is not a target runtime for this project.

When part of the living server population is asleep, the mod proportionally compresses **world/calendar time**. Awake players continue moving, fighting, driving, crafting, and interacting at normal active-game speed. When every living player is asleep, Enshrouded Sleep restores the native day length and lets vanilla Project Zomboid full-sleep fast-forward take over.

## What it does

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

Validated reference configuration:

```text
90-minute day / native FastForwardMultiplier=40
2 living / 0 sleeping -> 90 min/day
2 living / 1 sleeping -> 4.5 min/day
2 living / 2 sleeping -> restore 90; vanilla owns full sleep
```

## Public Alpha evidence

The core server/client sleep and clock architecture has passed controlled multiplayer testing on Project Zomboid 42.20.3. Validated behavior includes proportional partial-sleep calendar compression, synchronized server/client day-length pacing, smooth sleeping and awake clocks, normal-speed awake gameplay, exact baseline restoration, vanilla full-sleep handoff, disconnect recalculation, and normal vanilla wake timing after client/server pacing synchronization.

### SPIKE-004 health/survival safety result — GO

SPIKE-004 is complete and the pre-alpha health/survival deployment gate passed.

Measured awake-player injury behavior under compressed `MinutesPerDay` remained approximately real-time bound:

- active bleeding health loss: about **0.993x** baseline rate during ~5x calendar compression;
- measured `BleedingTime` and scratch-timer progression: approximately **1x**;
- ongoing overall body-health loss in the v0.0.10 forced-compression run remained approximately **1x** rather than scaling with world time;
- resting endurance recovery remained approximately **1x** when calendar compression was increased from 10x to 20x.

Survival/nutrition systems intentionally tied to world/calendar time accelerated with compressed world time:

- Hunger: approximately **4.85x** in the clean 5x comparison;
- Thirst: approximately **4.67x**;
- Fatigue: approximately **5.46x**;
- Calories/carbohydrates/proteins/lipids: approximately proportional to the observed 5x and 10x calendar-compression factors.

A short adjacent 10x-versus-baseline comparison produced roughly **9.5x** changes for hunger, thirst, fatigue, proteins and lipids while body-health loss remained about **0.95x**, reinforcing that different player systems use different time domains.

No proportional acute-health acceleration or thermal hazard was observed. Active sickness, poisoning, zombie infection/fever, and extreme thermal injury remain Public Alpha characterization targets because those pathological states were not present during the controlled run.

## Important design caveat: world time really is passing faster

Enshrouded Sleep does not merely animate the clock faster. During partial sleep, Project Zomboid world/calendar minutes genuinely elapse faster in real time.

That means an awake survivor experiences compressed-world-time progression for systems such as hunger, thirst, fatigue and nutrition. This is currently considered expected behavior rather than a defect: if several in-game hours pass while another player sleeps, those survival needs also advance through those in-game hours.

Other world-time systems such as spoilage, farming, generators, corpses, composting and weather remain Public Alpha characterization targets.

## Diagnostics

v0.0.10 retains opt-in diagnostic tooling for regression/support work. Normal servers should leave it disabled:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

Focused survival diagnostics use Build 42 `CharacterStat`, `MoodleType`, Nutrition and related APIs. The controlled one-connected-player forced-compression mode remains available for future regression testing, but it is **server-test-only** and must remain at factor `1.0` during normal Public Alpha play.

The forced override is active only when diagnostics are enabled, the factor is greater than 1, exactly one living player is connected, and that player is awake. If the player sleeps or another living player connects, the override restores baseline and suspends itself.

## Installation

Stable Project Zomboid Mod ID:

```text
pz-enshrouded-sleep
```

Preferred folder name:

```text
pz-enshrouded-sleep/
```

Server configuration:

```text
Mods=pz-enshrouded-sleep
```

Typical Windows client installation:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

Typical dedicated-server mod folder:

```text
mods/pz-enshrouded-sleep/
```

GitHub **Download ZIP** normally creates `pz-enshrouded-sleep-main`; rename that outer folder to `pz-enshrouded-sleep` before installation. Until an automated distribution mechanism is used, participating clients need the same mod snapshot installed locally.

## Configuration

Normal Public Alpha operation:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

`Enabled` turns the mechanic on/off.

`PartialSleepSpeedScale` scales the server's native `FastForwardMultiplier` for **real partial sleep only**. `1.0` is neutral.

`DiagnosticsEnabled` controls verbose development/support telemetry.

`DiagnosticForcedCompressionFactor` is **server-test-only**. At `1.0` it is inert.

## How proportional sleep is calculated

The server uses:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

During normal partial sleep:

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

## Documentation

The project roadmap is maintained only in [`docs/ROADMAP.md`](docs/ROADMAP.md).

- [`docs/README.md`](docs/README.md) — documentation index
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — Public Alpha deployment/rollback guidance
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — canonical roadmap and phase criteria
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical architecture
- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — canonical MVP requirements
- [`docs/TESTING.md`](docs/TESTING.md) — smoke/regression and Public Alpha testing procedures
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — detailed validation chronology
- [`docs/spikes/`](docs/spikes/) — formal exploratory investigations
- [`docs/adr/`](docs/adr/) — architecture decision records
- [`CHANGELOG.md`](CHANGELOG.md) — version/change history

## License

See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
