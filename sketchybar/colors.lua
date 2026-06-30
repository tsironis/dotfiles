return {
	-- Tango Dark palette (matches Ghostty's Builtin Tango Dark)
	black = 0xff000000,
	white = 0xffeeeeec,
	red = 0xffef2929,
	green = 0xff8ae234,
	blue = 0xff729fcf,
	yellow = 0xfffce94f,
	orange = 0xfff57900,
	magenta = 0xffad7fa8,
	grey = 0xff888a85,
	dirty_white = 0xffeeeeec,
	transparent = 0x00000000,

	bar = {
		bg = 0x00000000,
		border = 0xff2e3436,
	},
	popup = {
		bg = 0xe0000000,
		border = 0xff888a85,
	},
	bg1 = 0xff2e3436, -- tab border
	bg2 = 0xff555753, -- tab fill (visible on the transparent/black bar)

	with_alpha = function(color, alpha)
		if alpha > 1.0 or alpha < 0.0 then
			return color
		end
		return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
	end,
}
