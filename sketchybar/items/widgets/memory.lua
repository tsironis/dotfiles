local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Memory usage widget. Polled (no C event provider): `memory_pressure` reports the
-- system-wide free percentage, so used% = 100 - free%. Mirrors the cpu graph widget.
local mem = sbar.add("graph", "widgets.memory", 42, {
	position = "right",
	graph = { color = colors.green },
	background = {
		height = 22,
		color = { alpha = 0 },
		border_color = { alpha = 0 },
		drawing = true,
	},
	icon = { string = icons.memory },
	label = {
		string = "mem ??%",
		font = {
			family = settings.font.numbers,
			style = settings.font.style_map["Bold"],
			size = 9.0,
		},
		align = "right",
		padding_right = 0,
		width = 0,
		y_offset = 4,
	},
	update_freq = 5,
	padding_right = settings.paddings + 6,
})

mem:subscribe({ "routine", "system_woke" }, function()
	sbar.exec("memory_pressure | awk -F': ' '/free percentage/ {gsub(/%/, \"\", $2); print $2}'", function(free)
		local free_pct = tonumber(free)
		if not free_pct then
			return
		end
		local used = 100 - free_pct
		mem:push({ used / 100. })

		local color = colors.green
		if used > 60 then
			if used < 75 then
				color = colors.yellow
			elseif used < 90 then
				color = colors.orange
			else
				color = colors.red
			end
		end

		mem:set({
			graph = { color = color },
			label = "mem " .. used .. "%",
		})
	end)
end)

mem:subscribe("mouse.clicked", function(env)
	sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the memory item
sbar.add("bracket", "widgets.memory.bracket", { mem.name }, {
	background = { color = colors.bg1 },
})

-- Spacing after the memory item
sbar.add("item", "widgets.memory.padding", {
	position = "right",
	width = settings.group_paddings,
})
