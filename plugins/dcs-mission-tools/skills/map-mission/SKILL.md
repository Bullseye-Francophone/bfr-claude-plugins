---
name: map-mission
description: Builds a synthetic map of a DCS World mission - order of battle per coalition, trigger zones, mission logic (user triggers vs VEAF framework triggers), loaded scripts and kneeboards. Use when the user wants to understand, summarize, document or compare the content of a DCS mission.
---

# Map a DCS mission

Mission files are 5–25 MB Lua tables. NEVER read `src/mission/mission` whole.
Delegate raw lookups to the `mission-explorer` agent; it returns compact extracts.

## Procedure

1. Theatre and metadata: ask mission-explorer for `theatre`, `date`, `start_time`,
   `weather.name`, `descriptionText` (resolve the DictKey in `l10n/DEFAULT/dictionary`).
2. Order of battle: for each coalition, count groups per category
   (plane/helicopter/vehicle/ship/static) and list named flights with airframe types.
3. Zones: list `triggers.zones[].name` (grouped by prefix conventions if obvious).
4. Logic: list `trigrules[].comment` + predicate; flag VEAF-injected triggers
   (the 7 MISSION START ones, see
   `${CLAUDE_PLUGIN_ROOT}/knowledge/frameworks/vmct/injection.md`) separately from
   mission-specific logic.
5. Scripts: list `src/scripts/*.lua` and which VMCT modules `missionConfig.lua`
   initializes (`veafXxx.initialize()` calls).
6. Coordinates for key positions (bullseye, zone centers):
   `"${CLAUDE_PLUGIN_ROOT}/tools/mizlint.sh" coords <theatre> <x> <y>`
   (DCS x = northing, y = easting; supported theatres: caucasus, syria,
   persiangulf, marianaislands).

## Output

A markdown brief: Overview / Order of battle (table per coalition) / Zones /
Mission logic / Scripts & frameworks. Keep it under ~150 lines; link counts,
not exhaustive unit dumps, unless the user asks.
