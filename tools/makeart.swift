import AppKit

// Renders the app icon + marketing graphics with Core Graphics, in a flipped
// (top-left origin) coordinate space so layout math reads naturally.

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

let indigo  = col(122, 102, 255)
let indigo2 = col(86, 64, 196)
let violet  = col(58, 44, 138)
let dark    = col(11, 11, 20)
let darker  = col(7, 7, 13)
let accent  = col(94, 212, 255)
let red     = col(255, 69, 58)
let panelBg = col(9, 9, 14)
let inkHi   = col(255, 255, 255)

func roundRect(_ r: NSRect, _ rad: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad)
}

func fill(_ path: NSBezierPath, _ c: NSColor) { c.setFill(); path.fill() }

func bar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
    fill(roundRect(NSRect(x: x, y: y, width: w, height: h), h/2), c)
}

func drawText(_ s: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
              font: NSFont, color: NSColor, align: NSTextAlignment = .left, kern: CGFloat = 0) {
    let p = NSMutableParagraphStyle(); p.alignment = align
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color,
                                                .paragraphStyle: p, .kern: kern]
    s.draw(in: NSRect(x: x, y: y, width: w, height: h), withAttributes: attrs)
}

func render(_ w: Int, _ h: Int, _ body: (NSRect) -> Void) -> NSBitmapImageRep {
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocusFlipped(true)
    body(NSRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

// MARK: - App icon

func drawIcon(in R: NSRect) {
    let S = R.width
    let ctx = NSGraphicsContext.current!
    let corner = S * 0.224

    // Background squircle + gradient
    ctx.saveGraphicsState()
    let clip = roundRect(R, corner); clip.addClip()
    NSGradient(colors: [indigo, indigo2, violet, darker],
               atLocations: [0, 0.35, 0.6, 1], colorSpace: .sRGB)!
        .draw(in: R, angle: -65)
    // soft top glow
    NSGradient(colors: [col(255,255,255,0.22), col(255,255,255,0)], atLocations: [0,1], colorSpace: .sRGB)!
        .draw(fromCenter: NSPoint(x: R.midX, y: R.minY + S*0.16), radius: 0,
              toCenter: NSPoint(x: R.midX, y: R.minY + S*0.16), radius: S*0.55, options: [])

    // Notch hanging from the top
    let nW = S*0.40, nH = S*0.135
    let notch = NSRect(x: R.midX - nW/2, y: R.minY + S*0.075, width: nW, height: nH)
    let np = NSBezierPath(roundedRect: notch, xRadius: nH*0.55, yRadius: nH*0.55)
    fill(np, col(6,6,11))
    // camera lens in the notch
    let lensR = nH*0.26
    let lens = NSRect(x: notch.midX - lensR, y: notch.midY - lensR, width: lensR*2, height: lensR*2)
    fill(NSBezierPath(ovalIn: lens), col(30,32,42))
    fill(NSBezierPath(ovalIn: NSRect(x: lens.minX+lensR*0.5, y: lens.minY+lensR*0.35,
                                     width: lensR*0.5, height: lensR*0.5)), col(120,160,200,0.9))

    // Reading line (accent, glowing) + scrolling text lines below the notch
    ctx.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = accent.withAlphaComponent(0.8); sh.shadowBlurRadius = S*0.05; sh.shadowOffset = .zero; sh.set()
    bar(R.midX - S*0.30, R.minY + S*0.40, S*0.60, S*0.055, accent)
    ctx.restoreGraphicsState()
    bar(R.midX - S*0.25, R.minY + S*0.535, S*0.50, S*0.05, inkHi.withAlphaComponent(0.85))
    bar(R.midX - S*0.20, R.minY + S*0.645, S*0.40, S*0.05, inkHi.withAlphaComponent(0.45))
    bar(R.midX - S*0.275, R.minY + S*0.755, S*0.30, S*0.05, inkHi.withAlphaComponent(0.25))

    // Record dot, top-right
    ctx.saveGraphicsState()
    let rs = NSShadow(); rs.shadowColor = red.withAlphaComponent(0.9); rs.shadowBlurRadius = S*0.04; rs.shadowOffset = .zero; rs.set()
    let rr = S*0.05
    fill(NSBezierPath(ovalIn: NSRect(x: R.maxX - S*0.20, y: R.minY + S*0.10, width: rr*2, height: rr*2)), red)
    ctx.restoreGraphicsState()

    ctx.restoreGraphicsState()
}

// MARK: - Notch panel mock (used in banner + product shot)

func drawPanel(in rect: NSRect, scale: CGFloat) {
    let ctx = NSGraphicsContext.current!
    let PW = rect.width
    let corner = PW * 0.05

    ctx.saveGraphicsState()
    let glow = NSShadow(); glow.shadowColor = indigo.withAlphaComponent(0.55)
    glow.shadowBlurRadius = 60*scale; glow.shadowOffset = .zero; glow.set()
    let panel = roundRect(rect, corner)
    fill(panel, panelBg)
    ctx.restoreGraphicsState()
    col(255,255,255,0.08).setStroke(); panel.lineWidth = 1.2; panel.stroke()

    // notch bump at top center
    let nW = PW*0.20, nH = PW*0.052
    fill(roundRect(NSRect(x: rect.midX - nW/2, y: rect.minY, width: nW, height: nH), nH*0.5), col(4,4,8))

    // top bar: play (left), record (right) flanking the notch
    let cy = rect.minY + PW*0.064
    let tri = NSBezierPath()
    let px = rect.minX + PW*0.085, ph = PW*0.030
    tri.move(to: NSPoint(x: px, y: cy - ph)); tri.line(to: NSPoint(x: px, y: cy + ph))
    tri.line(to: NSPoint(x: px + ph*1.45, y: cy)); tri.close()
    fill(tri, inkHi.withAlphaComponent(0.92))
    let rr = PW*0.022
    ctx.saveGraphicsState()
    let rs = NSShadow(); rs.shadowColor = red.withAlphaComponent(0.9); rs.shadowBlurRadius = 10*scale; rs.shadowOffset = .zero; rs.set()
    fill(NSBezierPath(ovalIn: NSRect(x: rect.maxX - PW*0.10, y: cy - rr, width: rr*2, height: rr*2)), red)
    ctx.restoreGraphicsState()

    // reading line w/ ticks just under the notch
    let rly = rect.minY + PW*0.105
    let rlW = PW*0.60
    ctx.saveGraphicsState()
    let g2 = NSShadow(); g2.shadowColor = accent.withAlphaComponent(0.8); g2.shadowBlurRadius = 14*scale; g2.shadowOffset = .zero; g2.set()
    bar(rect.midX - rlW/2, rly, rlW, PW*0.014, accent)
    ctx.restoreGraphicsState()

    // scrolling text lines (center aligned, current line brightest)
    let widths: [CGFloat] = [0.52, 0.62, 0.46, 0.58, 0.40]
    let alphas: [CGFloat] = [0.95, 0.6, 0.42, 0.28, 0.16]
    var ly = rly + PW*0.055
    for i in 0..<widths.count {
        let w = PW*widths[i]
        bar(rect.midX - w/2, ly, w, PW*0.030, inkHi.withAlphaComponent(alphas[i]))
        ly += PW*0.072
    }

    // bottom toolbar dots
    let by = rect.maxY - PW*0.06
    let dotR = PW*0.013
    var dx = rect.minX + PW*0.09
    for i in 0..<9 {
        let c = (i == 7) ? accent.withAlphaComponent(0.9) : inkHi.withAlphaComponent(0.32)
        fill(NSBezierPath(ovalIn: NSRect(x: dx, y: by - dotR, width: dotR*2, height: dotR*2)), c)
        dx += PW*0.052
    }
}

// MARK: - Banner

func drawBanner(in R: NSRect) {
    let W = R.width, H = R.height
    // background
    NSGradient(colors: [col(13,12,26), col(9,9,16), col(6,6,11)], atLocations: [0,0.5,1], colorSpace: .sRGB)!
        .draw(in: R, angle: -90)
    NSGradient(colors: [indigo.withAlphaComponent(0.45), indigo.withAlphaComponent(0)], atLocations: [0,1], colorSpace: .sRGB)!
        .draw(fromCenter: NSPoint(x: W*0.30, y: H*0.18), radius: 0,
              toCenter: NSPoint(x: W*0.30, y: H*0.18), radius: W*0.45, options: [])
    NSGradient(colors: [accent.withAlphaComponent(0.20), accent.withAlphaComponent(0)], atLocations: [0,1], colorSpace: .sRGB)!
        .draw(fromCenter: NSPoint(x: W*0.82, y: H*0.85), radius: 0,
              toCenter: NSPoint(x: W*0.82, y: H*0.85), radius: W*0.4, options: [])

    // icon badge
    let badge = NSRect(x: 76, y: 70, width: 92, height: 92)
    drawIcon(in: badge)

    // wordmark + tagline
    drawText("NOTCH", x: 74, y: 196, w: 760, h: 90,
             font: .systemFont(ofSize: 78, weight: .heavy), color: .white, kern: 1)
    drawText("TELEPROMPTER", x: 74, y: 272, w: 760, h: 90,
             font: .systemFont(ofSize: 78, weight: .heavy), color: accent, kern: 1)
    drawText("Read straight down the lens — from your Mac's notch.",
             x: 78, y: 374, w: 600, h: 40,
             font: .systemFont(ofSize: 23, weight: .medium), color: col(178, 184, 202))

    // feature pills
    let pills = ["Camera + mic recording", "Keyboard control", "Universal · macOS 13+"]
    var px: CGFloat = 78
    for t in pills {
        let f = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let tw = (t as NSString).size(withAttributes: [.font: f]).width
        let pw = tw + 50
        let rect = NSRect(x: px, y: 432, width: pw, height: 38)
        fill(roundRect(rect, 19), col(255,255,255,0.06))
        col(255,255,255,0.10).setStroke(); let bp = roundRect(rect, 19); bp.lineWidth = 1; bp.stroke()
        fill(NSBezierPath(ovalIn: NSRect(x: px+18, y: 446, width: 9, height: 9)), accent)
        drawText(t, x: px+34, y: 441, w: tw+10, h: 24, font: f, color: col(205,210,225))
        px += pw + 16
    }

    // panel mock on the right
    let PW: CGFloat = 470
    let PH = PW * 0.60
    drawPanel(in: NSRect(x: W - 96 - PW, y: (H - PH)/2 - 6, width: PW, height: PH), scale: 1)
}

// MARK: - Product shot (panel on a soft stage)

func drawProductShot(in R: NSRect) {
    let W = R.width, H = R.height
    NSGradient(colors: [col(20,18,40), col(10,10,18), col(6,6,11)], atLocations: [0,0.55,1], colorSpace: .sRGB)!
        .draw(in: R, angle: -90)
    NSGradient(colors: [indigo.withAlphaComponent(0.5), indigo.withAlphaComponent(0)], atLocations: [0,1], colorSpace: .sRGB)!
        .draw(fromCenter: NSPoint(x: W*0.5, y: H*0.10), radius: 0,
              toCenter: NSPoint(x: W*0.5, y: H*0.10), radius: W*0.5, options: [])
    // faux menu bar with notch at very top
    fill(NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: 26)), col(0,0,0,0.55))
    let PW: CGFloat = 560
    let PH = PW * 0.60
    drawPanel(in: NSRect(x: (W-PW)/2, y: 70, width: PW, height: PH), scale: 1.2)
    drawText("The panel hangs from the notch. Reading line sits on the lens.",
             x: 0, y: H - 70, w: W, h: 30,
             font: .systemFont(ofSize: 20, weight: .medium), color: col(150,156,174), align: .center)
}

// MARK: - Run

let fm = FileManager.default
try? fm.createDirectory(atPath: "assets", withIntermediateDirectories: true)
let iconset = "/tmp/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// Marketing graphics
save(render(1280, 520) { drawBanner(in: $0) }, "assets/banner.png")
save(render(1100, 560) { drawProductShot(in: $0) }, "assets/product.png")
save(render(512, 512) { drawIcon(in: $0) }, "assets/icon.png")

// Iconset for .icns
let sizes = [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),
             (128,"128x128"),(256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),
             (512,"512x512"),(1024,"512x512@2x")]
for (px, name) in sizes {
    save(render(px, px) { drawIcon(in: $0) }, "\(iconset)/icon_\(name).png")
}
print("✓ art generated")
