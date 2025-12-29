/**
 * Toggle Extension for Quarto
 * Provides toggle buttons to show/hide code output sections
 *
 * @author James J Balamuta
 * @version 0.2.0
 */

(function() {
  'use strict';

  // ===========================================================================
  // Configuration
  // ===========================================================================

  /**
   * Central configuration object for class names, selectors, and defaults
   */
  var CONFIG = {
    classes: {
      toggleBtn: 'code-toggle-btn',
      outputHidden: 'output-hidden',
      initiallyHidden: 'initially-hidden',
      syncOn: 'output-sync-on',
      hidden: 'hidden',
      globalBtn: 'toggle-global-btn',
      allHidden: 'all-hidden',
      persistEnabled: 'persist-enabled'
    },
    selectors: {
      toggleableCell: '.toggleable-cell',
      toggleId: '[data-toggle-id]',
      toggleOutput: '[data-toggle-output]',
      globalEnabled: 'toggle-global-enabled',
      persistEnabled: 'toggle-persist-enabled'
    },
    storageKeyPrefix: 'quarto-toggle-',
    defaultButtonText: 'Output',
    tooltips: {
      show: 'Show output',
      hide: 'Hide output',
      showAll: 'Show all outputs',
      hideAll: 'Hide all outputs'
    }
  };

  // ===========================================================================
  // Storage Module
  // ===========================================================================

  /**
   * Handles localStorage operations for persisting toggle state
   */
  var Storage = {
    _available: null,

    /**
     * Check if localStorage is available (cached after first check)
     * @returns {boolean} True if localStorage is available
     */
    isAvailable: function() {
      if (this._available !== null) return this._available;
      try {
        var test = '__storage_test__';
        localStorage.setItem(test, test);
        localStorage.removeItem(test);
        this._available = true;
      } catch (e) {
        this._available = false;
      }
      return this._available;
    },

    /**
     * Generate a storage key for a specific item based on page path
     * @param {string} suffix - The suffix to append to the key
     * @returns {string} The full storage key
     */
    createKey: function(suffix) {
      var pageId = window.location.pathname.replace(/\//g, '-');
      return CONFIG.storageKeyPrefix + pageId + '-' + suffix;
    },

    /**
     * Save a value to localStorage
     * @param {string} key - The storage key
     * @param {*} value - The value to store (will be JSON stringified)
     */
    save: function(key, value) {
      if (!this.isAvailable()) return;
      try {
        localStorage.setItem(key, JSON.stringify(value));
      } catch (e) {
        // Silently fail (quota exceeded, etc.)
      }
    },

    /**
     * Load a value from localStorage
     * @param {string} key - The storage key
     * @returns {*} The parsed value, or null if not found
     */
    load: function(key) {
      if (!this.isAvailable()) return null;
      try {
        var stored = localStorage.getItem(key);
        return stored !== null ? JSON.parse(stored) : null;
      } catch (e) {
        return null;
      }
    }
  };

  // ===========================================================================
  // Accessibility Module
  // ===========================================================================

  /**
   * Handles accessibility features including screen reader announcements
   */
  var A11y = {
    liveRegion: null,

    /**
     * Initialize the ARIA live region for screen reader announcements
     */
    init: function() {
      if (this.liveRegion) return;
      this.liveRegion = document.createElement('div');
      this.liveRegion.setAttribute('role', 'status');
      this.liveRegion.setAttribute('aria-live', 'polite');
      this.liveRegion.setAttribute('aria-atomic', 'true');
      this.liveRegion.className = 'sr-only';
      // Visually hidden but accessible to screen readers
      this.liveRegion.style.cssText =
        'position:absolute;width:1px;height:1px;padding:0;margin:-1px;' +
        'overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0;';
      document.body.appendChild(this.liveRegion);
    },

    /**
     * Announce a message to screen readers
     * @param {string} message - The message to announce
     */
    announce: function(message) {
      if (!this.liveRegion) this.init();
      // Clear and re-set to ensure announcement is triggered
      this.liveRegion.textContent = '';
      requestAnimationFrame(function() {
        A11y.liveRegion.textContent = message;
      });
    }
  };

  // ===========================================================================
  // Button Module
  // ===========================================================================

  /**
   * Handles toggle button creation and state management
   */
  var Button = {
    /**
     * Update button state (classes, ARIA attributes, tooltip)
     * @param {HTMLButtonElement} btn - The button element
     * @param {boolean} isHidden - Whether the associated output is hidden
     */
    updateState: function(btn, isHidden) {
      btn.classList.toggle(CONFIG.classes.outputHidden, isHidden);
      btn.setAttribute('aria-expanded', String(!isHidden));
      btn.setAttribute('aria-label', isHidden ? 'Show output' : 'Hide output');
      btn.setAttribute('data-tooltip', isHidden ? CONFIG.tooltips.show : CONFIG.tooltips.hide);
    },

    /**
     * Create a new toggle button
     * @param {string} pairId - The ID linking this button to its output(s)
     * @param {string} buttonText - The button label text
     * @param {boolean} isHidden - Initial hidden state
     * @returns {HTMLButtonElement} The created button
     */
    create: function(pairId, buttonText, isHidden) {
      var btn = document.createElement('button');
      btn.className = CONFIG.classes.toggleBtn;
      btn.type = 'button';
      btn.tabIndex = 0;
      btn.dataset.pair = pairId;
      btn.textContent = buttonText || CONFIG.defaultButtonText;
      this.updateState(btn, isHidden);
      this.addKeyboardSupport(btn);
      return btn;
    },

    /**
     * Add keyboard support (Enter/Space to activate)
     * @param {HTMLButtonElement} btn - The button element
     */
    addKeyboardSupport: function(btn) {
      btn.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          btn.click();
        }
      });
    }
  };

  // ===========================================================================
  // Toggle Module
  // ===========================================================================

  /**
   * Core toggle logic for showing/hiding outputs
   */
  var Toggle = {
    /**
     * Set hidden state on multiple output elements
     * @param {HTMLElement[]} outputs - Array of output elements
     * @param {boolean} isHidden - Whether to hide the outputs
     */
    setOutputsHidden: function(outputs, isHidden) {
      for (var i = 0; i < outputs.length; i++) {
        outputs[i].classList.toggle(CONFIG.classes.hidden, isHidden);
      }
    },

    /**
     * Update state on multiple buttons
     * @param {HTMLButtonElement[]} buttons - Array of button elements
     * @param {boolean} isHidden - Whether outputs are hidden
     */
    updateButtons: function(buttons, isHidden) {
      for (var i = 0; i < buttons.length; i++) {
        Button.updateState(buttons[i], isHidden);
      }
    },

    /**
     * Toggle a single output (or group of outputs for one code block)
     * @param {HTMLElement[]} outputs - The output elements to toggle
     * @param {HTMLButtonElement} btn - The button that triggered the toggle
     * @param {string|null} storageKey - Optional key for persisting state
     */
    single: function(outputs, btn, storageKey) {
      var isCurrentlyHidden = outputs[0].classList.contains(CONFIG.classes.hidden);
      var newState = !isCurrentlyHidden;

      this.setOutputsHidden(outputs, newState);
      Button.updateState(btn, newState);
      A11y.announce(newState ? 'Output hidden' : 'Output shown');

      if (storageKey) {
        Storage.save(storageKey, newState);
      }
    },

    /**
     * Toggle all outputs in a synced group or globally
     * @param {HTMLElement[]} outputs - All output elements to toggle
     * @param {HTMLButtonElement[]} buttons - All buttons to update
     * @param {string|null} storageKey - Optional key for persisting state
     * @returns {boolean} The new hidden state
     */
    all: function(outputs, buttons, storageKey) {
      // Check if all are currently hidden
      var allHidden = true;
      for (var i = 0; i < outputs.length; i++) {
        if (!outputs[i].classList.contains(CONFIG.classes.hidden)) {
          allHidden = false;
          break;
        }
      }

      var newState = !allHidden;

      this.setOutputsHidden(outputs, newState);
      this.updateButtons(buttons, newState);
      A11y.announce(newState ? 'All outputs hidden' : 'All outputs shown');

      if (storageKey) {
        Storage.save(storageKey, newState);
      }

      return newState;
    }
  };

  // ===========================================================================
  // Cell Processor
  // ===========================================================================

  /**
   * Processes toggleable cells and sets up their toggle functionality
   */
  var CellProcessor = {
    /**
     * Process a single toggleable cell
     * @param {HTMLElement} cell - The cell container element
     * @param {number} cellIndex - The index of this cell (for storage keys)
     */
    process: function(cell, cellIndex) {
      var shouldHideInitially = cell.classList.contains(CONFIG.classes.initiallyHidden);
      var outputSyncOn = cell.classList.contains(CONFIG.classes.syncOn);
      var persistEnabled = cell.classList.contains(CONFIG.classes.persistEnabled);
      var customButtonText = cell.dataset.buttonText || CONFIG.defaultButtonText;

      var cellStorageKey = persistEnabled ? Storage.createKey('cell-' + cellIndex) : null;
      var persistedState = cellStorageKey ? Storage.load(cellStorageKey) : null;

      var codeBlocks = cell.querySelectorAll(CONFIG.selectors.toggleId);
      if (codeBlocks.length === 0) return;

      var allOutputs = [];
      var allButtons = [];
      var self = this;

      codeBlocks.forEach(function(codeBlock) {
        var toggleId = codeBlock.getAttribute('data-toggle-id');
        var outputs = cell.querySelectorAll('[data-toggle-output="' + toggleId + '"]');

        if (outputs.length === 0) return;

        var pairStorageKey = persistEnabled ? Storage.createKey('pair-' + toggleId) : null;
        var initiallyHidden = self.determineInitialState(
          shouldHideInitially,
          persistEnabled,
          outputSyncOn,
          persistedState,
          pairStorageKey
        );

        var toggleBtn = Button.create(toggleId, customButtonText, initiallyHidden);
        codeBlock.appendChild(toggleBtn);

        Toggle.setOutputsHidden(outputs, initiallyHidden);

        if (outputSyncOn) {
          self.collectForSync(outputs, toggleBtn, allOutputs, allButtons);
        } else {
          self.setupIndividualHandler(outputs, toggleBtn, pairStorageKey);
        }
      });

      // Set up sync mode handlers if enabled
      if (outputSyncOn && allButtons.length > 0) {
        this.setupSyncHandlers(allOutputs, allButtons, cellStorageKey);
      }
    },

    /**
     * Determine the initial hidden state based on config and persisted state
     * @param {boolean} shouldHideInitially - Document/cell default
     * @param {boolean} persistEnabled - Whether persistence is enabled
     * @param {boolean} outputSyncOn - Whether sync mode is enabled
     * @param {boolean|null} persistedState - Cell-level persisted state
     * @param {string|null} pairStorageKey - Key for pair-level persistence
     * @returns {boolean} The initial hidden state
     */
    determineInitialState: function(shouldHideInitially, persistEnabled, outputSyncOn, persistedState, pairStorageKey) {
      var initiallyHidden = shouldHideInitially;

      if (persistEnabled) {
        // Use cell-level key for sync mode, pair-level for individual
        var savedState = outputSyncOn ? persistedState : Storage.load(pairStorageKey);
        if (savedState !== null) {
          initiallyHidden = savedState;
        }
      }

      return initiallyHidden;
    },

    /**
     * Collect outputs and button for sync mode
     * @param {NodeList} outputs - Output elements for this code block
     * @param {HTMLButtonElement} toggleBtn - The toggle button
     * @param {HTMLElement[]} allOutputs - Accumulator for all outputs
     * @param {HTMLButtonElement[]} allButtons - Accumulator for all buttons
     */
    collectForSync: function(outputs, toggleBtn, allOutputs, allButtons) {
      for (var i = 0; i < outputs.length; i++) {
        allOutputs.push(outputs[i]);
      }
      allButtons.push(toggleBtn);
    },

    /**
     * Set up click handler for individual (non-synced) mode
     * @param {NodeList} outputs - Output elements for this code block
     * @param {HTMLButtonElement} toggleBtn - The toggle button
     * @param {string|null} storageKey - Optional persistence key
     */
    setupIndividualHandler: function(outputs, toggleBtn, storageKey) {
      var outputsArray = Array.from(outputs);
      toggleBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        Toggle.single(outputsArray, toggleBtn, storageKey);
      });
    },

    /**
     * Set up click handlers for sync mode (all buttons control all outputs)
     * @param {HTMLElement[]} allOutputs - All output elements in the cell
     * @param {HTMLButtonElement[]} allButtons - All toggle buttons in the cell
     * @param {string|null} storageKey - Optional persistence key
     */
    setupSyncHandlers: function(allOutputs, allButtons, storageKey) {
      for (var i = 0; i < allButtons.length; i++) {
        (function(outputs, buttons, key) {
          buttons[i].addEventListener('click', function(e) {
            e.stopPropagation();
            Toggle.all(outputs, buttons, key);
          });
        })(allOutputs, allButtons, storageKey);
      }
    }
  };

  // ===========================================================================
  // Global Toggle
  // ===========================================================================

  /**
   * Handles the global toggle button that controls all outputs on the page
   */
  var GlobalToggle = {
    /**
     * Initialize the global toggle button if enabled
     */
    init: function() {
      var docElement = document.documentElement;
      if (!docElement.classList.contains(CONFIG.selectors.globalEnabled)) return;
      if (document.querySelector('.' + CONFIG.classes.globalBtn)) return;

      var allOutputs = Array.from(document.querySelectorAll(CONFIG.selectors.toggleOutput));
      var allToggleButtons = Array.from(document.querySelectorAll('.' + CONFIG.classes.toggleBtn));

      if (allOutputs.length === 0) return;

      var persistEnabled = docElement.classList.contains(CONFIG.selectors.persistEnabled);
      var globalStorageKey = persistEnabled ? Storage.createKey('global') : null;
      var buttonText = docElement.dataset.toggleGlobalText || 'Toggle All Outputs';

      var globalBtn = this.createButton(buttonText);

      this.restoreState(globalStorageKey, allOutputs, allToggleButtons, globalBtn);
      this.setupHandler(globalBtn, allOutputs, allToggleButtons, globalStorageKey);

      document.body.appendChild(globalBtn);
    },

    /**
     * Create the global toggle button element
     * @param {string} text - The button label text
     * @returns {HTMLButtonElement} The created button
     */
    createButton: function(text) {
      var btn = document.createElement('button');
      btn.className = CONFIG.classes.globalBtn;
      btn.type = 'button';
      btn.tabIndex = 0;
      btn.textContent = text;
      this.updateButtonState(btn, false);
      Button.addKeyboardSupport(btn);
      return btn;
    },

    /**
     * Update the global button state
     * @param {HTMLButtonElement} btn - The global button
     * @param {boolean} allHidden - Whether all outputs are hidden
     */
    updateButtonState: function(btn, allHidden) {
      btn.classList.toggle(CONFIG.classes.allHidden, allHidden);
      var label = allHidden ? CONFIG.tooltips.showAll : CONFIG.tooltips.hideAll;
      btn.setAttribute('aria-label', label);
      btn.title = label;
    },

    /**
     * Restore persisted global state on page load
     * @param {string|null} storageKey - The persistence key
     * @param {HTMLElement[]} outputs - All output elements
     * @param {HTMLButtonElement[]} buttons - All toggle buttons
     * @param {HTMLButtonElement} globalBtn - The global button
     */
    restoreState: function(storageKey, outputs, buttons, globalBtn) {
      if (!storageKey) return;

      var savedState = Storage.load(storageKey);
      if (savedState === null) return;

      Toggle.setOutputsHidden(outputs, savedState);
      Toggle.updateButtons(buttons, savedState);
      this.updateButtonState(globalBtn, savedState);
    },

    /**
     * Set up click handler for the global button
     * @param {HTMLButtonElement} globalBtn - The global button
     * @param {HTMLElement[]} allOutputs - All output elements
     * @param {HTMLButtonElement[]} allToggleButtons - All toggle buttons
     * @param {string|null} storageKey - Optional persistence key
     */
    setupHandler: function(globalBtn, allOutputs, allToggleButtons, storageKey) {
      var self = this;

      globalBtn.addEventListener('click', function() {
        var newState = Toggle.all(allOutputs, allToggleButtons, storageKey);
        self.updateButtonState(globalBtn, newState);
      });
    }
  };

  // ===========================================================================
  // Initialization
  // ===========================================================================

  /**
   * Initialize the toggle extension
   */
  function init() {
    A11y.init();

    // Process all toggleable cells
    var toggleableCells = document.querySelectorAll(CONFIG.selectors.toggleableCell);
    toggleableCells.forEach(function(cell, index) {
      CellProcessor.process(cell, index);
    });

    // Initialize global toggle if enabled
    GlobalToggle.init();
  }

  // Run when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
