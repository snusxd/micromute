<p align="center">
  <img src="assets/Assets.xcassets/AppIcon.appiconset/appicon_128.png" alt="micromute icon" width="128" height="128" />
</p>

<h1 align="center">micromute</h1>

<p align="center">Minimal macOS menu-bar app to mute/unmute the default microphone with a hotkey and a small on-screen indicator.</p>

## Unique Features

- One-click hotkey recorder
- Built-in mic controls in the menu
- JSON-based `assets/langs/` localization (no `.strings` files)

## Requirements (Minimal)

- macOS 14+
- Xcode 15+ (to build)

## Build

Open `micromute.xcodeproj` in Xcode and run.

## Localization

All user-visible strings live in `assets/langs/`.
Add a new `*.json` with `"language_name"` to create a new language.
