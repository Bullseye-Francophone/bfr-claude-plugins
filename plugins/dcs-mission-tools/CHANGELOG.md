# Changelog

All notable changes to the **dcs-mission-tools** plugin are documented here. The
format is based on [Keep a Changelog](https://keepachangelog.com/); the plugin aims
to follow semantic versioning. The `version` field in `.claude-plugin/plugin.json`
is bumped on every release so installed copies pick the change up on a marketplace
update.

## [0.1.3] — 2026-07-01

Safe, structured mission reading: missions are parsed with **veaf-tools** (never by
executing their Lua), a packed `.miz` can be linted directly, and mission content can
be explored as JSON with `jq` instead of grepping the raw multi-megabyte Lua table.

### Added
- **`miz2json`** CLI (`tools/miz2json.sh` / `tools/miz2json.cmd`) — export a mission
  (extracted folder or packed `.miz`) to JSON via veaf-tools for cheap, structured
  `jq`/`python` exploration. Mirrors mizlint's platform-binary resolution
  (`VEAF_TOOLS` override → vendored `bin/<platform>/` → PATH); `--pretty` emits indented
  JSON for a no-jq grep fallback.
- **`knowledge/vanilla/mission-json.md`** — the schemaVersion-2 JSON export contract
  (records/sequences, string-numeric keys, the `__luaTable__` envelope and where it
  occurs), verified `jq` recipes per landmark, the recursive-descent exhaustiveness
  sweep, and the fallback ladder (jq → python3 → `--pretty` + grep → raw-Lua grep).
- Direct linting of a packed **`.miz`** — veaf-tools unpacks the embedded resources;
  data tables come from the JSON, scripts/resources from the archive's `l10n/DEFAULT`.
- Bundled **veaf-tools** parser for `windows-x64`, `linux-x64` and `macos-arm64`
  (aligned on v6.7.3), so the safe parse path works with nothing to install.
- JSON decoder for the veaf-tools export contract, preserving integer-vs-string Lua
  key types losslessly via the `__luaTable__` envelope.

### Changed
- Mission parsing now routes through **veaf-tools** (pure-Python, never executes the
  mission Lua); the sandboxed lua54 loader remains only as a fallback when veaf-tools
  is unavailable.
- **`mission-explorer`**, **`map-mission`** and **`trace-logic`** now prefer
  export→`jq` for structured lookups, with anchored grep on the raw Lua kept as the
  fallback and their hard rules (word-boundary anchoring, namespace-by-usage,
  `trig`+`trigrules`) preserved.
- README documents safe `.miz` parsing, the `miz2json` CLI and the new knowledge doc.

### Fixed
- `RES-*` findings on a `.miz` no longer carry a misleading `src/mission/mission`
  source-file hint (a built `.miz` has no extracted source tree).
- Windows `miz2json.cmd` resolved the vendored `veaf-tools.exe` inside an `if` block,
  where `%VT%` expanded at parse time (before the `set`) — the vendored binary was
  never used and the tool silently required `veaf-tools` on PATH. Resolution now happens
  at top level, mirroring `mizlint.cmd`.
- `miz2json.sh` removes its temp file on interrupt (`trap EXIT INT TERM`), not only on
  the normal exit paths.
- Corrected the `__luaTable__` envelope documentation (real exports envelope
  `.mission.failures`) and anchored the completeness sweep (`\b…\b`) so a search for
  `Zone-1` no longer matches `Zone-10`.

---

Releases before 0.1.3 predate this changelog; see the git history and the
`dcs-mission-tools--v0.1.2` tag.

[0.1.3]: https://github.com/Bullseye-Francophone/bfr-claude-plugins/compare/dcs-mission-tools--v0.1.2...dcs-mission-tools--v0.1.3
