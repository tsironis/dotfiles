// Injected by `render-pdf --toc`: start the body on a fresh page after the contents.
//
// A show rule rather than a literal `#pagebreak()`, because the outline is emitted by pandoc's
// typst template and there is no seam in the markdown to insert a break at. `weak: true` so an
// outline that already ends flush with a page boundary does not produce a blank page.
#show outline: it => {
  it
  pagebreak(weak: true)
}
