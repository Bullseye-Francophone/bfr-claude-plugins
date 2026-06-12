# VMCT Mission Template

## Project Layout

```
package.json                        # depends on veaf-mission-creation-tools
src/
  mission/                          # extracted .miz (tracked in git)
  scripts/
    missionConfig.lua               # mission entry point — calls veafXxx.initialize()
    <custom scripts>.lua            # optional mission-specific scripts
  radio/
    radioSettings.lua
  waypoints/
    waypointsSettings.lua
  spawnableAircrafts/
    settings.lua
  weatherAndTime/
    versions.json                   # date/weather variant presets
  options/
<build scripts>.bat / .sh           # command scripts at project root
```

---

## extract

Runs on a `.miz` received from a Mission Editor session. Steps in order:

1. Unzip the `.miz` into `src/mission/`.
2. Strip build-injected `*.lua` files from `l10n/DEFAULT` (these are regenerated at build
   time from the npm package and must not be committed).
3. Force both static predicates back to `return false`.
4. Re-apply radio presets.
5. Run `veafMissionNormalizer` — deterministic serialization: sorted keys, one entry per
   line. This is what makes mission files git-diffable and viable for line-based tools.
6. Delete the source `.miz`.

After a clean extract the working tree should show only meaningful mission changes, not
tool noise.

---

## build

Produces a dated `.miz` for distribution. Steps in order:

1. Install/refresh the npm dependency (`veaf-mission-creation-tools`).
2. Stage `src/mission/` into a temporary working copy.
3. Run the design-time editors against the staged copy:
   - `veafMissionRadioPresetsEditor`
   - `veafMissionFlightPlanEditor`
   - `veafSpawnableAircraftsEditor`
4. Flip predicates to static mode (`return false` on both).
5. Copy community scripts, mission scripts, and compiled bundle (`veaf-scripts.lua`) into
   staged `l10n/DEFAULT`.
6. Neutralize `requiredModules` — module entries would lock out players who lack the DLC.
7. Run `veafMissionNormalizer`.
8. Re-zip with 7-Zip into a dated `.miz`.

---

## build-dev

Same as build but switches to dynamic loading mode:

- Predicates are flipped to enable the dynamic trigger chain.
- At mission start DCS loads scripts from disk via `loadfile` using `VEAF_DYNAMIC_PATH`.
- Enables edit-and-restart iteration without full rebuilds.

Dynamic mode caveats apply: `veaf.Development = true` is forced, trace logging is on,
security is disabled. See [injection.md](./injection.md) and
[architecture.md](./architecture.md) for details.

---

## weather variants

`veaf-tools` weather injector generates date/weather variants of a built `.miz` from
presets defined in `src/weatherAndTime/versions.json`. Run after build, produces one
`.miz` per preset entry.

---

## Expected Committed State

What reviewers and linters should see in git at any given commit:

- `src/mission/` is extracted and normalized.
- Both loading-mode predicates are `return false`.
- No `.miz` file at the project root.
- `l10n/DEFAULT` contains **no** build-injected `.lua` files (those are generated at build
  time).
- `l10n/DEFAULT` contains only non-Lua resources (sounds, images) that genuinely belong to
  the mission.

Deviations from this state indicate an incomplete extract, a skipped extraction step, or a
direct `.miz` commit.

Relevant mizlint codes: `LOAD-COMMITTED-STATE`, `LOAD-MIZ-AT-ROOT`.

---

## How mizlint Maps to This Lifecycle

| When to run | What to check |
|-------------|--------------|
| After `extract` | Full lint — verifies committed state, key references, resource presence, trigger parity |
| Before a Mission Editor session | Baseline — confirms the starting state is clean |
| After a Mission Editor session (before re-extracting) | `TRG-*` findings are expected if ME was used without extract; re-extract to resolve |
| After `build` | `LOAD-*` findings should be absent; `RES-MISSING-FILE` catches sounds/images not in source tree |
| After `build-dev` | `LOAD-COMMITTED-STATE` will fire — expected in dev builds, not in committed files |

See [injection.md](./injection.md) for the full set of `LOAD-*` codes and what triggers
each one.

---

## Related Documents

- [injection.md](./injection.md) — trigger injection, predicate flipping, build-time file copy
- [architecture.md](./architecture.md) — module list, design-time editors, VMCT parts
- [../../vanilla/resources.md](../../vanilla/resources.md) — mapResource / dictionary, RES-* codes
- [../../vanilla/mission-file.md](../../vanilla/mission-file.md) — trig/trigrules, the regeneration contract
- [../../mist/mist.md](../../mist/mist.md) — MIST, the load-order invariant
