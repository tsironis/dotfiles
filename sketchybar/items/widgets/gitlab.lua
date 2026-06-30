local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- GitLab activity widget: count of pending GitLab todos (review requests,
-- assignments, mentions, unmergeable MRs) from gitlab.grnet.gr via glab, listed
-- in a popup. Hidden when there are none. Absolute glab path (sketchybar's PATH
-- lacks Homebrew); updates=true so the hidden item still gets "routine" events.
local MAX_ROWS = 8

-- One call: -i for the accurate X-Total header, then python prints
-- "TOTAL=<n>" followed by one tab-separated line per todo:
--   <target_type> \t <reference> \t <title> \t <url>
local FETCH = [[/opt/homebrew/bin/glab api "todos?state=pending&per_page=8" -i 2>/dev/null | python3 -c '
import sys, json, re
raw = sys.stdin.read()
m = re.search(r"(?im)^x-total:\s*(\d+)", raw)
parts = re.split(r"\r?\n\r?\n", raw, maxsplit=1)
body = parts[1] if len(parts) > 1 else raw
try:
    todos = json.loads(body)
except Exception:
    todos = []
total = m.group(1) if m else str(len(todos))
print("TOTAL=" + total)
for t in todos:
    tg = t.get("target") or {}
    ty = t.get("target_type", "")
    ref = tg.get("reference") or ""
    title = (tg.get("title") or t.get("body") or "").strip()
    if len(title) > 46:
        title = title[:45].rstrip() + "…"
    url = t.get("target_url", "")
    print(ty + "\t" + ref + "\t" + title + "\t" + url)
']]

local gitlab = sbar.add("item", "widgets.gitlab", {
  position = "right",
  drawing = false,
  updates = true,
  update_freq = 180,
  icon = {
    string = icons.gitlab,
    color = colors.yellow,
    -- keep the Nerd Font family, otherwise the (Nerd-only) glyph won't render
    font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 15.0 },
  },
  label = {
    font = { family = settings.font.numbers },
    color = colors.yellow,
  },
  popup = { align = "center" },
})

-- Preallocated popup rows (filled/hidden each refresh).
local rows = {}
for i = 1, MAX_ROWS do
  rows[i] = sbar.add("item", "widgets.gitlab.row." .. i, {
    position = "popup." .. gitlab.name,
    drawing = false,
    icon = {
      string = icons.merge_request,
      color = colors.grey,
      font = { family = settings.font.text, style = settings.font.style_map["Regular"], size = 13.0 },
      padding_left = 10,
      padding_right = 8,
      width = 24,
      align = "left",
    },
    label = {
      string = "",
      align = "left",
      padding_right = 12,
      width = 330,
      max_chars = 60,
    },
  })
end

local function refresh()
  sbar.exec(FETCH, function(out)
    local total = 0
    local todos = {}
    for line in (out or ""):gmatch("[^\r\n]+") do
      local n = line:match("^TOTAL=(%d+)$")
      if n then
        total = tonumber(n)
      else
        local ty, ref, title, url = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
        if ty then
          todos[#todos + 1] = { ttype = ty, ref = ref, title = title, url = url }
        end
      end
    end

    if total == 0 then
      gitlab:set({ drawing = false })
      for i = 1, MAX_ROWS do rows[i]:set({ drawing = false }) end
      return
    end

    gitlab:set({ drawing = true, label = { string = tostring(total) } })
    for i = 1, MAX_ROWS do
      local t = todos[i]
      if t then
        local glyph = (t.ttype == "Issue") and icons.issue or icons.merge_request
        local text = (t.ref ~= "" and (t.ref .. "  ") or "") .. t.title
        rows[i]:set({
          drawing = true,
          icon = { string = glyph },
          label = { string = text },
          click_script = "open " .. (t.url ~= "" and ("'" .. t.url .. "'") or "''"),
        })
      else
        rows[i]:set({ drawing = false })
      end
    end
  end)
end

local function hide_popup()
  gitlab:set({ popup = { drawing = false } })
end

gitlab:subscribe({ "routine", "system_woke" }, refresh)

gitlab:subscribe("mouse.clicked", function()
  local drawing = gitlab:query().popup.drawing
  gitlab:set({ popup = { drawing = "toggle" } })
  if drawing == "off" then refresh() end
end)

gitlab:subscribe("mouse.exited.global", hide_popup)

-- Background + spacing to match the other widgets.
sbar.add("bracket", "widgets.gitlab.bracket", { gitlab.name }, {
  background = { color = colors.bg1 },
})

sbar.add("item", "widgets.gitlab.padding", {
  position = "right",
  width = settings.group_paddings,
})

-- Populate on load (the first "routine" tick is up to update_freq away).
refresh()
