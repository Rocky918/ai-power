import SwiftUI
import AIPowerCore

struct QuotaLogoView: View {
    let remaining: Double?
    let size: CGFloat
    var isRefreshing = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var severity: QuotaSeverity {
        QuotaSeverity.forRemainingPercent(remaining ?? 100)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: max(2, size * 0.07))
            Circle()
                .trim(from: 0, to: CGFloat((remaining ?? 0) / 100))
                .stroke(color, style: StrokeStyle(lineWidth: max(2, size * 0.075), lineCap: .round))
                .rotationEffect(.degrees(-90))
            logo
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var logo: some View {
        if let url = Bundle.module.url(forResource: "OpenAILogo", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            if isRefreshing && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    logoImage(image)
                        .rotationEffect(.degrees(rotationAngle(at: context.date)))
                }
            } else {
                logoImage(image)
            }
        }
    }

    private func logoImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(.primary)
            .padding(size * 0.25)
    }

    private func rotationAngle(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 1.05) / 1.05 * 360
    }

    private var color: Color {
        switch severity {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
