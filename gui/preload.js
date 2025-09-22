const { contextBridge, ipcRenderer } = require('electron');

console.log('Preload script loaded');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  // Authentication
  requestSudo: () => ipcRenderer.invoke('request-sudo'),
  
  // Run htotheizzo with options
  runHtotheizzo: (options) => ipcRenderer.invoke('run-htotheizzo', options),
  
  // Dialog methods
  showError: (title, content) => ipcRenderer.invoke('show-error', title, content),
  showMessage: (options) => ipcRenderer.invoke('show-message', options),
  
  // Listen for real-time output
  onHtotheizzo: (callback) => {
    const subscription = (event, data) => callback(data);
    ipcRenderer.on('htotheizzo-output', subscription);
    
    // Return unsubscribe function
    return () => {
      ipcRenderer.removeListener('htotheizzo-output', subscription);
    };
  }
});

console.log('electronAPI exposed to main world');
