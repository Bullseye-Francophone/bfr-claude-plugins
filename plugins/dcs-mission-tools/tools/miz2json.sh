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
# veaf-tools' own output (banner on success, traceback / PyInstaller bootloader
# error on failure) is captured to a temp log, never shown on success. When the
# export fails, stderr gets "miz2json: veaf-tools export failed for <input>
# (exit N)" followed by the last $MIZ2JSON_LOG_LINES (default 20) lines of that
# log, indented — so a failure carries its real cause instead of being swallowed.
#
# veaf-tools resolution mirrors mizlint.sh: $VEAF_TOOLS override, then the
# vendored bin/<platform>/ binary, then `veaf-tools` on PATH. Exit 3 when none is
# available — callers should then fall back to anchored grep on the raw
# src/mission/mission (see knowledge/vanilla/mission-json.md, "Fallback ladder").
# Exit codes: 0 success, 1 export failed, 2 usage, 3 no veaf-tools.
#
# Never assign TMP / TEMP / TMPDIR here: veaf-tools.exe (PyInstaller) unpacks
# itself under %TMP%, and Git-Bash exports them to the Windows child (PR #8).
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
    MINGW*|MSYS*|CYGWIN*) VT="$DIR/bin/windows-x64/veaf-tools.exe" ;;
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

TMPJSON=""
VTLOG=""
trap 'rm -f ${TMPJSON:+"$TMPJSON"} ${VTLOG:+"$VTLOG"}' EXIT
trap 'exit 1' INT TERM

case "$MIZ2JSON_LOG_LINES" in
  ''|*[!0-9]*) LOGLINES=20 ;;
  *) LOGLINES="$MIZ2JSON_LOG_LINES" ;;
esac

# Capture veaf-tools' stdout+stderr; if no log can be created, still run (blind).
VTLOG="$(mktemp "${TMPDIR:-/tmp}/miz2json-log.XXXXXX" 2>/dev/null)" || VTLOG=""

# export_to <path>: run veaf-tools; 0 only if it exits 0 AND <path> is non-empty.
# On failure, report the exit code and the tail of veaf-tools' output on stderr.
export_to() {
  "$VT" export "$INPUT" "$1" --format json $COMPACT --no-pause >"${VTLOG:-/dev/null}" 2>&1
  VTCODE=$?
  if [ "$VTCODE" -eq 0 ] && [ -s "$1" ]; then
    return 0
  fi
  if [ "$VTCODE" -eq 0 ]; then
    echo "miz2json: veaf-tools export failed for $INPUT (exit 0 but no JSON written)" >&2
  else
    echo "miz2json: veaf-tools export failed for $INPUT (exit $VTCODE)" >&2
  fi
  if [ -z "$VTLOG" ]; then
    echo "  (veaf-tools output not captured: mktemp failed)" >&2
  elif [ -s "$VTLOG" ]; then
    echo "miz2json: veaf-tools output (last $LOGLINES lines):" >&2
    tail -n "$LOGLINES" "$VTLOG" | tr -d '\r' | sed 's/^/  /' >&2
  else
    echo "  (veaf-tools printed nothing)" >&2
  fi
  return 1
}

if [ -n "$OUT" ]; then
  export_to "$OUT" && exit 0
  exit 1
fi

TMPJSON="$(mktemp "${TMPDIR:-/tmp}/miz2json.XXXXXX")" || { echo "miz2json: mktemp failed" >&2; exit 1; }
if export_to "$TMPJSON"; then
  cat "$TMPJSON"
  exit 0
fi
exit 1
