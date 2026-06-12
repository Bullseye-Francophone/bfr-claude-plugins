# dcs-mission-tools

A Claude Code plugin to understand, lint and explain DCS World missions built on the VEAF mission template. It covers three layers of the mission stack: vanilla DCS mission internals (the `mission`, `dictionary` and `mapResource` Lua tables produced by the Mission Editor), MIST (the Mission Scripting Tools library), and VEAF-Mission-Creation-Tools (the VEAF build pipeline, dynamic loader, and module framework). Built by Bullseye Francophone (BFR) for the DCS mission-making community.

---

## Components

| Kind | Name | Purpose |
|------|------|---------|
| Skill | `lint-mission` | Run mizlint on a mission project and explain every finding across all layers |
| Skill | `map-mission` | Build a synthetic map of a mission — order of battle, zones, triggers, loaded scripts, kneeboards |
| Skill | `trace-logic` | Trace a chain of mission logic from a trigger or flag down through scripts, MIST and VEAF calls |
| Agent | `mission-explorer` | Answer targeted questions about huge mission files using anchored searches and compact extracts |
| Agent | `lua-analyst` | Classify every API call in a mission script by layer (vanilla SSE / MIST / VMCT) |
| Agent | `vmct-expert` | Answer questions about the VEAF-Mission-Creation-Tools framework from the bundled knowledge base |
| CLI | `mizlint` | Standalone static-analysis tool — no Claude Code required (`tools/mizlint.sh` / `tools\mizlint.cmd`) |
| Knowledge base | `knowledge/` | Seven reference files covering vanilla mission internals, MIST, and the VMCT architecture |

Knowledge base tree:

```
knowledge/
  vanilla/
    hoggit-links.md        Hoggit wiki quick-reference links for the SSE
    mission-file.md        Structure of the DCS mission Lua tables
    resources.md           How dictionary and mapResource work
  mist/
    mist.md                MIST API overview and common patterns
  frameworks/
    vmct/
      architecture.md      Module overview and roles in VEAF-Mission-Creation-Tools
      injection.md         How triggers and scripts are injected at build time
      mission-template.md  The VEAF mission template structure and conventions
```

---

## mizlint — standalone usage

No Claude Code required. The launchers vendor a Lua 5.4 interpreter for the three most common platforms (~1.6 MB total, nothing to install). On other platforms, mizlint falls back to a `lua` binary found on `PATH`.

**Linux / macOS**

```bash
tools/mizlint.sh all <path>
tools/mizlint.sh <check> <path>
tools/mizlint.sh list
tools/mizlint.sh coords <theatre> <x> <y>
tools/mizlint.sh all <path> --json
tools/mizlint.sh all <path> --checks-dir <extra-checks-dir>
```

**Windows**

```cmd
tools\mizlint.cmd all <path>
tools\mizlint.cmd <check> <path>
tools\mizlint.cmd list
tools\mizlint.cmd coords <theatre> <x> <y>
tools\mizlint.cmd all <path> --json
tools\mizlint.cmd all <path> --checks-dir <extra-checks-dir>
```

`<path>` is a mission project folder (containing `src/mission`), a `src/mission` folder, or a parent folder containing several mission projects (all sub-projects are linted).

**Exit codes**

| Code | Meaning |
|------|---------|
| 0 | No findings |
| 1 | Warnings only |
| 2 | One or more errors |
| 3 | Execution failure (bad arguments, unreadable files) |

---

## Checks reference

### Resources (`vanilla` layer)

| Code | Severity | Description |
|------|----------|-------------|
| `RES-UNDECLARED-KEY` | error | A key referenced in triggers or scripts is not declared in `dictionary` or `mapResource` |
| `RES-MISSING-FILE` | error | A file declared in `mapResource` does not exist on disk and is not build-injected |
| `RES-ENCODING` | error | A declared filename matches a file on disk only after mojibake normalization — the build will break |
| `RES-ORPHAN-KEY` | warning | A key is declared in `dictionary` or `mapResource` but never referenced |
| `RES-ORPHAN-FILE` | warning | A file exists in `l10n/DEFAULT` but is not declared in `mapResource` |
| `RES-VMCT-NOT-INSTALLED` | warning | Declared scripts could not be verified because the VMCT npm package is not installed — run `npm`/`yarn install` in the mission project |

