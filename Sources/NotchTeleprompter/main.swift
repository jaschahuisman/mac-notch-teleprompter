import AppKit
import SwiftUI

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

// MARK: - Borderless window that can still take keyboard focus (needed for the script editor)

final class NotchWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NotchWindow!
    private let model = TeleprompterModel()
    private let recorder = Recorder()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main ?? NSScreen.screens.first!

        // Measure the physical notch (0 on Macs without one).
        let metrics = Self.notchMetrics(for: screen)
        model.notchWidth = metrics.width
        model.notchHeight = metrics.height

        let size = CGSize(width: Layout.expandedWidth, height: Layout.expandedHeight)
        let origin = Self.topCenterOrigin(for: size, on: screen)

        window = NotchWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isMovable = false
        window.isReleasedWhenClosed = false

        model.window = window
        recorder.outputFolder = model.outputFolder

        let root = ContentView()
            .environmentObject(model)
            .environmentObject(recorder)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        model.startClock()
        buildMenu()
        installEventMonitors()
    }

    // MARK: Keyboard + scroll control (you're usually away from the keyboard reading)

    private func installEventMonitors() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, !self.model.editingScript else { return event }
            self.model.nudge(by: -event.scrollingDeltaY)   // scroll up → read upward
            return event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let cmd = event.modifierFlags.contains(.command)

        // ⌘E toggles editing from either state; otherwise the editor gets all keys.
        if cmd, event.charactersIgnoringModifiers?.lowercased() == "e" {
            model.toggleEditing(); return nil
        }
        if model.editingScript || cmd { return event }

        switch event.keyCode {
        case 49, 36, 76: model.toggleScroll(); return nil   // space / return / enter
        case 15:         recorder.toggle();    return nil   // R
        case 126:        model.changeSpeed(by: 5);  return nil   // up
        case 125:        model.changeSpeed(by: -5); return nil   // down
        default: break
        }
        switch event.charactersIgnoringModifiers {
        case "+", "=": model.changeFont(by: 2);  return nil
        case "-", "_": model.changeFont(by: -2); return nil
        default: return event
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Finalize any in-progress recording before quitting so the .mov isn't left corrupt.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard recorder.isRecording else { return .terminateNow }
        recorder.finishForTermination {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // Standard menu so Cmd+Q / Cmd+C/V work.
    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Notch Teleprompter", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: Screen geometry helpers

    static func notchMetrics(for screen: NSScreen) -> (width: CGFloat, height: CGFloat) {
        let top = screen.safeAreaInsets.top
        guard top > 0 else { return (0, 0) }
        let left = screen.auxiliaryTopLeftArea?.width ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let notchWidth = screen.frame.width - left - right
        return (max(0, notchWidth), top)
    }

    static func topCenterOrigin(for size: CGSize, on screen: NSScreen) -> CGPoint {
        let f = screen.frame
        return CGPoint(x: f.midX - size.width / 2, y: f.maxY - size.height)
    }
}
