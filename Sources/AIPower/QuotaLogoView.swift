import SwiftUI
import AIPowerCore

struct QuotaLogoView: View {
    let remaining: Double?
    let size: CGFloat

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
            if let url = Bundle.module.url(forResource: "OpenAILogo", withExtension: "svg"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .padding(size * 0.27)
            }
        }
        .frame(width: size, height: size)
    }

    private var color: Color {
        switch severity {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
