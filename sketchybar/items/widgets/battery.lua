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
local MAX_BT_ROWS = 5

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

local function refresh_bluetooth()
  sbar.exec(BT_HELPER, function(bleOut)
    local devices = {}
    for line in (bleOut or ""):gmatch("[^\r\n]+") do
      local name, pct = line:match("^(.-)=(%d+)$")
      if name and pct then
        devices[#devices + 1] = { name = name, pct = tonumber(pct) }
      end
    end
    sbar.exec(BT_SYSPROFILE, function(spOut)
      for line in (spOut or ""):gmatch("[^\r\n]+") do
        local name, pct = line:match("^(.-)=(%d+)$")
        if name and pct then
          devices[#devices + 1] = { name = name, pct = tonumber(pct) }
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

sbar.add("bracket", "widgets.battery.bracket", { battery.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.battery.padding", {
  position = "right",
  width = settings.group_paddings
})
