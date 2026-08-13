# Enshrouded Sleep - Clock Spike v0.0.1

Diagnostic technical spike for Project Zomboid Build 42.20+.

## Purpose

This is **not yet the Enshrouded Sleep mod**. It tests the core technical assumption:

> Can a dedicated B42 server dynamically reduce `GameTime.MinutesPerDay` so
> world/calendar time passes faster while the active gameplay simulation
> remains at normal speed?

The test intentionally never calls `GameTime:setMultiplier()`.

## Default test cycle

After the first fully instantiated player appears in `getOnlinePlayers()`:

1. Record the server's current `MinutesPerDay`.
2. Wait 10 real seconds.
3. Set `MinutesPerDay = baseline / 20`.
4. Leave that clock rate active for 60 real seconds.
5. Restore the original baseline exactly.
6. Stop. It will not run a second spike until Lua/server restart.

If the player disconnects during the test, the baseline is restored immediately.

## Recommended server setup

Use a disposable test world.

For an easy-to-measure test, set the normal day length to 1 real hour per
24 in-game hours.

At the default 20x acceleration:

- Baseline: 60 real minutes / game day.
- Temporary: 3 real minutes / game day.
- 60 real seconds of the spike should advance the game clock by roughly 8 hours.

## What to observe

During the 60-second accelerated period:

- Watch the in-game clock.
- Walk/run.
- Open/close inventory.
- Transfer items.
- Perform timed actions.
- Observe zombies.
- If safe, test combat.
- If practical, drive a vehicle.

The success condition is:

- The world clock advances rapidly.
- Movement/combat/animations/zombies/vehicle simulation remain normal.
- Server log shows `Multiplier`, `ServerMultiplier`, and `TrueMultiplier`
  remaining unchanged when `MinutesPerDay` changes.

## Log filter

Search the server log for:

`[EnshroudedSleep:Spike]`

Please save or paste those lines after the test.

## Sandbox options

- Enable diagnostic clock spike: true
- Clock acceleration factor: 20x
- Warm-up seconds: 10
- Test duration: 60 real seconds

## Mod ID

`EnshroudedSleepClockSpike`

## Version

`0.0.1`
