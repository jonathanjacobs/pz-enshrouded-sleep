<p align="center">
  <img src="docs/images/enshrouded-sleep-banner.png"
       alt="Enshrouded Sleep - Project Zomboid sleep and rest mod"
       width="100%">
</p>

# Enshrouded Sleep

**Proportional multiplayer sleeping for Project Zomboid Build 42 servers.**

Status: **Public Alpha candidate — pre-deployment health/time-domain validation in progress**  
Current development version: **v0.0.10**  
Current behaviorally validated PZ baseline: **42.20.3**

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

## Current status

The core server/client sleep and clock architecture has passed controlled two-player multiplayer testing on Project Zomboid 42.20.3.

Validated behavior includes proportional partial-sleep calendar compression, synchronized server/client day-length pacing, smooth sleeping and awake clocks, normal-speed awake gameplay, exact baseline restoration, vanilla full-sleep handoff, disconnect recalculation, and normal vanilla wake timing after client/server pacing synchronization.

### SPIKE-004 safety result so far

The v0.0.9 controlled multiplayer run materially narrowed the remaining Public Alpha safety question.

With an awake injured player while another player triggered approximately **5x partial calendar compression**:

- active bleeding health loss remained approximately **1x real-time rate** (`~0.993x`);
- `BleedingTime` and scratch-timer progression remained approximately **1x**;
- the feared rapid awake-player bleed-out was not observed.

Nutrition behaved differently:

- calories scaled approximately **5.01x** at 5x compression and **10.00x** at 10x;
- carbohydrates scaled approximately **5.00x / 10.00x**;
- proteins scaled approximately **5.00x / 10.01x**;
- lipids scaled approximately **5.00x / 10.00x**.

The remaining blocker is classification of hunger, thirst, fatigue, endurance, stress, sickness, temperature and related character state.

## v0.0.10 focused survival diagnostics

v0.0.10 uses the Build 42 `CharacterStat`, `MoodleType`, Nutrition and related APIs used by current vanilla Lua. Focused prefixes are:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

The older broad injury/body diagnostic remains available because its wound telemetry is already validated and useful.

### One-connected-player server test mode

v0.0.10 includes a **diagnostics-only multiplayer-server test override** so the remaining time-domain experiment can be run with only one player connected to the server. This is not support for a local single-player game.

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
    DiagnosticForcedCompressionFactor = 5.0,
}
```

The override activates only when all of these are true:

```text
running on the multiplayer server
DiagnosticsEnabled = true
DiagnosticForcedCompressionFactor > 1
exactly one living player is connected
that player is awake
```

With a 90-minute baseline and factor `5`, the server applies `MinutesPerDay=18` while the connected player remains awake. The global simulation multiplier is not changed.

If that player sleeps, or another living player connects, the diagnostic override is suspended and native `MinutesPerDay` is restored. This prevents the test state from affecting additional players or stacking with vanilla full-sleep acceleration.

Normal gameplay must use:

```text
DiagnosticsEnabled = false
DiagnosticForcedCompressionFactor = 1.0
```

## Important design caveat: world time really is passing faster

Enshrouded Sleep does not merely animate the clock faster. During partial sleep, Project Zomboid world/calendar minutes genuinely elapse faster in real time. v0.0.9 confirmed that different player systems use different time domains: awake bleeding/injury progression behaved approximately real-time bound, while core nutrition stores followed compressed world time almost exactly.

Other world-time systems such as spoilage, farming, generators, corpses, composting and weather remain later Public Alpha characterization targets.

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

Normal operation:

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

`DiagnosticForcedCompressionFactor` is **server-test-only**. At `1.0` it is inert. Values above `1.0` require diagnostics and exactly one awake living player connected to the multiplayer server.

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
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — deployment/rollback guidance and current deployment gate
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — canonical roadmap and phase criteria
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical architecture
- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — canonical MVP requirements
- [`docs/TESTING.md`](docs/TESTING.md) — current test procedures
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — detailed validation chronology
- [`docs/spikes/`](docs/spikes/) — formal exploratory investigations
- [`docs/adr/`](docs/adr/) — architecture decision records
- [`CHANGELOG.md`](CHANGELOG.md) — version/change history

## License

See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
