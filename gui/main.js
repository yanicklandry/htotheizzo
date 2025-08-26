const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const { spawn } = require('child_process');
const path = require('path');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('index.html');
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