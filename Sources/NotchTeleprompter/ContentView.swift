import SwiftUI

// MARK: - Geometry preference for measuring text height

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Panel shape: square at the top (meets the notch), rounded at the bottom

struct NotchPanelShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Small icon button

struct IconButton: View {
    let systemName: String
    var size: CGFloat = 14
    var tint: Color = .white
    var help: String = ""
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: size + 14, height: size + 14)
                .background(Circle().fill(Color.white.opacity(hovering ? 0.16 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Root view

struct ContentView: View {
    @EnvironmentObject var model: TeleprompterModel
    @EnvironmentObject var recorder: Recorder

    var body: some View {
        ZStack {
            NotchPanelShape(radius: Layout.cornerRadius)
                .fill(Color.black)

            if model.isExpanded {
                expanded
            } else {
                collapsed
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { recorder.prepare() }
        .onChange(of: model.outputFolder) { recorder.outputFolder = $0 }
    }

    // Red record control reused in the top bar and collapsed pill.
    private var recordButton: some View {
        Button(action: { recorder.toggle() }) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.55), lineWidth: 2)
                RoundedRectangle(cornerRadius: recorder.isRecording ? 3 : 9)
                    .fill(Color.red)
                    .frame(width: recorder.isRecording ? 11 : 16,
                           height: recorder.isRecording ? 11 : 16)
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(recorder.isRecording ? "Stop recording" : "Record yourself")
        .animation(.easeInOut(duration: 0.15), value: recorder.isRecording)
    }

    // MARK: Collapsed pill — minimal transport flanking the notch

    private var collapsed: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                IconButton(systemName: model.isScrolling ? "pause.fill" : "play.fill",
                           help: "Play / pause") { model.toggleScroll() }
                recordButton.scaleEffect(0.82)
            }
            .frame(maxWidth: .infinity)

            Color.clear.frame(width: max(model.notchWidth, 10))

            HStack(spacing: 6) {
                if recorder.isRecording {
                    Text(timeString(recorder.elapsed))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red)
                }
                IconButton(systemName: "chevron.down", help: "Expand") { model.setExpanded(true) }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
    }

    // MARK: Expanded panel

    private var expanded: some View {
        VStack(spacing: 0) {
            topBar
            teleprompterArea
            Divider().background(Color.white.opacity(0.08))
            toolbar
        }
    }

    // Top bar: play scrolling on the left of the notch, record on the right — the two
    // primary actions flanking the notch with equal weight.
    private var topBar: some View {
        HStack(spacing: 0) {
            HStack {
                IconButton(systemName: model.isScrolling ? "pause.fill" : "play.fill",
                           size: 16, help: "Play / pause (start scrolling)") { model.toggleScroll() }
            }
            .frame(maxWidth: .infinity)

            // Gap that clears the physical notch / camera.
            Color.clear.frame(width: max(model.notchWidth, 16))

            HStack(spacing: 8) {
                if recorder.isRecording {
                    Text(timeString(recorder.elapsed))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                recordButton
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .frame(height: max(model.notchHeight, Layout.collapsedHeight))
    }

    // Bottom toolbar: all edit controls live down here, away from the reading line.
    private var toolbar: some View {
        HStack(spacing: 13) {
            IconButton(systemName: "gobackward", size: 13, help: "Restart from top (R)") { model.restart() }

            toolbarDivider

            IconButton(systemName: "tortoise.fill", size: 12, help: "Slower (↓)") { model.changeSpeed(by: -10) }
            Text("\(Int(model.speed))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7)).frame(width: 26)
            IconButton(systemName: "hare.fill", size: 12, help: "Faster (↑)") { model.changeSpeed(by: 10) }

            toolbarDivider

            IconButton(systemName: "textformat.size.smaller", size: 13, help: "Smaller text (−)") { model.changeFont(by: -2) }
            IconButton(systemName: "textformat.size.larger", size: 13, help: "Larger text (+)") { model.changeFont(by: 2) }

            toolbarDivider

            IconButton(systemName: model.showCamera ? "camera.fill" : "camera",
                       size: 14, tint: model.showCamera ? .accentColor : .white,
                       help: "Toggle camera preview") { model.showCamera.toggle() }
            IconButton(systemName: model.editingScript ? "checkmark.circle.fill" : "pencil",
                       size: 14, tint: model.editingScript ? .green : .white,
                       help: model.editingScript ? "Done editing (⌘E)" : "Edit script (⌘E)") { model.toggleEditing() }

            Spacer(minLength: 8)

            IconButton(systemName: "folder", size: 13, help: "Choose save folder") { model.chooseFolder() }
            IconButton(systemName: "magnifyingglass", size: 13, help: "Show last recording in Finder") {
                recorder.revealLastInFinder()
            }
            IconButton(systemName: "chevron.up", size: 13, help: "Collapse to notch") { model.setExpanded(false) }
            IconButton(systemName: "xmark", size: 13, help: "Quit") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 16)
        .frame(height: Layout.toolbarHeight)
    }

    private var toolbarDivider: some View {
        Divider().frame(height: 16).background(Color.white.opacity(0.12))
    }

    // The scrolling script + camera preview overlay.
    private var teleprompterArea: some View {
        ZStack(alignment: .bottomTrailing) {
            if model.editingScript {
                scriptEditor
            } else {
                scrollingText
            }

            if model.showCamera && recorder.isAvailable {
                CameraPreview(session: recorder.session, mirrored: false)
                    .frame(width: 168, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .overlay(alignment: .topLeading) {
                        if recorder.isRecording {
                            Circle().fill(Color.red).frame(width: 9, height: 9).padding(7)
                        }
                    }
                    .padding(14)
                    .shadow(radius: 6)
            }

            if !recorder.status.isEmpty && model.showCamera {
                Text(recorder.status)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
    }

    private var scriptEditor: some View {
        TextEditor(text: $model.script)
            .font(.system(size: 16))
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.04))
            .foregroundColor(.white)
            .padding(12)
    }

    private var scrollingText: some View {
        GeometryReader { geo in
            let textWidth = max(120, geo.size.width - Layout.textInset * 2)
            ZStack(alignment: .top) {
                Text(model.script)
                    .font(.system(size: CGFloat(model.fontSize), weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .frame(width: textWidth, alignment: .center)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: HeightKey.self, value: g.size.height)
                    })
                    .padding(.horizontal, Layout.textInset)
                    // First line starts on the reading line; scrolling moves text upward.
                    .offset(y: Layout.readLineInset - model.scrollOffset)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .onAppear { model.viewportHeight = geo.size.height }
            .onChange(of: geo.size.height) { model.viewportHeight = $0 }
            .onPreferenceChange(HeightKey.self) { model.contentHeight = $0 }
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.09),
                    .init(color: .black, location: 0.84),
                    .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            )
            .overlay(alignment: .top) { readingGuide.offset(y: Layout.readLineInset) }
            .contentShape(Rectangle())
            .onTapGesture { model.toggleScroll() }
        }
    }

    // Reading line just under the notch, with inward ticks at each edge.
    private var readingGuide: some View {
        HStack(spacing: 0) {
            Image(systemName: "triangle.fill")
                .resizable().frame(width: 7, height: 6).rotationEffect(.degrees(90))
                .foregroundColor(.accentColor.opacity(0.8))
            Rectangle().fill(Color.accentColor.opacity(0.30)).frame(height: 1)
            Image(systemName: "triangle.fill")
                .resizable().frame(width: 7, height: 6).rotationEffect(.degrees(-90))
                .foregroundColor(.accentColor.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .allowsHitTesting(false)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
