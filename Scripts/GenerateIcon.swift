import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: GenerateIcon output-directory\n", stderr)
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in variants {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let inset = size * 0.055
        let background = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: size * 0.22, yRadius: size * 0.22)
        NSColor(calibratedWhite: 0.075, alpha: 1).setFill()
        background.fill()

        let center = NSPoint(x: size / 2, y: size / 2)
        let radius = size * 0.285
        NSColor(calibratedRed: 0.16, green: 0.82, blue: 0.47, alpha: 0.16).setStroke()
        let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        track.lineWidth = size * 0.075
        track.stroke()

        NSColor(calibratedRed: 0.19, green: 0.88, blue: 0.50, alpha: 1).setStroke()
        let ring = NSBezierPath()
        ring.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -205, clockwise: true)
        ring.lineWidth = size * 0.078
        ring.lineCapStyle = .round
        ring.stroke()

        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: size * 0.53, y: size * 0.72))
        bolt.line(to: NSPoint(x: size * 0.35, y: size * 0.48))
        bolt.line(to: NSPoint(x: size * 0.49, y: size * 0.48))
        bolt.line(to: NSPoint(x: size * 0.44, y: size * 0.27))
        bolt.line(to: NSPoint(x: size * 0.65, y: size * 0.55))
        bolt.line(to: NSPoint(x: size * 0.51, y: size * 0.55))
        bolt.close()
        NSColor.white.setFill()
        bolt.fill()
        return true
    }
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    try png.write(to: output.appendingPathComponent(name))
}
