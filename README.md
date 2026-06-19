# Notch Teleprompter

A simple native macOS teleprompter that hangs from your Mac's notch. Controls sit on
either side of the notch; the scrolling script extends below it; a built‑in recorder
captures video of you through the camera and saves it to a folder you choose.

> **Requirements:** macOS 13 (Ventura) or later. Universal binary — runs on both Apple
> Silicon and Intel Macs. (A notch is optional; on non‑notch Macs the panel docks centered
> at the top of the screen.)

## Install (download)

1. Go to the [**Releases**](https://github.com/jaschahuisman/mac-notch-teleprompter/releases/latest)
   page and download `NotchTeleprompter.zip`.
2. Unzip it and drag **Notch Teleprompter.app** into your `/Applications` folder.
3. The app is open‑source and **not notarized by Apple**, so Gatekeeper blocks it on first
   launch. To open it, do **either** of these once:
   - **Right‑click** the app → **Open** → **Open** in the dialog, **or**
   - run this in Terminal to clear the quarantine flag:
     ```bash
     xattr -dr com.apple.quarantine "/Applications/Notch Teleprompter.app"
     ```
4. On first record, macOS asks for **Camera** and **Microphone** access — click **Allow**.
   (No Screen Recording permission is ever requested.)

To quit, click the **✕** in the bottom toolbar, or press **⌘Q**.

## Build from source

Requires the Swift toolchain (Command Line Tools or Xcode). No Xcode project needed.

Requires the Swift toolchain (Command Line Tools or Xcode). No Xcode project needed.

```bash
./build.sh release
open "dist/Notch Teleprompter.app"
```

`build.sh` compiles with SwiftPM, assembles a `Notch Teleprompter.app` bundle in
`dist/`, and ad‑hoc code signs it so the camera/mic permission grant sticks.

For a quick dev run without the bundle:

```bash
swift run
```

> First launch: macOS asks for **Camera** and **Microphone** access — needed only for the
> record feature. Approve both prompts to record. (No Screen Recording permission is used.)

## Using it

The panel appears centered at the top of the screen, fused to the notch. The **reading line
sits just under the notch — level with the camera** — so as the script scrolls through it you
appear to be looking straight down the lens. All edit controls live in a toolbar at the
**bottom** of the panel, out of your eyeline.

**Top bar (flanking the notch)**
- ▶︎ / ⏸ (left of notch) — play / pause scrolling (you can also click the script to toggle)
- ⏺ (right of notch) — record yourself; the red dot becomes a stop square with an elapsed
  timer while recording

**Bottom toolbar**
- ↺ — restart from the top
- 🐢 / 🐇 — slower / faster scroll (points per second, shown between them)
- A− / A+ — smaller / larger text
- 📷 — show / hide the live camera preview thumbnail
- ✏️ — edit the script (paste your own lines, then press the green check to finish)
- 📁 — choose the folder recordings are saved to (defaults to `~/Movies`)
- 🔍 — reveal the last recording in Finder
- ⌃ — collapse the panel down to a small pill around the notch
- ✕ — quit

**Keyboard (you're usually away from the keyboard while reading)**
- `Space` / `Return` — play / pause scrolling
- `R` — start / stop recording
- `↑` / `↓` — faster / slower
- `+` / `−` — larger / smaller text
- `⌘E` — edit script / done editing
- **Scroll wheel / trackpad** — scrub the script up and down by hand

Your script, speed, font size, camera preference, and save folder are **remembered between
launches**. Recordings are saved as `Teleprompter_YYYY-MM-DD_HH-mm-ss.mov`, and quitting
mid-recording finalizes the file cleanly before the app exits.

## How it works

- **Windowing** — a borderless, shadowless `NSWindow` at `.statusBar` level, anchored
  top‑center, with a shape that's square at the top (to meet the notch) and rounded at the
  bottom — no border/outline, so it reads as an extension of the notch itself. Notch width
  and height are read from `NSScreen.safeAreaInsets` / `auxiliaryTop*Area` so controls leave a
  gap for the camera; on Macs without a notch it falls back to a centered top bar.
- **Scrolling** — a 60 Hz timer advances an offset applied to the script `Text`; speed is in
  points/second. The reading guide is fixed near the top (next to the lens); the script scrolls
  up through it and stops once the last line reaches the line. Top/bottom fades soften the ends.
  Scroll-wheel input and keyboard shortcuts are handled by app-level `NSEvent` monitors.
- **Recording** — `AVCaptureSession` (camera + mic) into `AVCaptureMovieFileOutput`, written
  straight to the chosen folder.

## Project layout

```
Package.swift
Sources/NotchTeleprompter/
  main.swift             # entry point, NSWindow + menu + screen geometry
  TeleprompterModel.swift# observable state, scroll clock, window layout
  Recorder.swift         # AVFoundation camera/mic capture → .mov
  CameraPreview.swift    # AVCaptureVideoPreviewLayer wrapper
  ContentView.swift      # SwiftUI panel, controls, scrolling text
Resources/
  Info.plist             # bundle metadata + camera/mic usage strings
  entitlements.plist     # camera, mic, user‑selected files
build.sh                 # build + bundle + sign
```
