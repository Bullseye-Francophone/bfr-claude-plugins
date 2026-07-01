---
name: map-mission
description: Builds a synthetic map of a DCS World mission - order of battle per coalition, trigger zones, mission logic (user triggers vs VEAF framework triggers), loaded scripts and kneeboards. Use when the user wants to understand, summarize, document or compare the content of a DCS mission.
---

# Map a DCS mission

Mission files are 5–25 MB Lua tables. NEVER read `src/mission/mission` whole.
Export it once to JSON and drive the map with jq (contract and recipes:
`${CLAUDE_PLUGIN_ROOT}/knowledge/vanilla/mission-json.md`); delegate to the
`mission-explorer` agent only for lookups the JSON does not cover or when veaf-tools
is unavailable.

```sh
"${CLAUDE_PLUGIN_ROOT}/tools/miz2json.sh" <project-or-.miz> > mission.json   # once, then reuse
```

## Procedure

1. Theatre and metadata: `.theatre`, `.mission.date`, `.mission.start_time`,
   `.mission.weather.name`, and the briefing text
   `.dictionary[.mission.descriptionText]`.
2. Order of battle: counts per coalition and category with the OOB recipe in
   mission-json.md, then list named flights
   (`.mission.coalition.<side>.country[].<plane|helicopter|vehicle|ship|static>.group[].name`)
   with airframe types (`…group[].units[].type`). To turn cryptic `type` strings into
   display names, categories or attributes (RCS, sensors, payloads), delegate to the
   `dcs-reference` agent (see `${CLAUDE_PLUGIN_ROOT}/knowledge/vanilla/dcs-database.md`).
   Optional and network-dependent — skip gracefully offline; the raw type strings still
   stand on their own.
3. Zones: `.mission.triggers.zones[].name` (grouped by prefix conventions if obvious).
4. Logic: `.mission.trigrules[] | {comment, predicate}`; flag the VEAF-injected head
   triggers (the first ~7 `triggerStart` entries — script/config loading, mission start,
   CTLD beacons; identified by position, not comment text — see
   `${CLAUDE_PLUGIN_ROOT}/knowledge/frameworks/vmct/injection.md`) separately from
   mission-specific logic.
5. Scripts: list `src/scripts/*.lua` (NOT in the export — read them on disk) and which
   VMCT modules `missionConfig.lua` initializes (`veafXxx.initialize()` calls).
6. Coordinates for key positions (bullseye, zone centers):
   `"${CLAUDE_PLUGIN_ROOT}/tools/mizlint.sh" coords <theatre> <x> <y>`
   (DCS x = northing, y = easting; supported theatres: caucasus, syria,
   persiangulf, marianaislands).

## Output

A markdown brief: Overview / Order of battle (table per coalition) / Zones /
Mission logic / Scripts & frameworks. Keep it under ~150 lines; link counts,
not exhaustive unit dumps, unless the user asks.
