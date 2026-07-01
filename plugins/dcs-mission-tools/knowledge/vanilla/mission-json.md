# Reading a Mission as JSON (veaf-tools export + jq)

The `mission`, `dictionary` and `mapResource` tables are 5–25 MB of Lua. Grepping
the flat Lua conflates unrelated matches (a name in a `comment` vs the same name
in a hundred `flag` fields) and forces manual cross-referencing. Instead, **export
the mission to JSON once and query it structurally** — safe (pure-Python parse,
never runs Lua), ~5× smaller than the source, and answers land as exact values
instead of excerpts you have to read and re-read.

This file maps mission structure to JSON access. The **authoritative structure**
lives in [mission-file.md](mission-file.md) (top-level keys, `trig` vs `trigrules`,
zones, coordinates) and [resources.md](resources.md) (dictionary/mapResource
namespacing — classify keys by *usage*, never by prefix). The paths below are
navigation entry points, **not an exhaustive whitelist** — see *Exhaustiveness*.

## Export

```sh
"${CLAUDE_PLUGIN_ROOT}/tools/miz2json.sh" <mission-folder-or-.miz> > mission.json   # Windows: miz2json.cmd
```

- Input: a project folder (containing `src/mission/`), a `src/mission` folder, or a
  packed `.miz`.
- One-time cost ~10 s for a 25 MB mission; the compact JSON is ~5 MB. **Export once,
  reuse the file for every query** — do not re-export per question.
- `$VEAF_TOOLS` overrides the binary. Exit code `3` means no veaf-tools for this
  platform → drop to the raw-Lua fallback (bottom of this file).
- `--pretty` emits indented JSON (one value per line) for the no-jq grep fallback.

## The JSON contract (schemaVersion 2)

Top-level object: `{ schemaVersion: 2, theatre, mission, dictionary, mapResource }`.

Lua → JSON mapping:

| Lua shape | JSON | Note |
|-----------|------|------|
| record (string keys) | object | keys verbatim (`DictKey_...`, `comment`, ...) |
| sequence (`1..n`) | array | `#t` in Lua = `length` in jq |
| string-numeric keys (`failures["10"]`) | object with string keys | stays `"10"`, never coerced to a number |
| sparse / mixed integer keys | `{ "__luaTable__": [[k,v], ...] }` | envelope: array of `[key,value]` pairs, lossless key types |

**Where the `__luaTable__` envelope occurs (measured on a real 25 MB mission):**
only `callsign`, `pylons`, `teamMembers`, and two internal indices (`func`,
`failures`). It **never** appears in `dictionary`, `mapResource`, `trigrules`, or
`triggers.zones` — the surfaces you normally query are plain objects/arrays, so
recipes there need no envelope handling. When you *do* hit one (a unit callsign or
pylon loadout):

```sh
# a specific enveloped key
jq -r '<...>.callsign.__luaTable__[] | select(.[0]=="name") | .[1]' mission.json
# rebuild the whole table as an object
jq -c '<...>.pylons.__luaTable__ | map({ (.[0]|tostring): .[1] }) | add' mission.json
```

## Landmarks & recipes (verified against a real mission)

Assume the export is in `mission.json`.

