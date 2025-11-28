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

    // All available package managers organized by category
    const packageManagers = [
        // System Packages
        { id: 'brew', label: 'Homebrew', category: 'System' },
        { id: 'port', label: 'MacPorts', category: 'System' },
        { id: 'mas', label: 'Mac App Store', category: 'System' },
        { id: 'snap', label: 'Snap', category: 'System' },
        { id: 'flatpak', label: 'Flatpak', category: 'System' },
        { id: 'nix_env', label: 'Nix', category: 'System' },

        // JavaScript/Node.js
        { id: 'npm', label: 'npm', category: 'JavaScript' },
        { id: 'yarn', label: 'yarn', category: 'JavaScript' },
        { id: 'pnpm', label: 'pnpm', category: 'JavaScript' },
        { id: 'bun', label: 'Bun', category: 'JavaScript' },
        { id: 'deno', label: 'Deno', category: 'JavaScript' },
        { id: 'nvm', label: 'nvm', category: 'JavaScript' },
        { id: 'nodenv', label: 'nodenv', category: 'JavaScript' },

        // Python
        { id: 'pip', label: 'pip', category: 'Python' },
        { id: 'pip3', label: 'pip3', category: 'Python' },
        { id: 'pipenv', label: 'pipenv', category: 'Python' },
        { id: 'poetry', label: 'Poetry', category: 'Python' },
        { id: 'pdm', label: 'PDM', category: 'Python' },
        { id: 'uv', label: 'uv', category: 'Python' },
        { id: 'conda', label: 'Conda', category: 'Python' },
        { id: 'mamba', label: 'Mamba', category: 'Python' },
        { id: 'pyenv', label: 'pyenv', category: 'Python' },

        // Ruby
        { id: 'gem', label: 'gem', category: 'Ruby' },
        { id: 'rvm', label: 'rvm', category: 'Ruby' },
        { id: 'rbenv', label: 'rbenv', category: 'Ruby' },

        // Other Languages
        { id: 'rustup', label: 'Rust', category: 'Languages' },
        { id: 'cargo', label: 'Cargo', category: 'Languages' },
        { id: 'go', label: 'Go', category: 'Languages' },
        { id: 'composer', label: 'PHP/Composer', category: 'Languages' },
        { id: 'cpan', label: 'Perl/CPAN', category: 'Languages' },

        // Version Managers
        { id: 'asdf', label: 'asdf', category: 'Version Managers' },
        { id: 'mise', label: 'mise', category: 'Version Managers' },
        { id: 'goenv', label: 'goenv', category: 'Version Managers' },
        { id: 'jenv', label: 'jenv', category: 'Version Managers' },
        { id: 'sdk', label: 'SDKMAN', category: 'Version Managers' },
        { id: 'tfenv', label: 'tfenv', category: 'Version Managers' },

        // Cloud & Infrastructure
        { id: 'docker', label: 'Docker', category: 'Cloud' },
        { id: 'helm', label: 'Helm', category: 'Cloud' },
        { id: 'kubectl', label: 'kubectl', category: 'Cloud' },
        { id: 'gh', label: 'GitHub CLI', category: 'Cloud' },
        { id: 'gcloud', label: 'Google Cloud', category: 'Cloud' },
        { id: 'aws', label: 'AWS CLI', category: 'Cloud' },
        { id: 'az', label: 'Azure CLI', category: 'Cloud' },

        // Development Tools
        { id: 'code', label: 'VS Code', category: 'Dev Tools' },
        { id: 'pod', label: 'CocoaPods', category: 'Dev Tools' },
        { id: 'flutter', label: 'Flutter', category: 'Dev Tools' },

        // Shell & Terminal
        { id: 'omz', label: 'Oh My Zsh', category: 'Shell' },
        { id: 'antibody', label: 'Antibody', category: 'Shell' },
        { id: 'fisher', label: 'Fisher', category: 'Shell' },
        { id: 'starship', label: 'Starship', category: 'Shell' },

        // macOS System
        { id: 'xcode_select', label: 'Xcode Tools', category: 'macOS' },
        { id: 'softwareupdate', label: 'Software Update', category: 'macOS' },
        { id: 'disk_maintenance', label: 'Disk Maintenance', category: 'macOS' },
        { id: 'system_maintenance', label: 'System Maintenance', category: 'macOS' },
        { id: 'spotlight', label: 'Spotlight Rebuild', category: 'macOS' },
        { id: 'launchpad', label: 'Launchpad Reset', category: 'macOS' },

        // Other
        { id: 'self_update', label: 'Self-Update', category: 'Other' },
        { id: 'kav', label: 'Kaspersky', category: 'Other' },
        { id: 'apm', label: 'Atom', category: 'Other' }
    ];

    // Populate options grid dynamically
    const optionsGrid = document.getElementById('optionsGrid');
    packageManagers.forEach(pm => {
        const optionDiv = document.createElement('div');
        optionDiv.className = 'option';
        optionDiv.innerHTML = `
            <input type="checkbox" id="skip_${pm.id}" checked />
            <label for="skip_${pm.id}">${pm.label}</label>
        `;
        optionsGrid.appendChild(optionDiv);
    });

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
    const selectAllBtn = document.getElementById('selectAll');
    const outputEl = document.getElementById('output');
    const progressContainer = document.getElementById('progressContainer');
    const progressFill = document.getElementById('progressFill');
    const progressText = document.getElementById('progressText');
    const advancedToggle = document.getElementById('advancedToggle');
    const advancedContent = document.getElementById('advancedContent');
    const terminalToggle = document.getElementById('terminalToggle');

    // Toggle handlers
    advancedToggle.addEventListener('click', () => {
        const icon = advancedToggle.querySelector('.toggle-icon');
        advancedContent.classList.toggle('open');
        icon.classList.toggle('open');
    });

    terminalToggle.addEventListener('click', () => {
        const icon = terminalToggle.querySelector('.toggle-icon');
        outputEl.classList.toggle('visible');
        icon.classList.toggle('open');
    });

    // Status management
    function setStatus(message, type = 'info') {
        statusEl.textContent = message;
        statusEl.className = `status ${type}`;
    }

    function showProgress() {
        progressContainer.style.display = 'block';
    }

    function hideProgress() {
        progressContainer.style.display = 'none';
    }

    function updateProgress(percent, text) {
        progressFill.style.width = percent + '%';
        progressText.textContent = text;
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

    // Select/Unselect all checkboxes
    unselectAllBtn.addEventListener('click', () => {
        const checkboxes = document.querySelectorAll('input[type="checkbox"]:not(:disabled)');
        checkboxes.forEach(checkbox => {
            checkbox.checked = false;
        });
        setStatus('All available package managers unselected', 'info');
    });

    selectAllBtn.addEventListener('click', () => {
        const checkboxes = document.querySelectorAll('input[type="checkbox"]:not(:disabled)');
        checkboxes.forEach(checkbox => {
            checkbox.checked = true;
        });
        setStatus('All available package managers selected', 'info');
    });

    // Progress simulation based on output
    let progressPercent = 0;
    let updateCount = 0;
    let estimatedTotalUpdates = 20; // Will be calculated based on enabled options

    function calculateTotalUpdates() {
        // Count only enabled (checked) package managers
        const enabledCheckboxes = document.querySelectorAll('input[type="checkbox"]:checked:not(:disabled)');
        // Each package manager typically has 1-2 update operations
        return Math.max(1, enabledCheckboxes.length * 1.5);
    }

    function simulateProgress(outputText) {
        // Increment progress based on output
        if (outputText.includes('Updating') || outputText.includes('Installing') ||
            outputText.includes('Upgrading') || outputText.includes('Cleaning')) {
            updateCount++;
            progressPercent = Math.min(95, (updateCount / estimatedTotalUpdates) * 100);

            // Extract current operation
            const lines = outputText.trim().split('\n');
            const lastLine = lines[lines.length - 1];
            updateProgress(progressPercent, lastLine.substring(0, 50) + '...');
        }
    }

    // Run updates
    runUpdateBtn.addEventListener('click', async () => {
        console.log('Run Updates button clicked');

        const skipOptions = getSkipOptions();
        console.log('Skip options:', skipOptions);

        runUpdateBtn.disabled = true;
        setStatus('Running updates...', 'info');
        clearOutput();
        showProgress();
        updateProgress(0, 'Initializing...');
        progressPercent = 0;
        updateCount = 0;

        // Calculate total updates based on enabled options
        estimatedTotalUpdates = calculateTotalUpdates();
        console.log('Estimated total updates:', estimatedTotalUpdates);

        try {
            const result = await electronAPI.runHtotheizzo(skipOptions);

            if (result.success) {
                updateProgress(100, 'Complete!');
                setStatus('Updates completed successfully!', 'success');
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

        runUpdateBtn.disabled = false;
        // Keep progress bar displayed after completion
    });

    // Listen for real-time output from htotheizzo
    if (electronAPI.onHtotheizzo) {
        electronAPI.onHtotheizzo((data) => {
            appendOutput(data);
            simulateProgress(data);
        });
    } else {
        console.error('onHtotheizzo method not available');
    }
});
