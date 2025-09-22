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
    
    // DOM elements
    const statusEl = document.getElementById('status');
    const runUpdateBtn = document.getElementById('runUpdate');
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
        const checkboxes = document.querySelectorAll('input[type="checkbox"]');
        
        checkboxes.forEach(checkbox => {
            if (!checkbox.checked) {
                options[checkbox.id] = '1';
            }
        });
        
        return options;
    }
    
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
