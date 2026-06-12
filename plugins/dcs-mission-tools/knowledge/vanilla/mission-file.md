# DCS Mission File Structure

## Anatomy of a .miz

A `.miz` is a standard ZIP archive. Rename it to `.zip` to inspect with any archive tool.

Extracted layout:

```
mission                        # main Lua table, 5–25 MB
theatre                        # plain text: map name (e.g. "Caucasus")
warehouses                     # Lua table: airport/warehouse stock levels
options                        # Lua table: mission options
l10n/DEFAULT/
  dictionary                   # Lua table: DictKey → display text
  mapResource                  # Lua table: ResKey → embedded file name
  <embedded files>             # .lua scripts, .ogg sounds, images referenced by mapResource
KNEEBOARD/
  <aircraft-type>/
    IMAGES/                    # per-aircraft kneeboard images
```

The `mission` file is the main artefact. It contains all coalition data, triggers, weather, and metadata as a single Lua table assignment (`mission = { ... }`).

---

## Top-Level Keys of the `mission` Table

| Key | Description |
|-----|-------------|
| `coalition` | Tree: coalition → country → plane/helicopter/vehicle/ship/static → group → units. Group and unit names are plain strings in normalized missions. |
| `triggers.zones` | Array of trigger zone records (see Coordinates section). |
| `trig` | Compiled trigger data DCS executes (see trig vs trigrules). |
| `trigrules` | Mission Editor source: array of human-readable rule records. |
| `weather` | Wind, clouds, visibility, fog, turbulence. |
| `date` | `{Day, Month, Year}` table. |
| `start_time` | Mission start time in seconds since midnight. |
| `failures` | Equipment failure schedule. |
| `forcedOptions` | Options locked regardless of player settings. |
| `requiredModules` | Map of module IDs that must be installed. |
| `descriptionText` | DictKey: main briefing text. |
| `sortie` | DictKey: mission sortie name. |
| `descriptionBlueTask` | DictKey: Blue task description. |
| `descriptionRedTask` | DictKey: Red task description. |
| `descriptionNeutralsTask` | DictKey: Neutrals task description. |
| `pictureFileNameB/R/N` | Arrays of ResKeys: briefing images per coalition. |
| `currentKey` | Next available key id (integer). |
| `maxDictId` | Highest dictionary id in use. |
| `version` | Mission format version integer. |

---

## trig vs trigrules — The Critical Distinction

### trigrules — ME source of truth

`trigrules` is an array of rule records. Each record:

```lua
trigrules[1] = {
  predicate  = "triggerStart",   -- "triggerStart"|"triggerOnce"|"triggerContinuous"|...
  comment    = "Load MIST",
  eventlist  = "",
  colorItem  = ...,
  actions = {
    [1] = { predicate = "a_do_script_file", file = "ResKey_Action_101" },
    -- or:
    [1] = { predicate = "a_do_script",      text = "trigger.action.outText(...)" },
    -- or:
    [1] = { predicate = "a_set_flag",       flag = "myFlag" },
  },
  rules = {
    [1] = { predicate = "c_flag_is_true", flag = "startFlag" },
    -- or:
    [1] = { predicate = "c_predicate",    text = "...", KeyDict_text = "DictKey_..." },
  },
}
```

### trig — the compiled form DCS executes

```lua
trig = {
  actions      = { [1] = 'a_do_script_file(getValueResourceByKey("ResKey_Action_101"));' },
  conditions   = { [1] = 'return(c_flag_is_true(...))' },
  flag         = { [1] = false },
  funcStartup  = { [1] = 'if ... then ... end' },  -- camelCase, run once at mission start
  func         = { [1] = 'if ... then ... end' },  -- evaluated every tick (Once triggers disarm via their flag)
  custom        = {},
  customStartup = {},
  events        = {},
}
```

### Compilation rules (verified on real missions)

- `{predicate="a_do_script", text=T}` compiles to:
  `a_do_script("<T with backslashes doubled, then quotes escaped>");`
- `{predicate="a_do_script_file", file=K}` compiles to:
  `a_do_script_file(getValueResourceByKey("<K>"));`

### Trigger type → trig slot mapping

| ME trigger type | predicate | trig slot |
|-----------------|-----------|-----------|
| Mission Start   | `triggerStart` | `funcStartup` |
| Once            | `triggerOnce` | `func` |
| Continuous      | `triggerContinuous` | `func` |
| Switched Condition | `triggerSwitchCondition` | `func` |

`func` entries are evaluated every tick. A trigger can self-deactivate by appending
`mission.trig.func[N] = nil;` to its action body — proof that DCS re-reads `trig.func`
each tick.

### The regeneration contract

**The Mission Editor regenerates `trig` from `trigrules` on every save.** A file edited
by external tools can have incoherent `trig` — it will misbehave until re-saved in ME.

Serialized files use `funcStartup` (camelCase) and lowercase `trigrules`. The Hoggit wiki
spells it `trigRules` — that spelling is wrong for serialized files; trust the file.

---

## Coordinates

DCS uses a flat Transverse Mercator coordinate system per theatre:

- `x` = northing (meters from theatre origin)
- `y` = easting (meters from theatre origin)
- Headings are in **radians**

### Trigger zones (`triggers.zones[]`)

Each zone record:

```lua
{
  name       = "ZoneName",
  x          = 12345.6,    -- northing
  y          = 67890.1,    -- easting
  radius     = 1000,
  type       = 0,          -- 0 = circle, 2 = quadrilateral
  verticies  = { ... },    -- 4-element array for quadrilateral zones
  zoneId     = 42,
  hidden     = false,
  properties = { ... },
  color      = { ... },
}
```

### Geographic conversion

`mizlint coords <theatre> <x> <y>` converts to geographic coordinates.

Supported theatres: `caucasus`, `syria`, `persiangulf`, `marianaislands`.

---

## Pitfalls

- **Hand-editing desyncs trig/trigrules**: any external modification to `trigrules` without
  recompiling `trig` leaves the mission in an inconsistent state. mizlint reports this as
  `TRG-*` codes. Always re-save in ME after external edits, or use mizlint to detect.

- **Inserting triggers shifts indices**: `trig.func[N]` and `trigrules[N]` are parallel
  arrays. Inserting a trigger at position N shifts every subsequent trigger's index in
  both arrays, invalidating any hard-coded `trig.func[N] = nil` self-deactivation.

- **Numeric vs string flags**: DCS flags can be numeric (`1`, `2`) or string (`"myFlag"`).
  mizlint's flag linting covers only quoted string flags; numeric flag mismatches are not
  caught.
