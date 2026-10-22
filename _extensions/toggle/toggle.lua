-- Toggle Extension for Quarto
-- Adds buttons that show or hide code cell output in HTML documents, based on
-- document-level and cell-level configuration options.
--
-- Document-level configuration:
--   extensions:
--     toggle:
--       output-toggle: true     # Enable toggle buttons (default: false)
--       output-hidden: true     # Hide outputs by default (default: false)
--       output-sync: true       # Sync all outputs in a cell (default: false)
--       global-toggle: true     # Show global toggle button (default: false)
--       persist: true           # Persist state in localStorage (default: false)
--       button-text: "Result"   # Custom button text (default: "Output")
--
-- Cell-level configuration:
--   ```{python}
--   #| toggle: true
--   #| output-hidden: true
--   print("Hello")
--   ```

---@class ToggleDocSettings
---@field toggle_enabled boolean `output-toggle`: add a toggle button to every cell
---@field output_hidden boolean `output-hidden`: start with outputs collapsed
---@field output_sync boolean `output-sync`: one button controls all of a cell's outputs
---@field global_toggle boolean `global-toggle`: show the floating toggle-all button
---@field persist boolean `persist`: remember toggle state in localStorage
---@field button_text string `button-text`: button label

---@class ToggleCellSettings
---@field toggle boolean
---@field hidden boolean
---@field sync boolean
---@field persist boolean
---@field button_text string

-- ============================================================================
-- Module State
-- ============================================================================

local DEFAULT_BUTTON_TEXT = "Output"

---@return ToggleDocSettings
local function default_settings()
  return {
    toggle_enabled = false,
    output_hidden = false,
    output_sync = false,
    global_toggle = false,
    persist = false,
    button_text = DEFAULT_BUTTON_TEXT
  }
end

-- Document-level settings, read from metadata in the first pass
local doc_settings = default_settings()

-- Set when the document or any cell needs the toggle CSS/JS
local needs_toggle = false

-- Counter for unique toggle IDs, incremented per toggleable cell
local cell_index = 0

-- ============================================================================
-- Document Settings
-- ============================================================================

-- Read a boolean option; anything other than a YAML `true` counts as false
---@param config table Options table from metadata
---@param key string
---@param current boolean Value to keep when the option is absent
---@return boolean
local function read_bool(config, key, current)
  if config[key] == nil then
    return current
  end
  return config[key] == true
end

-- Read a string option; an empty value keeps the current one
---@param config table Options table from metadata
---@param key string
---@param current string Value to keep when the option is absent or empty
---@return string
local function read_string(config, key, current)
  if config[key] == nil then
    return current
  end
  local value = pandoc.utils.stringify(config[key])
  if value == "" then
    return current
  end
  return value
end

-- Apply one metadata options table on top of `settings`
---@param config table Options table from metadata
---@param settings ToggleDocSettings
local function apply_config(config, settings)
  settings.toggle_enabled = read_bool(config, "output-toggle", settings.toggle_enabled)
  settings.output_hidden = read_bool(config, "output-hidden", settings.output_hidden)
  settings.output_sync = read_bool(config, "output-sync", settings.output_sync)
  settings.global_toggle = read_bool(config, "global-toggle", settings.global_toggle)
  settings.persist = read_bool(config, "persist", settings.persist)
  settings.button_text = read_string(config, "button-text", settings.button_text)
end

-- Read settings from `extensions.toggle`, then from the legacy top-level
-- `toggle` key, which wins when both are set
---@param meta pandoc.Meta
---@return ToggleDocSettings
local function read_settings(meta)
  local settings = default_settings()

  local extensions = meta.extensions
  if type(extensions) == "table" and type(extensions.toggle) == "table" then
    apply_config(extensions.toggle, settings)
  end

  local legacy = meta.toggle
  if type(legacy) == "table" then
    apply_config(legacy, settings)
  end

  return settings
end

-- ============================================================================
-- Cell Settings
-- ============================================================================

-- Read a boolean cell option (`#| toggle: true` arrives as the string "true")
---@param el pandoc.Div
---@param name string
---@param default boolean
---@return boolean
local function cell_bool(el, name, default)
  local value = el.attributes[name]
  if value == nil then
    return default
  end
  return value == "true"
end

---@param el pandoc.Div
---@param name string
---@param default string
---@return string
local function cell_string(el, name, default)
  local value = el.attributes[name]
  if value == nil or value == "" then
    return default
  end
  return value
end

