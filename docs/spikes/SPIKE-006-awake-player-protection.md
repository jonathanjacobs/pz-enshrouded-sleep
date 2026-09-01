# SPIKE-006 — Awake-Player Survival Protection Feasibility

Status: **COMPLETED — GO; PROMOTED TO PUBLIC BETA IN v0.1.0**

Target release: **v0.1.0 Public Beta (released)**

Validated source/runtime baseline: **Project Zomboid 42.20.3 controlled tests; 42.20.4 field evidence**

GitHub issue: **#7**

## Question

Can Enshrouded Sleep protect an **awake** multiplayer player from the extra hunger/thirst/fatigue/nutrition/weight progression caused by partial-sleep `MinutesPerDay` compression while preserving:

- vanilla sleeping-player behavior;
- vanilla activity, trait, thermoregulation, eating, and drinking effects;
- server authority;
- normal-speed active simulation;
- compatibility with ordinary Workshop Lua distribution?

This spike is intentionally narrower than SPIKE-005. External world systems may remain world-time-driven for the next release. The first product goal is awake-player survival protection.

## Evidence inherited from SPIKE-004

Controlled runtime testing established that the following scale with compressed world/calendar time:

- hunger;
- thirst;
- fatigue;
- calories;
- carbohydrates;
- proteins;
- lipids.

By contrast, the tested acute bleeding/body-health-loss path and resting endurance recovery remained approximately simulation/real-time bound.

Therefore the production implementation does **not** apply broad health compensation. It targets only systems known to accelerate with the world clock.

## B42.20.3 decompile findings

### Game-time scaling primitive

`GameTime.getDeltaMinutesPerDay()` returns:

```text
30 / MinutesPerDay
```

The decompiled method comment describes it as the factor used when a value should advance at a fixed **game-time** rather than real-time rate.

`GameTime.getGameWorldSecondsSinceLastUpdate()` similarly scales the normal update delta by:

```text
1440 / MinutesPerDay
```

Therefore changing a native 90-minute day to 4.5 minutes produces approximately 20x world-time progression without changing the global simulation multiplier.

### Awake hunger

`IsoGameCharacter.updateStats_Awake()` applies hunger using the current `ZomboidGlobals` base rates multiplied by `GameTime.getDeltaMinutesPerDay()`.

Relevant base rates include:

- `HungerIncrease`;
- `HungerIncreaseWhenWellFed`;
- `HungerIncreaseWhenExercise`.

Vanilla then applies appetite, sandbox, activity, trait, and thermoregulation-related modifiers.

### Sleeping hunger

`IsoPlayer.updateStats_Sleeping()` uses the separate `HungerIncreaseWhileAsleep` path. This supports the intended product boundary: **do not normalize sleepers**.

### Awake thirst

`IsoGameCharacter.updateThirst()` uses `ThirstIncrease`, sandbox stats-decrease multiplier, `GameTime.getDeltaMinutesPerDay()`, thirst traits, running modifiers, and thermoregulation fluids modifiers.

Sleeping thirst uses a separate `ThirstSleepingIncrease` path.

### Awake fatigue

`IsoGameCharacter.updateStats_Awake()` uses `FatigueIncrease`, sandbox stats-decrease multiplier, `GameTime.getDeltaMinutesPerDay()`, endurance-dependent modifiers, sleep traits, resting/sitting state, and thermoregulation fatigue modifiers.

Sleeping fatigue recovery is implemented separately in `IsoPlayer.updateStats_Sleeping()`.

### Nutrition

`Nutrition.update()` is authoritative on the non-client side and passively updates:

```text
Carbohydrates -= 0.0035  * gameWorldSeconds
Lipids        -= 0.00113 * gameWorldSeconds
Proteins      -= 0.00086 * gameWorldSeconds
```

`updateCalories()` also multiplies every activity branch by `getGameWorldSecondsSinceLastUpdate()`.

The vanilla calorie rate varies with sleeping/awake state, movement, running, sprinting, character actions, climbing/combat, body weight, and thermoregulation. Enshrouded Sleep should preserve those vanilla modifiers and remove only the extra calendar-compression component.

### Weight

`Nutrition.updateWeight()` also uses `getGameWorldSecondsSinceLastUpdate()` for weight gain/loss.

Therefore weight progression belongs in the protection boundary with calories/macros.

## Java/Lua feasibility result

The earlier idea of simply changing the live Java `ZomboidGlobals` rates from ordinary Lua is **not currently supported by the B42.20.3 exposure model**.

Important details:

1. `shared/defines.lua` creates the Lua `ZomboidGlobals` table.
2. Java `ZomboidGlobals.Load()` copies values from that Lua table into Java static fields.
3. The character update reads those Java static fields.
4. B42.20.3 `LuaManager.Exposer` exposes many character classes, including `Nutrition`, but does not expose the Java `zombie.ZomboidGlobals` class.
5. Ordinary Kahlua exposure does not provide writable access to arbitrary Java class fields.

