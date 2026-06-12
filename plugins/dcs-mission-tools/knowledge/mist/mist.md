# MIST — Mission Scripting Tools

## What MIST Is

MIST (Mission Scripting Tools) is a community Lua library that wraps the raw DCS
Simulator Scripting Engine (SSE) API with higher-level utilities for scheduling, spawning,
routing, and data access.

The VEAF ecosystem vendors a fork. Version string as of current missions:
`4.5.128-DYNSLOTS-02-VEAF` (adds dynamic-slot support on top of upstream MIST).

MIST is distributed as a single file, approximately 9600 lines:
`src/scripts/community/mist.lua` inside the `veaf-mission-creation-tools` npm package
(VMCT). Missions pull it from there at build time. It is **not** committed per-mission.

---

## API Families

### Data access — `mist.DBs.*`

Built once at mission start from `env.mission`. Provides fast lookup tables:

| Table | Contents |
|-------|----------|
| `mist.DBs.unitsByName` | All units keyed by name |
| `mist.DBs.unitsById` | All units keyed by id |
| `mist.DBs.groupsByName` | All groups keyed by name |
| `mist.DBs.groupsById` | All groups keyed by id |
| `mist.DBs.humansByName` | Human-controlled slots keyed by name |
| `mist.DBs.zonesByName` | Trigger zones keyed by name |
| `mist.DBs.MEgroupsByName` | ME-defined groups (pre-spawn state) |
| `mist.DBs.aliveUnits` | Currently alive unit ids |

### Scheduler

- `mist.scheduleFunction(fn, args, time, interval)` — schedule a function at `time`
  seconds, optionally repeating every `interval` seconds.
- `mist.removeFunction(taskId)` — cancel a scheduled task by its returned id.

### Dynamic spawning

- `mist.dynAdd(groupData)` — spawn a group from a table descriptor.
- `mist.dynAddStatic(staticData)` — spawn a static object.
- `mist.teleportToPoint(groupName, point)` — move a group to a position.
- `mist.respawnGroup(groupName, copyOriginal)` — respawn a group at its original position.
- `mist.cloneGroup(groupData, copyOriginal)` — clone a group with modifications.

### AI routing — `mist.goRoute` and waypoint builders

- `mist.goRoute(groupName, route)` — assign a route to a group.
- Waypoint builder helpers for ground units, fixed-wing aircraft, and helicopters provide
  correctly structured waypoint tables for each domain.

### Math and utilities

- `mist.utils.toRadian(deg)`, `mist.utils.round(n, dec)`, `mist.utils.deepCopy(tbl)`
  and other general helpers.
- `mist.vec.*` — vector math: add, subtract, dot product, magnitude, normalise.

### Flag automation — `mist.flagFunc.*`

Wrappers that set/check DCS flags from Lua without ME trigger overhead. Used to bridge
Lua logic with ME trigger conditions.

### Messaging and coordinate formatting

- `mist.message.*` — display messages to coalitions or groups.
- `mist.tostringLL(x, y, acc)` — convert DCS coordinates to Lat/Lon string.
- `mist.tostringMGRS(x, y, acc)` — convert to MGRS string.
- `mist.getBRtext(from, to)` — bearing/range text between two points.

### Other

- Marker event handling: callbacks on F10 map marker creation/modification.
- `mist.Logger` / `mist.log.*` — structured logging to DCS log file.

---

## The Load-Order Invariant

**MIST must be the first script loaded**, in both VEAF loading modes.

- Static loading: MIST must be the first `a_do_script_file` resource in the trigger chain.
- Dynamic loading: MIST must be the first `loadfile(...)` call in the bootstrap script.

The VMCT bundle `veaf-scripts.lua` does **not** include MIST — it is an external
dependency that must be loaded before the bundle executes.

There are approximately 470 call sites in the VEAF framework that assume `mist` is
already in the global environment. None of them guard with `if mist then`. A load-order
violation does not fail at load time; it fails at the first runtime call that touches
MIST — typically inside an `initialize()` method called seconds or minutes into the
mission. This makes the failure hard to diagnose without knowing the invariant.

mizlint code: **LOAD-MIST-FIRST**

---

## How Missions Load MIST

### Static loading (trigger-based)

MIST is embedded as a resource in `mapResource` and loaded by a Mission Start trigger:

```lua
-- trigrules (ME source)
trigrules[1] = {
  predicate = "triggerStart",
  comment   = "Load MIST",
  actions   = {
    [1] = { predicate = "a_do_script_file", file = "ResKey_Action_101" },
  },
  rules = {},
}

-- mapResource
mapResource["ResKey_Action_101"] = "mist.lua"
```

Compiled form in `trig.funcStartup[1]`:
```lua
a_do_script_file(getValueResourceByKey("ResKey_Action_101"));
```

### Dynamic loading (bootstrap script)

A bootstrap script (loaded via the first `a_do_script_file`) uses `loadfile` to load
scripts from disk at mission start:

```lua
-- Inside the bootstrap script (e.g. veafMissionLoader.lua)
local mistPath = basePath .. "community/mist.lua"
assert(loadfile(mistPath))()   -- MIST loaded first

local bundlePath = basePath .. "veaf-scripts.lua"
assert(loadfile(bundlePath))() -- VEAF bundle loaded after
```

MIST must appear before any VEAF script in either form. The order of subsequent scripts
is otherwise flexible, but MIST's position is not negotiable.
