local t = require("helpers")
local decode = require("logreduce.decode")

t.eq("decode: plain ascii passes through",
  decode.toText("hello"), "hello")

t.eq("decode: strips utf-8 bom",
  decode.toText("\239\187\191hello"), "hello")

t.eq("decode: utf-16le bom transcodes ascii",
  decode.toText("\255\254h\0i\0"), "hi")

local text, err = decode.toText(string.rep("\0", 32))
t.eq("decode: all-null returns nil", text, nil)
t.contains("decode: all-null explains why", err, "all-null")

t.eq("decode: splits crlf and lf, drops blanks",
  decode.splitLines("a\r\nb\n\nc"), { "a", "b", "c" })

t.eq("decode: preserves indented stack line",
  decode.splitLines("head\n\t[string \"x\"]:1: in function"),
  { "head", "\t[string \"x\"]:1: in function" })