### Triggers (`vanilla` layer)

| Code | Severity | Description |
|------|----------|-------------|
| `TRG-CARDINALITY` | error | The number of entries in `trig.actions`, `trig.conditions` or `trig.flag` does not match `#trigrules` — the mission was edited outside the Mission Editor or re-saved without re-injection |
| `TRG-STARTUP-COVERAGE` | error | A trigger appears in both `trig.funcStartup` and `trig.func`, in neither, or in the wrong one for its predicate type |
| `TRG-RECOMPILE` | error | A compiled trigger action in `trig.actions` does not match the corresponding `trigrules` action — the compiled and source representations are out of sync |

### Loading (`vmct` layer — VEAF-template missions only)

| Code | Severity | Description |
|------|----------|-------------|
| `LOAD-MIST-FIRST` | error | `mist.lua` is not the first script loaded in the static or dynamic loading trigger |
| `LOAD-PARITY` | error | A script is loaded in static mode but not in dynamic mode (or vice versa) — the two modes diverge |
| `LOAD-COMMITTED-STATE` | warning | A committed-state dictionary key still holds a dynamic build value instead of `return false ...` |
| `LOAD-MIZ-AT-ROOT` | warning | A `.miz` file sits at the project root and should be extracted or deleted before committing |
| `LOAD-REQUIRED-MODULES` | warning | `requiredModules` contains a paid module name — players without it cannot join unless the build neutralizes it |

### Flags (`vanilla` layer)

| Code | Severity | Description |
|------|----------|-------------|
| `FLAG-NEVER-SET` | warning | A flag is tested in triggers or scripts but never set anywhere |
| `FLAG-NEVER-READ` | info | A flag is set but never tested — dead flag or consumed by an external script |

### Names (`mist` layer)

| Code | Severity | Description |
|------|----------|-------------|
| `NAME-ZONE-MISSING` | error | A trigger zone name referenced in scripts or triggers does not exist in the mission |
| `NAME-GROUP-MISSING` | warning | A group name referenced in scripts is not present in the mission (may be spawned at runtime) |

---

## Extending

Load extra check modules at runtime with `--checks-dir`:

```bash
tools/mizlint.sh all <path> --checks-dir my-checks/
```

Each `.lua` file in the directory must return a module table:

```lua
return {
  name  = "my-check",       -- used as the check name on the CLI
  layer = "vanilla",        -- "vanilla" | "mist" | "vmct"
  run   = function(project)
    -- project fields: root, mission, dictionary, mapResource, l10nFiles,
    --   scriptFiles, scriptText, communityScripts, hasVmctMarkers
    local findings = {}
    -- table.insert(findings, {
    --   check    = "my-check",
    --   severity = "error" | "warning" | "info",
    --   code     = "MY-CODE",
    --   message  = "human-readable description",
    --   file     = "relative/path/for/display",   -- optional
    --   detail   = "extra context line",           -- optional
    -- })
    return findings
  end,
}
```

Future framework knowledge goes under `knowledge/frameworks/<name>/`.

---

## Known limitations

- **Read-only analysis.** mizlint never modifies mission files.
- **vmct-layer checks require the VEAF template.** `LOAD-*` checks are skipped automatically for vanilla and MIST-only missions.
- **Flag linting covers quoted string flags only.** Numeric flags passed as integer literals are not tracked.
- **Text-pattern matching can match commented-out code.** A flag or zone name inside a Lua comment counts as a reference.
- **`coords` supports four theatres:** `caucasus`, `syria`, `persiangulf`, `marianaislands`.
- **Not affiliated with Eagle Dynamics or VEAF.**

---

## Install

### As a Claude Code plugin

```
/plugin marketplace add Bullseye-Francophone/bfr-claude-plugins
/plugin install dcs-mission-tools@bfr
```

### Standalone (mizlint only)

```bash
git clone https://github.com/Bullseye-Francophone/bfr-claude-plugins.git
cd bfr-claude-plugins/plugins/dcs-mission-tools
tools/mizlint.sh all /path/to/your/mission
```
