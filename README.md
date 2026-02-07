# micromute

Minimal macOS menu‑bar app to mute/unmute the default microphone with a hotkey and a small on‑screen indicator.

## Unique Features

- One‑click hotkey recorder
- Built‑in mic controls in the menu
- JSON‑based `assets/langs/` localization (no .strings files needed)

## Requirements (Minimal)

- macOS 14+
- Xcode 15+ (to build)

## Build

Open `micromute.xcodeproj` in Xcode and run.

## Localization

All user‑visible strings live in `assets/langs/`.  
Add a new `*.json` with `"language_name"` to create a new language.
