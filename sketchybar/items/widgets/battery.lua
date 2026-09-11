local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Bluetooth device battery sources, shown in this widget's popup:
--   * AirPods / standard devices via system_profiler
--   * BLE devices macOS hides (e.g. the ZMK "Cherry Plum") via the compiled
--     CoreBluetooth helper that reads GATT 0x180F.
local BT_HELPER = "$CONFIG_DIR/helpers/bluetooth_battery/bin/bluetooth_battery"
local BT_SYSPROFILE = [[system_profiler SPBluetoothDataType -json 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
def levels(dev):
    out = []
    for k in ("device_batteryLevelMain","device_batteryLevelLeft","device_batteryLevelRight","device_batteryLevelCase"):
        v = dev.get(k)
        if v:
            try: out.append(int(str(v).strip().rstrip("%")))
            except: pass
    return out
for root in d.get("SPBluetoothDataType", []):
    for conn in root.get("device_connected", []):
        for name, dev in conn.items():
            ls = levels(dev)
            if ls: print("%s=%d" % (name, min(ls)))
']]
-- A split keyboard reports one row per half ("Cherry Plum R" / "Cherry Plum L"),
-- so one device can occupy two rows.
local MAX_BT_ROWS = 6
local BT_LOW = 20  -- a connected device at/below this % flags the bar indicator
-- The trackball half of the keyboard drains a full charge in about a week, and
-- letting it reach 0% is not merely inconvenient: macOS reacts to a BLE HID at
-- 0% by polling its battery characteristic ~33 times a second, which saturates
-- the connection and makes the keyboard appear to freeze. Warn earlier for
-- keyboards so there is time to charge.
local BT_LOW_KEYBOARD = 30

-- Last known readings, so a helper timeout blanks nothing. The helper takes a
-- few seconds and only runs every update_freq, so without this a single missed
-- read makes rows disappear and reappear.
local BT_STATE_FILE = os.getenv("HOME") .. "/.cache/sketchybar/bt_battery"
local BT_STATE_STALE = 24 * 60 * 60  -- forget a device unseen for this long

local battery = sbar.add("item", "widgets.battery", {
  position = "right",
  icon = {
    font = {
      style = settings.font.style_map["Regular"],
      size = 19.0,
    }
  },
  label = { font = { family = settings.font.numbers } },
  update_freq = 180,
  popup = { align = "center" }
})

local remaining_time = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = "Time remaining:",
    width = 100,
    align = "left"
  },
  label = {
    string = "??:??h",
    width = 100,
    align = "right"
  },
})

-- Preallocated popup rows for Bluetooth devices (filled/hidden each refresh).
local bt_rows = {}
for i = 1, MAX_BT_ROWS do
  bt_rows[i] = sbar.add("item", "widgets.battery.bt." .. i, {
    position = "popup." .. battery.name,
    drawing = false,
    icon = { string = icons.bluetooth, width = 130, align = "left", padding_left = 4 },
    label = { string = "", width = 70, align = "right", padding_right = 4 },
  })
end

-- Bar indicators (left of the battery icon): one red device glyph per low
-- device, shown side by side, so a device needing a charge is visible at a
-- glance (keyboard for the keyboard, headphones for AirPods, etc.).
local bt_indicators = {}
for i = 1, MAX_BT_ROWS do
  bt_indicators[i] = sbar.add("item", "widgets.battery.bt_low." .. i, {
    position = "right",
    drawing = false,
    icon = {
      string = icons.bluetooth,
      color = colors.red,
      font = { style = settings.font.style_map["Regular"], size = 14.0 },
      padding_left = 1,
      padding_right = 1,
    },
    label = { drawing = false },
  })
end

local function bt_icon_for(name)
  local n = name:lower()
  if n:find("airpod") or n:find("headphone") or n:find("buds") then
    return icons.headphones
  elseif n:find("key") or n:find("plum") or n:find("board") then
    return icons.keyboard
  end
  return icons.bluetooth
end

local function bt_color_for(pct)
  if pct <= 20 then
    return colors.red
  elseif pct <= 40 then
    return colors.yellow
  end
  return colors.green
end

local function bt_low_for(name)
  if bt_icon_for(name) == icons.keyboard then
    return BT_LOW_KEYBOARD
  end
  return BT_LOW
end

-- "Cherry Plum R" and "Cherry Plum L" are two halves of one physical device, so
-- they share a bar indicator driven by whichever half is worse.
local function bt_base_name(name)
  return name:match("^(.-)%s+[RL]$")
      or name:match("^(.-)%s+main$")
      or name:match("^(.-)%s+aux$")
      or name
end

