-- Gregorian ordinals: 1 = 0001-01-01. Hebrew months: Nisan=1, Tishrei=7.
-- Arithmetic Hebrew calendar; no network, timezone database, or native modules.
local M = {}
local floor = math.floor
local year_cache = {}

function M.gregorian_ordinal(y, m, d)
  local a = floor((14 - m) / 12)
  local yy, mm = y + 4800 - a, m + 12 * a - 3
  local jdn = d + floor((153 * mm + 2) / 5) + 365 * yy
    + floor(yy / 4) - floor(yy / 100) + floor(yy / 400) - 32045
  return jdn - 1721425
end

function M.gregorian_from_ordinal(n)
  local a = n + 1721425 + 32044
  local b = floor((4 * a + 3) / 146097)
  local c = a - floor(146097 * b / 4)
  local d = floor((4 * c + 3) / 1461)
  local e = c - floor(1461 * d / 4)
  local m = floor((5 * e + 2) / 153)
  return 100 * b + d - 4800 + floor(m / 10),
    m + 3 - 12 * floor(m / 10), e - floor((153 * m + 2) / 5) + 1
end

function M.hebrew_leap(y) return (7 * y + 1) % 19 < 7 end

local function delay1(y)
  local months = floor((235 * y - 234) / 19)
  local parts = 12084 + 13753 * months
  local day = months * 29 + floor(parts / 25920)
  if (3 * (day + 1)) % 7 < 3 then day = day + 1 end
  return day
end

function M.new_year(y)
  if year_cache[y] then return year_cache[y] end
  local prev, now, after = delay1(y - 1), delay1(y), delay1(y + 1)
  local correction = 0
  if after - now == 356 then correction = 2
  elseif now - prev == 382 then correction = 1 end
  local value = -1373427 + now + correction
  year_cache[y] = value
  return value
end

function M.hebrew_month_days(y, m)
  if m == 2 or m == 4 or m == 6 or m == 10 or m == 13 then return 29 end
  if m == 12 and not M.hebrew_leap(y) then return 29 end
  local length = M.new_year(y + 1) - M.new_year(y)
  if m == 8 and length % 10 ~= 5 then return 29 end
  if m == 9 and length % 10 == 3 then return 29 end
  return 30
end

function M.hebrew_from_ordinal(n)
  local y = floor((n + 1373427) / 365.2468) + 1
  while n < M.new_year(y) do y = y - 1 end
  while n >= M.new_year(y + 1) do y = y + 1 end
  local remaining, m = n - M.new_year(y), 7
  while remaining >= M.hebrew_month_days(y, m) do
    remaining = remaining - M.hebrew_month_days(y, m)
    m = m + 1
    if m > (M.hebrew_leap(y) and 13 or 12) then m = 1 end
  end
  return y, m, remaining + 1
end

-- A holy DAY's preceding evening is handled by schedule.lua.
function M.holy_day(n, israel, include_yomtov)
  if n % 7 == 6 then return true, "Shabbos" end
  if not include_yomtov then return false, "Weekday" end
  local _, m, d = M.hebrew_from_ordinal(n)
  if m == 7 then
    if d == 1 or d == 2 then return true, "Rosh Hashanah" end
    if d == 10 then return true, "Yom Kippur" end
    if d == 15 or (d == 16 and not israel) then return true, "Sukkos" end
    if d == 22 or (d == 23 and not israel) then return true, "Shemini Atzeres / Simchas Torah" end
  elseif m == 1 then
    if d == 15 or d == 21 or (not israel and (d == 16 or d == 22)) then
      return true, "Pesach"
    end
  elseif m == 3 and (d == 6 or (d == 7 and not israel)) then
    return true, "Shavuos"
  end
  return false, "Weekday"
end

M.UNIX_ORDINAL = M.gregorian_ordinal(1970, 1, 1)
return M
