# Hoggit DCS Reference Links

## Wiki Home

- **Hoggit DCS World Wiki**: https://wiki.hoggitworld.com/view/Hoggit_DCS_World_Wiki
  - Mission Making section covers ME concepts, trigger types, scripting overview.

## Simulator Scripting Engine (SSE)

- **SSE Documentation root**: https://wiki.hoggitworld.com/view/Simulator_Scripting_Engine_Documentation
  - Covers the full Lua API surface exposed to mission scripts.

## Singleton Pages

- `trigger`: https://wiki.hoggitworld.com/view/DCS_singleton_trigger
- `timer`: https://wiki.hoggitworld.com/view/DCS_singleton_timer
- `world`: https://wiki.hoggitworld.com/view/DCS_singleton_world
- `coalition`: https://wiki.hoggitworld.com/view/DCS_singleton_coalition
- `missionCommands`: https://wiki.hoggitworld.com/view/DCS_singleton_missionCommands
- `env`: https://wiki.hoggitworld.com/view/DCS_singleton_env

## Class Pages

- `Group`: https://wiki.hoggitworld.com/view/DCS_Class_Group
- `Unit`: https://wiki.hoggitworld.com/view/DCS_Class_Unit
- `Object`: https://wiki.hoggitworld.com/view/DCS_Class_Object

## MIST

- **Mission Scripting Tools Documentation**: https://wiki.hoggitworld.com/view/Mission_Scripting_Tools_Documentation

---

## Caveat

The wiki writes `trigRules` (camelCase) in several places. Serialized mission files use
lowercase `trigrules`. When there is a conflict between wiki spelling and what appears in
an actual `.miz`, trust the file.
