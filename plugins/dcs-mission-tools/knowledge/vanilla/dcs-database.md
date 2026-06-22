# DCS internal database — the Quaggles datamine (external reference)

A mission file references DCS **type strings** it never defines: every unit carries a
`["type"]` (for example `"FA-18C_hornet"`, `"M-113"`, `"E-3A"`), payloads reference weapon
ids, statics reference object types. The game's own definitions for these — attributes,
display names, sensors, weapon characteristics — are not in the `.miz`.

Since DCS 2.7 Eagle Dynamics removed most of the readable `Scripts/Database` Lua files.
**Quaggles/dcs-lua-datamine** fills the gap: a script dumps the game's in-memory Lua tables
to `.lua` files on every Open Beta patch. Use it as the authoritative, always-current
reference for DCS unit/weapon data — **consult it on demand; this plugin vendors nothing
from it** (referencing keeps it current and zero-maintenance).

- Browse: <https://github.com/Quaggles/dcs-lua-datamine>
- Raw file: `https://raw.githubusercontent.com/Quaggles/dcs-lua-datamine/master/<path>`
- Full path index (one call): `https://api.github.com/repos/Quaggles/dcs-lua-datamine/git/trees/master?recursive=1`

Prefer the **`dcs-reference` agent** to consult it — unit files are 10–160 KB, so a sub-agent
keeps the raw dump out of the main context and returns only the fields asked for.

## What it is authoritative for

| Need | Location |
| --- | --- |
| Every unit (planes, helicopters, ground, ships, statics): RCS, IR, mass, sensors, crew | `_G/db/Units/<Category>/<Subcat>/<file>.lua` |
| New-API weapon definitions (AIM-7, AIM-120…) | `_G/weapons_table/weapons/…` |
| Old-API missiles/rockets (R-27ER, AIM-54…) | `_G/rockets/` |
| Old-API bombs | `_G/bombs/` |
| Warheads referenced by weapons | `_G/warheads/` |
| AI-unit sensors (NOT player aircraft, those live in C++) | `_G/db/Sensors/Sensor/` |

Unit categories under `_G/db/Units/`: `Planes`, `Helicopters`, `Ships`, `Cars` (ground),
`GT_t` and `Fortifications` (ground tech / structures), `Cargos`, `Personnel`,
`Warehouses`, `Heliports`, `GrassAirfields`, plus a few small ones.

## Caveats — read before trusting an absence

1. **It is a memory dump**: no comments, no functions — only data values. Historical
   comments from 2.5.6 live in the repo README, not the dumped files.
2. **It reflects the dataminer's install.** Modules the author owns are present; modules he
   does **not** own and third-party **mods** are absent. So a type missing from the datamine
   is **not** proof the type is invalid — it may be a legitimate module/mod unit. Treat
   absence as "unknown here", never as "wrong".
3. **`master` is current-patch.** Values change between patches; that is the point — always
   read live, never cache a stale copy.

## Resolving a type string

The canonical type is the `type =` field **inside** the file. For `Planes`, `Helicopters`
and `Ships` the filename equals the type (`E-3A.lua` → `type = "E-3A"`). For `GT_t` and
`Fortifications` the files are numeric-indexed, so locate by the `type =` field, not the name.

Verified recipes (used by the `dcs-reference` agent):

```bash
# Locate a type when you don't know its category — search the path index:
curl -s "https://api.github.com/repos/Quaggles/dcs-lua-datamine/git/trees/master?recursive=1" \
  | python3 -c "import sys,json; [print(t['path']) for t in json.load(sys.stdin)['tree'] if t['path'].endswith('/M-113.lua')]"
#   -> _G/db/Units/Cars/Car/M-113.lua

# Pull just the identity fields of a known file:
curl -s "https://raw.githubusercontent.com/Quaggles/dcs-lua-datamine/master/_G/db/Units/Cars/Car/M-113.lua" \
  | grep -nE '^\s*(DisplayName|type) ='
#   -> DisplayName = "APC M113"   /   type = "M-113"
```

## When to consult it — and when not

Consult it for data the mission file does not carry: human-readable display name of a cryptic
type, unit category, RCS / IR / sensor ranges, weapon characteristics, what a payload weapon
actually is. Typical triggers: building an order-of-battle brief (`map-mission`), explaining a
script that references unit/weapon types (`lua-analyst`), answering "what is unit/weapon X".

Do **not** use it for anything the `.miz` already states (group/zone/flag names, coordinates,
the mission's own structure — those come from the mission file and the other references here),
and do not turn it into a hard validity check: per caveat 2, absence never means invalid.

See also: [mission-file.md](mission-file.md) (the unit `type` field), [hoggit-links.md](hoggit-links.md).

## Attribution

Data source: [Quaggles/dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine)
(no declared license — reference and consult, do not redistribute its file contents). The
underlying values originate from DCS World by Eagle Dynamics. This plugin is not affiliated
with either.
