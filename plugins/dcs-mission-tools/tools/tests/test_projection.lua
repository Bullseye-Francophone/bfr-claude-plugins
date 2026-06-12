local t = require("helpers")
local projection = require("lib.projection")

local CASES = {
  { "caucasus", -291014, 617414, 42.18654874, 41.67893429 },
  { "caucasus", 0, 0, 45.12949706, 34.26551519 },
  { "syria", 50000, -120000, 35.43077102, 34.56390494 },
  { "persiangulf", -100000, 200000, 25.26563769, 58.23384439 },
  { "marianaislands", 10000, 20000, 13.57691968, 144.98145132 },
}

for _, case in ipairs(CASES) do
  local theatre, x, y, expectedLat, expectedLon = table.unpack(case)
  local lat, lon = projection.xyToLatLon(theatre, x, y)
  t.check("projection: " .. theatre .. " lat", math.abs(lat - expectedLat) < 5e-6,
    string.format("got %.8f expected %.8f", lat, expectedLat))
  t.check("projection: " .. theatre .. " lon", math.abs(lon - expectedLon) < 5e-6,
    string.format("got %.8f expected %.8f", lon, expectedLon))

  local backX, backY = projection.latLonToXy(theatre, lat, lon)
  t.check("projection: " .. theatre .. " roundtrip x", math.abs(backX - x) < 0.5,
    string.format("got %.3f expected %d", backX, x))
  t.check("projection: " .. theatre .. " roundtrip y", math.abs(backY - y) < 0.5,
    string.format("got %.3f expected %d", backY, y))
end

local lat, err = projection.xyToLatLon("nevada", 0, 0)
t.eq("projection: unsupported theatre returns nil", lat, nil)
t.contains("projection: error names the theatre", err, "nevada")
t.check("projection: theatre case-insensitive",
  (projection.xyToLatLon("Caucasus", 0, 0)) ~= nil)
