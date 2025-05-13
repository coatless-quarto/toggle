-- Do we need toggle dependencies added?
local needsToggle = false

function Div(el)
  quarto.log.output("=== Handling Div with CodeBlock ===")

  if quarto.doc.is_format("html") and el.classes:includes("cell") and el.attributes.toggle == "true" then
    quarto.log.output("=== Inserted Class ===")
    needsToggle = true

    el.classes:insert("toggleable-cell")
    return el
  else
    return el
  end
end

return {
  {
    Div = Div
  },
  {
    Meta = function(meta)
      if meta.toggle then
        needsToggle = true
      end

      if needsToggle then
        quarto.log.output("=== Added Toggle Dependency ===")
        quarto.doc.add_html_dependency({
          name = "code-toggle",
          scripts = {"code-toggle.js"},
          stylesheets = {"code-toggle.css"}
        })
      end
      return meta
    end
  }
}