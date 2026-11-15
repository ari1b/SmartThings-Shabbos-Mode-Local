local calendar = require "calendar"
local solar = require "solar"
local M = {}

local function number(p, key, default, low, high)
  local raw = p[key]
  if raw == nil then raw = default end
  local n = tonumber(raw)
  assert(n and n == n and n >= low and n <= high, "Invalid setting: " .. key)
  return n
end

function M.settings(p)
  p = p or {}
  return {
    latitude = number(p, "latitude", "40.9276", -60, 60),
    longitude = number(p, "longitude", "-73.9974", -170, 170),
    elevation = number(p, "elevationMeters", 0, 0, 3000),
    candle = number(p, "candleMinutes", 18, 0, 120),
    havdalah = number(p, "havdalahMinutes", 72, 0, 180),
    adjustment = number(p, "sunsetAdjustment", 0, -30, 30),
    israel = p.israel == true,
    include_yomtov = p.includeYomTov ~= false,
    enabled = p.autoEnabled == true,
  }
end

function M.events(now, settings)
  local day = math.floor(now / 86400) + calendar.UNIX_ORDINAL
  local events = {}
  -- More than the longest possible continuous Shabbos/Yom Tov block.
  for n = day - 10, day + 16 do
    local today = calendar.holy_day(n, settings.israel, settings.include_yomtov)
    local tomorrow = calendar.holy_day(n + 1, settings.israel, settings.include_yomtov)
    if today ~= tomorrow then
      local sunset, err = solar.sunset(n, settings.latitude, settings.longitude, settings.elevation)
      assert(sunset, err)
      local on = tomorrow
      local timestamp = sunset + settings.adjustment * 60
        + (on and -settings.candle * 60 or settings.havdalah * 60)
      local y, m, d = calendar.gregorian_from_ordinal(n)
      events[#events + 1] = {
        at = math.floor(timestamp + 0.5), state = on and "on" or "off",
        date = string.format("%04d-%02d-%02d", y, m, d),
      }
    end
  end
  table.sort(events, function(a, b) return a.at < b.at end)
  return events
end

function M.evaluate(now, settings)
  local state, next_event
  for _, event in ipairs(M.events(now, settings)) do
    if event.at <= now then state = event.state
    elseif not next_event then next_event = event end
  end
  assert(state and next_event, "Could not resolve current/next transition")
  return state, next_event
end

return M
