local icons = require("icons")
local colors = require("colors")

local media_cover = sbar.add("item", {
	position = "right",
	background = {
		image = {
			string = "media.artwork",
		},
		color = colors.transparent,
	},
	label = { drawing = false },
	icon = { drawing = false },
	drawing = false,
	updates = true,
	popup = {
		align = "center",
		horizontal = true,
	},
})

local media_artist = sbar.add("item", {
	position = "right",
	drawing = false,
	padding_left = 3,
	padding_right = 0,
	width = 0,
	icon = { drawing = false },
	label = {
		width = "dynamic",
		font = { size = 9 },
		color = colors.with_alpha(colors.white, 0.6),
		max_chars = 38,
		y_offset = 6,
	},
})

local media_title = sbar.add("item", {
	position = "right",
	drawing = false,
	padding_left = 3,
	padding_right = 0,
	icon = { drawing = false },
	label = {
		font = { size = 11 },
		width = "dynamic",
		max_chars = 36,
		y_offset = -5,
	},
})

sbar.add("item", {
	position = "popup." .. media_cover.name,
	icon = { string = icons.media.back },
	label = { drawing = false },
	click_script = "nowplaying-cli previous",
})
sbar.add("item", {
	position = "popup." .. media_cover.name,
	icon = { string = icons.media.play_pause },
	label = { drawing = false },
	click_script = "nowplaying-cli togglePlayPause",
})
sbar.add("item", {
	position = "popup." .. media_cover.name,
	icon = { string = icons.media.forward },
	label = { drawing = false },
	click_script = "nowplaying-cli next",
})

media_cover:subscribe("media_change", function(env)
	-- Generic: show whatever app is reporting via MediaRemote, as long as it's
	-- actively playing and has a title (covers browsers, VLC, YouTube Music, etc.).
	local has_title = env.INFO.title ~= nil and env.INFO.title ~= ""
	local drawing = (env.INFO.state == "playing") and has_title
	media_artist:set({ drawing = drawing, label = env.INFO.artist or "" })
	media_title:set({ drawing = drawing, label = env.INFO.title or "" })
	media_cover:set({ drawing = drawing })
end)

media_cover:subscribe("mouse.clicked", function(env)
	media_cover:set({ popup = { drawing = "toggle" } })
end)

media_title:subscribe("mouse.exited.global", function(env)
	media_cover:set({ popup = { drawing = false } })
end)
