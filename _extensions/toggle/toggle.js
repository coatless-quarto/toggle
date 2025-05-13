document.addEventListener('DOMContentLoaded', function() {
  // Find all cell divs with the toggleable-cell class
  const toggleableCells = document.querySelectorAll('.toggleable-cell');
  
  toggleableCells.forEach(function(cell) {
    // Find the source code section
    const codeSection = cell.querySelector('.cell-code');
    
    // Find any type of output (text or graphical)
    // This covers both .cell-output, .cell-output-stdout, and .cell-output-display
    const outputSections = cell.querySelectorAll('[class^="cell-output"]');
    
    if (outputSections.length > 0 && codeSection) {
      // Create toggle button
      const toggleBtn = document.createElement('button');
      toggleBtn.className = 'code-toggle-btn';
      toggleBtn.setAttribute('aria-label', 'Toggle Output');
      toggleBtn.textContent = 'Output';
      
      // Add the toggle button to the code section
      codeSection.appendChild(toggleBtn);
      
      // Add toggle functionality
      toggleBtn.addEventListener('click', function(e) {
        e.stopPropagation(); // Prevent triggering other click events
        
        let allHidden = true;
        
        // Toggle visibility for all output sections
        outputSections.forEach(function(section) {
          const isHidden = section.classList.toggle('hidden');
          // If any section is not hidden, allHidden should be false
          if (!isHidden) {
            allHidden = false;
          }
        });
        
        // Update button state based on whether all outputs are hidden
        toggleBtn.classList.toggle('output-hidden', allHidden);
        toggleBtn.setAttribute('aria-label', allHidden ? 'Show Output' : 'Hide Output');
      });
    }
  });
});