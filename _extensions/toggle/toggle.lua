--- Toggle Extension for Quarto
-- Provides toggle buttons to show/hide code output sections in Quarto HTML documents.
-- This Lua filter processes code cells and adds toggle functionality based on
-- document-level and cell-level configuration options.
--
-- @author James J Balamuta
-- @copyright 2025 James J Balamuta
-- @release 0.2.0
--
-- @usage
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

-- ============================================================================
-- Module State
-- ============================================================================

--- Flag indicating if toggle dependencies are needed.
-- @field needs_toggle boolean
local needs_toggle = false

--- Cell counter for generating unique toggle IDs.
-- @field cell_index number Current cell index (0-based)
local cell_index = 0

--- Default settings values.
-- @class table
-- @name DEFAULT_SETTINGS
-- @field toggle_enabled boolean Default: false
-- @field output_hidden boolean Default: false
-- @field output_sync boolean Default: false
-- @field global_toggle boolean Default: false
-- @field persist boolean Default: false
-- @field button_text string Default: "Output"
local DEFAULT_SETTINGS = {
  toggle_enabled = false,
  output_hidden = false,
  output_sync = false,
  global_toggle = false,
  persist = false,
  button_text = "Output"
}

--- Document-level settings (populated from metadata).
-- @class table
-- @name doc_settings
local doc_settings = {}

--- Initialize doc_settings with default values.
-- Copies DEFAULT_SETTINGS to doc_settings.
-- @return nil
local function init_doc_settings()
  for k, v in pairs(DEFAULT_SETTINGS) do
    doc_settings[k] = v
  end
end

-- Initialize on load
init_doc_settings()

-- ============================================================================
-- Type Conversion Utilities
-- ============================================================================

--- Convert a value to boolean.
-- Safely converts Pandoc metadata values to Lua booleans.
-- @param value any The value to convert
-- @return boolean|nil The boolean representation or nil if input is nil
local function to_boolean(value)
  if value == nil then
    return nil
  end
  if type(value) == "boolean" then
    return value
  end
  return value == true
end

--- Convert a value to string.
-- Safely converts Pandoc metadata values to Lua strings.
-- @param value any The value to convert
-- @return string|nil The string representation or nil if empty/invalid
local function to_string(value)
  if value == nil then
    return nil
  end
  local str = pandoc.utils.stringify(value)
  if str and str ~= "" then
    return str
  end
  return nil
end

-- ============================================================================
-- Configuration Extraction
-- ============================================================================

--- Extract a single boolean setting from a config table.
-- @param config table The configuration table
-- @param key string The key to extract
-- @param current_value boolean The current/default value
-- @return boolean The extracted value or current value if not found
local function extract_bool_setting(config, key, current_value)
  if config[key] ~= nil then
    local val = to_boolean(config[key])
    if val ~= nil then
      return val
    end
  end
  return current_value
end

--- Extract a single string setting from a config table.
-- @param config table The configuration table
-- @param key string The key to extract
-- @param current_value string The current/default value
-- @return string The extracted value or current value if not found
local function extract_string_setting(config, key, current_value)
  if config[key] ~= nil then
    local val = to_string(config[key])
    if val then
      return val
    end
  end
  return current_value
end

--- Process a toggle configuration table and update settings.
-- Extracts all toggle options from a configuration table.
-- @param config table The configuration table (from YAML)
-- @param settings table The settings table to update
-- @return table The updated settings table
local function process_config_table(config, settings)
  settings.toggle_enabled = extract_bool_setting(config, "output-toggle", settings.toggle_enabled)
  settings.output_hidden = extract_bool_setting(config, "output-hidden", settings.output_hidden)
  settings.output_sync = extract_bool_setting(config, "output-sync", settings.output_sync)
  settings.global_toggle = extract_bool_setting(config, "global-toggle", settings.global_toggle)
  settings.persist = extract_bool_setting(config, "persist", settings.persist)
  settings.button_text = extract_string_setting(config, "button-text", settings.button_text)
  return settings
