// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
    // Access the secure API exposed via preload script
    const electronAPI = window.electronAPI;
    
    // Debug: Check if electronAPI is available
    if (!electronAPI) {
        console.error('electronAPI is not available. Check preload script.');
        document.getElementById('status').textContent = 'Error: electronAPI not loaded';
        document.getElementById('status').className = 'status error';
        return;
    }
    
    console.log('electronAPI loaded successfully:', Object.keys(electronAPI));
    
    // Detect available commands and grey out undetected ones
    async function detectAndMarkCommands() {
        try {
            const detectionResults = await electronAPI.detectCommands();
            console.log('Command detection results:', detectionResults);
            
            // Iterate through all checkboxes and mark undetected commands
            const checkboxes = document.querySelectorAll('input[type="checkbox"]');
            checkboxes.forEach(checkbox => {
                const commandName = checkbox.id.replace('skip_', '');
                const optionDiv = checkbox.closest('.option');
                
                if (detectionResults[commandName] === false) {
                    // Command not detected - grey it out
                    optionDiv.classList.add('undetected');
                    checkbox.disabled = true;
                    checkbox.checked = false;
                } else if (detectionResults[commandName] === true) {
                    // Command detected - ensure it's enabled
                    optionDiv.classList.remove('undetected');
                    checkbox.disabled = false;
                }
            });
        } catch (error) {
            console.error('Error detecting commands:', error);
        }
    }
    
    // Run detection on page load
    detectAndMarkCommands();
    
    // DOM elements
    const statusEl = document.getElementById('status');
    const runUpdateBtn = document.getElementById('runUpdate');
    const unselectAllBtn = document.getElementById('unselectAll');
    const loadingEl = document.getElementById('loading');
    const outputEl = document.getElementById('output');
    
    // Status management
    function setStatus(message, type = 'info') {
        statusEl.textContent = message;
        statusEl.className = `status ${type}`;
    }
    
    function setLoading(isLoading) {
        loadingEl.style.display = isLoading ? 'block' : 'none';
        runUpdateBtn.disabled = isLoading;
    }
    
    function showOutput() {
        outputEl.style.display = 'block';
    }
    
    function appendOutput(text) {
        outputEl.textContent += text;
        outputEl.scrollTop = outputEl.scrollHeight;
    }
    
    function clearOutput() {
        outputEl.textContent = '';
    }
    
    // Collect skip options from checkboxes (send skip variable when unchecked)
    function getSkipOptions() {
        const options = {};
        const checkboxes = document.querySelectorAll('input[type="checkbox"]:not(#mockMode)');

        checkboxes.forEach(checkbox => {
            if (!checkbox.checked) {
                options[checkbox.id] = '1';
            }
        });

        // Add mock mode if checked
        const mockModeCheckbox = document.getElementById('mockMode');
        if (mockModeCheckbox && mockModeCheckbox.checked) {
            options['MOCK_MODE'] = '1';
        }

        return options;
    }
    
    // Unselect all checkboxes
    unselectAllBtn.addEventListener('click', () => {
        const checkboxes = document.querySelectorAll('input[type="checkbox"]:not(:disabled):not(#mockMode)');
        checkboxes.forEach(checkbox => {
            checkbox.checked = false;
        });
        setStatus('All available package managers unselected', 'info');
    });

    // Run updates
    runUpdateBtn.addEventListener('click', async () => {
        console.log('Run Updates button clicked');
        
        const skipOptions = getSkipOptions();
        console.log('Skip options:', skipOptions);
        
        setLoading(true);
        setStatus('Running updates...', 'info');
        clearOutput();
        showOutput();
        
        try {
            const result = await electronAPI.runHtotheizzo(skipOptions);
            
            if (result.success) {
                setStatus('Updates completed successfully! ✓', 'success');
            } else {
                setStatus(`Updates failed: ${result.error.code || result.error}`, 'error');
                if (result.error.output) {
                    appendOutput('\n--- Error Output ---\n');
                    appendOutput(result.error.output);
                }
                if (result.error.errorOutput) {
                    appendOutput('\n--- Error Details ---\n');
                    appendOutput(result.error.errorOutput);
                }
            }
        } catch (error) {
            console.error('Error running htotheizzo:', error);
            setStatus(`Error: ${error.message}`, 'error');
            appendOutput(`Error: ${error.message}\n`);
        }
        
        setLoading(false);
    });
    
    // Listen for real-time output from htotheizzo
    if (electronAPI.onHtotheizzo) {
        electronAPI.onHtotheizzo((data) => {
            appendOutput(data);
        });
    } else {
        console.error('onHtotheizzo method not available');
    }
});
