import AppKit
import AIPowerCore

enum StatusIconRenderer {
    private static let logo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "OpenAILogo", withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }()

    static func image(remaining: Double?, shortCycleSeverity: QuotaSeverity?) -> NSImage {
        let image = NSImage(size: NSSize(width: 25, height: 21), flipped: false) { _ in
            let ring = NSRect(x: 1, y: 1, width: 19, height: 19)
            NSColor.labelColor.withAlphaComponent(0.18).setStroke()
            let track = NSBezierPath(ovalIn: ring.insetBy(dx: 1.25, dy: 1.25))
            track.lineWidth = 2.1
            track.stroke()

            if let remaining {
                severityColor(QuotaSeverity.forRemainingPercent(remaining)).setStroke()
                let progress = NSBezierPath()
                progress.appendArc(
                    withCenter: NSPoint(x: ring.midX, y: ring.midY),
                    radius: 8.25,
                    startAngle: 90,
                    endAngle: 90 - CGFloat(min(max(remaining, 0), 100) / 100 * 360),
                    clockwise: true
                )
                progress.lineWidth = 2.35
                progress.lineCapStyle = .round
                progress.stroke()
            }

            if let logo {
                let logoRect = NSRect(x: 4.5, y: 4.5, width: 12, height: 12)
                let tintedLogo = NSImage(size: logoRect.size, flipped: false) { bounds in
                    logo.draw(in: bounds)
                    NSColor.labelColor.setFill()
                    bounds.fill(using: .sourceAtop)
                    return true
                }
                tintedLogo.draw(in: logoRect)
            }

            if let severity = shortCycleSeverity, severity != .normal {
                severityColor(severity).setFill()
                NSBezierPath(ovalIn: NSRect(x: 21, y: 2, width: 4, height: 4)).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    static func severityColor(_ severity: QuotaSeverity) -> NSColor {
        switch severity {
        case .normal: return .systemGreen
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }
}