end

--- Create a new settings table with default values.
-- @return table A new settings table initialized with defaults
local function create_default_settings()
  local settings = {}
  for k, v in pairs(DEFAULT_SETTINGS) do
    settings[k] = v
  end
  return settings
end

--- Extract toggle settings from document metadata.
-- Parses both new format (extensions.toggle.*) and legacy format (toggle.*).
-- @param meta table The document metadata from Pandoc
-- @return table A settings table with all toggle configuration options
local function extract_settings(meta)
  local settings = create_default_settings()
  
  -- New format: extensions.toggle
  if meta.extensions and meta.extensions.toggle then
    settings = process_config_table(meta.extensions.toggle, settings)
  end
  
  -- Legacy format: toggle.* (processed second to allow override)
  if meta.toggle then
    settings = process_config_table(meta.toggle, settings)
  end
  
  return settings
end

-- ============================================================================
-- Cell Attribute Utilities
-- ============================================================================

--- Get a boolean attribute from a Div element.
-- @param el table The Pandoc Div element
-- @param attr_name string The attribute name
-- @param default boolean The default value
-- @return boolean The attribute value or default
local function get_bool_attr(el, attr_name, default)
  local value = el.attributes[attr_name]
  if value == nil then
    return default
  end
  return value == "true"
end

--- Get a string attribute from a Div element.
-- @param el table The Pandoc Div element
-- @param attr_name string The attribute name
-- @param default string The default value
-- @return string The attribute value or default
local function get_string_attr(el, attr_name, default)
  local value = el.attributes[attr_name]
  if value == nil or value == "" then
    return default
  end
  return value
end

--- Check if an attribute exists on a Div element.
-- @param el table The Pandoc Div element
-- @param attr_name string The attribute name
-- @return boolean True if attribute exists
local function has_attr(el, attr_name)
  return el.attributes[attr_name] ~= nil
end

-- ============================================================================
-- Cell Settings
-- ============================================================================

--- Create cell settings from document settings and element attributes.
-- Cell-level attributes override document-level settings.
-- @param el table The Pandoc Div element
-- @return table The resolved cell settings
local function resolve_cell_settings(el)
  local settings = {
    toggle = doc_settings.toggle_enabled,
    hidden = doc_settings.output_hidden,
    sync = doc_settings.output_sync,
    persist = doc_settings.persist,
    button_text = doc_settings.button_text
  }
  
  -- Override with cell-level attributes
  if has_attr(el, "toggle") then
    settings.toggle = get_bool_attr(el, "toggle", settings.toggle)
  end
  
  if has_attr(el, "output-hidden") then
    settings.hidden = get_bool_attr(el, "output-hidden", settings.hidden)
  end
  
  if has_attr(el, "output-sync") then
    settings.sync = get_bool_attr(el, "output-sync", settings.sync)
  end
  
  if has_attr(el, "persist") then
    settings.persist = get_bool_attr(el, "persist", settings.persist)
  end
  
  if has_attr(el, "button-text") then
    settings.button_text = get_string_attr(el, "button-text", settings.button_text)
  end
  
  return settings
end

-- ============================================================================
-- Class Application
-- ============================================================================

--- Add the base toggleable class to an element.
-- @param el table The Pandoc Div element
-- @return nil
local function add_toggleable_class(el)
  el.classes:insert("toggleable-cell")
end

--- Add sync mode class to an element.
-- @param el table The Pandoc Div element
-- @param is_sync boolean Whether sync mode is enabled
-- @return nil
local function add_sync_class(el, is_sync)
  if is_sync then
    el.classes:insert("output-sync-on")
  else
    el.classes:insert("output-sync-off")
  end
end

