# BarBoss 🍸

**BarBoss** is a lightweight, high-performance macOS menu bar manager inspired by [Bartender](https://www.macbartender.com). It gives you total control over your menu bar items, allowing you to combine, declutter, or hide icons with speed and elegance.

---

## Features

- **Menu Bar Management**:
  - **macOS 27**: Choose individual apps in BarBoss and hide or reveal them automatically.
  - **macOS 14–26**: Use native `⌘-drag` placement behind the BarBoss separator, then click the glasses to hide or reveal the group.
- **Fast Access & Triggers**:
  - Click to toggle or right-click / control-click for the context menu.
  - **Global Hotkey**: Press `⌘ + Shift + B` from any app to toggle hidden items instantly.
  - **Hover to Reveal**: Move your mouse to the top edge / menu bar to automatically reveal hidden items.
  - **Auto-Hide Timers**: Automatically re-collapses after a configurable delay (3s, 5s, 10s, 15s, 30s) or on click-outside.
- **Dedicated Settings Window**:
  - Built as a pure menu bar utility (`LSUIElement = true`) with a native macOS Settings window.
  - Tabs: **General**, **Menu Bar**, **Hotkeys**, **Appearance**, **Updates**, and **About**.
- **Update Management (Sparkle)**:
  - Powered by the [Sparkle 2 framework](https://sparkle-project.org).
  - Background update checks, automatic downloads, and release channel support.
- **DMG Distribution**:
  - Automated build script (`scripts/build_dmg.sh`) that produces a signed, compressed read-only `.dmg` installer with an `/Applications` drag-and-drop symlink.

---

## Quick Start

### 1. Build and Run from Source

```bash
# Generate the Xcode project
xcodegen generate

# Build Release binary
./scripts/build_dmg.sh
```

The built app is located at `build/DerivedData/Build/Products/Release/BarBoss.app`.
The distributable disk image is located at `build/BarBoss.dmg`.

### 2. Running BarBoss

Launch `BarBoss.app`:
```bash
open build/DerivedData/Build/Products/Release/BarBoss.app
```

Once launched:
1. You will see the **BarBoss** icon in your menu bar along with the separator (`|`).
2. Hold `⌘` (Command) and drag any status icons you wish to hide to the **left** of the separator.
3. Click the BarBoss icon or press `⌘ + Shift + B` to collapse or reveal them.
4. Right-click or Control-click the BarBoss icon to open **Settings...** or **Check for Updates...**.

---

## Configuring Sparkle Updates

BarBoss uses Sparkle 2 for updates. To set up your own update feed:

1. Generate an EdDSA keypair in the login keychain (account `BarBoss`):
   ```bash
   # From the Sparkle tools that ship with the Swift package
   generate_keys --account BarBoss
   ```
2. Put the printed public key into `SUPublicEDKey` in `BarBoss/Resources/Info.plist` and `project.yml`.
3. Keep `SUFeedURL` pointed at `https://barboss.artsvit.com/appcast.xml`.
4. Run `./scripts/build_dmg.sh`. It signs the DMG, writes `landing/appcast.xml` with `sparkle:version` / `sparkle:edSignature`, and copies `BarBoss.dmg` into `landing/`.
5. Deploy the landing folder so both `BarBoss.dmg` and `appcast.xml` go live together.

---

## Project Structure

```
BarBoss/
├── BarBoss/
│   ├── Sources/
│   │   ├── BarBossApp.swift                       # App entry point & lifecycle
│   │   ├── Core/
│   │   │   ├── Preferences.swift                  # User preferences & defaults
│   │   │   ├── MenuBarManager.swift               # Status items coordinator
│   │   │   ├── FloatingBarController.swift        # BarBoss Bar panel controller
│   │   │   ├── HotkeyManager.swift                # Global hotkey monitor (⌘⇧B)
│   │   │   └── HoverManager.swift                 # Menu bar mouse hover detection
│   │   ├── UI/
│   │   │   ├── FloatingBar/
│   │   │   │   └── FloatingBarView.swift          # Secondary floating bar view
│   │   │   └── Settings/
│   │   │       ├── SettingsView.swift             # Native macOS Settings UI tabs
│   │   │       └── SettingsWindowController.swift # Settings window manager
│   │   └── Updates/
│   │       └── UpdateManager.swift                # Sparkle 2 integration wrapper
│   └── Resources/
│       ├── Info.plist                             # App configuration & Sparkle keys
│       ├── BarBoss.entitlements                   # App entitlements
│       └── Assets.xcassets/                       # App icons & symbol assets
├── project.yml                                    # XcodeGen configuration
├── scripts/
│   ├── build_dmg.sh                               # Automated DMG build & packaging
│   └── generate_icon.swift                        # App icon generator
└── README.md
```

---

## License

MIT License. Copyright © 2026 BarBoss. All rights reserved.
