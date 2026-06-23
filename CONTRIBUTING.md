# Contributing

Thanks for your interest in improving the BFR DCS mission tooling! This repository is a Claude Code plugin marketplace. Its main plugin, `dcs-mission-tools`, ships **mizlint** (a standalone Lua linter for DCS World missions built on the VEAF template), a knowledge base, skills, and agents.

By contributing, you agree that your contributions are licensed under the repository's [MIT License](LICENSE).

## Repository layout

```
.claude-plugin/marketplace.json     Marketplace manifest
plugins/dcs-mission-tools/
  .claude-plugin/plugin.json         Plugin manifest
  agents/                            Read-only lookup agents
  skills/                            lint-mission, map-mission, trace-logic
  knowledge/                         Vanilla DCS / MIST / VMCT references
  tools/
    src/checks/                      One Lua file per mizlint check
    src/lib/                         Shared library (loader, model, json, projection)
    bin/                             Vendored Lua 5.4 interpreters
    tests/                           Dependency-free test suite + fixtures
```

## Development setup

mizlint is pure Lua 5.4. The interpreters are vendored under `tools/bin/`, so there is nothing to install on the bundled platforms (Windows, Linux x64, macOS arm64). On other platforms, install a `lua` 5.4 on your `PATH`.

## Running the tests

Run from the **repository root** (the fixtures use repo-root-relative paths):

```bash
# macOS arm64
./plugins/dcs-mission-tools/tools/bin/lua-macos-arm64 \
  plugins/dcs-mission-tools/tools/tests/run.lua \
  plugins/dcs-mission-tools/tools/tests/test_*.lua

# Linux x64: swap the interpreter for ./plugins/dcs-mission-tools/tools/bin/lua-linux-x64
```

The suite is dependency-free and must end with `N passed, 0 failed`.

## Validating the plugin

If you change manifests, skills, or agents:

```bash
claude plugin validate plugins/dcs-mission-tools
claude plugin validate .
```

## Adding or changing a mizlint check

- Checks live in `plugins/dcs-mission-tools/tools/src/checks/<name>.lua`.
- Each finding carries a stable code (e.g. `RES-MISSING-FILE`) documented in the plugin README "Checks reference" — keep that table in sync.
- Add a fixture under `tools/tests/fixtures/`: the `clean/` variant must stay finding-free, and broken variants should reproduce exactly the case you detect.
- Add assertions in `tools/tests/test_check_<name>.lua`.
- Favor determinism and avoid false positives — a noisy check is worse than a missing one.

## Coding style

- Match the surrounding code. The codebase favors clear, self-documenting names over comments.
- Use semantic commit messages with a scope: `type(scope): description` (e.g. `fix(mizlint): …`, `docs(plugin): …`).
- Keep one logical change per commit.

## Please don't commit

- Personal absolute paths, secrets, or credentials.
- Private or proprietary mission content. Use the small synthetic fixtures — never a real `.miz` or third-party framework source.

## Reporting issues

Open a GitHub issue with: the plugin version, your OS, a sanitized description of the mission or scenario, and the exact mizlint output or behavior you observed.
