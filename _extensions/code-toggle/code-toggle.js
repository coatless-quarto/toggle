document.addEventListener('DOMContentLoaded', function() {
  // Find all cell divs with the toggleable-cell class
  const toggleableCells = document.querySelectorAll('.toggleable-cell');
  
  toggleableCells.forEach(function(cell) {
    // Find the source code section and the output portion
    const codeSection = cell.querySelector('.cell-code');
    const outputSection = cell.querySelector('.cell-output');
    
    if (outputSection && codeSection) {
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
        const isHidden = outputSection.classList.toggle('hidden');
        toggleBtn.classList.toggle('output-hidden', isHidden);
        toggleBtn.setAttribute('aria-label', isHidden ? 'Show Output' : 'Hide Output');
      });
    }
  });
});