local function bt_state_load()
  local f = io.open(BT_STATE_FILE, "r")
  if not f then return {} end
  local now, out = os.time(), {}
  for line in f:lines() do
    local name, pct, seen = line:match("^(.-)=(%d+)=(%d+)$")
    if name and now - tonumber(seen) <= BT_STATE_STALE then
      out[#out + 1] = { name = name, pct = tonumber(pct), seen = tonumber(seen) }
    end
  end
  f:close()
  return out
end

local function bt_state_save(devices)
  os.execute("mkdir -p " .. BT_STATE_FILE:match("^(.*)/[^/]*$"))
  local f = io.open(BT_STATE_FILE, "w")
  if not f then return end
  for _, d in ipairs(devices) do
    f:write(("%s=%d=%d\n"):format(d.name, d.pct, d.seen))
  end
  f:close()
end

local function bt_parse(out)
  local devices = {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    local name, pct = line:match("^(.-)=(%d+)$")
    if name and pct then
      devices[#devices + 1] = { name = name, pct = tonumber(pct) }
    end
  end
  return devices
end

-- Overlay this run's readings onto the persisted ones, keeping row order stable
-- and carrying forward anything the helper failed to read this time.
local function bt_merge(persisted, fresh)
  local now, merged, index = os.time(), {}, {}
  for _, d in ipairs(persisted) do
    merged[#merged + 1] = { name = d.name, pct = d.pct, seen = d.seen }
    index[d.name] = #merged
  end
  for _, d in ipairs(fresh) do
    local at = index[d.name]
    if at then
      merged[at].pct, merged[at].seen = d.pct, now
    else
      merged[#merged + 1] = { name = d.name, pct = d.pct, seen = now }
      index[d.name] = #merged
    end
  end
  return merged
end

local function refresh_bluetooth()
  sbar.exec(BT_HELPER, function(bleOut)
    -- Only the BLE helper's readings are persisted; system_profiler is cheap
    -- and always available, so its devices are read fresh each time.
    local devices = bt_merge(bt_state_load(), bt_parse(bleOut))
    bt_state_save(devices)

    sbar.exec(BT_SYSPROFILE, function(spOut)
      -- A device can show up in both sources: the MX Vertical exposes GATT
      -- 0x180F to the helper and is also surfaced by system_profiler. Prefer
      -- the helper's direct read, which is the one that resolves split halves.
      local seen = {}
      for _, d in ipairs(devices) do seen[bt_base_name(d.name)] = true end
      for _, d in ipairs(bt_parse(spOut)) do
        local base = bt_base_name(d.name)
        if not seen[base] then
          devices[#devices + 1] = d
          seen[base] = true
        end
      end

      -- Collapse the halves of a split device to its worst reading, so one
      -- physical device raises at most one indicator and a flat half is never
      -- hidden behind a healthy one.
      local low, low_index = {}, {}
      for _, d in ipairs(devices) do
        if d.pct <= bt_low_for(d.name) then
          local base = bt_base_name(d.name)
          local at = low_index[base]
          if at then
            if d.pct < low[at].pct then low[at].pct = d.pct end
          else
            low[#low + 1] = { name = base, pct = d.pct }
            low_index[base] = #low
          end
        end
      end

      for i = 1, MAX_BT_ROWS do
        local d = devices[i]
        if d then
          bt_rows[i]:set({
            drawing = true,
            icon = { string = bt_icon_for(d.name) .. " " .. d.name },
            label = { string = d.pct .. "%", color = bt_color_for(d.pct) },
          })
        else
          bt_rows[i]:set({ drawing = false })
        end
      end

      -- One red indicator per low device (keyboard / headphones), side by side.
      for i = 1, MAX_BT_ROWS do
        local d = low[i]
        if d then
          bt_indicators[i]:set({ drawing = true, icon = { string = bt_icon_for(d.name), color = colors.red } })
        else
          bt_indicators[i]:set({ drawing = false })
        end
      end
    end)
  end)
end

battery:subscribe({"routine", "power_source_change", "system_woke"}, function()
  sbar.exec("pmset -g batt", function(batt_info)
    local icon = "!"
    local label = "?"

    local found, _, charge = batt_info:find("(%d+)%%")
    if found then
      charge = tonumber(charge)
      label = charge .. "%"
    end

    local color = colors.green
    local charging, _, _ = batt_info:find("AC Power")

    if charging then
      icon = icons.battery.charging
    else
      if found and charge > 80 then
        icon = icons.battery._100
      elseif found and charge > 60 then
        icon = icons.battery._75
      elseif found and charge > 40 then
        icon = icons.battery._50
      elseif found and charge > 20 then
        icon = icons.battery._25
        color = colors.orange
      else
        icon = icons.battery._0
        color = colors.red
      end
    end

    local lead = ""
    if found and charge < 10 then
      lead = "0"
    end

    battery:set({
      icon = {
        string = icon,
        color = color
      },
      label = { string = lead .. label },
    })
  end)

  refresh_bluetooth()
end)

battery:subscribe("mouse.clicked", function(env)
  local drawing = battery:query().popup.drawing
  battery:set( { popup = { drawing = "toggle" } })

  if drawing == "off" then
    sbar.exec("pmset -g batt", function(batt_info)
      local found, _, remaining = batt_info:find(" (%d+:%d+) remaining")
      local label = found and remaining .. "h" or "No estimate"
      remaining_time:set( { label = label })
    end)
    refresh_bluetooth()
  end
end)

local bracket_items = { battery.name }
for i = 1, MAX_BT_ROWS do
  bracket_items[#bracket_items + 1] = bt_indicators[i].name
end
sbar.add("bracket", "widgets.battery.bracket", bracket_items, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.battery.padding", {
  position = "right",
  width = settings.group_paddings
})
