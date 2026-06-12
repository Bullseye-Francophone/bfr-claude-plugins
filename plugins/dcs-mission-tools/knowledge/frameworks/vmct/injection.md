# VMCT Injection and Loading

## Injection Is One-Shot and Design-Time

`veafMissionTriggerInjector.lua` is run manually with a standalone Lua interpreter on an
extracted mission. It seeds the mission with the framework's bootstrap triggers **once**.

Builds never re-inject. They only:
- flip predicate values by regex
- copy script files into `l10n/DEFAULT` of the staged mission

---

## What Gets Injected

### 7 trigrules inserted at the HEAD of the list

| # | Comment | Purpose |
|---|---------|---------|
| 1 | — | Sets `VEAF_DYNAMIC_PATH` variable |
| 2 | — | Sets `VEAF_DYNAMIC_MISSIONPATH` variable |
| 3 | "mission start - dynamic" | `loadfile` chain: community scripts with mist.lua FIRST, then `VeafDynamicLoader.lua` |
| 4 | "mission start - static" | `a_do_script_file` chain via mapResource keys: community scripts, then compiled bundle `veaf-scripts.lua` |
| 5 | "mission config - dynamic" | `loadfile missionConfig` from `VEAF_DYNAMIC_MISSIONPATH` |
| 6 | "mission config - static" | `a_do_script_file missionConfig` key |
| 7 | CTLD beacon sounds | `a_out_sound_c` calls |

### 6 dictionary predicate keys

| Key id (template default) | Value | Purpose |
|--------------------------|-------|---------|
| `10501` | `return false -- scripts` | Static/dynamic switch for loading mode |
| `10502` | `return false -- config` | Static/dynamic switch for config loading |
| `10601` | `return VEAF_DYNAMIC_PATH ~= nil` | Condition: dynamic path is set |
| `10701` | `return VEAF_DYNAMIC_PATH == nil` | Condition: dynamic path is NOT set |
| `10801` | `return VEAF_DYNAMIC_MISSIONPATH ~= nil` | Condition: mission path is set |
| `10901` | `return VEAF_DYNAMIC_MISSIONPATH == nil` | Condition: mission path is NOT set |

### ~14 mapResource keys

Community script files, `veaf-scripts.lua`, `missionConfig.lua`, and beacon `.ogg` files.

**Important**: these numeric ids are template defaults. Real missions drift — keys get
rewired or shifted. Always resolve per mission. See
[../../vanilla/resources.md](../../vanilla/resources.md) for the key-stability caveat.

---

## The Mandatory Mission Editor Re-Save

The injector targets the obsolete lowercase `trig["funcstartup"]` key. Modern DCS files
use camelCase `funcStartup`. The injector's template also carries a corrupted
`community/e` action entry.

Both defects are healed when the mission is opened and saved in the Mission Editor, which
regenerates `trig` from `trigrules`.

**Between injection and that re-save, the compiled tables are incoherent.** mizlint's
`TRG-*` findings on such a file are correct — the fix is the re-save, not suppressing the
finding. See [../../vanilla/mission-file.md](../../vanilla/mission-file.md) for the
trig/trigrules regeneration contract.

---

## What Builds Actually Do

Per the VEAF template build:

1. Flip `-- scripts` / `-- config` predicates with a regex to enable the target loading
   mode (static for release, dynamic for dev).
2. Rewrite the `VEAF_DYNAMIC_*PATH` strings.
3. Copy `*.lua` files (community scripts, mission scripts, compiled bundle) into
   `l10n/DEFAULT` of the staged mission.
4. Run normalizer, re-zip.

**Implication**: only `.lua` files are injected at build time. Any non-Lua resource
declared in mapResource (sounds, images) must exist in the source tree or the `.miz` ships
without it — mizlint code `RES-MISSING-FILE`.

---

## Reading the Committed State

A properly extracted (committed) mission has:
- Both predicates at `return false`
- No `.miz` at the project root
- Static-mode resource keys resolving to script basenames

**Dynamic mode is a DEV mode.** In addition to loading scripts from disk, it forces
`veaf.Development = true`, enables trace logging, and disables security. See
[architecture.md](./architecture.md) for the upstream quirks this introduces.

### Relevant mizlint Codes

| Code | Condition |
|------|-----------|
| `LOAD-COMMITTED-STATE` | Predicates are not at `return false` in a committed mission |
| `LOAD-MIZ-AT-ROOT` | A `.miz` file is present at the project root |
| `LOAD-PARITY` | Static and dynamic trigger sets are inconsistent |
| `LOAD-MIST-FIRST` | MIST is not the first script in the loading chain |

---

## Related Documents

- [architecture.md](./architecture.md) — module map and upstream quirks
- [mission-template.md](./mission-template.md) — full build/extract lifecycle
- [../../vanilla/resources.md](../../vanilla/resources.md) — key id stability and namespace rules
- [../../vanilla/mission-file.md](../../vanilla/mission-file.md) — trig/trigrules structure
- [../../mist/mist.md](../../mist/mist.md) — MIST load-order invariant
