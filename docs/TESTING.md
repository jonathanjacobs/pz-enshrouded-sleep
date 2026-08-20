# Enshrouded Sleep — Testing Guide

Current status: **Public Alpha**  
Current version: `v0.0.10`  
Current behaviorally validated Project Zomboid baseline: `42.20.3`

Enshrouded Sleep is a **multiplayer-server mod**. Local/standalone single-player is not a supported runtime target.

Historical procedures/results are consolidated in [`VALIDATION_HISTORY.md`](VALIDATION_HISTORY.md). The completed pre-alpha health/survival investigation is [`SPIKE-004`](spikes/SPIKE-004-health-time-domains.md).

The authoritative runtime mod tree is:

```text
Contents/mods/pz-enshrouded-sleep/
```

## 1. Tier 1 — startup smoke test

Run after any source/configuration change or Project Zomboid update.

Minimum checks:

1. Server starts without Enshrouded Sleep Lua errors.
2. Client(s) connect without Enshrouded Sleep Lua errors.
3. Core controller and client clock synchronization load as Public Alpha `v0.0.10`.
4. With all connected players awake, `MinutesPerDay` remains at native baseline.
5. With `DiagnosticsEnabled=false`, no one-second diagnostic stream is emitted.
6. `DiagnosticForcedCompressionFactor=1.0` remains inert.

## 2. Tier 2 — core multiplayer regression

Reference validated configuration:

```text
Baseline MinutesPerDay = 90
SleepAllowed = true
SleepNeeded = true
FastForwardMultiplier = 40
PartialSleepSpeedScale = 1.0
DiagnosticsEnabled = false
DiagnosticForcedCompressionFactor = 1.0
```

Minimum regression:

1. Connect two living players and confirm server/clients at baseline.
2. Put one player to sleep and keep one awake.
3. Confirm proportional compression (`2 living / 1 sleeping` gave factor 20 / `MinutesPerDay=4.5` in the reference setup).
4. Confirm both clients adopt the authoritative value and clocks remain visually smooth.
5. Confirm awake movement/actions remain normal-speed.
6. Wake the sleeper and confirm exact baseline restoration.
7. Put both to sleep and confirm baseline is restored before vanilla full-sleep fast-forward owns the state.
8. If practical, disconnect one player and confirm population/state recalculation.

## 3. Completed SPIKE-004 safety baseline

Controlled v0.0.9/v0.0.10 testing established:

- awake bleeding/body-health loss remained approximately real-time bound;
- measured bleeding/scratch timers remained approximately real-time bound;
- resting endurance recovery remained approximately real-time bound under the tested condition;
- hunger, thirst, fatigue and core nutrition stores tracked compressed world/calendar time;
- `TrueMultiplier` remained `1.0` during partial/forced calendar compression;
- no proportional acute-health acceleration was observed;
- temperature remained physiologically stable in the tested 5x/10x/20x periods;
- the one-player diagnostic override restored baseline when the test player slept.

SPIKE-004 decision: **GO for Public Alpha**.

Detailed measurements remain in [`spikes/SPIKE-004-health-time-domains.md`](spikes/SPIKE-004-health-time-domains.md).

## 4. Steam Workshop package smoke test

Run this before broad publication and after any change to Workshop/package structure.

1. Confirm the clean Workshop authoring directory contains `workshop.txt`, the required valid `preview.png`, and `Contents/mods/pz-enshrouded-sleep/`.
2. Confirm source-control metadata (`.git/`), private logs, credentials, local test artifacts, ZIPs/backups, and scratch files are absent.
3. Upload/update through Project Zomboid `Workshop -> Create and Update Items`.
4. Subscribe/download the resulting Steam item rather than testing the authoring copy directly.
5. Confirm the downloaded Workshop package contains the expected Public Alpha documentation plus exactly one runtime mod tree.
6. Confirm the inner runtime `mod.info`/`42/mod.info` identify `pz-enshrouded-sleep` and version `0.0.10`.
7. Configure a dedicated test server with the real Workshop ID plus `Mods=pz-enshrouded-sleep`.
8. Run Tier 1 against the Workshop-distributed copy.
9. Run a short Tier 2 two-player partial-sleep transition before broad announcement if practical.
10. Verify uninstall/disable returns future sleep/time behavior to vanilla as documented.

See [`STEAM_WORKSHOP.md`](STEAM_WORKSHOP.md) for authoring and permanent-ID handling.

## 5. Public Alpha field testing

Normal live configuration:

```lua
EnshroudedSleep = {
    Enabled = true,
    PartialSleepSpeedScale = 1.0,
    DiagnosticsEnabled = false,
    DiagnosticForcedCompressionFactor = 1.0,
}
```

Primary field targets:

- 3–12+ living players;
- multiple sleeping fractions;
- joins/disconnects/deaths/respawns;
- repeated sleep/wake cycles;
- long-session stability;
- normal live mod-stack interaction;
- spoilage, generators, crops, corpses, composting and weather;
- pathological survival states not activated during SPIKE-004 where safe/practical;
- client pacing during ordinary administration and sandbox changes;
- Steam Workshop install/update behavior on server and clients.

## 6. Focused diagnostic regression

The v0.0.10 one-connected-player forced-compression mode is retained for controlled support/regression work only.

Activation requires:

```text
DiagnosticsEnabled=true
DiagnosticForcedCompressionFactor>1
living=1
sleeping=0
```

With a native baseline of `90`:

```text
factor 5  -> 18 min/day
factor 10 -> 9 min/day
factor 20 -> 4.5 min/day
```

Expected safety behavior:

```text
player sleeps        -> restore baseline; suspend override
second player joins  -> restore baseline; suspend override
no players connected -> retain baseline; override remains armed
factor returns to 1  -> normal server policy resumes
```

For ordinary support diagnostics, keep the forced factor at `1.0`.

## 7. Diagnostics collection

When needed, collect:

```text
server console
server Logs/DebugLog
affected client Logs/DebugLog
```

Relevant prefixes:

```text
[EnshroudedSleep]
[EnshroudedSleepSync][SERVER]
[EnshroudedSleepSync][CLIENT]
[EnshroudedSleepDiag][SERVER]
[EnshroudedSleepDiag][CLIENT]
[EnshroudedSleepHealthDiag][SERVER]
[EnshroudedSleepHealthDiag][CLIENT]
[EnshroudedSleepSurvivalDiag][SERVER]
[EnshroudedSleepSurvivalDiag][CLIENT]
```

Disable verbose diagnostics after the shortest useful reproduction.

## 8. Project Zomboid update regression

For a new B42 build, review relevant `GameTime`, sleep/lifecycle, `CharacterStat`, `MoodleType`, `Nutrition` and BodyDamage changes; run Tier 1; run Tier 2 if engine behavior changed; and re-run focused survival testing only when relevant.

See [`ROADMAP.md`](ROADMAP.md) for phase criteria.
