# DCS Resource and Dictionary System

## The Two Indirection Tables

Every `.miz` contains two key→value lookup tables inside `l10n/DEFAULT/`:

**`dictionary`** — maps key → display text (string values shown in briefings, trigger
messages, task descriptions).

```lua
-- l10n/DEFAULT/dictionary
dictionary = {
  ["DictKey_descriptionText_1"] = "Mission briefing text here.",
  ["DictKey_sortie_2"]          = "Alpha Strike",
}
```

**`mapResource`** — maps key → embedded file name (the file lives inside `l10n/DEFAULT/`
in the .miz archive).

```lua
-- l10n/DEFAULT/mapResource
mapResource = {
  ["ResKey_Action_101"]          = "mist.lua",
  ["DictKey_ActionText_10201"]   = "veafSpawnableAircrafts.lua",
}
```

---

## The Cardinal Rule: Namespace by Usage, Not by Prefix

A key resolves in **dictionary** when consumed by:
- `getValueDictByKey(...)` at runtime
- `trigrules[].rules[].text` fields
- `KeyDict_text` fields in rule records

A key resolves in **mapResource** when consumed by:
- `getValueResourceByKey(...)` at runtime
- `trigrules[].actions[].file` fields

**Key names are misleading.** The `DictKey_`/`ResKey_` prefix convention is a naming
habit, not a technical constraint. VEAF-injected keys named `DictKey_ActionText_102xx`
through `DictKey_ActionText_104xx` live in **mapResource**, not in dictionary. A linter
that classifies keys by their name prefix produces guaranteed false positives — 13 per
typical VEAF mission, measured empirically.

Always determine the namespace by tracing where the key is **consumed**, not by reading
its name.

---

## Key ID Stability

**Key ids are not stable across missions.** The same numeric id can point to different
files in different missions.

Real-world examples:
- One campaign rewired id `10309` from `missionConfig.lua` to a custom briefing script
  after a reorganisation.
- Another mission shifted the entire `1020x` block after removing a script trigger,
  causing every subsequent key to point to a different file.

Always resolve key → file per mission. Never assume a key id from a template maps to the
same file in another mission.

---

## Word-Boundary Anchoring When Grepping Keys

When searching for a specific key id in source files, anchor with the closing quote to
avoid substring matches:

```
# Wrong — matches DictKey_ActionText_1044, DictKey_ActionText_10400, etc.
grep 'DictKey_ActionText_104'

# Correct — matches only DictKey_ActionText_104 exactly
grep 'DictKey_ActionText_104"'
```

Failure to anchor produces false positives and masks missing-reference bugs.

---

## Where References Live

| Field | Table | Notes |
|-------|-------|-------|
| `mission.descriptionText` | dictionary | Main briefing body |
| `mission.sortie` | dictionary | Sortie/mission name |
| `mission.descriptionBlueTask` | dictionary | Blue coalition task |
| `mission.descriptionRedTask` | dictionary | Red coalition task |
| `mission.descriptionNeutralsTask` | dictionary | Neutrals task |
| `mission.pictureFileNameB/R/N[]` | mapResource | Briefing images per coalition |
| `trigrules[].actions[].file` | mapResource | Script file keys |
| `trigrules[].rules[].text` / `KeyDict_text` | dictionary | Condition text keys |
| Compiled `trig.actions[]` strings | mapResource | `getValueResourceByKey(...)` calls |
| Compiled `trig.func[]` strings | either | Depending on original predicate |

---

## Error Classes and mizlint Codes

### RES-UNDECLARED-KEY (error)

A key is referenced (in a trigger action, condition, or mission field) but has no entry
in either `dictionary` or `mapResource`. Consequence: briefing text renders as the raw
key string (e.g. `DictKey_sortie_5`), or a script trigger silently loads nothing at
runtime. The mission may appear to work until the broken path is exercised.

### RES-MISSING-FILE (error)

A key is declared in `mapResource` but the referenced file is absent from `l10n/DEFAULT/`
on disk and is not part of the build-injected script set. Consequence: sounds play
silence, scripts are never loaded. Real-world case: beacon `.ogg` files declared and
referenced in 28 missions across a campaign but absent from every mission archive —
discovered only when testing on a clean install.

### RES-ENCODING (error)

A key is declared with a file name that matches an on-disk file only after accounting for
CP437 mojibake introduced by certain ZIP tools. Example: a file named `é_briefing.png`
on disk is stored in `mapResource` as `├®_briefing.png` after a Windows ZIP tool
re-encodes the name. The briefing image fails to load after a clean rebuild because the
zip tool re-applies the encoding, producing a different byte sequence.

### RES-ORPHAN-KEY (warning)

A key is declared in `dictionary` or `mapResource` but never referenced anywhere in the
mission. The declaration is dead weight but harmless at runtime. Common after removing
a trigger or briefing section without cleaning up the key tables.

### RES-ORPHAN-FILE (warning)

A file is present in `l10n/DEFAULT/` on disk but not declared in `mapResource`. The file
is bundled into the `.miz` at build time but can never be reached at runtime. Common
after renaming a script without updating the resource table.
