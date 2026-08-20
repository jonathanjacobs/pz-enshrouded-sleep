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

The remaining blocker is observability of hunger, thirst, fatigue, endurance, stress, sickness, and related character state. v0.0.9 used legacy `Stats` getter/public-field assumptions and attempted to enumerate Moodles numerically; Build 42.20.3 vanilla code uses a different API shape.

## v0.0.10 focused survival diagnostics

v0.0.10 adds a shared read-only probe and focused server/client diagnostic stream based on the same APIs used by current Build 42 vanilla Lua.

Continuous character stats are read through `CharacterStat` objects:

```lua
local stats = player:getStats()
local hunger = stats:get(CharacterStat.HUNGER)
local thirst = stats:get(CharacterStat.THIRST)
local fatigue = stats:get(CharacterStat.FATIGUE)
local endurance = stats:get(CharacterStat.ENDURANCE)
```

The diagnostic also samples stress, panic, pain, boredom, unhappiness, sickness, food sickness, poison, zombie-infection/fever values, temperature, wetness, fitness, morale, intoxication, discomfort and related registered `CharacterStat` values.

Moodles are queried by `MoodleType`, not by numeric index:

```lua
local moodles = player:getMoodles()
local hungryLevel = moodles:getMoodleLevel(MoodleType.HUNGRY)
local thirstLevel = moodles:getMoodleLevel(MoodleType.THIRST)
local tiredLevel = moodles:getMoodleLevel(MoodleType.TIRED)
local enduranceLevel = moodles:getMoodleLevel(MoodleType.ENDURANCE)
```

Nutrition remains directly observable through:

```lua
local nutrition = player:getNutrition()
nutrition:getWeight()
nutrition:getCalories()
nutrition:getCarbohydrates()
nutrition:getProteins()
nutrition:getLipids()
```

The new diagnostic also emits a one-time `CAPABILITIES` record on server and client so a future `N/A` result tells us whether the class globals, enum members, object, or actual getter path failed.

Diagnostic prefixes are:

```text
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

The older broad health/body diagnostic remains in place because its detailed injury telemetry was already useful and validated. The new stream is deliberately focused on the Build 42 survival-state API gap.

All diagnostic code is observational only and remains dormant unless `DiagnosticsEnabled=true`.

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
true  -> one-second clock, health/body, CharacterStat, Moodle and nutrition telemetry
```

Leave diagnostics off except during controlled testing or focused troubleshooting.

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
