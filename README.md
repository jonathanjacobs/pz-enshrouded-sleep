<p align="center">
  <img src="docs/images/enshrouded-sleep-banner.png" alt="Enshrouded Sleep - Project Zomboid multiplayer sleep mod" width="100%">
</p>

# Enshrouded Sleep

**Proportional multiplayer sleeping for Project Zomboid Build 42 servers.**

Status: **Public Beta**  
Current version: **v0.1.1**  
Validated Project Zomboid baseline: **42.20.4**  
Steam Workshop ID: **3786842301**

## What it does

Enshrouded Sleep lets part of a multiplayer server population sleep without requiring every living player to go to bed at the same time.

During partial sleep, the authoritative server accelerates world/calendar time by reducing `GameTime:MinutesPerDay`. Awake movement, combat, vehicles, animations, physics, and ordinary timed actions remain on the normal active-simulation path. When all living players are asleep, the mod restores the native day length and hands full-sleep acceleration back to vanilla Project Zomboid.

Public Beta also protects awake living players from the extra partial-sleep acceleration of Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, and Weight progression. Sleeping players remain vanilla-authoritative.

Local/standalone single-player gameplay is outside the supported scope.

## Features

- proportional partial-sleep calendar compression based on the sleeping fraction;
- server-authoritative day-length changes rather than global simulation fast-forward;
- explicit server-to-client clock pacing synchronization;
- exact baseline restoration and vanilla all-asleep handoff;
- awake-player survival protection during partial sleep;
- independent protection-disable switch for compatibility testing;
- optional concise server-chat sleep/world-time notifications, disabled by default and controlled by the server administrator;
- low-volume operational logging plus opt-in verbose diagnostics.

## Build 42.20.4 compatibility

Public Beta v0.1.1 is based on a Project Zomboid **42.20.4** (`b0bbce05d5`) compatibility checkpoint from dedicated-server and connected-client logs. Startup, native baseline capture, normal all-awake operation, and server-to-client `ClockState` synchronization completed without a relevant Enshrouded Sleep Lua exception.

The 42.20.4 security hotfix removed Lua `loadstring`/`loadstream`. Enshrouded Sleep does not use either API. Its multiplayer synchronization and optional notification paths use predefined named `sendServerCommand` / `OnServerCommand` messages with structured arguments rather than server-supplied executable code.

The optional sleep-notification path is included in v0.1.1 for live Public Beta field validation on the WHG server. It is disabled by default and can be turned off independently if the chat/display path causes a compatibility issue; doing so does not alter sleep policy, clock synchronization, or awake-player protection.

## Server setup

```text
WorkshopItems=3786842301
Mods=pz-enshrouded-sleep
```

Recommended Public Beta defaults:

```text
EnshroudedSleep.Enabled=true
EnshroudedSleep.PartialSleepSpeedScale=1.0
EnshroudedSleep.AwakePlayerProtectionEnabled=true
EnshroudedSleep.SleepNotificationsEnabled=false
EnshroudedSleep.DiagnosticsEnabled=false
EnshroudedSleep.DiagnosticForcedCompressionFactor=1.0
```

`SleepNotificationsEnabled=true` broadcasts short sleep-state messages such as `[Enshrouded Sleep] 1/2 living players sleeping (50%). World time is 20x faster.` whenever the effective multiplayer sleep state changes. It is an administrator-controlled presentation option only; disabling it does not change sleep policy, clock synchronization, or awake-player protection.

For option semantics, upgrade procedure, monitoring, diagnostic use, and rollback, use [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md). The in-game sandbox tooltips contain the same administrator-facing option guidance.

## Important Beta boundary

World/calendar time genuinely advances faster during partial sleep. Awake-player protection applies only to the explicitly supported player survival fields above. External world-time systems—including food aging/spoilage, generator and vehicle resources, farming/crops, weather, corpses, and modded world systems—remain on their normal game-world clocks unless separately addressed.

Controlled testing established the core time-compression/client-sync architecture and the feasibility of awake-player protection. Public Beta is collecting broader multiplayer, lifecycle, performance, notification, and mod-stack evidence. Current targets are maintained only in [`docs/ROADMAP.md`](docs/ROADMAP.md); detailed evidence lives in [`docs/VALIDATION_HISTORY.md`](docs/VALIDATION_HISTORY.md) and [`docs/spikes/`](docs/spikes/).

## Documentation

- [`docs/README.md`](docs/README.md) — documentation index.
- [`docs/DOCUMENTATION_OWNERSHIP.md`](docs/DOCUMENTATION_OWNERSHIP.md) — source-of-truth rules for repository documentation.
- [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) — normative behavior.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — technical design.
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — server administration and rollback.
- [`docs/TESTING.md`](docs/TESTING.md) — current test procedures.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — current/future work.
- [`CHANGELOG.md`](CHANGELOG.md) — release history.
- [`COMPLIANCE.md`](COMPLIANCE.md) — mod-policy compliance entry point.

## License and disclaimers

Source-code licensing is in [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE); creative/promotional asset licensing is in [`ASSET_LICENSE.md`](ASSET_LICENSE.md); third-party provenance is tracked in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

**Project Zomboid / The Indie Stone:** Enshrouded Sleep is an unofficial community mod. It is not developed by, affiliated with, sponsored by, endorsed by, or otherwise official to The Indie Stone.

**Enshrouded / Keen Games:** Enshrouded Sleep is not developed by, affiliated with, sponsored by, or endorsed by Keen Games. The name refers to general multiplayer-sleep design inspiration only; no Enshrouded code, assets, or game content are redistributed.
