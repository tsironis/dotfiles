local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Bluetooth device battery widget.
--   * AirPods / standard devices: macOS reports these via `system_profiler`.
--   * BLE devices macOS hides (e.g. the ZMK "Cherry Plum" keyboard): read over
--     GATT 0x180F by the compiled CoreBluetooth helper (helpers/bluetooth_battery).
-- Headline shows the lowest battery among connected devices; popup lists each.

local HELPER = "$CONFIG_DIR/helpers/bluetooth_battery/bin/bluetooth_battery"
-- Emit "Name=pct" lines for connected AirPods/standard devices via system_profiler.
local SYSPROFILE = [[system_profiler SPBluetoothDataType -json 2>/dev/null | python3 -c '
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

local MAX_ROWS = 6

local bt = sbar.add("item", "widgets.bluetooth", {
	position = "right",
	icon = {
		string = icons.bluetooth,
		font = { style = settings.font.style_map["Regular"], size = 16.0 },
	},
	label = { font = { family = settings.font.numbers } },
	update_freq = 300,
	popup = { align = "center" },
	drawing = false,
})

-- Preallocated popup rows (filled/hidden on each refresh).
local rows = {}
for i = 1, MAX_ROWS do
	rows[i] = sbar.add("item", "widgets.bluetooth.row." .. i, {
		position = "popup." .. bt.name,
		drawing = false,
		icon = { string = icons.bluetooth, padding_left = 8, width = 24, align = "left" },
		label = { string = "", width = 130, align = "right", padding_right = 8 },
	})
end

local function icon_for(name)
	local n = name:lower()
	if n:find("airpod") or n:find("headphone") or n:find("buds") then
		return icons.headphones
	elseif n:find("key") or n:find("plum") or n:find("board") then
		return icons.keyboard
	end
	return icons.bluetooth
end

local function color_for(pct)
	if pct <= 20 then
		return colors.red
	elseif pct <= 40 then
		return colors.yellow
	end
	return colors.green
end

local function render(devices)
	-- devices: array of { name = string, pct = number }
	if #devices == 0 then
		bt:set({ drawing = false })
		return
	end

	local lowest = 100
	for _, d in ipairs(devices) do
		if d.pct < lowest then lowest = d.pct end
	end

	bt:set({
		drawing = true,
		label = { string = lowest .. "%" },
		icon = { color = color_for(lowest) },
	})

	for i = 1, MAX_ROWS do
		local d = devices[i]
		if d then
			rows[i]:set({
				drawing = true,
				icon = { string = icon_for(d.name) },
				label = { string = d.name .. "  " .. d.pct .. "%", color = color_for(d.pct) },
			})
		else
			rows[i]:set({ drawing = false })
		end
	end
end

local function refresh()
	-- Collect from the BLE helper first, then merge AirPods/standard devices.
	sbar.exec(HELPER, function(bleOut)
		local devices = {}
		for line in (bleOut or ""):gmatch("[^\r\n]+") do
			local name, pct = line:match("^(.-)=(%d+)$")
			if name and pct then
				devices[#devices + 1] = { name = name, pct = tonumber(pct) }
			end
		end
		sbar.exec(SYSPROFILE, function(spOut)
			for line in (spOut or ""):gmatch("[^\r\n]+") do
				local name, pct = line:match("^(.-)=(%d+)$")
				if name and pct then
					devices[#devices + 1] = { name = name, pct = tonumber(pct) }
				end
			end
			render(devices)
		end)
	end)
end

bt:subscribe({ "routine", "system_woke", "forced" }, function()
	refresh()
end)

bt:subscribe("mouse.clicked", function()
	bt:set({ popup = { drawing = "toggle" } })
end)

bt:subscribe("mouse.exited", function()
	bt:set({ popup = { drawing = false } })
end)

-- Background + spacing to match the other widgets.
sbar.add("bracket", "widgets.bluetooth.bracket", { bt.name }, {
	background = { color = colors.bg1 },
})

sbar.add("item", "widgets.bluetooth.padding", {
	position = "right",
	width = settings.group_paddings,
})
