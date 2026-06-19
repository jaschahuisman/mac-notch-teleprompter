import AppKit
import SwiftUI
import Combine

enum Layout {
    static let expandedWidth: CGFloat = 660
    static let expandedHeight: CGFloat = 360
    static let collapsedHeight: CGFloat = 34
    static let textInset: CGFloat = 40
    static let cornerRadius: CGFloat = 20
    static let toolbarHeight: CGFloat = 40
    /// Distance of the reading line from the top of the script area — kept small so the
    /// active line sits right under the notch, level with the camera (reads as eye contact).
    static let readLineInset: CGFloat = 26
}

final class TeleprompterModel: ObservableObject {
    // Script & presentation
    @Published var script: String { didSet { defaults.set(script, forKey: Keys.script) } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: Keys.fontSize) } }
    @Published var showCamera: Bool { didSet { defaults.set(showCamera, forKey: Keys.showCamera) } }
    @Published var editingScript: Bool = false

    // Scrolling
    @Published var isScrolling: Bool = false
    @Published var speed: Double { didSet { defaults.set(speed, forKey: Keys.speed) } }   // points/sec
    @Published var scrollOffset: CGFloat = 0
    @Published var contentHeight: CGFloat = 0
    @Published var viewportHeight: CGFloat = 0

    // Window state
    @Published var isExpanded: Bool = true

    // Output
    @Published var outputFolder: URL { didSet { defaults.set(outputFolder.path, forKey: Keys.folder) } }

    // Wiring
    weak var window: NSWindow?
    var notchWidth: CGFloat = 0
    var notchHeight: CGFloat = 0

    private let defaults = UserDefaults.standard
    private var timer: Timer?

    private enum Keys {
        static let script = "script", fontSize = "fontSize", speed = "speed"
        static let showCamera = "showCamera", folder = "folder"
    }

    init() {
        script = defaults.string(forKey: Keys.script) ?? TeleprompterModel.defaultScript
        let fs = defaults.double(forKey: Keys.fontSize); fontSize = fs > 0 ? fs : 30
        let sp = defaults.double(forKey: Keys.speed); speed = sp > 0 ? sp : 45
        showCamera = defaults.object(forKey: Keys.showCamera) as? Bool ?? true
        if let p = defaults.string(forKey: Keys.folder) {
            outputFolder = URL(fileURLWithPath: p)
        } else {
            outputFolder = TeleprompterModel.defaultFolder
        }
    }

    /// One line's height — used to know when the last line has reached the reading line.
    private var lineHeight: CGFloat { CGFloat(fontSize) * 1.3 + 8 }

    /// Max scroll: the last line should come to rest on the reading line.
    var maxOffset: CGFloat { max(0, contentHeight - lineHeight) }

    func startClock() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, self.isScrolling else { return }
            let limit = self.maxOffset
            let next = self.scrollOffset + CGFloat(self.speed) / 60.0
            if next >= limit {
                self.scrollOffset = limit
                self.isScrolling = false
            } else {
                self.scrollOffset = next
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func toggleScroll() {
        guard !editingScript else { return }
        if scrollOffset >= maxOffset { scrollOffset = 0 }
        isScrolling.toggle()
    }

    func restart() {
        scrollOffset = 0
    }

    func nudge(by delta: CGFloat) {
        isScrolling = false
        scrollOffset = min(max(0, scrollOffset + delta), maxOffset)
    }

    func changeSpeed(by delta: Double) { speed = min(250, max(10, speed + delta)) }
    func changeFont(by delta: Double) { fontSize = min(80, max(14, fontSize + delta)) }

    func toggleEditing() {
        editingScript.toggle()
        if editingScript { isScrolling = false }
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        relayout()
    }

    func relayout() {
        guard let window else { return }
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let size: CGSize
        if isExpanded {
            size = CGSize(width: Layout.expandedWidth, height: Layout.expandedHeight)
        } else {
            let w = max(notchWidth + 180, 260)
            let h = max(notchHeight, Layout.collapsedHeight)
            size = CGSize(width: w, height: h)
        }
        let f = screen.frame
        let rect = NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height,
                          width: size.width, height: size.height)
        window.setFrame(rect, display: true, animate: true)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where recordings are saved"
        panel.directoryURL = outputFolder
        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
        }
    }

    static var defaultFolder: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    static let defaultScript = """
    Welcome to Notch Teleprompter.

    This panel hangs from your Mac's notch. Press play on the left of the notch to start the text scrolling, and the red button on the right to record yourself through the camera.

    The reading line sits just under the notch — right next to the lens — so when you read it looks like you're talking straight to camera.

    Press space to play or pause. Use the arrow keys to change speed, and scroll to position the text by hand.

    Tap the pencil at the bottom to edit this script. Paste your own lines, press Done, and you're ready to roll.

    Look into the lens, breathe, and read naturally. You've got this.
    """
}