--- Add initially hidden class to an element.
-- @param el table The Pandoc Div element
-- @param is_hidden boolean Whether output should be hidden
-- @return nil
local function add_hidden_class(el, is_hidden)
  if is_hidden then
    el.classes:insert("initially-hidden")
  end
end

--- Add persistence class to an element.
-- @param el table The Pandoc Div element
-- @param is_persist boolean Whether persistence is enabled
-- @return nil
local function add_persist_class(el, is_persist)
  if is_persist then
    el.classes:insert("persist-enabled")
  end
end

--- Add button text data attribute to an element.
-- @param el table The Pandoc Div element
-- @param button_text string The button text
-- @return nil
local function add_button_text_attr(el, button_text)
  if button_text ~= DEFAULT_SETTINGS.button_text then
    el.attributes["data-button-text"] = button_text
  end
end

--- Apply all toggle classes and attributes to an element.
-- @param el table The Pandoc Div element
-- @param settings table The cell settings
-- @return nil
local function apply_toggle_classes(el, settings)
  add_toggleable_class(el)
  add_sync_class(el, settings.sync)
  add_hidden_class(el, settings.hidden)
  add_persist_class(el, settings.persist)
  add_button_text_attr(el, settings.button_text)
end

-- ============================================================================
-- HTML Dependency Injection
-- ============================================================================

--- Build the list of HTML classes for document-level features.
-- @return table Array of class names
local function build_html_classes()
  local classes = {}
  
  if doc_settings.global_toggle then
    table.insert(classes, "toggle-global-enabled")
  end
  
  if doc_settings.persist then
    table.insert(classes, "toggle-persist-enabled")
  end
  
  return classes
end

--- Build the JavaScript for setting data attributes.
-- @return string JavaScript code or empty string
local function build_attr_script()
  if doc_settings.button_text ~= DEFAULT_SETTINGS.button_text then
    return string.format(
      "document.documentElement.setAttribute('data-toggle-global-text', %q);",
      doc_settings.button_text
    )
  end
  return ""
end

--- Generate the header injection script.
-- Creates a script tag that adds classes to the HTML element.
-- @param classes table Array of class names
-- @param attr_script string Additional attribute script
-- @return string The complete script tag
local function generate_injection_script(classes, attr_script)
  local class_str = table.concat(classes, " ")
  
  return string.format([[
<script>
(function() {
  var classes = %q.split(' ').filter(Boolean);
  classes.forEach(function(c) { document.documentElement.classList.add(c); });
  %s
})();
</script>
]], class_str, attr_script)
end

--- Add toggle HTML dependency to the document.
-- Registers CSS and JS files with Quarto.
-- @return nil
local function add_html_dependency()
  quarto.doc.add_html_dependency({
    name = "toggle",
    version = "0.1.0",
    scripts = {"toggle.js"},
    stylesheets = {"toggle.css"}
  })
end

--- Inject document-level configuration into the HTML.
-- Adds classes and attributes to the HTML element.
-- @return nil
local function inject_document_config()
  local classes = build_html_classes()
  local attr_script = build_attr_script()
  
  if #classes > 0 or attr_script ~= "" then
    local script = generate_injection_script(classes, attr_script)
    quarto.doc.include_text("in-header", script)
  end
end

-- ============================================================================
-- Format Checking
-- ============================================================================

--- Check if the current output format is HTML.
-- @return boolean True if output format is HTML
local function is_html_format()
  return quarto.doc.is_format("html")
end

--- Check if an element is a code cell.
-- @param el table The Pandoc Div element
-- @return boolean True if element has "cell" class
local function is_cell(el)
  return el.classes:includes("cell")
end

-- ============================================================================
-- Toggle ID Marking
-- ============================================================================

--- Check if a CodeBlock element is a code block within a cell.
-- @param el table The Pandoc element
-- @return boolean True if element is a cell-code section
local function is_code_block(el)
  if el.t ~= "CodeBlock" then
    return false
  end
  return el.classes:includes("cell-code")
end

