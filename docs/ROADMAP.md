# Roadmap

This is the single canonical roadmap for Enshrouded Sleep. The top-level README links here rather than maintaining a second roadmap.

Enshrouded Sleep is a multiplayer-server mod. Local/standalone single-player support is not a project goal.

## Current phase — Public Beta

Status: **Public Beta / field validation**  
Current version: `v0.1.0`  
Validated platform baseline: Project Zomboid `42.20.3`  
Steam Workshop ID: `3786842301`

Public Beta promotes the SPIKE-006 awake-player protection mechanism into normal multiplayer partial sleep. The controlled one-player forced-compression path is no longer the production behavior; it remains only as a diagnostic regression tool.

## v0.1.0 product semantics

During normal partial sleep:

```text
SleepFraction = SleepingPlayers / LivingPlayers
CalendarCompressionFactor = max(1,
    FastForwardMultiplier × PartialSleepSpeedScale × SleepFraction)
EffectiveMinutesPerDay = BaselineMinutesPerDay / CalendarCompressionFactor
```

When `AwakePlayerProtectionEnabled=true` (Beta default), each awake living player is normalized toward native-day-length progression for:

- hunger;
- thirst;
- fatigue;
- calories;
- carbohydrates;
- proteins;
- lipids;
- weight progression.

Sleeping players are never normalized. When every living player is asleep, Enshrouded Sleep restores native `MinutesPerDay` and vanilla full-sleep acceleration owns the state.

External world systems remain on vanilla world/calendar time. v0.1.0 does not compensate spoilage, farming/crops, generator fuel/wear, vehicle resource use, corpses, weather, or arbitrary modded world systems.

## SPIKE-006 decision

Controlled feasibility: **GO for Public Beta field validation**.

Evidence established before promotion includes:

- server tick-driven correction path executes reliably on dedicated B42.20.3;
- world/calendar clock remained approximately 20x while `TrueMultiplier=1.0`;
- passive Hunger/Thirst/Fatigue/Calories/Protein/Weight measurements were approximately native 1x in the first successful correction run;
- subsequent testing with Carbohydrates/Lipids away from clamps showed those stores also near native pacing;
- eating and drinking favorable effects were preserved;
- running/sprinting retained active gameplay consequences such as endurance loss and increased expenditure;
- sleeping immediately suspended awake correction and restored native `MinutesPerDay` for vanilla full-sleep behavior;
- waking reinitialized the reference snapshot before correction resumed;
- no relevant Enshrouded Sleep Lua error occurred in the successful controlled run.

This is not a claim that all multiplayer/mod-stack combinations are proven safe. Public Beta deliberately moves the remaining validation into normal server field operation with an independent protection-disable switch and documented rollback path.

## Public Beta field goals

Primary live goals:

- exercise 3–12+ living-player populations and multiple sleeping fractions;
- verify every awake living player is protected while sleepers remain vanilla-authoritative;
- exercise joins, disconnects, deaths, respawns, and rapidly changing denominators;
- repeat sleep/wake cycles across long sessions;
- observe client clock continuity and exact baseline restoration;
- characterize normal gameplay effects under real multiplayer activity;
- identify conflicts with mods that alter sleep, `MinutesPerDay`, hunger/thirst/fatigue, nutrition, or timed actions;
- monitor performance/log volume of the multi-player correction path;
- validate disable/upgrade/rollback through the permanent Workshop item.

Verbose diagnostics are not required for ordinary Beta operation. Low-volume roster/protection transitions remain useful continuously; verbose diagnostics should be enabled for focused windows when a reproducible anomaly needs deeper evidence.

## Public Beta exit criteria

Move toward a stable release candidate when field evidence supports:

- no recurring clock-jump/client synchronization defect during ordinary play;
- no global acceleration of awake simulation;
- no repeated sleep-duration pathology;
- awake-player protection remains stable across representative multiplayer populations;
- eating/drinking/activity and other common direct effects are not materially distorted;
- sleeping-player physiology remains vanilla-authoritative;
- reliable baseline restoration and vanilla full-sleep handoff;
- joins/disconnects/deaths/respawns do not leave stale protected state;
- operationally acceptable CPU/log volume;
- representative mod-stack interaction is stable enough for routine operation;
- major external world-time side effects remain documented/accepted or are addressed separately;
- Workshop install/update/rollback remains repeatable.

## SPIKE-005 / later world-system policy

SPIKE-005 remains open but is not a blocker to v0.1.0. Confirmed world/calendar examples include generator fuel, ambient/refrigerated food aging, vehicle fuel while idling, and vehicle battery drain under a stable engine-off load.

Potential later policy remains subsystem-specific and evidence-backed. Unsupported systems must remain vanilla rather than being represented as compensated.

## Administrator UX

Public Beta includes clearer in-game sandbox labels/tooltips for proportional speed, awake-player protection, verbose diagnostics, and the one-player forced-compression test. A separate read-only admin runtime status panel remains a future candidate because custom sandbox options are editable configuration rather than dynamic status fields.

## v1.0 readiness

A stable v1.0 requires stable server/client synchronization, reliable representative multiplayer behavior, no known high-severity player/save/world-state risk, documented world-time interactions, reliable install/upgrade/disable/rollback procedures, concise administration, and compatibility claims limited to tested combinations.

## Explicit non-goals

The project is not trying to support local/standalone single-player, replace vanilla fatigue/sleep eligibility, create a readiness/voting system, globally fast-forward active simulation, patch Project Zomboid Java/core files for ordinary Workshop distribution, guarantee compatibility with every mod, or preemptively compensate every world-time-driven system.
