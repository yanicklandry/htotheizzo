const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const { exec } = require('child_process');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
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
    // First request sudo access
    await requestSudoAccess();
    
    // Then run htotheizzo
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
  const commands = [
    'brew', 'port', 'mas', 'snap', 'flatpak', 'nix-env',
    'npm', 'yarn', 'pnpm', 'bun', 'deno',
    'pip', 'pip3', 'pipenv', 'poetry', 'pdm', 'uv', 'conda', 'mamba',
    'gem', 'rvm',
    'rustup', 'cargo', 'go', 'composer', 'cpan',
    'asdf', 'mise', 'nvm', 'nodenv', 'pyenv', 'rbenv', 'goenv', 'jenv', 'sdk', 'tfenv',
    'docker', 'helm', 'kubectl', 'gh', 'gcloud', 'aws', 'az',
    'code', 'pod', 'flutter',
    'antibody', 'fisher', 'starship',
    'kav', 'apm'
  ];

  const detectionResults = {};

  for (const cmd of commands) {
    try {
      await new Promise((resolve, reject) => {
        exec(`command -v ${cmd}`, (error) => {
          if (error) {
            detectionResults[cmd] = false;
            resolve();
          } else {
            detectionResults[cmd] = true;
            resolve();
          }
        });
      });
    } catch (error) {
      detectionResults[cmd] = false;
    }
  }

  // Special cases for macOS-specific commands
  if (process.platform === 'darwin') {
    detectionResults['spotlight'] = true;
    detectionResults['launchpad'] = true;
  } else {
    detectionResults['spotlight'] = false;
    detectionResults['launchpad'] = false;
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

  return detectionResults;
});
