# WinList

A lightweight native window switcher for macOS. Press `Fn + Space`, choose a window, and switch to it without leaving the keyboard.

## Features

- Lists open and minimized windows across macOS Spaces
- Highlights the currently focused window
- Supports keyboard navigation and single-click selection
- Runs as a menu bar app without a Dock icon
- Uses only native AppKit, SwiftUI, and Accessibility APIs

## Requirements

- macOS 13 or later
- Accessibility permission

## Build and run

```bash
./Scripts/build-app.sh
open dist/WinList.app
```

On first launch, enable WinList in **System Settings → Privacy & Security → Accessibility**.

## Controls

| Input | Action |
| --- | --- |
| `Fn + Space` | Show or hide WinList |
| Arrow keys | Select a window |
| `Enter` | Activate the selected window |
| Mouse click | Activate a window |
| `Escape` | Close WinList |

To start WinList automatically, add the built app under **System Settings → General → Login Items & Extensions**.

## Development

```bash
swift test
swift run WinList
```
