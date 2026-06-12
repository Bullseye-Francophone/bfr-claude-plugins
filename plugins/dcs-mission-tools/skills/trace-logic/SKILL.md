---
name: trace-logic
description: Traces and explains a chain of DCS mission logic across layers - from a trigger or flag in the mission file, through mission scripts, down to VEAF-Mission-Creation-Tools and MIST calls. Use when the user asks why or how a trigger, flag, zone activation or scripted behavior works (or does not work) in a DCS mission.
---

# Trace mission logic

Goal: given a flag name, zone name, trigger comment or observed behavior,
produce the complete causal chain with file:line citations.

## Method

1. Locate the entry point with anchored greps on `src/mission/mission`
   (never read it whole — delegate to the `mission-explorer` agent):
   - flag: `a_set_flag(\"<name>\")`, `c_flag_is_true(\"<name>\")`,
     `getUserFlag("<name>")`, `setUserFlag("<name>"`
   - zone: exact name in `triggers.zones`, `ActivateZone(\"<name>\")`
   - Use word-boundary anchoring: `Zone-1` must not match `Zone-10`.
2. For each hit, identify the trigger index, then fetch its `trigrules[i].comment`,
   `rules` (conditions) and `actions` — that is the editor-level truth.
3. Follow `a_do_script` payloads into `src/scripts/*.lua`; for VMCT/MIST calls,
   resolve semantics with the `lua-analyst` or `vmct-expert` agent and the
   knowledge files (`${CLAUDE_PLUGIN_ROOT}/knowledge/`).
4. Check both directions: who sets the flag, who consumes it, what the actions
   trigger downstream (other flags, zone activations, spawns).

## Output

A numbered chain, each step `what happens — where (file:line) — layer
(vanilla/MIST/VMCT)`, followed by "Conditions for this to fire" and, if the user
reported a malfunction, the most likely break point with evidence.
