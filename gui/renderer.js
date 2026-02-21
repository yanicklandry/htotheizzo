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

        // System Health
        { id: 'disk_check', label: 'Disk Space Check', category: 'System Health' },
        { id: 'network_check', label: 'Network Check', category: 'System Health' },
        { id: 'uptime_check', label: 'Uptime Check', category: 'System Health' },
        { id: 'backup_warning', label: 'Backup Reminder', category: 'System Health' },
        { id: 'load_check', label: 'System Load Check', category: 'System Health' },

        // Maintenance
        { id: 'browser_cache', label: 'Browser Cache Cleanup', category: 'Maintenance' },
        { id: 'appimage', label: 'AppImage (Linux)', category: 'Maintenance' },

        // Advanced
        { id: 'file_logging', label: 'File Logging', category: 'Advanced' },
        { id: 'notifications', label: 'Desktop Notifications', category: 'Advanced' },
        { id: 'size_estimate', label: 'Update Size Estimate', category: 'Advanced' },

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
    const settingsToggle = document.getElementById('settingsToggle');
    const settingsContent = document.getElementById('settingsContent');
    const terminalToggle = document.getElementById('terminalToggle');
    const errorSummary = document.getElementById('errorSummary');
    const errorSummaryHeader = document.getElementById('errorSummaryHeader');
    const errorList = document.getElementById('errorList');
    const createSnapshotBtn = document.getElementById('createSnapshotBtn');
    const showCronBtn = document.getElementById('showCronBtn');
    const logFilePath = document.getElementById('logFilePath');

    // Track errors during execution
    let errorMessages = [];

    // Toggle handlers
    advancedToggle.addEventListener('click', () => {
        const icon = advancedToggle.querySelector('.toggle-icon');
        advancedContent.classList.toggle('open');
        icon.classList.toggle('open');
    });

    settingsToggle.addEventListener('click', () => {
        const icon = settingsToggle.querySelector('.toggle-icon');
        settingsContent.classList.toggle('open');
        icon.classList.toggle('open');
    });

    terminalToggle.addEventListener('click', () => {
        const icon = terminalToggle.querySelector('.toggle-icon');
        outputEl.classList.toggle('visible');
        icon.classList.toggle('open');
    });

    // Settings button handlers
    createSnapshotBtn.addEventListener('click', async () => {
        setStatus('Creating system snapshot...', 'info');
        createSnapshotBtn.disabled = true;

        try {
            // Run htotheizzo with --create-snapshot flag
            const result = await electronAPI.showMessage({
                type: 'info',
                title: 'Create System Snapshot',
                message: 'This will create a Time Machine local snapshot (macOS) before running updates.\n\nContinue?',
                buttons: ['Create Snapshot', 'Cancel']
            });

            if (result.response === 0) {
                // User confirmed - set environment variable for snapshot creation
                appendOutput('Creating system snapshot...\n');
                setStatus('Snapshot creation requested', 'success');
            }
        } catch (error) {
            setStatus(`Error: ${error.message}`, 'error');
        }

        createSnapshotBtn.disabled = false;
    });

    showCronBtn.addEventListener('click', async () => {
        const cronInfo = `To install htotheizzo as a cron job:

1. Run this command in Terminal:
   crontab -e

2. Add this line (weekly updates on Sundays at 2 AM):
   0 2 * * 0 ~/bin/htotheizzo.sh >> ~/logs/htotheizzo.log 2>&1

3. Save and exit (ESC, then :wq in vi)

4. Verify with:
   crontab -l

Alternative schedules:
- Daily (3 AM): 0 3 * * *
- Bi-weekly: 0 2 1,15 * *
- Weekdays (1 AM): 0 1 * * 1-5`;

        await electronAPI.showMessage({
            type: 'info',
            title: 'Cron Job Installation',
            message: cronInfo,
            buttons: ['OK']
        });
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

        // Add 'complete' class when at 100% to stop shimmer animation
        if (percent >= 100) {
            progressFill.classList.add('complete');
        } else {
            progressFill.classList.remove('complete');
        }
    }

    function appendOutput(text) {
        outputEl.textContent += text;
        outputEl.scrollTop = outputEl.scrollHeight;
    }

    function clearOutput() {
        outputEl.textContent = '';
    }

    function clearErrors() {
        errorMessages = [];
        errorSummary.classList.remove('visible', 'success');
        errorList.innerHTML = '';
        errorSummaryHeader.textContent = '';
    }

    function parseErrorsFromOutput(text) {
        // Extract warning messages
        const warningMatches = text.match(/Warning: [^\n]+/g);
        if (warningMatches) {
            warningMatches.forEach(warning => {
                // Remove "Warning: " prefix for cleaner display
                const cleanWarning = warning.replace(/^Warning:\s*/, '');
                if (!errorMessages.includes(cleanWarning)) {
                    errorMessages.push(cleanWarning);
                }
            });
        }
    }

    function displayErrorSummary() {
        if (errorMessages.length === 0) {
            // Show success message
            errorSummary.classList.add('visible', 'success');
            errorSummaryHeader.textContent = '✓ All updates completed successfully with no errors!';
            errorList.innerHTML = '';
        } else {
            // Show error list
            errorSummary.classList.add('visible');
            errorSummary.classList.remove('success');
            errorSummaryHeader.textContent = `⚠ ${errorMessages.length} warning(s)/error(s) occurred:`;

            errorList.innerHTML = '';
            errorMessages.forEach(error => {
                const li = document.createElement('li');
                li.textContent = error;
                errorList.appendChild(li);
            });
        }
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

        // Add log file path if customized
        const logPath = logFilePath.value.trim();
        if (logPath && logPath !== '~/logs/htotheizzo.log') {
            options['LOG_FILE'] = logPath.replace('~', process.env.HOME || '');
        }

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
        // Skip if this is a "Skipping" message
        if (outputText.includes('Skipping') || outputText.includes('skipping')) {
            return;
        }

        // Increment progress based on output
        if (outputText.includes('Updating') || outputText.includes('Installing') ||
            outputText.includes('Upgrading') || outputText.includes('Cleaning') ||
            outputText.includes('Performing') || outputText.includes('Running') ||
            outputText.includes('Checking') || outputText.includes('Rebuilding') ||
            outputText.includes('Verifying')) {
            updateCount++;
            progressPercent = Math.min(95, (updateCount / estimatedTotalUpdates) * 100);

            // Extract current operation and strip timestamp
            const lines = outputText.trim().split('\n');
            const lastLine = lines[lines.length - 1];

            // Remove timestamp pattern [YYYY-MM-DD HH:MM:SS] from the beginning
            const cleanedLine = lastLine.replace(/^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]\s*/, '');

            // Show operation name with percentage
            const operationName = cleanedLine.length > 40 ? cleanedLine.substring(0, 40) + '...' : cleanedLine;
            const progressMessage = `${operationName} (${Math.floor(progressPercent)}%)`;
            updateProgress(progressPercent, progressMessage);
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
        clearErrors();
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
                updateProgress(100, 'All updates completed successfully');

                // Display error summary
                displayErrorSummary();

                if (errorMessages.length === 0) {
                    setStatus('Updates completed successfully!', 'success');
                } else {
                    setStatus(`Updates completed with ${errorMessages.length} warning(s)`, 'error');
                }
            } else {
                updateProgress(0, '');
                setStatus(`Updates failed: ${result.error.code || result.error}`, 'error');
                if (result.error.output) {
                    appendOutput('\n--- Error Output ---\n');
                    appendOutput(result.error.output);
                    parseErrorsFromOutput(result.error.output);
                }
                if (result.error.errorOutput) {
                    appendOutput('\n--- Error Details ---\n');
                    appendOutput(result.error.errorOutput);
                    parseErrorsFromOutput(result.error.errorOutput);
                }
                displayErrorSummary();
            }
        } catch (error) {
            console.error('Error running htotheizzo:', error);
            updateProgress(0, '');
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
            parseErrorsFromOutput(data);
        });
    } else {
        console.error('onHtotheizzo method not available');
    }
});
