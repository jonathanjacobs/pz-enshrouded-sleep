# Enshrouded Sleep for Project Zomboid B42

A multiplayer sleep mod for Project Zomboid Build 42 that adds Enshrouded-style proportional partial sleeping while leaving vanilla Project Zomboid in control of normal sleep eligibility and full-sleep fast-forward.

The key idea is **calendar/world-time compression**, not global simulation acceleration.

- players sleep using vanilla Project Zomboid rules;
- if no currently instantiated living player is asleep, the native day length is left unchanged;
- if some but not all living players are asleep, the mod dynamically shortens `MinutesPerDay` in proportion to the sleeping fraction;
- awake players, zombies, vehicles, animations, physics, inventory actions, timed actions, combat, and crafting remain at normal active-game simulation speed;
- if all currently instantiated living players are asleep, the mod restores the native day length and vanilla full-sleep fast-forward takes over.

The current development version is `v0.0.6`. The proportional server controller remains behaviorally the same architecture validated in v0.0.4. v0.0.6 adds an experimental server-to-client `MinutesPerDay` synchronization path to address the clock-jump defect identified conclusively by v0.0.5, and expands sleep telemetry for the long-sleep investigation.

See [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) for the canonical specification and acceptance tests, [`docs/TESTING.md`](docs/TESTING.md) for repeatable test procedures, and [`CHANGELOG.md`](CHANGELOG.md) for development history.

## Current validation status

The first successful two-player v0.0.4 test validated the core server-side proportional-sleep path:

```text
2 living / 0 sleeping
-> MinutesPerDay=90.000

2 living / 1 sleeping
-> SleepFraction=0.5000
-> CalendarCompressionFactor=20.000
-> EffectiveMinutesPerDay=4.500

2 living / 2 sleeping
-> restore MinutesPerDay=90.000
-> vanilla full-sleep fast-forward owns the state
```

The test also validated wake restoration and denominator recalculation after disconnect. No Enshrouded Sleep controller exception or fail-safe event was observed.

v0.0.5 then established the root cause of the visible clock snapping. During the same partial-sleep condition, the server correctly ran at `MinutesPerDay=4.5`, while the tested client remained at `MinutesPerDay=90`. The client's local clock therefore advanced too slowly and periodically received multiplayer time corrections of roughly 51 in-game minutes.

Open issues currently under test:

- **Issue #1:** sleeping black-screen clock jumps during partial compression;
- **Issue #2:** awake player's upper-right HUD/watch clock snaps forward during partial compression;
- **Issue #3:** a sleeping character can remain asleep for implausibly large amounts of compressed world time.

At `MinutesPerDay=4.5`, world time naturally advances approximately 5.33 in-game minutes per real second. Rapid clock motion is expected; long holds followed by large corrections are not.

## v0.0.6 synchronization experiment

v0.0.6 introduces two narrowly scoped synchronization modules:

```text
42/media/lua/server/EnshroudedSleep/ClockStateSync_Server.lua
42/media/lua/client/EnshroudedSleep/ClockStateSync_Client.lua
```

The server observes the authoritative runtime `MinutesPerDay` produced by the normal proportional controller and broadcasts it to connected clients whenever the effective clock state changes. A two-second heartbeat allows a client that finishes loading after an earlier state-change packet to converge to the current value.

The client handles only the Enshrouded Sleep `ClockState` command and mirrors that authoritative value through local `GameTime:setMinutesPerDay()`.

The client synchronization path intentionally does **not** call:

```text
setTimeOfDay()
setMultiplier()
GameServer.syncClock()
```

The server remains authoritative for actual world time, sleep state, and the proportional compression decision. The client only uses the same day-length pacing value so its local clock should advance at approximately the same rate between normal multiplayer synchronization corrections.

Synchronization prefixes are:

```text
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
```

The existing one-second diagnostics remain active under:

```text
[EnshroudedSleepDiag][SERVER]
[EnshroudedSleepDiag][CLIENT]
```

For issue #3, v0.0.6 additionally records:

```text
player / OnlineID
isAsleep
AsleepTime
ForceWakeUpTime
Fatigue
SleepingPillsTaken
```

Those sleep values are observational only in v0.0.6. No sleep-recovery or wake-time compensation has been implemented yet.

For the exact test procedure, use [`docs/TESTING.md`](docs/TESTING.md).

## Installation identity

The stable Project Zomboid Mod ID is:

```text
pz-enshrouded-sleep
```

The local mod folder should preferably use the same stable name:

```text
pz-enshrouded-sleep/
```

The server `Mods=` entry must use the `id=` value from `mod.info`:

```text
Mods=pz-enshrouded-sleep
```

Some Build 42/server configurations may display or preserve a leading backslash form such as `\pz-enshrouded-sleep`; the authoritative identifier remains `pz-enshrouded-sleep`.

