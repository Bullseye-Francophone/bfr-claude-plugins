---
name: trace-logic
description: Traces and explains a chain of DCS mission logic across layers - from a trigger or flag in the mission file, through mission scripts, down to VEAF-Mission-Creation-Tools and MIST calls. Use when the user asks why or how a trigger, flag, zone activation or scripted behavior works (or does not work) in a DCS mission.
---

# Trace mission logic

Goal: given a flag name, zone name, trigger comment or observed behavior,
produce the complete causal chain with source citations.

## Method

1. Export the mission once and locate the entry point with jq (contract and recipes:
   `${CLAUDE_PLUGIN_ROOT}/knowledge/vanilla/mission-json.md`; delegate to the
   `mission-explorer` agent if you prefer):

   ```sh
   "${CLAUDE_PLUGIN_ROOT}/tools/miz2json.sh" <project-or-.miz> > mission.json
   # triggers that reference the flag/zone in their conditions or actions
   jq -c '.mission.trigrules[] | select(([.actions,.rules]|tostring)|test("<name>")) | {comment,predicate,rules,actions}' mission.json
   # a trigger zone by name
   jq -c '.mission.triggers.zones[] | select(.name|test("<name>"))' mission.json
   ```

   For completeness use the recursive sweep — anchor the term so `Zone-1` does not match
   `Zone-10`:
   `jq -r '[.. | strings | select(test("\\b<name>\\b";"i"))] | unique[]' mission.json` — a
   flag can be set/read in places a single landmark query misses.

   Directionality (feeds step 4): a flag is SET by an action `{predicate:"a_set_flag"}`
   (compiled `a_set_flag("<name>")` / `setUserFlag("<name>",…)` in `.mission.trig.actions[]`)
   and CONSUMED by a condition `{predicate:"c_flag_is_true"}` (compiled
   `c_flag_is_true("<name>")` / `getUserFlag("<name>")` in `.mission.trig.conditions[]`).
   Split your hits on these predicates.
2. For each hit, read its `trigrules[i]` — `comment`, `rules` (conditions) and
   `actions` are the editor-level truth (see
   `${CLAUDE_PLUGIN_ROOT}/knowledge/vanilla/mission-file.md` → *trig vs trigrules*).
3. Follow `a_do_script` / `a_do_script_file` payloads into `src/scripts/*.lua` (these
   are on disk, NOT in the export — grep them directly); for VMCT/MIST calls, resolve
   semantics with the `lua-analyst` or `vmct-expert` agent and the knowledge files
   (`${CLAUDE_PLUGIN_ROOT}/knowledge/`).
4. Check both directions: who sets the flag, who consumes it, what the actions
   trigger downstream (other flags, zone activations, spawns). Remember flags set
   dynamically by scripts (`setUserFlag(ListeTriggers[i], …)`) resolve to no literal —
   note them rather than assuming they are unused.

## Output

A numbered chain, each step `what happens — where (jq path or file:line) — layer
(vanilla/MIST/VMCT)`, followed by "Conditions for this to fire" and, if the user
reported a malfunction, the most likely break point with evidence.
