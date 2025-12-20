# Paste - Clipboard History Manager

A macOS application that mimics the Windows clipboard history function. It stores the last 10 copied items and allows you to paste them via a global shortcut.

## Features

- **History**: Stores the last 10 copied text items.
- **Global Shortcut**: Default is `Cmd + Shift + V`.
- **Configurable**: Choose from preset shortcuts in the Settings.
- **Auto-Paste**: Automatically pastes the selected item into the active application.

## Requirements

- macOS 13.0+
- Accessibility Permissions (for pasting functionality)

## How to Build

1. Open `Paste.xcodeproj` in Xcode.
2. Ensure the Signing & Capabilities team is set to your personal team.
3. Build and Run (Cmd + R).

## Permissions

When running the app for the first time:
1. **Accessibility**: The app needs Accessibility permissions to simulate the `Cmd + V` keystroke for pasting. Go to `System Settings -> Privacy & Security -> Accessibility` and enable `Paste`.

## Usage

1. Copy text as usual.
2. Press `Cmd + Shift + V` (or your configured shortcut) to open the history window.
3. Click on an item to paste it into the previously active application.
4. Click the gear icon to change the shortcut.
