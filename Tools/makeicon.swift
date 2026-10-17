import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = NSSize(width: 1024, height: 1024)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let graphics = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
defer { NSGraphicsContext.restoreGraphicsState() }

let ctx = graphics.cgContext
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

// macOS-style rounded tile, no circular frame.
let tile = NSRect(x: 92, y: 92, width: 840, height: 840)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 190, yRadius: 190)

ctx.saveGState()
tilePath.addClip()
let bg = NSGradient(colors: [
    NSColor(srgbRed: 0.045, green: 0.095, blue: 0.075, alpha: 1),
    NSColor(srgbRed: 0.018, green: 0.035, blue: 0.040, alpha: 1)
])!
bg.draw(in: tile, angle: -75)

// Soft green light behind the printer.
let glow = NSGradient(colors: [
    NSColor(srgbRed: 0.20, green: 0.92, blue: 0.56, alpha: 0.36),
    NSColor(srgbRed: 0.20, green: 0.92, blue: 0.56, alpha: 0.0)
])!
glow.draw(fromCenter: NSPoint(x: 512, y: 530), radius: 20,
          toCenter: NSPoint(x: 512, y: 530), radius: 430, options: [])

// Faint technical grid.
NSColor.white.withAlphaComponent(0.045).setFill()
for row in 0..<6 {
    for col in 0..<6 {
        let rect = NSRect(x: 240 + CGFloat(col) * 108, y: 215 + CGFloat(row) * 108, width: 4, height: 4)
        NSBezierPath(ovalIn: rect).fill()
    }
}
ctx.restoreGState()

NSColor.white.withAlphaComponent(0.08).setStroke()
tilePath.lineWidth = 5
tilePath.stroke()

// A green printer, large and centered.
let green = NSColor(srgbRed: 0.17, green: 0.86, blue: 0.50, alpha: 1)
let mint = NSColor(srgbRed: 0.33, green: 0.95, blue: 0.69, alpha: 1)

if let symbol = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 360, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [green]))
    if let glyph = symbol.withSymbolConfiguration(config) {
        let gs = glyph.size
        let scale = min(500 / gs.width, 410 / gs.height)
        let w = gs.width * scale
        let h = gs.height * scale
        let rect = NSRect(x: 512 - w / 2, y: 540 - h / 2, width: w, height: h)
        let glowShadow = NSShadow()
        glowShadow.shadowColor = green.withAlphaComponent(0.48)
        glowShadow.shadowBlurRadius = 46
        glowShadow.shadowOffset = .zero
        glowShadow.set()
        glyph.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSShadow().set()
    }
}

// Three gentle layer lines, suggesting a print in progress.
for i in 0..<3 {
    let alpha: CGFloat = 0.34 - CGFloat(i) * 0.08
    let width: CGFloat = 300 + CGFloat(i) * 62
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 512 - width / 2, y: 270 - CGFloat(i) * 32))
    line.line(to: NSPoint(x: 512 + width / 2, y: 270 - CGFloat(i) * 32))
    line.lineWidth = 10
    line.lineCapStyle = .round
    let color = i == 0 ? mint : green
    color.withAlphaComponent(alpha).setStroke()
    line.stroke()
}

if let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: output))
    print("wrote \(output)")
}
