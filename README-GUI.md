# htotheizzo GUI

A modern Electron-based GUI for the htotheizzo system update automation tool.

## Quick Start

```bash
# Launch the GUI
./htotheizzo-gui.sh

# Development mode (with DevTools)
./htotheizzo-gui.sh --dev
```

## Features

- **Cross-platform**: Works on macOS, Linux, and Windows
- **Real-time output**: See update progress live in the GUI
- **Selective updates**: Choose which package managers to update
- **OS Native Authentication**: Uses system password dialogs
- **Modern UI**: Dark theme with intuitive controls
- **Keyboard shortcuts**: Quick access to common actions

## Authentication

The GUI uses your operating system's native authentication dialogs instead of custom password prompts. When administrator privileges are needed, you'll see a system dialog asking for your password.

## Installation

First time setup will automatically install dependencies when you run the GUI launcher.

Requirements:
- Node.js (v16 or later)
- npm

## Usage

1. **Select Updates**: Check/uncheck boxes for package managers you want
2. **Click "Run Selected"**: Only selected items will update  
3. **System Authentication**: OS will prompt for password if needed
4. **View Progress**: Real-time output shows update status

Choose terminal (`./htotheizzo.sh`) for automation, GUI for interactive use.