import SwiftUI
import AIPowerCore

struct UsagePopoverView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 16)
            content.padding(16)
            Divider().padding(.horizontal, 16)
            footer
        }
        .frame(width: 334)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, settings.locale)
    }

    private var header: some View {
        HStack(spacing: 12) {
            QuotaLogoView(remaining: model.snapshot?.menuWindow?.remainingPercent, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.text("codex.usage")).font(.headline)
                Text(planAndStatus).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRefreshing { ProgressView().controlSize(.small) }
        }
        .padding(16)
    }

    @ViewBuilder private var content: some View {
        if let snapshot = model.snapshot, !snapshot.windows.isEmpty {
            VStack(spacing: 12) {
                ForEach(snapshot.windows) { window in
                    windowCard(window, featured: window.id == snapshot.menuWindow?.id)
                }
                if let error = model.lastError {
                    Label(settings.text("stale.data"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .help(error)
                }
            }
        } else if model.isRefreshing {
            VStack(spacing: 10) {
                ProgressView()
                Text(settings.text("loading.usage")).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 116)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle").font(.title).foregroundStyle(.secondary)
                Text(settings.text("no.data")).font(.headline)
                Text(model.lastError ?? settings.text("no.data.help"))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button(settings.text("retry")) { model.refresh() }
            }.frame(maxWidth: .infinity, minHeight: 116)
        }
    }

    private func windowCard(_ window: QuotaWindow, featured: Bool) -> some View {
        VStack(spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PeriodFormatter.label(for: window, settings: settings))
                        .font(featured ? .headline : .subheadline.weight(.semibold))
                    Text(PeriodFormatter.resetText(for: window, settings: settings))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(settings.formatted("remaining.percent", Int(window.remainingPercent.rounded())))
                    .font(.system(size: featured ? 20 : 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(window.severity))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.09))
                    Capsule().fill(color(window.severity))
                        .frame(width: geometry.size.width * CGFloat(window.remainingPercent / 100))
                }
            }.frame(height: featured ? 7 : 5)
        }
        .padding(featured ? 13 : 11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(featured ? Color.primary.opacity(0.055) : Color.primary.opacity(0.025)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.primary.opacity(featured ? 0.09 : 0.05), lineWidth: 1))
    }

    private var footer: some View {
        HStack {
            Text(settings.text("threshold.hint")).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button(action: openSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.plain).help(settings.text("settings"))
            Button(action: quit) { Image(systemName: "power") }
                .buttonStyle(.plain).help(settings.text("quit"))
        }.padding(14)
    }

    private var planAndStatus: String {
        let plan = model.snapshot?.planType?.capitalized ?? "Plus"
        if model.lastError != nil { return "\(plan) · \(settings.text("stale.data"))" }
        if model.isRefreshing { return "\(plan) · \(settings.text("updating"))" }
        return "\(plan) · \(settings.text("just.updated"))"
    }

    private func color(_ severity: QuotaSeverity) -> Color {
        switch severity {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
