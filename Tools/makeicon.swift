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

// Transparent margin, macOS style rounded tile.
let tile = NSRect(x: 92, y: 92, width: 840, height: 840)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 190, yRadius: 190)

ctx.saveGState()
tilePath.addClip()
let bg = NSGradient(colors: [
    NSColor(srgbRed: 0.055, green: 0.105, blue: 0.085, alpha: 1),
    NSColor(srgbRed: 0.025, green: 0.045, blue: 0.055, alpha: 1)
])!
bg.draw(in: tile, angle: -70)

// Soft green glow in the upper left.
let glow = NSGradient(colors: [
    NSColor(srgbRed: 0.18, green: 0.86, blue: 0.52, alpha: 0.34),
    NSColor(srgbRed: 0.18, green: 0.86, blue: 0.52, alpha: 0.0)
])!
glow.draw(fromCenter: NSPoint(x: 330, y: 720), radius: 0, toCenter: NSPoint(x: 330, y: 720), radius: 520, options: [])

// Faint grid dots.
NSColor.white.withAlphaComponent(0.055).setFill()
for row in 0..<7 {
    for col in 0..<7 {
        let rect = NSRect(x: 210 + CGFloat(col) * 96, y: 200 + CGFloat(row) * 96, width: 4, height: 4)
        NSBezierPath(ovalIn: rect).fill()
    }
}
ctx.restoreGState()

// Border
NSColor.white.withAlphaComponent(0.10).setStroke()
tilePath.lineWidth = 5
tilePath.stroke()

// Progress ring
let center = NSPoint(x: 512, y: 512)
let radius: CGFloat = 265
let track = NSBezierPath()
track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
track.lineWidth = 46
NSColor.white.withAlphaComponent(0.10).setStroke()
track.stroke()

let progress: CGFloat = 0.82
let arc = NSBezierPath()
arc.appendArc(withCenter: center, radius: radius, startAngle: -90, endAngle: -90 + 360 * progress, clockwise: false)
arc.lineWidth = 46
arc.lineCapStyle = .round
let accent = NSColor(srgbRed: 0.20, green: 0.90, blue: 0.55, alpha: 1)
accent.setStroke()
let shadow = NSShadow()
shadow.shadowColor = accent.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = .zero
shadow.set()
arc.stroke()
NSShadow().set()

// End cap dot
let angle = (-90 + 360 * progress) * .pi / 180
let dotCenter = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
let dot = NSBezierPath(ovalIn: NSRect(x: dotCenter.x - 15, y: dotCenter.y - 15, width: 30, height: 30))
NSColor(srgbRed: 0.86, green: 1.0, blue: 0.92, alpha: 1).setFill()
dot.fill()

// Printer glyph
if let symbol = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: 300, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.white.withAlphaComponent(0.96)]))
    if let glyph = symbol.withSymbolConfiguration(config) {
        let gs = glyph.size
        let scale = min(400 / gs.width, 330 / gs.height)
        let w = gs.width * scale
        let h = gs.height * scale
        let rect = NSRect(x: center.x - w / 2, y: center.y - h / 2 - 6, width: w, height: h)
        let glyphShadow = NSShadow()
        glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        glyphShadow.shadowBlurRadius = 20
        glyphShadow.shadowOffset = NSSize(width: 0, height: -8)
        glyphShadow.set()
        glyph.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSShadow().set()
    }
}

// Orange status dot
let badge = NSBezierPath(ovalIn: NSRect(x: 700, y: 704, width: 88, height: 88))
NSColor(srgbRed: 1.0, green: 0.64, blue: 0.24, alpha: 1).setFill()
let badgeShadow = NSShadow()
badgeShadow.shadowColor = NSColor(srgbRed: 1.0, green: 0.55, blue: 0.2, alpha: 0.55)
badgeShadow.shadowBlurRadius = 26
badgeShadow.shadowOffset = .zero
badgeShadow.set()
badge.fill()
NSShadow().set()
NSColor(srgbRed: 0.09, green: 0.08, blue: 0.05, alpha: 0.85).setFill()
NSBezierPath(ovalIn: NSRect(x: 728, y: 732, width: 32, height: 32)).fill()

if let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: output))
    print("wrote \(output)")
}
