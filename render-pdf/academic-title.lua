-- Promote a leading `# Title` heading into the document's title block.
--
-- Applied only by `render-pdf --academic`. The academic style renders a real title block from
-- frontmatter `title:`, and pandoc emits the table of contents immediately after that block.
-- A document that instead opens with a `#` heading therefore gets an empty title block, a ToC
-- at the very top of page one, the "title" pushed below it as an ordinary section, and that
-- same title listed as its own first ToC entry.
--
-- The default style is deliberately left alone: pdf-defaults.yaml is built around `#` for the
-- title and `###` for sections, and promoting the heading there would change how every
-- existing document renders.
--
-- The promotion is conservative. It fires only when the document has no frontmatter title AND
-- contains exactly one level-1 heading AND that heading is the very first block. A document
-- using `#` per section (`# Introduction` ... `# Conclusion`) has more than one, so its first
-- section is never mistaken for a title.

function Pandoc(doc)
  local title = doc.meta.title
  if title ~= nil and pandoc.utils.stringify(title) ~= '' then
    return nil
  end

  local seen, first = 0, nil
  for i, block in ipairs(doc.blocks) do
    if block.t == 'Header' and block.level == 1 then
      seen = seen + 1
      if first == nil then first = i end
    end
  end
  if seen ~= 1 or first ~= 1 then
    return nil
  end

  doc.meta.title = pandoc.MetaInlines(doc.blocks[1].content)
  doc.blocks:remove(1)

  -- With the title lifted out of the body, the `##` sections underneath it are the document's
  -- real top level, so shift everything up one. Without this, `--auto-numbering` numbers from
  -- a level that now holds no headings and every section comes out as 0.1, 0.2, 0.2.1.
  -- Safe by construction: the only level-1 heading was the one just removed.
  doc.blocks = doc.blocks:walk({
    Header = function(h)
      h.level = h.level - 1
      return h
    end,
  })

  return doc
end
