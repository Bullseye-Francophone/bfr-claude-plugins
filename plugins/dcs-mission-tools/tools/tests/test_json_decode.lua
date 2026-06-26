local t = require("helpers")
local json = require("lib.json")

-- Scalars -------------------------------------------------------------------
t.eq("decode: integer", json.decode("42"), 42)
t.eq("decode: float", json.decode("42.5"), 42.5)
t.eq("decode: negative", json.decode("-7"), -7)
t.eq("decode: true", json.decode("true"), true)
t.eq("decode: false", json.decode("false"), false)
t.eq("decode: string", json.decode('"hello"'), "hello")
t.eq("decode: string escapes", json.decode('"a\\"b\\\\c\\nd"'), 'a"b\\c\nd')
t.eq("decode: surrounding whitespace", json.decode("  \n 12 \t"), 12)

-- UTF-8 (contract §5) -------------------------------------------------------
t.eq("decode: \\u escape -> UTF-8", json.decode('"caf\\u00e9"'), "caf\u{00e9}")
t.eq("decode: surrogate pair -> UTF-8", json.decode('"\\ud83d\\ude00"'), "\u{1f600}")
t.eq("decode: raw UTF-8 passthrough", json.decode('"caf\u{00e9}"'), "caf\u{00e9}")

-- Arrays: contiguous 1..n -> Lua sequence (contract §2) ----------------------
t.eq("decode: array", json.decode('[1,2,3]'), { 1, 2, 3 })
do
  local seq = json.decode('["a","b","c"]')
  t.eq("decode: array supports #", #seq, 3)
  local joined = ""
  for _, v in ipairs(seq) do joined = joined .. v end
  t.eq("decode: array supports ipairs", joined, "abc")
end

-- Objects: records stay string-keyed ----------------------------------------
t.eq("decode: object record", json.decode('{"a":2,"b":1}'), { a = 2, b = 1 })
t.eq("decode: nested", json.decode('{"x":[1,{"y":"z"}]}'), { x = { 1, { y = "z" } } })

-- Sparse object: canonical integer-string keys -> integer keys (contract §3) -
do
  local sparse = json.decode('{"2":"a","5":"b"}')
  t.eq("decode: sparse key 2 is integer", sparse[2], "a")
  t.eq("decode: sparse key 5 is integer", sparse[5], "b")
  t.eq("decode: sparse not under string key", sparse["2"], nil)
end

-- Key coercion edge cases (contract §3) -------------------------------------
do
  local m = json.decode('{"0":"zero","01":"leading","-7":"neg","x":"str"}')
  t.eq("decode: '0' -> integer 0", m[0], "zero")
  t.eq("decode: '01' stays string (leading zero)", m["01"], "leading")
  t.eq("decode: '-7' -> integer -7", m[-7], "neg")
  t.eq("decode: 'x' stays string", m.x, "str")
end

-- Empty array and empty object both -> empty Lua table (contract §4) ---------
t.eq("decode: empty array -> empty table", json.decode("[]"), {})
t.eq("decode: empty object -> empty table", json.decode("{}"), {})
do
  local a, o = json.decode("[]"), json.decode("{}")
  t.eq("decode: empty array #", #a, 0)
  t.eq("decode: empty object #", #o, 0)
  t.check("decode: empty array next() == nil", next(a) == nil)
  t.check("decode: empty object next() == nil", next(o) == nil)
end

-- Worked example from the contract §2: trig / trigrules ---------------------
do
  local m = json.decode([[
    { "trigrules": [ {"r1": true}, {"r2": true} ],
      "trig": { "actions": ["a_do_script(...)"],
                "conditions": ["return true"],
                "flag": [true] } }
  ]])
  t.eq("decode: #trigrules behaves like load()", #m.trigrules, 2)
  t.eq("decode: trig is a record (string keys)", m.trig.actions[1], "a_do_script(...)")
  local n = 0
  for _ in ipairs(m.trig.actions) do n = n + 1 end
  t.eq("decode: ipairs(trig.actions)", n, 1)
end

-- Round-trip parity: encode(x) then decode reproduces x ---------------------
-- (covers sequences and sparse integer-keyed tables, the parity-critical case)
for _, value in ipairs({
  { 1, 2, 3 },
  { a = 1, b = { 2, 3 } },
  { [1] = "a", [3] = "c" },          -- sparse -> object -> back to integer keys
  { trig = { actions = { "x", "y" } } },
}) do
  t.eq("decode: round-trip " .. json.encode(value), json.decode(json.encode(value)), value)
end

-- Malformed input raises ----------------------------------------------------
t.check("decode: trailing data raises", not pcall(json.decode, "[1,2] junk"))
t.check("decode: unterminated string raises", not pcall(json.decode, '"abc'))
t.check("decode: bad literal raises", not pcall(json.decode, "tru"))
