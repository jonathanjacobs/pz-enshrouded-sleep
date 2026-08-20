# Roadmap

This is the **single canonical roadmap** for Enshrouded Sleep. The top-level README links here but intentionally does not duplicate roadmap content.

The roadmap is evidence-driven. Controlled spikes and Public Alpha field results may change priorities.

## Current phase — Pre-Public-Alpha validation

Status: **Public Alpha candidate; deployment paused pending final survival-state characterization**

Current development version: `v0.0.10`

Current behaviorally validated platform baseline: Project Zomboid `42.20.3`

The core two-player sleep/clock architecture is working. Issues involving clock jumps, client day-length mismatch, and pathological long sleep have been resolved. The remaining pre-alpha gate is [`SPIKE-004 — Player Health and Survival Time Domains Under Calendar Compression`](spikes/SPIKE-004-health-time-domains.md).

### Evidence established by v0.0.9

The controlled two-player v0.0.9 run materially reduced the safety risk:

- awake-player health loss from active bleeding remained approximately real-time bound (`~0.993x` during a 5x partial-compression comparison);
- `BleedingTime` and scratch-timer progression remained approximately `1x`;
- no rapid awake-player bleed-out caused by `MinutesPerDay` compression was observed;
- calories scaled approximately `5.01x` at 5x compression and `10.00x` at 10x;
- carbohydrates scaled approximately `5.00x / 10.00x`;
- proteins scaled approximately `5.00x / 10.01x`;
- lipids scaled approximately `5.00x / 10.00x`;
- server/client `MinutesPerDay` synchronization and baseline restoration remained correct;
- `TrueMultiplier` remained `1.0` during partial compression.

This establishes that player systems do not share one time domain: awake injury/bleeding behaved simulation/real-time bound, while core nutrition stores behaved world/calendar-time bound.

### Why v0.0.10 exists

v0.0.9 still returned `N/A` for hunger, thirst, fatigue, endurance, stress, panic, pain, sickness and related continuous state; its Moodle fallback also failed.

Review of current Build 42.20.3 vanilla Lua and decompiled classes identified the cause: current vanilla code reads survival state through registered `CharacterStat` objects and queries Moodles using `MoodleType` objects. The earlier diagnostic still assumed legacy named Stats getters/public fields and numeric Moodle enumeration.

v0.0.10 therefore adds a focused read-only diagnostic using:

```lua
player:getStats():get(CharacterStat.HUNGER)
player:getStats():get(CharacterStat.THIRST)
player:getStats():get(CharacterStat.FATIGUE)
player:getStats():get(CharacterStat.ENDURANCE)

player:getMoodles():getMoodleLevel(MoodleType.HUNGRY)
player:getMoodles():getMoodleLevel(MoodleType.THIRST)
player:getMoodles():getMoodleLevel(MoodleType.TIRED)
player:getMoodles():getMoodleLevel(MoodleType.ENDURANCE)
```

It also emits one-time capability records so inaccessible classes/enums/methods can be diagnosed directly from the next test logs.

### Current blocker

Run one focused v0.0.10 test and classify the still-unresolved variables:

- hunger / Hungry Moodle;
- thirst / Thirst Moodle;
- fatigue / Tired Moodle;
- endurance / Endurance Moodle;
- stress, panic and pain where useful;
- sickness / food sickness / poison where practical;
- zombie infection/fever values where practical;
- temperature/wetness/cold state where practical.

The bleeding experiment does **not** need to be repeated unless v0.0.10 unexpectedly exposes a regression.

### Recommended v0.0.10 test

Use two players and native `FastForwardMultiplier=10`:

```text
Phase A: both awake, 60–90 real seconds
Phase B: monitored player awake + other player asleep, 60–90 real seconds
         expected ~5x / MinutesPerDay=18
Phase C: both awake again, 60–90 real seconds
```

Before interpreting rates, verify the new `CAPABILITIES` records show that CharacterStats and Moodles are readable on the relevant server/client side.

### Pre-alpha exit criteria

Move to Public Alpha when:

- v0.0.10 loads without new Enshrouded Sleep errors;
- corrected CharacterStat/Moodle telemetry is verified, or any remaining unavailable fields are explicitly characterized;
- hunger/thirst/fatigue/endurance and other practical high-severity values are classified sufficiently to assess player safety;
- no unacceptable rapid awake-player starvation/dehydration, infection, temperature or comparable failure is observed, **or** a validated mitigation/configuration bound is adopted;
- the normal core two-player sleep regression still passes;
- SPIKE-004 records a formal **GO / CONDITIONAL GO / NO-GO** decision.

## Public Alpha — next

If SPIKE-004 produces a GO or acceptable conditional GO, deploy to a real multiplayer server with diagnostics normally disabled.

Primary goals:

- exercise proportional sleep with 3–12+ players;
- observe joins, disconnects, deaths, respawns, and repeated sleep/wake cycles;
- verify clock continuity and normal-speed awake gameplay over long sessions;
- validate player survival behavior under ordinary live conditions;
- characterize non-health world-time-driven effects such as spoilage, crops, generators, corpse decay, composting, and weather;
- identify compatibility problems with other sleep/recovery or world-time-driven mods;
- keep deployment and rollback operationally simple.

### Public Alpha exit criteria

Move toward Public Beta when field evidence supports:

- no recurring clock-jump/client synchronization defect;
- no global acceleration of awake simulation;
- no repeated sleep-duration pathology;
- no high-severity awake-player health/survival effect caused by partial compression;
- reliable baseline restoration and vanilla full-sleep handoff across larger populations;
- proportional behavior validated with more than two living players;
- configuration inheritance validated across alternate native day length and/or `FastForwardMultiplier` settings;
- operationally acceptable log/error volume;
- major world-time side effects documented, accepted, or explicitly addressed.

## Public Beta / v0.1.x

Public Beta focuses on stabilization, not replacement of the validated core sleep model.

Likely work:

- complete the remaining MVP acceptance matrix;
- establish a compatibility matrix for important B42 multiplayer/sleep mods;
- document expected behavior of major world-time-driven systems;
- decide whether any measured system needs optional real-time compensation or should intentionally follow compressed world time;
- improve administrator-facing configuration/documentation based on alpha feedback;
- reduce/remove development instrumentation no longer needed;
- improve distribution/installation workflow;
- establish regression checks for future Project Zomboid B42 updates.

## v1.0 readiness

A stable `v1.0` requires:

- stable, documented server/client synchronization architecture;
- reliable behavior across representative multiplayer population sizes;
- no known high-severity player/save/world-state risk caused by the mod;
- clearly documented interaction with world-time-driven systems;
- reliable installation, upgrade, disable, and rollback procedures;
- concise administrator configuration;
- clean support/reporting workflow;
- compatibility claims limited to combinations actually tested.

## Post-MVP candidates

Possible future features, not commitments:

- player-facing notification when partial-sleep compression begins/ends;
- configuration presets;
- optional policies/compensation for selected measured world-time-driven systems;
- administrator observability/status tools;
- compatibility helpers for specific sleep/recovery mods;
- refined lifecycle handling if public-server evidence demonstrates a real need;
- configurable sleep windows or other non-vanilla sleep policy extensions.

## Explicit non-goals for current pre-alpha/alpha work

The project is not currently trying to:

- replace vanilla fatigue or sleep eligibility;
- create a separate ready/not-ready voting system;
- implement custom lobby/readiness tracking;
- globally fast-forward active gameplay simulation;
- guarantee compatibility with every mod;
- preemptively compensate every world-time-driven system without measured evidence.
