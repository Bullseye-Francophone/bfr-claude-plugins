#!/bin/sh
# mizlint launcher — picks the vendored Lua for this platform, falls back to PATH lua.
DIR="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  BIN="$DIR/bin/lua-macos-arm64" ;;
  Linux-x86_64)  BIN="$DIR/bin/lua-linux-x64" ;;
  *)             BIN="" ;;
esac
if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  if command -v lua >/dev/null 2>&1; then
    BIN="lua"
  else
    echo "mizlint: no vendored Lua for $(uname -s)-$(uname -m) and no 'lua' on PATH" >&2
    exit 3
  fi
fi
exec "$BIN" "$DIR/src/main.lua" "$@"
