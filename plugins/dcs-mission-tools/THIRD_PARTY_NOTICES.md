# Third-party notices

This plugin redistributes the following third-party components. Their original
licenses and copyright notices are reproduced below.

## Lua 5.4 interpreters

`tools/bin/` ships prebuilt Lua 5.4.8 interpreters so that `mizlint` can run
without a separate Lua installation:

- `tools/bin/lua-macos-arm64`
- `tools/bin/lua-linux-x64`
- `tools/bin/windows-x64/lua54.exe`
- `tools/bin/windows-x64/lua54.dll`

Lua is licensed under the MIT license.

```
Copyright (C) 1994-2025 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

For details and rationale, see https://www.lua.org/license.html.

## veaf-tools (VEAF Mission Creation Tools)

`tools/bin/windows-x64/veaf-tools.exe`, `tools/bin/linux-x64/veaf-tools` and
`tools/bin/macos-arm64/veaf-tools` are vendored builds of the VEAF Mission
Creation Tools `export` command (v6.7.3). `mizlint` uses them to parse a
mission's `mission` / `dictionary` / `mapResource` data with a pure-Python
parser instead of executing it through a Lua interpreter.

veaf-tools is published by the Virtual European Air Force (VEAF) at
https://github.com/VEAF/VEAF-Mission-Creation-Tools and licensed under the
Apache License 2.0 (see the project's `LICENSE.md`).

Each vendored binary is a PyInstaller bundle that additionally embeds a Python
runtime and third-party Python libraries (e.g. `luadata`, `PyYAML`, `Typer`),
each under its own license; refer to the upstream project for the full
dependency manifest.