Changing the Lua table after load is therefore not evidence that the Java static rates used by `IsoGameCharacter` change with it.

No core Java patching or custom Java loader will be introduced for this feature. The project remains a normal Workshop-distributable Lua mod.

## Candidate Lua implementation paths

### A. Global Java-rate mutation

**NO-GO for ordinary Workshop Lua** based on B42.20.3 exposure.

### B. `CalculateStats` interception/reimplementation

`IsoGameCharacter.calculateStats()` exposes a `CalculateStats` Lua hook. Returning true suppresses a broad vanilla block that also updates endurance, tripping, thirst, stress, wake-state stats, morale, and fitness.

**Reject as primary design.**

It is too broad, would require reimplementing substantial vanilla character logic, and creates unnecessary compatibility risk.

### C. Post-update normalization

**PASSIVE-MECHANISM GO; active-effect regressions still required.**

Concept:

```text
vanilla updates player normally
        ↓
observe current state
        ↓
retain only 1 / CalendarCompressionFactor
of the world-time-driven passive delta
        ↓
write corrected authoritative state
```

For the controlled prototype:

- hunger/thirst/fatigue: normalize only increases;
- calories/carbs/proteins/lipids: normalize only decreases;
- weight: normalize either direction.

Opposite-direction changes are accepted in full so eating/drinking can be exercised later.

The passive test now demonstrates that this mechanism can mathematically remove the extra calendar-compression component. It is still **not production-safe** until legitimate active state changes are tested, especially changes that share the same direction as passive progression.

## Diagnostics-only prototype

Branch:

```text
spike-006-awake-player-protection
```

Runtime file:

```text
Contents/mods/pz-enshrouded-sleep/42/media/lua/server/EnshroudedSleep/AwakePlayerProtectionPrototype_Server.lua
```

Log prefix:

```text
[EnshroudedSleepAwakeProtect][SERVER]
```

The prototype is inert unless all of these conditions hold:

```text
DiagnosticsEnabled=true
DiagnosticAwakeProtectionPrototype=true
DiagnosticForcedCompressionFactor>1
living=1
sleeping=0
native baseline MinutesPerDay observed first at forced factor 1
```

It fails open if a required read/write binding is unavailable.

## Runtime validation attempt 1 — callback failure

The first dedicated-server SPIKE-006 run confirmed that the development branch was loaded and that the forced-compression controller behaved correctly:

```text
native MinutesPerDay = 90
forced factor        = 20
compressed MPD       = 4.5
TrueMultiplier       = 1.0
living               = 1
sleeping             = 0
```

However, the original prototype registered its correction function with:

```lua
Events.OnPlayerUpdate.Add(onPlayerUpdate)
```

The server emitted the module load message but produced no `STATUS`, prototype `BASELINE`, or `CORRECTION` records from that callback. At the same time, the ordinary tick-driven Enshrouded Sleep diagnostics continued to run.

The survival stream showed no protection. Representative nutrition depletion remained approximately proportional to the 20x calendar-compression factor.

Conclusion:

**`Events.OnPlayerUpdate` is not a reliable dedicated-server callback for this prototype on the tested B42.20.3 runtime.**

This attempt did **not** test the correction mathematics; it failed before the correction routine was invoked.

## Tick-driven prototype revision

The prototype now registers with:

```lua
Events.OnTick.Add(onTick)
```

and explicitly obtains the server player population with `getOnlinePlayers()`.

The same mutation safety gates remain in place. The normalizer still operates only during the single-living-awake-player forced-compression diagnostic test.

Successive server-tick snapshots are used to measure deltas. Even if the Lua `OnTick` callback occurs before the Java character update in a particular frame, the following tick observes the prior frame's vanilla state change and permits correction.

A diagnostics-only heartbeat emits approximately every 30 real seconds while diagnostics are enabled:

```text
[EnshroudedSleepAwakeProtect][SERVER] HEARTBEAT
```

It reports at least:

- `tickCalls`;
- whether the prototype is enabled;
- forced compression factor;
- living/sleeping counts;
- current `MinutesPerDay`;
- captured baseline `MinutesPerDay`.

This prevents a loaded-but-never-called event path from failing silently again.

## Runtime validation attempt 2 — passive normalization GO

The revised tick-driven prototype was tested on a dedicated B42.20.3 server with one living awake player. The test successfully demonstrated all required control-path markers:

```text
BASELINE
HEARTBEAT with increasing tickCalls
STATUS | prototype-armed-at-baseline
STATUS | prototype-active
CORRECTION records during 20x
```

The controller held:

```text
native MinutesPerDay       = 90
forced MinutesPerDay       = 4.5
world/calendar compression ≈ 20x
TrueMultiplier             = 1.0
living                     = 1
sleeping                   = 0
```

Using stable server-side survival samples, the protected 20x rate relative to the native 1x baseline was approximately:

| System | Protected 20x / native 1x rate |
| --- | ---: |
| Hunger | 0.989x |
| Thirst | 1.000x |
| Fatigue | 1.001x |
| Calories | 1.000x |
| Proteins | 1.000x |
| Weight progression | 1.008x |
| World/calendar clock | 19.997x |

