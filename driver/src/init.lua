local Driver = require "st.driver"
local capabilities = require "st.capabilities"
local log = require "log"
local schedule = require "schedule"

local PROFILE = "shabbos-mode-local.v1"
local DNI = "shabbos-mode-local-v1"
local MANUAL_SECONDS = 300
local reconcile

local function utc(timestamp)
  return os.date("!%Y-%m-%d %H:%M:%S UTC", timestamp)
end

local function emit_state(device, state)
  local previous = device:get_latest_state("main", capabilities.switch.ID,
    capabilities.switch.switch.NAME)
  if previous ~= state then
    device:emit_event(capabilities.switch.switch(state))
    log.info("Shabbos Mode output: " .. state:upper())
  end
end

local function clear_manual(device)
  if device:get_field("manual") then device:set_field("manual", nil, { persist = true }) end
end

local function cancel_wake(device)
  local timer = device:get_field("wake_timer")
  if timer then
    device.thread:cancel_timer(timer)
    device:set_field("wake_timer", nil)
  end
end

local function reschedule(driver, device, target, now)
  local existing = device:get_field("wake_at")
  if existing == target and device:get_field("wake_timer") then return end
  cancel_wake(device)
  device:set_field("wake_at", target)
  device:set_field("wake_timer", device.thread:call_with_delay(math.max(1, target - now), function()
    device:set_field("wake_timer", nil)
    device:set_field("wake_at", nil)
    reconcile(driver, device, false)
  end, "shabbos-transition"))
end

reconcile = function(driver, device, verbose)
  local ok, err = pcall(function()
    local now = os.time()
    -- Avoid acting on an obviously uninitialised hub clock.
    assert(now >= 1767225600 and now < 4102444800, "Hub clock must be between 2026 and 2099")
    local settings = schedule.settings(device.preferences)
    local expected, next_event = schedule.evaluate(now, settings)
    local manual = device:get_field("manual")
    if manual and (type(manual) ~= "table" or not manual.expires or manual.expires <= now) then
      clear_manual(device)
      manual = nil
    end

    if settings.enabled then
      emit_state(device, manual and manual.state or expected)
    elseif device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == nil then
      emit_state(device, "off")
    end

    local target = next_event.at
    if manual and settings.enabled then target = math.min(target, manual.expires) end
    -- Daily wake also limits long timers; the heartbeat handles time corrections.
    reschedule(driver, device, math.min(target, now + 86400), now)
    device:online()
    device:set_field("last_error", nil)

    local summary = string.format("auto=%s; calendar=%s; next=%s at %s; override=%s",
      tostring(settings.enabled), expected, next_event.state, utc(next_event.at),
      manual and (manual.state .. " until " .. utc(manual.expires)) or "none")
    if verbose or summary ~= device:get_field("last_summary") then
      log.info(summary)
      device:set_field("last_summary", summary)
    end
  end)
  if not ok then
    -- No guessed OFF command on configuration/astronomy errors.
    cancel_wake(device)
    device:set_field("wake_at", nil)
    if tostring(err) ~= device:get_field("last_error") then
      log.error("Schedule error; preserving output and retrying every minute: " .. tostring(err))
      device:set_field("last_error", tostring(err))
    end
    device:offline()
  end
end

local function manual_command(driver, device, command)
  local state = command.command
  if state ~= "on" and state ~= "off" then return end
  local now, expires = os.time(), os.time() + MANUAL_SECONDS
  if device.preferences.autoEnabled == true then
    local ok, _, next_event = pcall(function()
      return schedule.evaluate(now, schedule.settings(device.preferences))
    end)
    if ok then expires = math.min(expires, next_event.at) end
  end
  device:set_field("manual", { state = state, expires = expires }, { persist = true })
  emit_state(device, state)
  log.info("Manual " .. state .. "; automatic mode resumes within 5 minutes if enabled")
  reconcile(driver, device, true)
end

local function init(driver, device)
  cancel_wake(device)
  local heartbeat = device:get_field("heartbeat")
  if heartbeat then device.thread:cancel_timer(heartbeat) end
  device:set_field("heartbeat", device.thread:call_on_schedule(60, function()
    reconcile(driver, device, false)
  end, "shabbos-heartbeat"))
  reconcile(driver, device, true)
end

local function info_changed(driver, device)
  clear_manual(device)
  reconcile(driver, device, true)
end

local function refresh(driver, device)
  clear_manual(device)
  reconcile(driver, device, true)
end

local function removed(_, device)
  cancel_wake(device)
  local heartbeat = device:get_field("heartbeat")
  if heartbeat then device.thread:cancel_timer(heartbeat) end
end

local function discovery(driver)
  for _, device in pairs(driver:get_devices()) do
    if device.device_network_id == DNI then return end
  end
  if driver._creating_shabbos then return end
  driver._creating_shabbos = true
  -- Creation is asynchronous; allow another scan after a failed/abandoned attempt.
  driver:call_with_delay(30, function() driver._creating_shabbos = false end)
  driver:try_create_device({
    type = "LAN", device_network_id = DNI, label = "Shabbos Mode Local",
    profile = PROFILE, manufacturer = "Personal", model = "ShabbosLocalV1",
    vendor_provided_label = "Shabbos Mode Local",
  })
end

local driver = Driver("shabbos-mode-local", {
  discovery = discovery,
  supported_capabilities = { capabilities.switch, capabilities.refresh },
  lifecycle_handlers = { init = init, infoChanged = info_changed, removed = removed },
  capability_handlers = {
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = manual_command,
      [capabilities.switch.commands.off.NAME] = manual_command,
    },
    [capabilities.refresh.ID] = { [capabilities.refresh.commands.refresh.NAME] = refresh },
  },
})
driver:run()
