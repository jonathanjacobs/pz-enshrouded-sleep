<p align="center">
  <img src="docs/images/enshrouded-sleep-banner.png" alt="Enshrouded Sleep - Project Zomboid multiplayer sleep mod" width="100%">
</p>

# Enshrouded Sleep

**Proportional multiplayer sleeping for Project Zomboid Build 42 servers.**

Status: **Public Beta**  
Current version: **v0.1.0**  
Validated Project Zomboid baseline: **42.20.3**  
Steam Workshop ID: **3786842301**

## Overview

Enshrouded Sleep is a multiplayer-server mod for Project Zomboid Build 42. It lets part of a server population sleep without requiring every living player to go to bed at the same time.

During partial sleep, the authoritative server compresses world/calendar time by changing `GameTime:MinutesPerDay`. Awake movement, combat, vehicles, animations, physics, and ordinary timed actions remain on the normal active-simulation path. When all living players are asleep, Enshrouded Sleep restores the native day length and hands full-sleep acceleration back to vanilla Project Zomboid.

Public Beta v0.1.0 adds server-authoritative **awake-player survival protection**. During normal partial sleep, awake living players are normalized toward the survival-needs/metabolism rate expected at the server's native day length for Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, and Weight. Sleeping players are never corrected.

Local/standalone single-player gameplay is not a supported target.

## Features

- proportional partial-sleep calendar compression based on `SleepingPlayers / LivingPlayers`;
- server-authoritative `MinutesPerDay` changes rather than global simulation fast-forward;
- explicit server-to-client day-length synchronization;
- exact baseline restoration when partial sleep ends;
- vanilla full-sleep handoff when every living player sleeps;
- runtime inheritance of native day length and `FastForwardMultiplier`;
- awake-player survival protection during partial sleep, enabled by default in Public Beta;
- independent protection rollback switch for compatibility testing;
- low-volume roster/protection state logging plus opt-in verbose diagnostics.

## Requirements and installation

Validated baseline: Project Zomboid **42.20.3**.

Stable identifiers:

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

The single authoritative runtime tree is:

```text
Contents/mods/pz-enshrouded-sleep/
```

Players joining a Workshop-configured server should use the Workshop-distributed copy rather than keeping a separate manual copy of the same mod. See [`docs/STEAM_WORKSHOP.md`](docs/STEAM_WORKSHOP.md) and [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

## Configuration

Recommended Public Beta configuration:

```text
EnshroudedSleep.Enabled=true
EnshroudedSleep.PartialSleepSpeedScale=1.0
EnshroudedSleep.AwakePlayerProtectionEnabled=true
EnshroudedSleep.DiagnosticsEnabled=false
EnshroudedSleep.DiagnosticForcedCompressionFactor=1.0
```

### Enabled

Turns Enshrouded Sleep on/off. Disabling the mod restores the captured native `MinutesPerDay` baseline where possible.

### PartialSleepSpeedScale

Fine-tunes partial-sleep acceleration without replacing the player ratio:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = FastForwardMultiplier × PartialSleepSpeedScale
CalendarCompressionFactor = max(1, EffectivePartialSleepCap × SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

`1.0` is neutral, `0.5` halves partial-sleep acceleration, `2.0` doubles it, and `0.0` disables extra partial-sleep calendar compression. This setting does not alter vanilla full-sleep behavior.

### AwakePlayerProtectionEnabled

Default: `true` in Public Beta.

When enabled, awake living players are protected from the extra Hunger/Thirst/Fatigue/Nutrition/Weight progression caused specifically by partial-sleep calendar compression. Sleeping players remain vanilla-authoritative. Controlled SPIKE-006 testing showed passive rates near native 1x while the world clock ran near 20x, and preserved tested eating, drinking, running/sprinting, sleep/wake, and direct favorable effects.

If a compatibility problem is suspected, set this to `false` first. Proportional sleep/calendar compression will continue, but awake survival fields will return to the older Alpha behavior and follow compressed world time.

### DiagnosticsEnabled

Default: `false`.

Enables detailed clock, sleep, CharacterStat, Moodle, nutrition, injury, action/activity, and awake-protection telemetry. It can grow logs very quickly, especially with several connected players. Ordinary roster and protection-mode transitions remain low-volume even when verbose diagnostics are disabled.

### DiagnosticForcedCompressionFactor

Default: `1.0`. This is a controlled **one-player test tool**, not gameplay tuning. Values above 1 only operate with diagnostics enabled and exactly one living awake player; sleeping or another player connecting suspends the override and restores native `MinutesPerDay`. Keep it at `1.0` during normal multiplayer operation.

## Time-domain behavior and Beta scope

World/calendar time genuinely advances faster during partial sleep. Public Beta v0.1.0 protects only the explicitly supported awake-player survival fields. External world-time systems remain vanilla: food aging/spoilage, generator fuel, vehicle fuel/battery behavior, farming/crops, weather, corpses, modded world systems, and similar systems can continue advancing with the compressed calendar.

Controlled testing established that acute awake bleeding/body-health loss and resting endurance recovery were approximately simulation/real-time bound under tested conditions; they are not broadly compensated.

Public Beta is intentionally collecting larger-population field evidence. Real multiplayer fractions, joins/disconnects/deaths/respawns, repeated sleep/wake cycles, long sessions, and mod-stack interactions remain validation targets. See [`docs/ROADMAP.md`](docs/ROADMAP.md) and [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md).

## Diagnostics and support

Useful log prefixes include:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
[EnshroudedSleepAwakeProtect][SERVER]
[EnshroudedSleepActionDiag][SERVER]
[EnshroudedSleepActionDiag][CLIENT]
[EnshroudedSleepDiag][SERVER]
[EnshroudedSleepDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

For an awake-protection-only problem, first set `AwakePlayerProtectionEnabled=false`, preserve logs, and verify whether the core proportional sleep behavior remains stable. For controller/time synchronization or serious player/world-state problems, stop the server, preserve logs, and follow the full rollback procedure in [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

## Documentation

- [`docs/README.md`](docs/README.md) — documentation index and current state
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — Public Beta deployment, monitoring, diagnostics, and rollback
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — canonical roadmap
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical architecture
- [`docs/TESTING.md`](docs/TESTING.md) — smoke/regression/field-testing procedures
- [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) — validation chronology
- [`docs/spikes/SPIKE-006-awake-player-protection.md`](docs/spikes/SPIKE-006-awake-player-protection.md) — awake-protection investigation
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) — release/Workshop gate
- [`COMPLIANCE.md`](COMPLIANCE.md) — Project Zomboid mod-policy compliance entry point
- [`CHANGELOG.md`](CHANGELOG.md) — version history

## License and disclaimers

Source-code licensing is in [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE); creative/promotional asset licensing is in [`ASSET_LICENSE.md`](ASSET_LICENSE.md); third-party provenance is tracked in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

**Project Zomboid / The Indie Stone:** Enshrouded Sleep is an unofficial community mod. It is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone. Project Zomboid and associated intellectual property remain the property of The Indie Stone.

**Enshrouded / Keen Games:** Enshrouded Sleep is not developed by, affiliated with, sponsored by, or endorsed by Keen Games. The name refers to general multiplayer-sleep design inspiration only; no Enshrouded code, assets, or game content are redistributed.
