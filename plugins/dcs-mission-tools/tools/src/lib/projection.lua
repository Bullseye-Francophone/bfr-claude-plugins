local M = {}

local A = 6378137.0
local F = 1 / 298.257223563
local K0 = 0.9996
local E2 = F * (2 - F)
local EP2 = E2 / (1 - E2)
local E4, E6 = E2 * E2, E2 * E2 * E2

local THEATRES = {
  caucasus = { lon0 = 33, x0 = -99516.9999999732, y0 = -4998114.999999984 },
  syria = { lon0 = 39, x0 = 282801.00000003993, y0 = -3879865.9999999935 },
  persiangulf = { lon0 = 57, x0 = 75755.99999999645, y0 = -2894933.0000000377 },
  marianaislands = { lon0 = 147, x0 = 238417.99999989968, y0 = -1491840.000000048 },
}

local rad, deg = math.rad, math.deg

local function meridionalArc(phi)
  return A * ((1 - E2 / 4 - 3 * E4 / 64 - 5 * E6 / 256) * phi
    - (3 * E2 / 8 + 3 * E4 / 32 + 45 * E6 / 1024) * math.sin(2 * phi)
    + (15 * E4 / 256 + 45 * E6 / 1024) * math.sin(4 * phi)
    - (35 * E6 / 3072) * math.sin(6 * phi))
end

local function theatreParams(theatre)
  local params = THEATRES[tostring(theatre):lower()]
  if not params then
    return nil, "unsupported theatre '" .. tostring(theatre) ..
      "' (supported: caucasus, syria, persiangulf, marianaislands)"
  end
  return params
end

local function tmercForward(phi, dlambda)
  local sinPhi, cosPhi = math.sin(phi), math.cos(phi)
  local n = A / math.sqrt(1 - E2 * sinPhi ^ 2)
  local t = math.tan(phi) ^ 2
  local c = EP2 * cosPhi ^ 2
  local aCoef = dlambda * cosPhi
  local easting = K0 * n * (aCoef + (1 - t + c) * aCoef ^ 3 / 6
    + (5 - 18 * t + t ^ 2 + 72 * c - 58 * EP2) * aCoef ^ 5 / 120)
  local northing = K0 * (meridionalArc(phi) + n * math.tan(phi) * (aCoef ^ 2 / 2
    + (5 - t + 9 * c + 4 * c ^ 2) * aCoef ^ 4 / 24
    + (61 - 58 * t + t ^ 2 + 600 * c - 330 * EP2) * aCoef ^ 6 / 720))
  return northing, easting
end

local function tmercInverse(northing, easting, lon0)
  local meridian = northing / K0
  local mu = meridian / (A * (1 - E2 / 4 - 3 * E4 / 64 - 5 * E6 / 256))
  local e1 = (1 - math.sqrt(1 - E2)) / (1 + math.sqrt(1 - E2))

  local phi1 = mu
    + (3 * e1 / 2 - 27 * e1 ^ 3 / 32) * math.sin(2 * mu)
    + (21 * e1 ^ 2 / 16 - 55 * e1 ^ 4 / 32) * math.sin(4 * mu)
    + (151 * e1 ^ 3 / 96) * math.sin(6 * mu)
    + (1097 * e1 ^ 4 / 512) * math.sin(8 * mu)

  local sinPhi1, cosPhi1 = math.sin(phi1), math.cos(phi1)
  local c1 = EP2 * cosPhi1 ^ 2
  local t1 = math.tan(phi1) ^ 2
  local n1 = A / math.sqrt(1 - E2 * sinPhi1 ^ 2)
  local r1 = A * (1 - E2) / (1 - E2 * sinPhi1 ^ 2) ^ 1.5
  local d = easting / (n1 * K0)

  local phi0 = phi1 - (n1 * math.tan(phi1) / r1) * (d ^ 2 / 2
    - (5 + 3 * t1 + 10 * c1 - 4 * c1 ^ 2 - 9 * EP2) * d ^ 4 / 24
    + (61 + 90 * t1 + 298 * c1 + 45 * t1 ^ 2 - 252 * EP2 - 3 * c1 ^ 2) * d ^ 6 / 720)
  local dlambda0 = (d - (1 + 2 * t1 + c1) * d ^ 3 / 6
    + (5 - 2 * c1 + 28 * t1 - 3 * c1 ^ 2 + 8 * EP2 + 24 * t1 ^ 2) * d ^ 5 / 120) / cosPhi1

  for _ = 1, 10 do
    local n0, e0 = tmercForward(phi0, dlambda0)
    local sinP, cosP = math.sin(phi0), math.cos(phi0)
    local nv = A / math.sqrt(1 - E2 * sinP ^ 2)
    local rv = A * (1 - E2) / (1 - E2 * sinP ^ 2) ^ 1.5
    local dphi = (northing - n0) / (rv * K0)
    local ddlambda = (easting - e0) / (nv * cosP * K0)
    phi0 = phi0 + dphi
    dlambda0 = dlambda0 + ddlambda
    if math.abs(dphi) < 1e-13 and math.abs(ddlambda) < 1e-13 then break end
  end

  return deg(phi0), lon0 + deg(dlambda0)
end

function M.xyToLatLon(theatre, x, y)
  local params, err = theatreParams(theatre)
  if not params then return nil, err end
  return tmercInverse(x - params.y0, y - params.x0, params.lon0)
end

function M.latLonToXy(theatre, lat, lon)
  local params, err = theatreParams(theatre)
  if not params then return nil, err end
  local northing, easting = tmercForward(rad(lat), rad(lon - params.lon0))
  return northing + params.y0, easting + params.x0
end

return M
