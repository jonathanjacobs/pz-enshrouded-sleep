<p align="center">
  <img src="docs/images/enshrouded-sleep-banner.png"
       alt="Enshrouded Sleep - Project Zomboid sleep and rest mod"
       width="100%">
</p>

# Enshrouded Sleep

**Proportional multiplayer sleeping for Project Zomboid Build 42.**

Status: **Public Alpha candidate — pre-deployment health/time-domain validation in progress**  
Current development version: **v0.0.10**  
Current behaviorally validated PZ baseline: **42.20.3**

Enshrouded Sleep lets some players sleep without requiring every survivor on a multiplayer server to go to bed at the same time.

When part of the living player population is asleep, the mod proportionally compresses **world/calendar time**. Awake players continue moving, fighting, driving, crafting, and interacting at normal active-game speed. When every living player is asleep, Enshrouded Sleep restores the native day length and lets vanilla Project Zomboid full-sleep fast-forward take over.

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

On the validated 90-real-minute-day / native-fast-forward-40 test configuration:

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
- smooth sleeping black-screen and awake HUD/watch clocks;
- normal-speed awake movement/actions while calendar time is compressed;
- exact baseline restoration on wake;
- correct handoff to vanilla when all living players sleep;
- correct recalculation after disconnects;
- normal vanilla wake timing once client/server pacing is synchronized;
- clean regression without the earlier client synchronization error flood.

### SPIKE-004 safety result so far

The v0.0.9 two-player controlled run materially narrowed the remaining Public Alpha safety question.

With an awake injured subject while another player triggered approximately **5x partial calendar compression**:

- active bleeding health loss remained approximately **1x real-time rate** (`~0.993x` in the clean comparison interval);
- `BleedingTime` and scratch-timer progression remained approximately **1x**;
- therefore the feared case where an awake wounded player suddenly bleeds out five or ten times faster was **not observed**.

Nutrition behaved differently and very cleanly:

- calories scaled approximately **5.01x** at 5x compression and **10.00x** at 10x;
- carbohydrates scaled approximately **5.00x / 10.00x**;
- proteins scaled approximately **5.00x / 10.01x**;
- lipids scaled approximately **5.00x / 10.00x**.

Those stores are therefore strongly world/calendar-time bound in the tested conditions.

The remaining blocker is classification of hunger, thirst, fatigue, endurance, stress, sickness, temperature and related character state.

## v0.0.10 focused survival diagnostics

v0.0.10 uses the same registered `CharacterStat`, `MoodleType`, Nutrition and related APIs used by current Build 42 vanilla Lua. The focused streams are:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

The older broad injury/body diagnostic remains available because its wound telemetry is already useful.

### Single-player SPIKE-004 test mode

v0.0.10 also adds an explicit diagnostics-only forced calendar-compression mode so the remaining time-domain test can be run with **one awake character** rather than requiring two computers.

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = true,
    DiagnosticForcedCompressionFactor = 5.0,
}
```

The override is intentionally difficult to activate accidentally:

```text
DiagnosticsEnabled must be true
AND
DiagnosticForcedCompressionFactor must be > 1
```

With a 90-minute baseline and factor `5`, the controller forces `MinutesPerDay=18` while the observed character remains awake. It does **not** change the global simulation multiplier.

If any observed living player falls asleep, the test override is immediately suspended and native `MinutesPerDay` is restored so it cannot stack with vanilla full-sleep acceleration.

For normal gameplay:

```text
DiagnosticsEnabled = false
DiagnosticForcedCompressionFactor = 1.0
```

A standalone `getPlayer()` diagnostic fallback is included so CharacterStat/Nutrition and detailed injury telemetry can still be collected when a single-player session does not expose a populated `getOnlinePlayers()` collection.

## Important design caveat: world time really is passing faster

Enshrouded Sleep does not merely animate the clock faster. During partial sleep, Project Zomboid world/calendar minutes genuinely elapse faster in real time.

The v0.0.9 run confirms that different player systems use different time domains: awake bleeding/injury progression behaved approximately real-time bound, while core nutrition stores followed compressed world time almost exactly. Other world-time systems such as spoilage, farming, generators, corpses, composting and weather remain later characterization targets.

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

`PartialSleepSpeedScale` scales the server's native `FastForwardMultiplier` for **real partial sleep only**. `1.0` is the neutral/default value.

`DiagnosticsEnabled` controls verbose development/support telemetry.

`DiagnosticForcedCompressionFactor` is a **test-only** SPIKE-004 control. At the normal value `1.0` it does nothing. Values above `1.0` only take effect while diagnostics are enabled and must not be used for ordinary play.

## How proportional sleep is calculated

The server uses the currently instantiated living player population:

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

Detailed engineering material is intentionally kept out of this landing page. **The project roadmap is maintained only in [`docs/ROADMAP.md`](docs/ROADMAP.md); this README intentionally does not duplicate it.**

- [`docs/README.md`](docs/README.md) — documentation index
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — deployment/rollback guidance and current deployment gate
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — canonical roadmap and phase criteria
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical architecture
- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — canonical MVP requirements
- [`docs/TESTING.md`](docs/TESTING.md) — current test procedures
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — detailed validation chronology
- [`docs/spikes/`](docs/spikes/) — formal exploratory investigations, including the current health/time-domain spike
- [`docs/adr/`](docs/adr/) — architecture decision records
- [`CHANGELOG.md`](CHANGELOG.md) — version/change history

## License

See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
