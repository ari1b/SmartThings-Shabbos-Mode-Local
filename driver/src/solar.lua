-- NOAA/Meeus solar-position equations. Angles use degrees except math calls.
-- Longitude: east positive, west negative. Standard apparent sunset = 90d50'.
local M = {}
local rad, deg = math.rad, math.deg
local function sin(x) return math.sin(rad(x)) end
local function cos(x) return math.cos(rad(x)) end

local function solar_terms(jd)
  local t = (jd - 2451545.0) / 36525
  local l = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360
  local m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
  local e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
  local center = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
    + sin(2 * m) * (0.019993 - 0.000101 * t) + sin(3 * m) * 0.000289
  local omega = 125.04 - 1934.136 * t
  local apparent = l + center - 0.00569 - 0.00478 * sin(omega)
  local obliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
  obliquity = obliquity + 0.00256 * cos(omega)
  local declination = deg(math.asin(sin(obliquity) * sin(apparent)))
  local y = math.tan(rad(obliquity / 2)) ^ 2
  local eq = 4 * deg(y * sin(2 * l) - 2 * e * sin(m)
    + 4 * e * y * sin(m) * cos(2 * l) - 0.5 * y * y * sin(4 * l)
    - 1.25 * e * e * sin(2 * m))
  return eq, declination
end

function M.sunset(ordinal, latitude, longitude, elevation)
  local jd = ordinal + 1721424.5
  local zenith = 90 + 50 / 60
  if elevation > 0 then
    zenith = zenith + deg(math.acos(6356.9 / (6356.9 + elevation / 1000)))
  end
  local minutes = 720 - 4 * longitude
  for _ = 1, 5 do
    local eq, declination = solar_terms(jd + minutes / 1440)
    local c = (cos(zenith) - sin(latitude) * sin(declination))
      / (cos(latitude) * cos(declination))
    if c < -1 or c > 1 then return nil, "No ordinary sunset for this date/location" end
    minutes = 720 - 4 * longitude + 4 * deg(math.acos(c)) - eq
  end
  -- Do not reduce modulo 1440: sunset can be on a different UTC date.
  return (ordinal - 719163) * 86400 + minutes * 60
end

return M
