document.addEventListener('DOMContentLoaded', function() {
  // Find all cell divs with the toggleable-cell class
  const toggleableCells = document.querySelectorAll('.toggleable-cell');
  
  toggleableCells.forEach(function(cell, cellIndex) {
    
    // Get all direct children of the cell
    const children = Array.from(cell.children);
    
    // Check if outputs should be initially hidden for this cell
    const shouldHideInitially = cell.classList.contains('initially-hidden');
    
    // Check output sync mode for this cell
    const outputSyncOn = cell.classList.contains('output-sync-on');
    const outputSyncOff = cell.classList.contains('output-sync-off');
    
    let pairCount = 0;
    let allOutputSections = []; // Collect all outputs for sync mode
    let allToggleButtons = []; // Collect all toggle buttons for sync mode
    
    // Find code-output pairs by looking for adjacent elements
    for (let i = 0; i < children.length; i++) {
      const currentChild = children[i];
      let codeSection = null;
      let startSearchFrom = i;
      
      // Check if current child is a code section (direct)
      const isDirectCodeSection = currentChild.classList.contains('cell-code') || 
                                 (currentChild.classList.contains('sourceCode') && currentChild.classList.contains('cell-code'));
      
      // Check if current child is a code-fold details element
      const isCodeFold = currentChild.tagName === 'DETAILS' && currentChild.classList.contains('code-fold');
      
      if (isDirectCodeSection) {
        codeSection = currentChild;
      } else if (isCodeFold) {
        // Look inside the details element for the code section
        const nestedCodeSection = currentChild.querySelector('.sourceCode.cell-code, .cell-code');
        if (nestedCodeSection) {
          codeSection = nestedCodeSection;
        }
      }
      
      if (codeSection) {
        // Look for the next output section after this code section
        for (let j = i + 1; j < children.length; j++) {
          const nextChild = children[j];
          
          // Check if it's an output div (any class starting with "cell-output")
          const isOutputSection = nextChild.tagName === 'DIV' && 
                                 Array.from(nextChild.classList).some(cls => cls.startsWith('cell-output'));
          
          if (isOutputSection) {
            pairCount++;
            
            // Create toggle button for this specific code-output pair
            const toggleBtn = document.createElement('button');
            toggleBtn.className = 'code-toggle-btn';
            toggleBtn.setAttribute('aria-label', 'Toggle Output');
            toggleBtn.textContent = 'Output';
            toggleBtn.setAttribute('data-pair', `${cellIndex}-${pairCount}`); // For debugging
            
            // Add the toggle button to the actual code section (whether direct or nested)
            codeSection.appendChild(toggleBtn);
                        
            // Collect outputs and buttons for sync mode
            if (outputSyncOn) {
              allOutputSections.push(nextChild);
              allToggleButtons.push(toggleBtn);
            }
            
            // If outputs should be initially hidden, hide this output and update button state
            if (shouldHideInitially) {
              nextChild.classList.add('hidden');
              toggleBtn.classList.add('output-hidden');
              toggleBtn.setAttribute('aria-label', 'Show Output');
            }
            
            // Add toggle functionality based on output-sync setting
            if (outputSyncOn) {
              // In sync mode, defer event handler setup until after all buttons are collected
              // We'll set up the handlers after this loop
            } else {
              // Individual mode: each button controls only its own output
              (function(outputElement, buttonElement, pairId) {
                buttonElement.addEventListener('click', function(e) {
                  e.stopPropagation();
                                    
                  const isHidden = outputElement.classList.toggle('hidden');
                  
                  buttonElement.classList.toggle('output-hidden', isHidden);
                  buttonElement.setAttribute('aria-label', isHidden ? 'Show Output' : 'Hide Output');
                });
              })(nextChild, toggleBtn, `${cellIndex}-${pairCount}`);
            }
            
            // Found the output for this code block, stop looking
            break;
          }
          
          // If we encounter another code section or code-fold, stop looking
          const isAnotherCodeSection = nextChild.classList.contains('cell-code') || 
                                      (nextChild.classList.contains('sourceCode') && nextChild.classList.contains('cell-code'));
          const isAnotherCodeFold = nextChild.tagName === 'DETAILS' && nextChild.classList.contains('code-fold');
          
          if (isAnotherCodeSection || isAnotherCodeFold) {
            break;
          }
        }
      }
    }
    
    // Set up event handlers for sync mode after collecting all outputs and buttons
    if (outputSyncOn && allToggleButtons.length > 0) {
      
      allToggleButtons.forEach(function(button, buttonIndex) {
        button.addEventListener('click', function(e) {
          e.stopPropagation();
                    
          // Check if all outputs are currently hidden
          let allHidden = allOutputSections.every(output => output.classList.contains('hidden'));
          
          // Toggle all outputs to the opposite state
          allOutputSections.forEach(function(output) {
            if (allHidden) {
              output.classList.remove('hidden');
            } else {
              output.classList.add('hidden');
            }
          });
          
          // Update all button states
          allToggleButtons.forEach(function(btn) {
            if (allHidden) {
              btn.classList.remove('output-hidden');
              btn.setAttribute('aria-label', 'Hide Output');
            } else {
              btn.classList.add('output-hidden');
              btn.setAttribute('aria-label', 'Show Output');
            }
          });
        });
      });
    }
  });
});