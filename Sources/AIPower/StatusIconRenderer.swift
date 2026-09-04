import AppKit
import AIPowerCore

enum StatusIconRenderer {
    private static let logo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "OpenAILogo", withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }()

    static func image(remaining: Double?, shortCycleSeverity: QuotaSeverity?) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            let ring = NSRect(x: 1, y: 1, width: 16, height: 16)
            NSColor.labelColor.withAlphaComponent(0.18).setStroke()
            let track = NSBezierPath(ovalIn: ring.insetBy(dx: 1.15, dy: 1.15))
            track.lineWidth = 1.8
            track.stroke()

            if let remaining {
                severityColor(QuotaSeverity.forRemainingPercent(remaining)).setStroke()
                let progress = NSBezierPath()
                progress.appendArc(
                    withCenter: NSPoint(x: ring.midX, y: ring.midY),
                    radius: 6.85,
                    startAngle: 90,
                    endAngle: 90 - CGFloat(min(max(remaining, 0), 100) / 100 * 360),
                    clockwise: true
                )
                progress.lineWidth = 2.05
                progress.lineCapStyle = .round
                progress.stroke()
            }

            if let logo {
                logo.draw(in: NSRect(x: 5.2, y: 5.2, width: 7.6, height: 7.6))
                NSColor.labelColor.setFill()
                NSRect(x: 5.2, y: 5.2, width: 7.6, height: 7.6).fill(using: .sourceAtop)
            }

            if let severity = shortCycleSeverity, severity != .normal {
                severityColor(severity).setFill()
                NSBezierPath(ovalIn: NSRect(x: 18, y: 2, width: 4, height: 4)).fill()
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