--- Check if a Div element is an output section.
-- @param el table The Pandoc element
-- @return boolean True if element is a cell-output section
local function is_output_block(el)
  if el.t ~= "Div" then
    return false
  end
  for _, class in ipairs(el.classes) do
    if class:match("^cell%-output") then
      return true
    end
  end
  return false
end

--- Generate a toggle ID for a code-output pair.
-- @param cell_idx number The cell index
-- @param pair_idx number The pair index within the cell
-- @return string The generated toggle ID
local function generate_toggle_id(cell_idx, pair_idx)
  return string.format("toggle-%d-%d", cell_idx, pair_idx)
end

--- Find and mark code-output pairs within a cell.
-- Traverses cell content recursively to find code blocks and their associated outputs,
-- assigning matching toggle IDs to each pair.
-- @param el table The cell Div element
-- @param cell_idx number The cell index
-- @return table The modified cell with marked elements
local function mark_toggle_pairs(el, cell_idx)
  local pair_idx = 0
  local current_code_id = nil

  -- Walk through all elements in the cell
  el = el:walk({
    -- Handle CodeBlock elements (code sections)
    CodeBlock = function(item)
      if is_code_block(item) then
        -- Found a code block, generate new ID
        pair_idx = pair_idx + 1
        current_code_id = generate_toggle_id(cell_idx, pair_idx)
        item.attributes["data-toggle-id"] = current_code_id
        return item
      end
      return nil
    end,

    -- Handle Div elements (output sections)
    Div = function(item)
      if is_output_block(item) then
        -- Found an output block
        if current_code_id then
          -- Mark with the current code block's ID
          item.attributes["data-toggle-output"] = current_code_id
        end
        return item
      end
      return nil
    end
  })

  return el
end

-- ============================================================================
-- Filter Functions
-- ============================================================================

--- Process document metadata to extract toggle settings.
-- First filter pass: reads YAML configuration.
-- @param meta table The document metadata from Pandoc
-- @return table The metadata table (unchanged)
local function process_meta(meta)
  doc_settings = extract_settings(meta)
  
  if doc_settings.toggle_enabled or doc_settings.global_toggle then
    needs_toggle = true
  end
  
  return meta
end

--- Process a single cell Div element.
-- Determines if toggle should be applied and adds necessary classes.
-- @param el table The Pandoc Div element
-- @return table The modified Div element
local function process_cell(el)
  local settings = resolve_cell_settings(el)

  -- Track if cell-level toggle was enabled
  if has_attr(el, "toggle") and settings.toggle then
    needs_toggle = true
  end

  -- Skip if toggle not enabled for this cell
  if not settings.toggle then
    return el
  end

  -- Apply toggle classes to the cell
  apply_toggle_classes(el, settings)

  -- Mark code-output pairs with matching IDs
  el = mark_toggle_pairs(el, cell_index)

  -- Increment cell counter for next cell
  cell_index = cell_index + 1

  return el
end

--- Process Div elements to add toggle functionality.
-- Second filter pass: processes each cell div.
-- @param el table The Pandoc Div element
-- @return table The modified Div element
local function process_div(el)
  if not is_html_format() then
    return el
  end
  
  if not is_cell(el) then
    return el
  end
  
  return process_cell(el)
end

--- Finalize and add HTML dependencies.
-- Third filter pass: adds CSS/JS dependencies and injects config.
-- @param meta table The document metadata from Pandoc
-- @return table The metadata table (unchanged)
local function finalize_meta(meta)
  if not needs_toggle then
    return meta
  end
  
  add_html_dependency()
  inject_document_config()
  
  return meta
end

-- ============================================================================
-- Filter Specification
-- ============================================================================

--- Filter specification for Quarto/Pandoc.
-- Defines processing order: Meta -> Div -> Meta (finalize).
-- @return table The filter specification
return {
  { Meta = process_meta },
  { Div = process_div },
  { Meta = finalize_meta }
}
