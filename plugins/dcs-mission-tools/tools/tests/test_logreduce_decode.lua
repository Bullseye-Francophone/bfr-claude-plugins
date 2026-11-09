local t = require("helpers")
local decode = require("logreduce.decode")

t.eq("decode: plain ascii passes through",
  decode.toText("hello"), "hello")

t.eq("decode: strips utf-8 bom",
  decode.toText("\239\187\191hello"), "hello")

t.eq("decode: utf-16le bom transcodes ascii",
  decode.toText("\255\254h\0i\0"), "hi")

t.eq("decode: utf-16le accented letter becomes utf-8",
  decode.toText("\255\254\233\0"), "\195\169")

t.eq("decode: utf-16be accented letter becomes utf-8",
  decode.toText("\254\255\0\233"), "\195\169")

t.eq("decode: utf-16le surrogate pair becomes a four-byte character",
  decode.toText("\255\254\61\216\0\222"), "\240\159\152\128")

t.eq("decode: utf-16le lone surrogate becomes the replacement character",
  decode.toText("\255\254\61\216h\0"), "\239\191\189h")

t.eq("decode: iso-8859 line becomes utf-8",
  decode.toText("caf\233"), "caf\195\169")

t.eq("decode: valid utf-8 is left untouched",
  decode.toText("caf\195\169"), "caf\195\169")

t.eq("decode: a latin-1 line does not alter its utf-8 neighbour",
  decode.toText("caf\195\169\ncaf\233"), "caf\195\169\ncaf\195\169")

local text, err = decode.toText(string.rep("\0", 32))
t.eq("decode: all-null returns nil", text, nil)
t.contains("decode: all-null explains why", err, "all-null")

t.eq("decode: splits crlf and lf, drops blanks",
  decode.splitLines("a\r\nb\n\nc"), { "a", "b", "c" })

t.eq("decode: preserves indented stack line",
  decode.splitLines("head\n\t[string \"x\"]:1: in function"),
  { "head", "\t[string \"x\"]:1: in function" })
