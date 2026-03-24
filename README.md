# KeyFlow ⌨️

A native macOS auto-typing simulator with a liquid glass UI. Paste any text, set a delay, switch to your target window, and KeyFlow types it out with human-like timing — random pauses, speed variation, and punctuation rhythm included.

Built with **SwiftUI** (frontend) and **C++** (typing engine), bridged via Objective-C++.

---

## Features

- **Human-like typing** — randomized keystroke speed, variation, and natural pauses
- **Start delay** — gives you time to click into Google Docs, Word, Notion, or any text field before typing begins
- **Pause / Resume** — stop and continue mid-text at any time
- **Punctuation pauses** — automatically slows after `.` `!` `?` `,` `;` `:`
- **Long think pauses** — occasional 0.7–2.2s pauses that mimic someone re-reading
- **Liquid glass UI** — native SwiftUI with `.ultraThinMaterial`, translucent cards and buttons that read your desktop behind the window
- **No Python, no Electron** — fully native, zero runtime dependencies

---

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools:
  ```bash
  xcode-select --install
  ```

---

## Build & Install

```bash
cd ~/Downloads/KeyFlow
chmod +x build.sh
./build.sh
```

This will:
1. Generate the app icon
2. Compile the C++ engine and Swift UI
3. Bundle everything into `KeyFlow.app`
4. Package it as `KeyFlow.dmg`

Then:
1. Open `KeyFlow.dmg`
2. Drag **KeyFlow** → **Applications**
3. Right-click → **Open** on first launch (Gatekeeper warning for unsigned apps)

---

## Accessibility Permission

KeyFlow types into other apps using macOS Accessibility APIs. On first run it will prompt you automatically. If it doesn't:

> **System Settings → Privacy & Security → Accessibility → enable KeyFlow**

Then relaunch the app.

---

## How to Use

1. Paste your text into the input box
2. Set your **Start Delay** (e.g. 5 seconds)
3. Click **▶ Start Typing**
4. Switch to your target window before the countdown ends
5. Watch it type

---

## Controls

| Control | Description |
|---|---|
| **Start Delay** | Seconds before typing begins — use this to switch windows |
| **Speed (WPM)** | Baseline typing speed (10–140 words per minute) |
| **Variation** | How much the speed fluctuates per keystroke |
| **Pause chance** | Probability of a random hesitation on any character |
| **Long think pauses** | Occasional long pauses like someone re-reading |
| **Punctuation pauses** | Natural slowdown after sentence-ending characters |

---

## Project Structure

| File | Description |
|---|---|
| `UI.swift` | Entire SwiftUI frontend — **edit this for visual changes** |
| `Engine.h` | C++ typing engine using CoreGraphics key events |
| `EngineWrapper.h/.mm` | Objective-C++ bridge between C++ and Swift |
| `KeyFlow-Bridging-Header.h` | Exposes the ObjC bridge to Swift |
| `build.sh` | Build script — compiles, bundles, and packages the DMG |
| `make_icon.py` | Generates the app icon as a `.icns` file |
| `Info.plist` | App bundle metadata |

---

## Customization

All visual changes live in **`UI.swift`**. Jump to these `MARK:` sections:

- `MARK: LiquidGlassButton` — button style, hover/press animations
- `MARK: LiquidGlassCard` — card background and blur
- `MARK: Theme` — colors, accent, status colors
- `MARK: TitleBar` — app name, icon, subtitle
- `MARK: TextPanel` — text input area
- `MARK: ControlsPanel` — sliders and toggles
- `MARK: FooterBar` — status bar, progress, buttons

To change the app icon, replace `make_icon.py` with your own 512×512 PNG named `icon.png` and update `build.sh` — see the comments inside for instructions.

---

## Tech Stack

- **SwiftUI** — UI framework
- **AppKit** — window transparency (`NSWindow`)
- **C++17** — typing engine with `std::thread` and `std::chrono`
- **CoreGraphics** — low-level key event posting via `CGEventCreateKeyboardEvent`
- **Objective-C++** — bridge layer between C++ and Swift

---

## License

MIT — do whatever you want with it.
