-- toggle tests. Run from the repo root: quarto pandoc lua path/to/qtest.lua
-- The fixtures run R code, so they need R with rmarkdown. knitr splits a cell's
-- code wherever output appears, which gives cells with several code blocks;
-- Jupyter's one-block cells get the same markup.
local t = require("qtest")

local DEPENDENCY = "/toggle-0.3.0-dev.1/toggle.js"

t.test("html: output-toggle marks every cell and pairs each code block with the outputs after it", function()
  local r = t.render("basic.qmd", "html")
  r:succeeded()
  t.count(r.text, '<div class="cell toggleable-cell output-sync-off">', 1)
  t.in_order(r.text, {
    'data-toggle-id="toggle-0-1"', 'data-toggle-output="toggle-0-1"',
    'data-toggle-id="toggle-0-2"', 'data-toggle-output="toggle-0-2"',
  })
  t.count(r.text, DEPENDENCY, 1)
  t.count(r.text, "/toggle-0.3.0-dev.1/toggle.css", 1)
end)

t.test("toggle: a cell's own setting wins; a page with no toggles gets no toggle JavaScript", function()
  local opted_out = t.render("basic.qmd", "html")
  t.contains(opted_out.text, '<div class="cell" data-toggle="false">')
  t.count(opted_out.text, "toggleable-cell", 1)

  local opted_in = t.render("plain.qmd", "html")
  opted_in:succeeded()
  t.count(opted_in.text, '<div class="cell toggleable-cell output-sync-off" data-toggle="true">', 1)
  t.count(opted_in.text, "toggleable-cell", 1)

  local untouched = t.render("untouched.qmd", "html")
  untouched:succeeded()
  t.not_contains(untouched.text, "toggleable-cell")
  t.not_contains(untouched.text, DEPENDENCY)
end)

t.test("output-hidden: the document starts outputs collapsed; a cell can opt out", function()
  local r = t.render("options.qmd", "html")
  r:succeeded()
  t.count(r.text, "initially-hidden", 1)
  t.contains(r.text, '<div class="cell toggleable-cell output-sync-on initially-hidden persist-enabled"')
end)

t.test("output-sync: the document syncs a cell's outputs; a cell can opt out", function()
  local r = t.render("options.qmd", "html")
  t.in_order(r.text, { "toggleable-cell output-sync-on", "toggleable-cell output-sync-off" })
end)

-- Regression: the global button's label went into the header script through
-- Lua's %q, which writes emoji as decimal escapes such as \240 that JavaScript
-- reads as octal, so the label came out garbled.
t.test("button-text: the document's label goes on each cell and the global button, emoji intact", function()
  local r = t.render("options.qmd", "html")
  t.contains(r.text, 'data-button-text="▶ Result 🎉"')
  -- A cell's own label reaches the page as Quarto's data-button-text attribute
  t.contains(r.text, 'data-button-text="Code output"')
  t.contains(r.text, "setAttribute('data-toggle-global-text', \"▶ Result 🎉\")")
  t.not_contains(r.text, "\\240")
end)

t.test("global-toggle and persist: the page gets their classes, and cells remember their state", function()
  local r = t.render("options.qmd", "html")
  t.contains(r.text, '"toggle-global-enabled toggle-persist-enabled"')
  -- Both cells: their class lists end with persist-enabled, before data- attributes
  t.count(r.text, 'persist-enabled" data-', 2)
end)

t.test("revealjs: cells are marked and paired, with the toggle JavaScript", function()
  local r = t.render("basic.qmd", "revealjs")
  r:succeeded()
  t.count(r.text, '<div class="cell toggleable-cell output-sync-off">', 1)
  t.in_order(r.text, { 'data-toggle-id="toggle-0-1"', 'data-toggle-output="toggle-0-1"' })
  t.count(r.text, DEPENDENCY, 1)
end)

-- Regression: with output-toggle or global-toggle set for the document, the
-- header <script> went into every format, and PDF builds failed with
-- "LaTeX Error: Missing \begin{document}".
t.test("pdf: document options add no script or toggle markup to the LaTeX", function()
  local r = t.render("options.qmd", "latex")
  r:succeeded()
  t.not_contains(r.text, "<script>")
  t.not_contains(r.text, "toggle-global-enabled")
  t.not_contains(r.text, "toggleable-cell")
end)
