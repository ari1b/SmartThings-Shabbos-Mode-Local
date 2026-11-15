-- Deterministic lifecycle/command tests with simulated SmartThings APIs.
-- These supplement reference tests; they are not a test on physical hub firmware.
local logs, events = {}, {}
local now = 1794592800 -- Fri 2026-11-13 18:00 UTC, before candle lighting in NJ
local real_time = os.time
os.time = function() return now end
local active_driver

package.preload["log"] = function()
  return { info = function(s) logs[#logs + 1] = s end,
    error = function(s) logs[#logs + 1] = s end }
end
local sw = { ID = "switch", commands = { on = { NAME = "on" }, off = { NAME = "off" } } }
sw.switch = setmetatable({ NAME = "switch" }, { __call = function(_, value) return { value = value } end })
local refresh_cap = { ID = "refresh", commands = { refresh = { NAME = "refresh" } } }
package.preload["st.capabilities"] = function() return { switch = sw, refresh = refresh_cap } end

local timers = {}
local thread = {}
function thread:call_with_delay(delay, callback)
  assert(delay >= 1)
  local t = { due = now + delay, callback = callback }
  timers[#timers + 1] = t
  return t
end
function thread:call_on_schedule(interval, callback)
  local t = self:call_with_delay(interval, callback)
  t.interval = interval
  return t
end
function thread:cancel_timer(t) t.cancelled = true end

local fields, persisted = {}, {}
local device = { preferences = { autoEnabled = false }, thread = thread,
  device_network_id = "shabbos-mode-local-v1" }
function device:get_field(key) return fields[key] end
function device:set_field(key, value, opts)
  fields[key] = value
  if opts and opts.persist then persisted[key] = value end
end
function device:get_latest_state() return self.state end
function device:emit_event(event)
  self.state = event.value
  events[#events + 1] = event.value
end
function device:online() self.is_online = true end
function device:offline() self.is_online = false end

package.preload["st.driver"] = function()
  return function(_, template)
    template.devices = { device }
    template.run = function(self) active_driver = self end
    template.get_devices = function(self) return self.devices end
    template.call_with_delay = function(_, ...) return thread:call_with_delay(...) end
    template.try_create_device = function(self, metadata) self.created = metadata end
    return template
  end
end

dofile("driver/src/init.lua")
local driver = assert(active_driver)
local life = driver.lifecycle_handlers
local handlers = driver.capability_handlers
local function press(state) handlers.switch[state](driver, device, { command = state }) end
local function tick(to)
  now = to
  -- Snapshot: callbacks may append replacement timers.
  local snapshot = {}
  for _, timer in ipairs(timers) do snapshot[#snapshot + 1] = timer end
  for _, timer in ipairs(snapshot) do
    if not timer.cancelled and timer.due <= now then
      if timer.interval then timer.due = now + timer.interval else timer.cancelled = true end
      timer.callback()
    end
  end
end

life.init(driver, device)
assert(device.state == "off" and device.is_online)
press("on")
assert(device.state == "on")
tick(now + 600)
assert(device.state == "on", "Disabled mode must not overwrite manual output")
device.preferences.autoEnabled = true
life.infoChanged(driver, device)
assert(device.state == "off", "Enabling must compute current calendar state")
local schedule = require "schedule"
local _, next_event = schedule.evaluate(now, schedule.settings(device.preferences))
tick(next_event.at)
assert(device.state == "on", "Natural boundary must change output")
press("off")
assert(device.state == "off" and persisted.manual)
tick(now + 299)
assert(device.state == "off")
tick(now + 1)
assert(device.state == "on" and not persisted.manual, "Manual hold must expire")
press("off")
handlers.refresh.refresh(driver, device)
assert(device.state == "on" and not persisted.manual, "Refresh must cancel override")

-- Reboot while in Shabbos: in-memory timers and fields vanish; persisted data remains.
fields, timers = {}, {}
for k, v in pairs(persisted) do fields[k] = v end
device.state = nil
life.init(driver, device)
assert(device.state == "on", "Restart must reconstruct state")

-- A manual override survives restart, then expires. Calendar wins afterwards.
press("off")
fields, timers = {}, {}
for k, v in pairs(persisted) do fields[k] = v end
life.init(driver, device)
assert(device.state == "off")
tick(now + 301)
assert(device.state == "on")

-- Invalid configuration and bad clock do not issue a guessed OFF.
device.preferences.latitude = "invalid"
life.infoChanged(driver, device)
assert(device.state == "on" and not device.is_online)
device.preferences.latitude = "40.9276"
tick(now + 61)
assert(device.state == "on" and device.is_online)
local saved = now
now = 0
handlers.refresh.refresh(driver, device)
assert(device.state == "on" and not device.is_online)
now = saved
tick(now + 61)
assert(device.is_online)

-- Skip directly past the end, simulating long outage or a corrected clock.
local _, ending = schedule.evaluate(now, schedule.settings(device.preferences))
tick(ending.at + 600)
assert(device.state == "off")

-- Existing device is not duplicated by discovery; a new installation is created.
driver.discovery(driver)
assert(not driver.created)
driver.devices = {}
driver.discovery(driver)
assert(driver.created.type == "LAN" and driver.created.profile == "shabbos-mode-local.v1")
driver.created = nil
driver.discovery(driver)
assert(not driver.created, "Overlapping discovery must not duplicate creation")
life.removed(driver, device)
for _, timer in ipairs(timers) do
  if timer.interval then assert(timer.cancelled) end
end
os.time = real_time
print("PASS: simulated startup, enable/disable, natural transition, manual expiry, refresh, reboot, error recovery, clock jumps, discovery, removal")
