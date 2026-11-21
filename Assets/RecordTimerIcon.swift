import AppKit
import Foundation

let canvas = 1024
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
graphics.shouldAntialias = true

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func strokeLine(from start: NSPoint, to end: NSPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.lineCapStyle = .round
    path.lineWidth = width
    path.move(to: start)
    path.line(to: end)
    color.setStroke()
    path.stroke()
}

let tile = NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: 976, height: 976), xRadius: 230, yRadius: 230)
NSGradient(colors: [color(0.08, 0.13, 0.31), color(0.15, 0.12, 0.42), color(0.10, 0.25, 0.43)])!
    .draw(in: tile, angle: 315)

// Clip all artwork to the app-icon silhouette.
NSGraphicsContext.saveGraphicsState()
tile.addClip()

// Soft, oversized halos add depth without competing with the timer mark.
color(0.20, 0.56, 0.88, 0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 110, y: 500, width: 800, height: 800)).fill()
color(0.52, 0.30, 0.96, 0.12).setFill()
NSBezierPath(ovalIn: NSRect(x: 360, y: 30, width: 800, height: 800)).fill()

// Crown and short stem distinguish this as a timer rather than a record button.
let stem = NSBezierPath(roundedRect: NSRect(x: 480, y: 775, width: 64, height: 76), xRadius: 26, yRadius: 26)
NSGradient(colors: [color(0.48, 0.91, 1.0), color(0.24, 0.72, 0.94)])!.draw(in: stem, angle: 90)
let crown = NSBezierPath(roundedRect: NSRect(x: 425, y: 828, width: 174, height: 46), xRadius: 22, yRadius: 22)
color(0.48, 0.91, 1.0).setFill()
crown.fill()

// Clock face.
let center = NSPoint(x: 512, y: 485)
let faceRect = NSRect(x: 231, y: 204, width: 562, height: 562)
let face = NSBezierPath(ovalIn: faceRect)
face.lineWidth = 44
color(0.91, 0.96, 1.0).setStroke()
face.stroke()

let tickColor = color(0.44, 0.86, 1.0)
strokeLine(from: NSPoint(x: 512, y: 706), to: NSPoint(x: 512, y: 667), width: 19, color: tickColor)
strokeLine(from: NSPoint(x: 733, y: 485), to: NSPoint(x: 694, y: 485), width: 19, color: tickColor)
strokeLine(from: NSPoint(x: 512, y: 264), to: NSPoint(x: 512, y: 303), width: 19, color: tickColor)
strokeLine(from: NSPoint(x: 291, y: 485), to: NSPoint(x: 330, y: 485), width: 19, color: tickColor)

// Clean, rounded hands at a balanced 10:10 position.
strokeLine(from: center, to: NSPoint(x: 425, y: 574), width: 34, color: color(0.97, 0.99, 1.0))
strokeLine(from: center, to: NSPoint(x: 649, y: 606), width: 27, color: color(0.97, 0.99, 1.0))
let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 31, y: center.y - 31, width: 62, height: 62))
color(0.31, 0.83, 1.0).setFill()
hub.fill()

NSGraphicsContext.restoreGraphicsState()

// Fine inset border keeps the rounded square crisp against light desktops.
tile.lineWidth = 3
color(1, 1, 1, 0.16).setStroke()
tile.stroke()

graphics.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: output)