GitHub's **Download ZIP** feature names the extracted source folder after both the repository and branch, typically:

```text
pz-enshrouded-sleep-main/
```

That branch suffix is not part of the Mod ID. For the least ambiguous server deployment, rename the extracted GitHub folder to `pz-enshrouded-sleep` before placing it in the server's local mods directory.

For v0.0.6 testing, install the same snapshot on every participating client under the normal local user mod directory, for example:

```text
C:\Users\<user>\Zomboid\mods\pz-enshrouded-sleep\
```

The mod's sandbox namespace is:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
},
```

The old prototype-facing names `EnshroudedSleepClockSpike` and `ClockSpike_Server.lua` are no longer active configuration/source names.

## What "compression" means

Suppose a server is configured for a two-hour real-world day:

```text
BaselineMinutesPerDay = 120
FastForwardMultiplier = 40
PartialSleepSpeedScale = 1.0
LivingPlayers = 4
```

The partial-sleep calculation is:

```text
SleepFraction = SleepingPlayers / LivingPlayers
EffectivePartialSleepCap = FastForwardMultiplier * PartialSleepSpeedScale
CalendarCompressionFactor = max(1,
    EffectivePartialSleepCap * SleepFraction)
EffectiveMinutesPerDay =
    BaselineMinutesPerDay / CalendarCompressionFactor
```

That produces:

```text
0 of 4 sleeping -> 1x  -> 120 min/day
1 of 4 sleeping -> 10x -> 12 min/day
2 of 4 sleeping -> 20x -> 6 min/day
3 of 4 sleeping -> 30x -> 4 min/day
4 of 4 sleeping -> theoretical 40x / 3 min/day, but the mod does NOT apply it;
                    it restores 120 and lets vanilla full-sleep fast-forward take over
```

The `10x`, `20x`, and `30x` values are **calendar-compression factors**. They are not player/zombie animation-speed multipliers.

## MVP philosophy: extend vanilla, do not replace it

Vanilla Project Zomboid remains authoritative for:

- `SleepAllowed`;
- `SleepNeeded` and fatigue requirements;
- entering and leaving sleep;
- death and respawn;
- joining and loading;
- spectators and administrative sessions;
- all-living-players-asleep fast-forward.

The mod adds only the missing partial-sleep branch.

The MVP does **not** maintain its own READY/NOT READY state, pre-spawn connection registry, loading-player handshake, or death/respawn suppression layer. It uses the instantiated living-player population exposed through `getOnlinePlayers()` and accepts vanilla lifecycle semantics.

## Native server settings are authoritative

The mod does not duplicate Project Zomboid server configuration with hard-coded native values.

It reads:

- live `GameTime:getMinutesPerDay()` as the native baseline;
- `SleepAllowed`;
- `SleepNeeded`;
- `FastForwardMultiplier`.

The only gameplay-specific mod settings are:

```text
Enabled = true
PartialSleepSpeedScale = 1.0
```

`PartialSleepSpeedScale` fine-tunes the server's existing fast-forward policy:

```text
FastForwardMultiplier = 40
Scale 1.0 -> effective partial cap 40
Scale 0.5 -> effective partial cap 20
Scale 2.0 -> effective partial cap 80
```

The current test server has been validated with:

```text
DayLength = 4
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40.0
```

which produces a live `MinutesPerDay=90`. Those values are a test example, not production constants.

## Runtime behavior

The server controller evaluates the currently instantiated player population every tick:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

The state machine is intentionally small:

```text
Sleeping == 0
    -> restore exact native MinutesPerDay

0 < Sleeping < Living
    -> calculate CalendarCompressionFactor
    -> set EffectiveMinutesPerDay

Sleeping == Living
    -> restore exact native MinutesPerDay
    -> stop interfering
    -> vanilla full-sleep fast-forward owns the state
