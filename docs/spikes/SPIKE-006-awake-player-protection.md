# SPIKE-006 — Awake-Player Survival Protection Feasibility

Status: **IN PROGRESS**  
Target release: **v0.0.11 candidate**  
Validated source baseline: **Project Zomboid 42.20.3**  
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

Controlled runtime testing already established that the following scale with compressed world/calendar time:

- hunger;
- thirst;
- fatigue;
- calories;
- carbohydrates;
- proteins;
- lipids.

By contrast, the tested acute bleeding/body-health-loss path and resting endurance recovery remained approximately simulation/real-time bound.

Therefore v0.0.11 must **not** apply broad health compensation. It should target only systems known to accelerate with the world clock.

## B42.20.3 decompile findings

### Game-time scaling primitive

`GameTime.getDeltaMinutesPerDay()` returns:

```text
30 / MinutesPerDay
```

The decompiled method comment explicitly describes it as the factor used when a value should advance at a fixed **game-time** rather than real-time rate.

`GameTime.getGameWorldSecondsSinceLastUpdate()` similarly scales the normal update delta by:

```text
1440 / MinutesPerDay
```

Therefore changing a native 90-minute day to 4.5 minutes produces approximately 20x world-time progression without changing the global simulation multiplier.

### Awake hunger

`IsoGameCharacter.updateStats_Awake()` applies hunger using the current `ZomboidGlobals` base rates multiplied by `GameTime.getDeltaMinutesPerDay()`.

Relevant base rates:

- `HungerIncrease`;
- `HungerIncreaseWhenWellFed`;
- `HungerIncreaseWhenExercise`.

Vanilla then applies appetite, sandbox, activity, trait, and thermoregulation-related modifiers.

### Sleeping hunger

`IsoPlayer.updateStats_Sleeping()` uses the separate:

- `HungerIncreaseWhileAsleep`.

This supports the intended product boundary: **do not normalize sleepers**.

### Awake thirst

`IsoGameCharacter.updateThirst()` uses:

- `ThirstIncrease`;
- sandbox stats-decrease multiplier;
- `GameTime.getDeltaMinutesPerDay()`;
- high-/low-thirst trait multiplier;
- running modifier;
- thermoregulation fluids multiplier.

Sleeping thirst takes a separate branch using:

- `ThirstSleepingIncrease`.

Again, awake and sleeping behavior are already separated by vanilla.

### Awake fatigue

`IsoGameCharacter.updateStats_Awake()` uses:

- `FatigueIncrease`;
- sandbox stats-decrease multiplier;
- `GameTime.getDeltaMinutesPerDay()`;
- endurance-dependent modifier;
- Needs Less Sleep / Needs More Sleep modifiers;
- resting/sitting modifier;
- thermoregulation fatigue multiplier.

Sleeping fatigue recovery is implemented separately in `IsoPlayer.updateStats_Sleeping()` using elapsed game-hours, sleep traits, and bed quality.

### Nutrition

`Nutrition.update()` is authoritative on the non-client side and passively updates:

```text
Carbohydrates -= 0.0035  * gameWorldSeconds
Lipids        -= 0.00113 * gameWorldSeconds
Proteins      -= 0.00086 * gameWorldSeconds
```

`updateCalories()` also multiplies every activity branch by `getGameWorldSecondsSinceLastUpdate()`.

The vanilla calorie rate varies with state, including:

- sleeping;
- stationary awake;
- ordinary movement;
- running;
- sprinting;
- active character actions;
- climbing/combat states;
- body weight;
- thermoregulation energy multiplier.

This means Enshrouded Sleep should preserve the vanilla formula and remove only the extra calendar-compression component.

### Weight

`Nutrition.updateWeight()` also uses `getGameWorldSecondsSinceLastUpdate()` for weight gain/loss.

Therefore weight progression belongs in the protection boundary with calories/macros. Protecting nutrition stores while leaving weight at compressed world speed would be internally inconsistent.

## Java/Lua feasibility result

The earlier idea of simply changing the live Java `ZomboidGlobals` rates from ordinary Lua is **not currently supported by the B42.20.3 exposure model**.

Important details:

1. `shared/defines.lua` creates the Lua `ZomboidGlobals` table.
2. Java `ZomboidGlobals.Load()` copies values from that Lua table into Java static fields.
3. The character update reads those Java static fields.
4. B42.20.3 `LuaManager.Exposer` exposes many character classes, including `Nutrition`, but does not expose the Java `zombie.ZomboidGlobals` class.
5. Ordinary Kahlua exposure does not provide writable access to arbitrary Java class fields.

Consequence:

```text
ZomboidGlobals.HungerIncrease = ...
```

changes the Lua table but is not evidence that the already-loaded Java static `hungerIncrease` used by `IsoGameCharacter` changes with it.

No core Java patching or custom Java loader will be introduced for this feature. The project remains a normal Workshop-distributable Lua mod.

## Candidate Lua implementation paths

### A. Global Java-rate mutation

**NO-GO for ordinary Workshop Lua** based on B42.20.3 exposure.

Would be clean mathematically, but the required Java static fields/class are not exposed as a safe mutable runtime API.

### B. `CalculateStats` interception/reimplementation

`IsoGameCharacter.calculateStats()` exposes a `CalculateStats` Lua hook. Returning true suppresses the vanilla block that otherwise updates endurance, tripping, thirst, stress, wake-state stats, morale, and fitness.

**Reject as primary design.**

It is too broad, would require reimplementing substantial vanilla character logic, and creates unnecessary incompatibility risk with PZ updates and other mods.

### C. Post-update normalization

Prototype under test.

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

For the first controlled prototype:

- hunger/thirst/fatigue: normalize only increases;
- calories/carbs/proteins/lipids: normalize only decreases;
- weight: normalize either direction.

Opposite-direction changes are accepted in full so eating/drinking can be exercised later.

This is deliberately a **feasibility prototype**, not yet production-safe. Some legitimate active effects share the same direction as passive decay (for example fatigue from medication/toxic exposure or food that increases thirst), so source-specific regression testing is required before release.

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

## First validation sequence

See [`SPIKE-006-FIRST-TEST.md`](SPIKE-006-FIRST-TEST.md).

The first test is intentionally idle/stationary. It asks only whether the normalization mechanism can turn the previously observed ~20x passive progression back toward ~1x.

If that works, later tests add legitimate state changes:

1. eat while compressed;
2. drink while compressed;
3. walk/run/sprint;
4. rest/sit;
5. Well Fed;
6. high-/low-thirst traits where practical;
7. sleep transition;
8. second-player join safety;
9. medication/toxic/other positive-fatigue edge cases where safe.

## Success criteria

A candidate implementation can advance only if, during 20x partial/forced calendar compression:

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

Possible outcomes:

### GO

A narrowly scoped server-authoritative normalizer reliably protects all targeted awake-player systems with no material distortion of legitimate active changes.

### PARTIAL GO

Only a subset can be protected safely. Ship explicit support only for that subset and document exclusions.

### NO-GO

The available Lua hooks require excessive vanilla reimplementation, create unacceptable active-effect distortion, or cannot be made authoritative/stable in multiplayer.

## Policy / provenance

This spike is based on behavioral testing plus source inspection of Project Zomboid 42.20.3 for interoperability/research. No decompiled Project Zomboid source is redistributed in this repository. Documentation records only the minimum method/formula facts needed to explain the mod's compatibility behavior and design decisions.

No third-party mod code/assets are incorporated.
