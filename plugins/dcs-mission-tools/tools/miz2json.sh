#!/bin/sh
# miz2json — export a DCS mission (extracted folder or packed .miz) to JSON via
# veaf-tools (pure-Python parse, never runs Lua). Emits JSON on stdout so it can
# be piped to jq / python for cheap, structured exploration. See
# knowledge/vanilla/mission-json.md for the JSON contract and query recipes.
#
#   miz2json.sh [--pretty] <mission-folder-or-.miz> [output.json]
#
# --pretty  emit indented JSON (one value per line) for the no-jq fallback of
#           grepping the export; the default is compact (best for jq).
# With an output path the JSON is written there; otherwise it goes to stdout
# (veaf-tools prints a progress banner, so stdout mode routes the export through
# a temp file and cats it — a direct pipe would interleave the banner).
#
# veaf-tools resolution mirrors mizlint.sh: $VEAF_TOOLS override, then the
# vendored bin/<platform>/ binary, then `veaf-tools` on PATH. Exit 3 when none is
# available — callers should then fall back to anchored grep on the raw
# src/mission/mission (see knowledge/vanilla/mission-json.md, "Fallback ladder").
DIR="$(cd "$(dirname "$0")" && pwd)"

COMPACT="--compact"
case "$1" in
  --pretty|-p) COMPACT=""; shift ;;
esac

if [ -n "$VEAF_TOOLS" ]; then
  VT="$VEAF_TOOLS"
else
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)  VT="$DIR/bin/macos-arm64/veaf-tools" ;;
    Linux-x86_64)  VT="$DIR/bin/linux-x64/veaf-tools" ;;
    *)             VT="" ;;
  esac
  if [ -z "$VT" ] || [ ! -x "$VT" ]; then
    if command -v veaf-tools >/dev/null 2>&1; then
      VT="veaf-tools"
    else
      echo "miz2json: no vendored veaf-tools for $(uname -s)-$(uname -m) and none on PATH (set VEAF_TOOLS)" >&2
      exit 3
    fi
  fi
fi

INPUT="$1"
if [ -z "$INPUT" ]; then
  echo "usage: miz2json.sh [--pretty] <mission-folder-or-.miz> [output.json]" >&2
  exit 2
fi
OUT="$2"

if [ -n "$OUT" ]; then
  if "$VT" export "$INPUT" "$OUT" --format json $COMPACT --no-pause >/dev/null 2>&1; then
    exit 0
  fi
  echo "miz2json: veaf-tools export failed for $INPUT" >&2
  exit 1
fi

TMP="$(mktemp "${TMPDIR:-/tmp}/miz2json.XXXXXX")" || { echo "miz2json: mktemp failed" >&2; exit 1; }
if "$VT" export "$INPUT" "$TMP" --format json $COMPACT --no-pause >/dev/null 2>&1; then
  cat "$TMP"
  rm -f "$TMP"
  exit 0
fi
rm -f "$TMP"
echo "miz2json: veaf-tools export failed for $INPUT" >&2
exit 1