```

The authoritative controller never calls `GameTime:setMultiplier()`.

In v0.0.6, a separate sync observer republishes the resulting server `MinutesPerDay` to clients. It does not calculate or override the authoritative target.

## Important distinction: world time vs active simulation

Changing `MinutesPerDay` does more than move the clock hands. It changes how rapidly Project Zomboid world/calendar minutes and `WorldAgeHours` progress in real time.

That means systems driven by game minutes or world age may also progress faster in real time during partial sleep compression, even though movement/combat/animation simulation remains normal.

Potential examples, which still require system-by-system validation, include:

- crops/farming;
- food spoilage;
- generator fuel consumption;
- hunger/thirst/fatigue;
- healing;
- corpse decay;
- composting;
- weather progression;
- mods driven by `Events.EveryOneMinute` or `WorldAgeHours`.

For a compression factor `A`, the natural future compensation factor for a system that should remain tied to real/simulation time is:

```text
RealTimeCompensationFactor = 1 / A
```

Per-system compensation is deliberately post-MVP.

## What the diagnostic builds established

Dedicated-server testing on B42.20.2 established that:

- changing server `GameTime:MinutesPerDay` can accelerate world/calendar progression without globally fast-forwarding active gameplay simulation;
- `WorldAgeHours` follows the compressed calendar rate;
- `IsoPlayer:isAsleep()` is reliable server-side;
- `IsoPlayer:isDead()` is sufficient to exclude dead characters from the proportional denominator;
- dead player objects can remain in `getOnlinePlayers()` during respawn;
- an authenticated/loading client may exist before its `IsoPlayer` appears in `getOnlinePlayers()`;
- vanilla full-sleep fast-forward does not work by changing `MinutesPerDay`;
- v0.0.4 correctly applies the expected 20x partial-sleep compression in a two-player/one-sleeper test and correctly restores baseline for vanilla full sleep;
- v0.0.5 proved that a runtime server `MinutesPerDay` change is not automatically reflected in client `getMinutesPerDay()`;
- the mismatched server/client day lengths produce a repeating drift-and-correction pattern visible as large clock jumps;
- the same v0.0.5 run exposed a separate long-sleep behavior that now requires direct sleep-counter telemetry.

## Vanilla full-sleep observation

On the current B42.20.2 test server, `FastForwardMultiplier=40.0` did **not** correspond to an observed 40x calendar rate during vanilla full sleep.

The measured full-sleep behavior was approximately:

```text
MinutesPerDay: 90 -> remains 90
GameTime:getMultiplier(): ~4.8 -> ~575
TrueMultiplier: remains 1
Observed calendar progression: roughly 120x baseline
```

The mod deliberately does not convert that observation into a hard-coded `120x` or `3 * FastForwardMultiplier` rule.

For partial sleep, the configured `FastForwardMultiplier` is used as the administrator's **policy input** for calendar compression. At 100% asleep, vanilla owns the behavior.

## v0.0.6 implementation

The current development build:

- uses stable Mod ID `pz-enshrouded-sleep`;
- uses sandbox namespace `EnshroudedSleep`;
- retains the server-authoritative proportional controller introduced in v0.0.3 and validated in v0.0.4;
- captures the exact runtime `MinutesPerDay` baseline;
- reads native `SleepAllowed`, `SleepNeeded`, and `FastForwardMultiplier` from `getServerOptions()`;
- exposes `PartialSleepSpeedScale` as a double-valued sandbox option;
- counts living/sleeping players from `getOnlinePlayers()`;
- applies proportional server `MinutesPerDay` compression only during partial sleep;
- restores the exact server baseline at zero sleepers, all sleepers, disable, or fail-safe conditions;
- never calls the global simulation multiplier from the authoritative controller;
- broadcasts authoritative server `MinutesPerDay` to clients on state changes plus a two-second heartbeat;
- mirrors that value into local client `GameTime:MinutesPerDay` without setting `TimeOfDay` or a multiplier;
- records one-second server/client GameTime telemetry;
- records per-player sleep counters while sleep is active.

## MVP acceptance criteria

Before `v0.1.0`, dedicated-server testing should demonstrate:

1. changing native day length automatically changes the captured baseline;
2. changing native `FastForwardMultiplier` automatically changes partial-sleep compression;
3. `PartialSleepSpeedScale=1.0` is neutral and other values scale proportionally;
4. one of two players sleeping at baseline 90 / native FF 40 produces approximately `MinutesPerDay=4.5`; **validated server-side in v0.0.4**;
5. with baseline 120 / native FF 40 / four players, 1/4, 2/4, and 3/4 sleeping produce approximately 12, 6, and 4 MinutesPerDay;
6. awake gameplay simulation remains normal during partial sleep;
7. calendar time and `WorldAgeHours` follow the calculated compression factor;
8. waking the last partial sleeper restores the exact baseline immediately; **observed in v0.0.4**;
9. all living players asleep restores baseline before vanilla takes over, with no intentional stacking; **observed in v0.0.4**;
10. disabling the mod or hitting a recoverable error restores native time;
11. connected clients use the same effective `MinutesPerDay` as the server during partial compression;
12. sleeping and awake client clocks visually track compressed world time without large periodic snaps;
13. vanilla sleep duration remains sensible in world-time terms, including when sleeping pills or other native modifiers are present.

## Explicitly out of scope for MVP

The first release intentionally excludes:

- time-of-day sleep windows;
- custom fatigue/sleep eligibility;
- pre-spawn/loading-player readiness tracking;
- custom death/respawn fast-forward suppression;
- spectator-session readiness tracking;
- broad per-system time-domain compensation;
- explicit compensation for spoilage, farming, generator fuel, corpse decay, composting, etc. until validated;
- guaranteed compatibility with other sleep/recovery mods;
- player-facing compression notifications;
- configuration presets.
