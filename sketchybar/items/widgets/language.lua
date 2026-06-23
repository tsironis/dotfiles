local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Execute the event provider binary which provides the event "network_update"
-- for the network interface "en0", which is fired every 2.0 seconds.

local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local language = sbar.add("item", "widgets.language", {
	position = "right",
	icon = {
		font = {
			style = settings.font.style_map["Regular"],
			size = 19.0,
		},
	},
	label = { font = { family = settings.font.numbers } },
	update_freq = 180,
	popup = { align = "center" },
})

sbar.exec(
	"fswatch --fire-idle-event -m poll_monitor ~/Library/Preferences/com.apple.HIToolbox.plist | while read; do sketchybar --trigger language_change; done"
)

language:subscribe({ "routine", "power_source_change", "system_woke", "language_change" }, function()
	sbar.exec("defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID", function(language_info)
		local color = colors.green

		if language_info:find("com.apple.keylayout.ABC") then
			label = "en"
		elseif language_info:find("com.apple.keylayout.Greek") then
			label = "gr"
		else
			label = "n/a"
		end

		language:set({
			label = { string = label },
		})
	end)
end)

-- language:subscribe("mouse.clicked", function(env)
--   local drawing = battery:query().popup.drawing
--   battery:set( { popup = { drawing = "toggle" } })
--
--   if drawing == "off" then
--     sbar.exec("pmset -g batt", function(batt_info)
--       local found, _, remaining = batt_info:find(" (%d+:%d+) remaining")
--       local label = found and remaining .. "h" or "No estimate"
--       remaining_time:set( { label = label })
--     end)
--   end
-- end)

sbar.add("bracket", "widgets.language.bracket", { language.name }, {
	background = { color = colors.bg1 },
})

sbar.add("item", "widgets.language.padding", {
	position = "right",
	width = settings.group_paddings,
})