-- Combine the document settings with the cell's own `#|` options
---@param el pandoc.Div
---@return ToggleCellSettings
local function resolve_cell_settings(el)
  return {
    toggle = cell_bool(el, "toggle", doc_settings.toggle_enabled),
    hidden = cell_bool(el, "output-hidden", doc_settings.output_hidden),
    sync = cell_bool(el, "output-sync", doc_settings.output_sync),
    persist = cell_bool(el, "persist", doc_settings.persist),
    button_text = cell_string(el, "button-text", doc_settings.button_text)
  }
end

-- Add the classes and attributes that toggle.js looks for
---@param el pandoc.Div
---@param settings ToggleCellSettings
local function apply_toggle_classes(el, settings)
  el.classes:insert("toggleable-cell")
  el.classes:insert(settings.sync and "output-sync-on" or "output-sync-off")
  if settings.hidden then
    el.classes:insert("initially-hidden")
  end
  if settings.persist then
    el.classes:insert("persist-enabled")
  end
  if settings.button_text ~= DEFAULT_BUTTON_TEXT then
    el.attributes["data-button-text"] = settings.button_text
  end
end

-- ============================================================================
-- Toggle ID Marking
-- ============================================================================

-- True for Quarto's output divs (`cell-output`, `cell-output-display`, ...)
---@param div pandoc.Div
---@return boolean
local function is_output_div(div)
  for _, class in ipairs(div.classes) do
    if class:match("^cell%-output") then
      return true
    end
  end
  return false
end

-- Give each code block in a cell an ID and tag the outputs that follow it
-- with the same ID, so toggle.js can pair them inside nested containers
---@param el pandoc.Div The cell
---@param cell_idx integer
---@return pandoc.Div
local function mark_toggle_pairs(el, cell_idx)
  local pair_idx = 0
  local current_code_id = nil

  return el:walk({
    CodeBlock = function(block)
      if block.classes:includes("cell-code") then
        pair_idx = pair_idx + 1
        current_code_id = string.format("toggle-%d-%d", cell_idx, pair_idx)
        block.attributes["data-toggle-id"] = current_code_id
        return block
      end
    end,

    Div = function(div)
      if current_code_id and is_output_div(div) then
        div.attributes["data-toggle-output"] = current_code_id
        return div
      end
    end
  })
end

-- ============================================================================
-- HTML Dependency Injection
-- ============================================================================

-- Adds document-level classes and the global button label to <html>
local HEADER_SCRIPT = [[
<script>
(function() {
  var classes = %s.split(' ').filter(Boolean);
  classes.forEach(function(c) { document.documentElement.classList.add(c); });
  %s
})();
</script>
]]

-- Register the toggle CSS/JS and, when needed, the header script
local function add_dependencies()
  quarto.doc.add_html_dependency({
    name = "toggle",
    version = "0.3.0-dev.1",
    scripts = {"toggle.js"},
    stylesheets = {"toggle.css"}
  })

  local classes = {}
  if doc_settings.global_toggle then
    table.insert(classes, "toggle-global-enabled")
  end
  if doc_settings.persist then
    table.insert(classes, "toggle-persist-enabled")
  end

  local attr_script = ""
  if doc_settings.button_text ~= DEFAULT_BUTTON_TEXT then
    attr_script = string.format(
      "document.documentElement.setAttribute('data-toggle-global-text', %s);",
      quarto.json.encode(doc_settings.button_text)
    )
  end

  if #classes > 0 or attr_script ~= "" then
    local script = string.format(HEADER_SCRIPT, quarto.json.encode(table.concat(classes, " ")), attr_script)
    quarto.doc.include_text("in-header", script)
  end
end

-- ============================================================================
-- Filter Functions
-- ============================================================================

-- First pass: read the document settings
---@param meta pandoc.Meta
local function process_meta(meta)
  doc_settings = read_settings(meta)
  if doc_settings.toggle_enabled or doc_settings.global_toggle then
    needs_toggle = true
  end
end

-- Second pass: mark up each cell that has toggling enabled
---@param el pandoc.Div
---@return pandoc.Div|nil
local function process_div(el)
  if not quarto.doc.is_format("html") or not el.classes:includes("cell") then
    return nil
  end

  local settings = resolve_cell_settings(el)
  if not settings.toggle then
    return nil
  end
  needs_toggle = true

  apply_toggle_classes(el, settings)
  el = mark_toggle_pairs(el, cell_index)
  cell_index = cell_index + 1

  return el
end

-- Third pass: add the CSS/JS once we know whether any cell uses them
local function finalize_meta()
  if needs_toggle and quarto.doc.is_format("html") then
    add_dependencies()
  end
end

return {
  { Meta = process_meta },
  { Div = process_div },
  { Meta = finalize_meta }
}
