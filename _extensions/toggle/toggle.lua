-- Do we need toggle dependencies added?
local needs_toggle = false

-- Should we enable toggle by default?
-- This is set to true if the document metadata has "output-toggle: true"
local doc_toggle_enabled = false

-- Should we hide all outputs by default?
-- This is set to true if the document metadata has "output-hidden: true"
local doc_output_hidden = false

-- Default cell level output toggle sync for the document
local doc_output_sync = false -- Default to individual mode

-- Get document-level settings from YAML metadata
function Meta(meta)
  -- Check if toggle is defined in metadata
  if meta.toggle then
    -- Check if output-toggle is enabled
    if meta.toggle["output-toggle"] and meta.toggle["output-toggle"] == true then
      doc_toggle_enabled = true
      needs_toggle = true
    end
    
    -- Check if output-hidden is defined
    if meta.toggle["output-hidden"] and meta.toggle["output-hidden"] == true then
      doc_output_hidden = true
    end

    -- Check if toggle-mode is defined
    if meta.toggle["output-sync"] then
        doc_output_sync = meta.toggle["output-sync"] == true
    end
  end


  
  return meta
end


-- Process Div elements with "cell" class
function Div(el)

  -- Only process in HTML format
  if quarto.doc.is_format("html") and el.classes:includes("cell") then
    -- Determine if toggle should be enabled for this cell
    local cell_toggle_enabled = doc_toggle_enabled
    local output_hidden = doc_output_hidden
    local output_sync = doc_output_sync

    -- Check for cell-level toggle attribute
    if el.attributes["toggle"] then
      cell_toggle_enabled = el.attributes.toggle == "true"
      needs_toggle = true
    end

    -- Check for cell-level toggle-mode attribute, which overrides document setting
    if el.attributes["output-sync"] then
      output_sync = el.attributes["output-sync"] == "true"
    end
    
    -- Check for cl-level output-hidden attribute, which overrides document setting
    if el.attributes["output-hidden"] then
      output_hidden = el.attributes["output-hidden"] == "true"
    end
    
    -- If toggle is enabled for this cell, process the child elements
    -- Apply classes if toggle is enabled for this cell
    if cell_toggle_enabled then
      -- Add the toggleable class
      el.classes:insert("toggleable-cell")

      -- Add the output sync class
      if output_sync then
        el.classes:insert("output-sync-on")
      else
        el.classes:insert("output-sync-off")
      end
      
      -- If output should be initially hidden, add the class
      if output_hidden then
        el.classes:insert("initially-hidden")
      end
    end
    
    return el
  else
    return el
  end
end

return {
  {
    Meta = Meta
  },
  {
    Div = Div
  },
  {
    Meta = function(meta)
      if needs_toggle then
        -- quarto.log.output("=== Added Toggle Dependency ===")
        quarto.doc.add_html_dependency({
          name = "toggle",
          scripts = {"toggle.js"},
          stylesheets = {"toggle.css"}
        })
      end
      return meta
    end
  }
}