# VMCT Architecture

## What VMCT Is

VEAF-Mission-Creation-Tools (VMCT) is the npm package `veaf-mission-creation-tools`
(GitHub: VEAF/VEAF-Mission-Creation-Tools). It is the de-facto framework behind the VEAF
mission template.

Four parts:

1. **~35 runtime Lua modules** (`src/scripts/veaf/veaf*.lua`) layered on MIST.
2. **Vendored community scripts** (`src/scripts/community/`): mist.lua, CTLD, CSAR,
   Skynet-IADS, DCS-SimpleTextToSpeech, WeatherMark, HoundElint, Hercules cargo, and
   others.
3. **Design-time Lua editors** run by the build: veafMissionNormalizer,
   veafMissionRadioPresetsEditor, veafMissionFlightPlanEditor,
   veafSpawnableAircraftsEditor, and the one-shot veafMissionTriggerInjector.
4. **Node.js tools** (`veaf-tools` binary): weather/time injection, mission selector.

---

## Runtime Module Map

| Module | Role |
|--------|------|
| `veaf.lua` | Root module: constants, loggers, shared utils. **Must load before every other veaf module.** |
| `veafRadio` | F10 radio menu infrastructure |
| `veafMarkers` | Map-marker event dispatch |
| `veafSpawn` | `_spawn` marker commands: units, groups, cargo, fire effects |
| `veafCasMission` | `_cas` on-demand CAS training group |
| `veafMove` | `_move` group/tanker relocation |
| `veafNamedPoints` | `_name point` named map points, ATC info |
| `veafWeather` | `_weather`, METAR/ATIS |
| `veafShortcuts` | `-` aliases expanding to full commands |
| `veafCombatZone` | Editor-defined combat zones with radio menus, briefings, activation |
| `veafCombatMission` | Air-to-air mission orchestration |
| `veafAssets` | Tankers/AWACS tracking and respawn |
| `veafAirWaves` | Zones defended by waves of AI |
| `veafQraManager` | Quick reaction alerts |
| `veafTransportMission` | Transport/logistics missions |
| `veafGrass` | Grass runways/FARPs |
| `veafCarrierOperations` | Carrier ops menus |
| `veafSecurity` | Password-gated commands |
| `veafRemote` | NIOD/server hooks |
| `veafInterpreter` | Commands embedded in dummy units |
| `veafEventHandler` | DCS event hub |
| `veafUnits` + `dcsUnits` | Unit/group alias databases |
| `veafTime` | Time utilities |
| `veafSanctuary` | Sanctuary zones |
| `veafGroundAI` | Ground AI control |
| `veafHoundElintHelper` | HoundElint integration helper |
| `veafSkynetIadsHelper` | Skynet-IADS integration helper |
| `veafCacheManager` | Script-level cache |
| `veafMissileGuardian` | Missile guardian feature |

---

## Per-Mission Configuration

`src/scripts/missionConfig.lua` is the mission's entry point. It calls
`veafXxx.initialize()` for each module the mission uses. Order matters: veaf root loads
first (via the loader), then feature modules.

The dynamic-mode variant config script name varies between missions — commonly
`veafDynamicConfig.lua`, but some missions reuse `missionConfig.lua`. Always resolve per
mission.

---

## Known Upstream Quirks

These are framework-level defects; report them as such rather than treating them as user
errors.

**Case mismatch in dynamic loader**: `VeafDynamicLoader.lua` references `veafAirwaves.lua`
while the file on disk is `veafAirWaves.lua` (capital W). This breaks on case-sensitive
filesystems (Linux servers).

**Missing module in dynamic loader**: `VeafDynamicLoader.lua` omits `veafMissileGuardian`
although the compiled static bundle includes it. Static and dynamic modes genuinely load
different module sets — this is not a configuration error.

**Dev settings forced in dynamic mode**: the loader hard-codes `veaf.Development = true`,
disables security, and enables trace logging whenever dynamic mode is active. See
[injection.md](./injection.md) for the full implications.

---

## Related Documents

- [injection.md](./injection.md) — trigger injection, build steps, loading modes
- [mission-template.md](./mission-template.md) — project layout and lifecycle
- [../../mist/mist.md](../../mist/mist.md) — MIST API and the load-order invariant
- [../../vanilla/resources.md](../../vanilla/resources.md) — mapResource / dictionary system
- [../../vanilla/mission-file.md](../../vanilla/mission-file.md) — trig/trigrules structure
