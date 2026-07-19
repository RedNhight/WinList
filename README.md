# WinList

A lightweight native window switcher for macOS. It replaces the app-based `Command + Tab` switcher with window-level navigation.

## Features

- Lists open and minimized windows across macOS Spaces
- Replaces `Command + Tab` while WinList is running
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
| `Command + Tab` | Show WinList and select the next window |
| `Command + Shift + Tab` | Select the previous window |
| Release `Command` | Activate the selected window |
| `Fn + Space` | Show or hide WinList without cycling |
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
