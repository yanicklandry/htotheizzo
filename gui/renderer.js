const { ipcRenderer } = require('electron');

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
    const skipOptions = getSkipOptions();
    
    setLoading(true);
    setStatus('Running updates...', 'info');
    clearOutput();
    showOutput();
    
    try {
        const result = await ipcRenderer.invoke('run-htotheizzo', skipOptions);
        
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
        setStatus(`Error: ${error.message}`, 'error');
        appendOutput(`Error: ${error.message}\n`);
    }
    
    setLoading(false);
});

// Listen for real-time output from htotheizzo
ipcRenderer.on('htotheizzo-output', (event, data) => {
    appendOutput(data);
});