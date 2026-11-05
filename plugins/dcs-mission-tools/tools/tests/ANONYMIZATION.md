# Log anonymization

## Hard rule

**No real log excerpt is ever committed.** Every log fixture under
`tools/tests/fixtures/logs/` must be either:

- fully synthetic (hand-written to reproduce a specific case), or
- derived from a real log that has been scrubbed with `anonymize.lua`
  **and then hand-reviewed** before it is added to the repository.

## Fields to neutralize

`anonymize.scrub(text)` performs a reproducible, format-preserving
substitution pass and automates only the following four transforms:

- Windows user directories: `C:\Users\<user>\...` → `C:\Users\PLAYER`
- Saved Games instance paths: `Saved Games\<instance>` → `Saved Games\INSTANCE`
- IPv4 addresses → `0.0.0.0`
- 32-hex-character UCIDs → 32 zero digits

**NOT automatically redacted** — contributor must hand-review and manually remove:

- Usernames and callsigns (except those embedded in Windows paths)
- Steam IDs and Discord IDs
- Port numbers (IP addresses alone are transformed, but ports are not)
- SRS / Discord / gRPC tokens
- Any other personal data not caught by the regex patterns above

Replacements are consistent placeholders that preserve the original
shape of the data so downstream parsing/format assumptions in the
reducer and its tests keep working.

## Reproducible command

```bash
./plugins/dcs-mission-tools/tools/bin/lua-macos-arm64 \
  plugins/dcs-mission-tools/tools/tests/anonymize.lua < real.log > fixtures/logs/derived.log
```

`anonymize.lua` is usable both as a library (`require("anonymize")`,
see `tools/tests/test_logreduce_cli.lua`) and, when invoked directly as
above, as a CLI filter that reads stdin and writes scrubbed output to
stdout.

## Best-effort — always hand-review

`scrub` is a best-effort regex pass. It does not understand every
field that could carry personal data (custom callsigns, freeform chat
text, unusual path layouts, etc.). **Always read the scrubbed output
before committing it** and manually redact anything the pass missed.
