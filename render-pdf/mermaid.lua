-- Render ```mermaid code blocks into vector SVG and place them in the document.
--
-- Driven by ./render-pdf.sh, which supplies the tool paths through the environment:
--   MMDC           path to the mermaid CLI (must be docs/node_modules/.bin/mmdc; see the script)
--   PUPPETEER_CFG  puppeteer launch flags, reused from docs/plugins/mermaid-png/
--   MERMAID_CFG    mermaid runtime config; htmlLabels:false is what makes the SVG usable
--   DIAGRAM_DIR    cache directory for the rendered SVGs
--   TEXT_BLOCK_ASPECT  optional; overrides the tall-diagram cutoff for a style whose
--                      margins differ from pdf-defaults.yaml
--
-- Diagrams are keyed by a hash of their source, so an unchanged diagram is never re-rendered.
-- Same approach as docs/plugins/mermaid-png/index.ts, in SVG rather than PNG.

local MMDC = os.getenv('MMDC') or 'mmdc'
local PUPPETEER_CFG = os.getenv('PUPPETEER_CFG')
local MERMAID_CFG = os.getenv('MERMAID_CFG')
local DIAGRAM_DIR = os.getenv('DIAGRAM_DIR') or 'diagrams'

-- Diagrams taller than the A4 text block (17cm x 25.3cm at the margins in pdf-defaults.yaml)
-- cannot fit beside prose, so they get a page of their own. Wider ones stay inline.
-- A style with different margins has a different text block, so render-pdf.sh overrides this
-- via the environment (--academic sets 0.63 for its 16cm x 24.7cm block).
local TEXT_BLOCK_ASPECT = tonumber(os.getenv('TEXT_BLOCK_ASPECT') or '') or 0.67

local function quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function capture(cmd)
  local h = io.popen(cmd .. ' 2>&1')
  local out = h:read('a')
  local ok = h:close()
  return ok, out
end

local function exists(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

-- Aspect ratio (width/height) from the SVG's viewBox, used to pick the layout.
local function aspect_of(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local head = f:read(4000) or ''
  f:close()
  local w, h = head:match('viewBox="[%d%.%-]+ [%d%.%-]+ ([%d%.]+) ([%d%.]+)"')
  if w and h and tonumber(h) > 0 then
    return tonumber(w) / tonumber(h)
  end
  return nil
end

local function render(code)
  local hash = pandoc.utils.sha1(code):sub(1, 12)
  local svg = DIAGRAM_DIR .. '/' .. hash .. '.svg'
  if exists(svg) then return svg end

  os.execute('mkdir -p ' .. quote(DIAGRAM_DIR))
  local src = DIAGRAM_DIR .. '/' .. hash .. '.mmd'
  local f = assert(io.open(src, 'w'))
  f:write(code)
  f:close()

  local cmd = quote(MMDC)
  if PUPPETEER_CFG then cmd = cmd .. ' -p ' .. quote(PUPPETEER_CFG) end
  if MERMAID_CFG then cmd = cmd .. ' -c ' .. quote(MERMAID_CFG) end
  cmd = cmd .. ' -i ' .. quote(src) .. ' -o ' .. quote(svg) .. ' -b white'

  local ok, out = capture(cmd)
  os.remove(src)
  -- Fail loudly: a diagram that silently disappears from a 12-page PDF goes unnoticed.
  if not ok or not exists(svg) then
    error('mermaid.lua: mmdc failed for diagram ' .. hash .. '\n' .. out, 0)
  end
  return svg
end

function CodeBlock(el)
  if not el.classes:includes('mermaid') then return nil end

  local svg = render(el.text)
  local inline = pandoc.Image({}, svg, '', pandoc.Attr('', {}, { { 'width', '100%' } }))

  if FORMAT ~= 'typst' then
    -- HTML, docx and friends: a plain image, pandoc handles the media itself.
    return pandoc.Para({ inline })
  end

  local aspect = aspect_of(svg)
  if aspect and aspect >= TEXT_BLOCK_ASPECT then
    return pandoc.Para({ inline })
  end

  -- Tall diagram: give it a page of its own, scaled to the page height. The path is absolute
  -- because typst compiles in a temp directory; --root=/ in pdf-defaults.yaml makes it resolve.
  local abs = svg
  if not abs:match('^/') then
    local _, pwd = capture('pwd')
    abs = pwd:gsub('%s+$', '') .. '/' .. svg
  end

  return pandoc.RawBlock('typst', table.concat({
    '#pagebreak(weak: true)',
    string.format('#align(center + horizon, image("%s", height: 96%%))', abs),
    '#pagebreak(weak: true)',
  }, '\n'))
end