```sh
# Resolve a dictionary key (briefing / trigger message text)
jq -r '.dictionary.DictKey_ActionText_13' mission.json

# Dictionary strings mentioning a term (key + text)
jq -r '.dictionary | to_entries[]
       | select(.value|type=="string" and test("Peca";"i"))
       | "\(.key)\t\(.value)"' mission.json

# F10 radio menu items (ActionRadioText keys)
jq -r '.dictionary | to_entries[]
       | select(.key|test("ActionRadioText")) | select(.value|test("Peca"))
       | "\(.key) = \(.value)"' mission.json

# Resource key → embedded file (scripts, sounds, images)
jq -r '.mapResource["ResKey_Action_101"]' mission.json

# Triggers by section-header comment
jq -r '.mission.trigrules[] | select(.comment? and (.comment|test("Peca";"i"))) | .comment' mission.json

# Triggers whose actions OR conditions reference a term (structural, no flag-field noise)
jq -c '.mission.trigrules[] | select(([.actions,.rules]|tostring)|test("Peca")) | {comment, predicate}' mission.json

# Trigger zones by name
jq -r '.mission.triggers.zones[] | select(.name|test("Peca"))
       | "\(.name) [type=\(.type) r=\(.radius) id=\(.zoneId)]"' mission.json

# Order of battle counts, per coalition and category
jq -r '.mission.coalition | to_entries[] | .key as $c
       | (.value.country // [] | map(
           {p:(.plane.group//[]|length), h:(.helicopter.group//[]|length),
            v:(.vehicle.group//[]|length), s:(.ship.group//[]|length), st:(.static.group//[]|length)})
         | reduce .[] as $x ({p:0,h:0,v:0,s:0,st:0};
             {p:(.p+$x.p),h:(.h+$x.h),v:(.v+$x.v),s:(.s+$x.s),st:(.st+$x.st)}))
       | "\($c): planes=\(.p) helos=\(.h) vehicles=\(.v) ships=\(.s) statics=\(.st)"' mission.json
```

Order-of-battle nesting:
`.mission.coalition.<blue|red|neutrals>.country[].<plane|helicopter|vehicle|ship|static>.group[].units[]`
— group name is `.name`, unit type is `.units[].type` (a DCS type string; resolve to
a display name with the `dcs-reference` agent, see [dcs-database.md](dcs-database.md)).

## Exhaustiveness — landmarks are shortcuts, the sweep is the guarantee

For a **complete** search ("every reference to X"), do **not** trust a single
landmark path — a flag or name can appear in places you did not anticipate. Use the
recursive descent, which reaches every value at any depth and cannot miss one:

```sh
# every string VALUE mentioning X, deduped
jq -r '[.. | strings | select(test("Peca";"i"))] | unique[]' mission.json
# include object KEYS too (e.g. a flag used as a key somewhere)
jq -r '[paths | .[-1] | select(type=="string" and test("Peca";"i"))] | unique[]' mission.json
```

Never conclude "X appears only in `<place>`" from a landmark query — confirm with the
sweep. Two hard limits of the export you must state rather than paper over:

1. **Scripts are not in the export.** Logic frequently lives in `src/scripts/*.lua`
   (separate files on disk). A full trace must also grep those — the export covers
   the mission *tables* only.
2. **The export is data, not runtime.** Flags set dynamically by scripts
   (`setUserFlag(ListeTriggers[i], …)`) appear as no literal anywhere; static search
   cannot resolve them (see [mission-file.md](mission-file.md) → *Dynamically set flags*).

## Fallback ladder (when a tool is missing)

1. **jq present** → the recipes above. Install if missing: `brew install jq` /
   `apt install jq` / `winget install jqlang.jq` / `choco install jq`.
2. **No jq, `python3` present** (usual on macOS/Linux) → load the export and filter:
   ```sh
   python3 -c 'import json,re; d=json.load(open("mission.json"));
   print("\n".join(f"{k}\t{v}" for k,v in d["dictionary"].items()
     if isinstance(v,str) and re.search("Peca",v,re.I)))'
   ```
3. **No jq/python** → export `--pretty` (one value per line) and grep it; far cleaner
   than the raw Lua because keys and values are normalized and line-oriented:
   ```sh
   "${CLAUDE_PLUGIN_ROOT}/tools/miz2json.sh" --pretty <folder> pretty.json
   grep -n '"VILLE DE Peca' pretty.json
   ```
4. **No veaf-tools at all** (unsupported platform, stripped checkout — `miz2json`
   exits 3) → anchored grep on the raw `src/mission/mission`, per the conventions in
   [mission-file.md](mission-file.md) and [resources.md](resources.md) (word-boundary
   anchoring, namespace-by-usage). This is the original method and the last resort.