The owning-client stream independently tracked the same corrected state, with measured rates approximately 0.98–1.00x of its own baseline for the protected fields.

No Enshrouded Sleep Lua error, repeated write failure, factor mismatch, or simulation-multiplier change was observed. Restoring the forced factor to 1 returned `MinutesPerDay` to the native 90-minute baseline.

### Limits of this result

Carbohydrates and lipids were already clamped at the vanilla lower bound of `-500`, so this run could not measure their depletion rates. A later test must begin with both values away from the clamp.

The baseline and compressed measurement intervals were shorter than the original written procedure. The agreement across the six measurable protected fields was nevertheless sufficiently close to 1x to establish feasibility of the passive correction mechanism; repeating a long idle-only run is not currently a priority.

### Decision after attempt 2

**GO for the passive post-update normalization mechanism.**

At this checkpoint, this was **not yet a production GO**. The subsequent active-effects regression below determined whether the directional correction preserved legitimate player-driven and state-driven changes while compressed.

## Post-validation implementation cleanup

After the successful passive run:

1. the prototype hot path was narrowed so each server tick reads only Hunger, Thirst, Fatigue, Calories, Carbohydrates, Proteins, Lipids, and Weight rather than invoking the full broad `SurvivalStatProbe.collect()` diagnostic snapshot;
2. clock and broad health diagnostic phase labels were made aware of diagnostic-forced compression so telemetry no longer mislabels the controlled forced test as ordinary `baseline` or `partial` behavior.

These changes do not broaden the prototype's mutation boundary.

## Subsequent validation — active effects

The controlled regression was defined in [`SPIKE-006-ACTIVE-EFFECTS-TEST.md`](SPIKE-006-ACTIVE-EFFECTS-TEST.md).

It tested whether the normalizer preserved legitimate effects while compressed, including:

1. eating;
2. drinking;
3. walking/running/sprinting;
4. resting/sitting where relevant;
5. Well Fed or comparable rate modifiers;
6. a test with carbohydrate/lipid values away from their clamps;
7. sleep-transition suspension;
8. second-player-join suspension;
9. selected same-direction direct effects where a safe/reproducible test is available.

The regression passed for the production scope: Carbohydrates and Lipids were exercised away from their clamps, favorable eating and drinking effects were preserved, running/sprinting retained active consequences, sleep immediately suspended awake correction, waking reinitialized the reference snapshot, baseline restoration was clean, and no relevant Enshrouded Sleep Lua exception occurred. Exact observed evidence remains canonical in [`../VALIDATION_HISTORY.md`](../VALIDATION_HISTORY.md).

## Success criteria

The candidate implementation could advance only if, during 20x partial/forced calendar compression:

```text
awake hunger passive rate       ≈ 1x baseline real-time rate
awake thirst passive rate       ≈ 1x baseline real-time rate
awake fatigue passive rate      ≈ 1x baseline real-time rate
awake macro depletion           ≈ 1x baseline real-time rate
awake calorie depletion         ≈ 1x baseline real-time rate
awake weight progression        ≈ 1x baseline real-time rate
```

while:

```text
world clock                     ≈ 20x
TrueMultiplier                  ≈ 1
movement/combat/actions         ≈ 1x
bleeding/body-health loss       remains vanilla
endurance recovery              remains vanilla
sleeping-player physiology      remains vanilla
food/generator/vehicle world systems remain world-time driven
```

Eating/drinking and activity modifiers must retain their vanilla magnitude/semantics.

## Release decision

Final outcome: **GO**. The narrowly scoped server-authoritative normalizer was promoted into normal multiplayer partial-sleep behavior in v0.1.0 with `AwakePlayerProtectionEnabled` as an independent soft-rollback control. Subsequent v0.1.1 field evidence covered 38 dedicated-server sessions, 87 proportional partial-sleep states, populations up to seven players, repeated baseline restoration, and no explicit Enshrouded Sleep-prefixed runtime error. Broader lifecycle, rollback, performance, and compatibility coverage remains general release validation in [`../ROADMAP.md`](../ROADMAP.md), not unfinished SPIKE-006 feasibility work.

The evaluated outcomes were:

### GO

A narrowly scoped server-authoritative normalizer reliably protects all targeted awake-player systems with no material distortion of legitimate active changes.

### PARTIAL GO

Only a subset can be protected safely. Ship explicit support only for that subset and document exclusions.

### NO-GO

The available Lua hooks require excessive vanilla reimplementation, create unacceptable active-effect distortion, or cannot be made authoritative/stable in multiplayer.

## Policy / provenance

This spike is based on behavioral testing plus source inspection of Project Zomboid 42.20.3 for interoperability/research. No decompiled Project Zomboid source is redistributed in this repository. Documentation records only the minimum method/formula facts needed to explain the mod's compatibility behavior and design decisions.

No third-party mod code/assets are incorporated.
