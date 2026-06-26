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

-- UTF-8 (contract §4) -------------------------------------------------------
t.eq("decode: \\u escape -> UTF-8", json.decode('"caf\\u00e9"'), "caf\u{00e9}")
t.eq("decode: surrogate pair -> UTF-8", json.decode('"\\ud83d\\ude00"'), "\u{1f600}")
t.eq("decode: raw UTF-8 passthrough", json.decode('"caf\u{00e9}"'), "caf\u{00e9}")

-- Arrays: contiguous 1..n -> Lua sequence (contract §2) ----------------------
t.eq("decode: array", json.decode("[1,2,3]"), { 1, 2, 3 })
do
  local seq = json.decode('["a","b","c"]')
  t.eq("decode: array supports #", #seq, 3)
  local joined = ""
  for _, v in ipairs(seq) do joined = joined .. v end
  t.eq("decode: array supports ipairs", joined, "abc")
end

-- Object record: keys stay VERBATIM strings, never coerced (contract §2, §6.2) -
t.eq("decode: object record", json.decode('{"a":2,"b":1}'), { a = 2, b = 1 })
t.eq("decode: nested", json.decode('{"x":[1,{"y":"z"}]}'), { x = { 1, { y = "z" } } })
do
  -- DCS `failures = {["10"]=...}` : string-numeric keys must remain strings.
  local fail = json.decode('{"10":{"enable":false},"11":{"enable":true}}')
  t.eq("decode: failures key '10' stays string", fail["10"].enable, false)
  t.eq("decode: failures key '11' stays string", fail["11"].enable, true)
  t.eq("decode: failures not under integer key", fail[10], nil)
end

-- Envelope __luaTable__ : sparse-integer and mixed keys, lossless (contract §2) -
do
  -- pylons = {[1]=,[2]=,[8]=,[11]=} (sparse integers)
  local pylons = json.decode('{"__luaTable__":[[1,"AIM-9"],[2,"AIM-120"],[8,"fuel"],[11,"AIM-9"]]}')
  t.eq("decode: pylon 1 is integer key", pylons[1], "AIM-9")
  t.eq("decode: pylon 8 is integer key", pylons[8], "fuel")
  t.eq("decode: pylon 11 is integer key", pylons[11], "AIM-9")
  t.eq("decode: pylon not under string key", pylons["1"], nil)
end
do
  -- callsign = {[1]=169,[2]=1,[3]=1,["name"]="Colt11"} (mixed)
  local cs = json.decode('{"__luaTable__":[[1,169],[2,1],[3,1],["name","Colt11"]]}')
  t.eq("decode: mixed integer part", cs[1], 169)
  t.eq("decode: mixed string part", cs.name, "Colt11")
  t.eq("decode: mixed not coerced", cs["1"], nil)
end
do
  -- Nested values inside an envelope pair are decoded recursively.
  local m = json.decode('{"__luaTable__":[[2,{"id":"a"}],[5,["x","y"]]]}')
  t.eq("decode: envelope nested object value", m[2].id, "a")
  t.eq("decode: envelope nested array value", m[5][2], "y")
end

-- Sentinel hardening: not every object with the key is an envelope (contract §6.3) -
do
  -- value is not a pair list -> verbatim object with the literal key
  local v = json.decode('{"__luaTable__":"plain"}')
  t.eq("decode: sentinel w/ non-list value stays verbatim", v.__luaTable__, "plain")
end
do
  -- more than one key -> verbatim object, never an envelope
  local v = json.decode('{"__luaTable__":[[1,2]],"other":3}')
  t.eq("decode: sentinel + other key stays verbatim (other)", v.other, 3)
  t.eq("decode: sentinel + other key stays verbatim (sentinel value)", type(v.__luaTable__), "table")
end

-- Empty array and empty object both -> empty Lua table (contract §3) ---------
t.eq("decode: empty array -> empty table", json.decode("[]"), {})
t.eq("decode: empty object -> empty table", json.decode("{}"), {})
do
  local a, o = json.decode("[]"), json.decode("{}")
  t.check("decode: empty array next() == nil", next(a) == nil)
  t.check("decode: empty object next() == nil", next(o) == nil)
end

-- Worked example from the contract §2: trig / trigrules ---------------------
do
  local m = json.decode([[
    { "trigrules": [ {"comment": "init"}, {"comment": "win"} ],
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

-- Round-trip parity for the shapes the plugin's own encoder also emits -------
-- (sequences and string records; integer-keyed tables are veaf-tools' envelope,
-- which the plugin only ever decodes, never encodes)
for _, value in ipairs({
  { 1, 2, 3 },
  { a = 1, b = { 2, 3 } },
  { trig = { actions = { "x", "y" } } },
}) do
  t.eq("decode: round-trip " .. json.encode(value), json.decode(json.encode(value)), value)
end

-- Malformed input raises ----------------------------------------------------
t.check("decode: trailing data raises", not pcall(json.decode, "[1,2] junk"))
t.check("decode: unterminated string raises", not pcall(json.decode, '"abc'))
t.check("decode: bad literal raises", not pcall(json.decode, "tru"))
