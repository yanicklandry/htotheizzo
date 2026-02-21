const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const { exec } = require('child_process');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 600,
    height: 670,
    resizable: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  mainWindow.loadFile('index.html');

  // Open DevTools in development mode
  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools();
  }

  // Clear cache to avoid stale code issues
  mainWindow.webContents.session.clearCache();
}

// Request sudo authentication using native dialog with Touch ID support
function requestSudoAccess() {
  return new Promise((resolve, reject) => {
    const sudo = spawn('sudo', ['-v']);
    
    sudo.on('close', (code) => {
      if (code === 0) {
        resolve('Authentication successful');
      } else {
        reject('Authentication failed');
      }
    });
    
    sudo.on('error', (err) => {
      reject(`Failed to start authentication: ${err.message}`);
    });
  });
}

// Run htotheizzo script
function runHtotheizzo(options = {}) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(__dirname, '..', 'htotheizzo.sh');
    const env = { ...process.env, ...options };
    
    const htotheizzo = spawn(scriptPath, [], {
      env,
      shell: true
    });
    
    let output = '';
    let errorOutput = '';
    
    htotheizzo.stdout.on('data', (data) => {
      output += data.toString();
      mainWindow.webContents.send('htotheizzo-output', data.toString());
    });
    
    htotheizzo.stderr.on('data', (data) => {
      errorOutput += data.toString();
      mainWindow.webContents.send('htotheizzo-output', data.toString());
    });
    
    htotheizzo.on('close', (code) => {
      if (code === 0) {
        resolve({ output, errorOutput });
      } else {
        reject({ code, output, errorOutput });
      }
    });
    
    htotheizzo.on('error', (err) => {
      reject({ error: err.message, output, errorOutput });
    });
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

// IPC handlers
ipcMain.handle('request-sudo', async () => {
  try {
    await requestSudoAccess();
    return { success: true };
  } catch (error) {
    return { success: false, error };
  }
});

ipcMain.handle('run-htotheizzo', async (event, options) => {
  try {
    const result = await runHtotheizzo(options);
    return { success: true, ...result };
  } catch (error) {
    return { success: false, error };
  }
});

ipcMain.handle('show-error', async (event, title, content) => {
  await dialog.showErrorBox(title, content);
});

ipcMain.handle('show-message', async (event, options) => {
  const result = await dialog.showMessageBox(mainWindow, options);
  return result;
});

ipcMain.handle('detect-commands', async () => {
  // Map of checkbox IDs (without skip_ prefix) to actual command names
  const commandMap = {
    'brew': 'brew',
    'port': 'port',
    'mas': 'mas',
    'snap': 'snap',
    'flatpak': 'flatpak',
    'nix_env': 'nix-env',
    'npm': 'npm',
    'yarn': 'yarn',
    'pnpm': 'pnpm',
    'bun': 'bun',
    'deno': 'deno',
    'pip': 'pip',
    'pip3': 'pip3',
    'pipenv': 'pipenv',
    'poetry': 'poetry',
    'pdm': 'pdm',
    'uv': 'uv',
    'conda': 'conda',
    'mamba': 'mamba',
    'gem': 'gem',
    'rvm': 'rvm',
    'rustup': 'rustup',
    'cargo': 'cargo',
    'go': 'go',
    'composer': 'composer',
    'cpan': 'cpan',
    'asdf': 'asdf',
    'mise': 'mise',
    'nvm': 'nvm',
    'nodenv': 'nodenv',
    'pyenv': 'pyenv',
    'rbenv': 'rbenv',
    'goenv': 'goenv',
    'jenv': 'jenv',
    'sdk': 'sdk',
    'tfenv': 'tfenv',
    'docker': 'docker',
    'helm': 'helm',
    'kubectl': 'kubectl',
    'gh': 'gh',
    'gcloud': 'gcloud',
    'aws': 'aws',
    'az': 'az',
    'code': 'code',
    'pod': 'pod',
    'flutter': 'flutter',
    'antibody': 'antibody',
    'fisher': 'fisher',
    'starship': 'starship',
    'kav': 'kav',
    'apm': 'apm',
    'xcode_select': 'xcode-select',
    'softwareupdate': 'softwareupdate',
    'self_update': 'git',  // Check for git since self-update uses git
  };

  const detectionResults = {};

  for (const [checkboxId, actualCommand] of Object.entries(commandMap)) {
    try {
      await new Promise((resolve, reject) => {
        exec(`command -v ${actualCommand}`, (error) => {
          if (error) {
            detectionResults[checkboxId] = false;
            resolve();
          } else {
            detectionResults[checkboxId] = true;
            resolve();
          }
        });
      });
    } catch (error) {
      detectionResults[checkboxId] = false;
    }
  }

  // Special cases for macOS-specific commands
  if (process.platform === 'darwin') {
    detectionResults['spotlight'] = true;
    detectionResults['launchpad'] = true;
    detectionResults['disk_maintenance'] = true;  // Uses diskutil, always available on macOS
    detectionResults['system_maintenance'] = true;  // Uses periodic, always available on macOS
  } else {
    detectionResults['spotlight'] = false;
    detectionResults['launchpad'] = false;
    detectionResults['disk_maintenance'] = false;
    detectionResults['system_maintenance'] = false;
  }

  // Special detection for Oh My Zsh (check for directory instead of command)
  try {
    await new Promise((resolve) => {
      exec('test -d ~/.oh-my-zsh', (error) => {
        detectionResults['omz'] = !error;
        resolve();
      });
    });
  } catch (error) {
    detectionResults['omz'] = false;
  }

  // New feature detection
  detectionResults['disk_check'] = true;  // Always available (uses df)
  detectionResults['network_check'] = true;  // Always available (uses ping)
  detectionResults['uptime_check'] = true;  // Always available (uses uptime)
  detectionResults['backup_warning'] = true;  // Always available
  detectionResults['load_check'] = true;  // Always available
  detectionResults['browser_cache'] = true;  // Always available
  detectionResults['file_logging'] = true;  // Always available
  detectionResults['size_estimate'] = true;  // Always available

  // AppImage (Linux only)
  detectionResults['appimage'] = process.platform === 'linux';

  // Desktop notifications
  if (process.platform === 'darwin') {
    detectionResults['notifications'] = true;  // macOS has osascript
  } else if (process.platform === 'linux') {
    try {
      await new Promise((resolve) => {
        exec('command -v notify-send', (error) => {
          detectionResults['notifications'] = !error;
          resolve();
        });
      });
    } catch (error) {
      detectionResults['notifications'] = false;
    }
  } else {
    detectionResults['notifications'] = false;
  }

  return detectionResults;
});
