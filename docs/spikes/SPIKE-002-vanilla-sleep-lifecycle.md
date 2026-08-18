# SPIKE-002 — Vanilla Multiplayer Sleep/Lifecycle Semantics

Status: **Completed / GO**  
Historical implementations: v0.0.2 and v0.0.2b  
Test platform: Project Zomboid Build 42.20.2

## Question

Can Enshrouded Sleep rely on vanilla Project Zomboid's instantiated player objects and sleep/death state rather than building a separate connection-readiness and sleep-voting subsystem?

## Scope

This spike observed:

- `getOnlinePlayers()` population behavior;
- `IsoPlayer:isAsleep()`;
- `IsoPlayer:isDead()`;
- join/loading timing;
- death/respawn object lifecycle;
- vanilla all-asleep fast-forward behavior.

No partial-sleep policy was implemented during the diagnostic phase.

## Results

Controlled dedicated-server testing established that:

- server-side `isAsleep()` reliably reflected vanilla sleep/wake state;
- dead player objects can remain in `getOnlinePlayers()` during respawn and therefore must be excluded from the living denominator;
- a connecting/authenticated client can exist before an `IsoPlayer` appears in `getOnlinePlayers()`;
- an instantiated admin character behaves like a normal player for the relevant sleep-state APIs;
- vanilla full-sleep fast-forward leaves `MinutesPerDay` unchanged and instead increases another GameTime multiplier path;
- therefore partial `MinutesPerDay` compression must be removed before the all-living-players-asleep state is handed back to vanilla.

The full-sleep probe observed `MinutesPerDay=90` remaining constant while `GameTime:getMultiplier()` rose from roughly 4.8 to roughly 575. No fixed mathematical relationship between that observed rate and the configured `FastForwardMultiplier=40` was assumed.

## Decision

**GO with vanilla-extension semantics.**

For MVP purposes:

```text
LivingPlayers = getOnlinePlayers() where isDead() == false
SleepingPlayers = LivingPlayers where isAsleep() == true
```

The mod does not maintain a second readiness registry for loading clients, respawn screens, or other non-instantiated sessions.

When all living instantiated players are asleep, Enshrouded Sleep restores the exact native `MinutesPerDay` and lets vanilla full-sleep fast-forward own the state.

## Follow-up

- ADR-002 records this vanilla-lifecycle/full-sleep-handoff decision.
- v0.0.3 implemented the first proportional controller using these semantics.
- SPIKE-003 investigated client clock synchronization after the first successful multiplayer run exposed visual clock snapping.
