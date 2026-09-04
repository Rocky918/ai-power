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
            insetDivider
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            insetDivider
            resetCreditsRow
            insetDivider
            footer
        }
        .frame(width: 376)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, settings.locale)
    }

    private var header: some View {
        HStack(spacing: 12) {
            QuotaLogoView(
                remaining: model.snapshot?.menuWindow?.remainingPercent,
                size: 52,
                isRefreshing: model.isRefreshing && model.popoverIsVisible
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.text("codex.usage")).font(.headline)
                Text(planAndStatus).font(.caption).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            tokenSummary
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var tokenSummary: some View {
        let display = tokenDisplay
        return VStack(alignment: .trailing, spacing: 2) {
            Label(display.label, systemImage: "number")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(display.value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(12.0 / 17.0)
                .frame(width: 128, alignment: .trailing)
            Text(display.detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: 128, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var content: some View {
        if let snapshot = model.snapshot, !snapshot.windows.isEmpty {
            VStack(spacing: 10) {
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
            Text(settings.text("loading.usage"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 88)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle").font(.title).foregroundStyle(.secondary)
                Text(settings.text("no.data")).font(.headline)
                Text(model.lastError ?? settings.text("no.data.help"))
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button(settings.text("retry")) { model.refresh() }
            }.frame(maxWidth: .infinity, minHeight: 96)
        }
    }

    private func windowCard(_ window: QuotaWindow, featured: Bool) -> some View {
        VStack(spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PeriodFormatter.label(for: window, settings: settings))
                        .font(featured ? .headline : .subheadline.weight(.semibold))
                    Text(PeriodFormatter.resetText(for: window, settings: settings))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(settings.formatted("remaining.percent", Int(window.remainingPercent.rounded())))
                    .font(.system(size: featured ? 19 : 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(window.severity))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.09))
                    Capsule().fill(color(window.severity))
                        .frame(width: geometry.size.width * CGFloat(window.remainingPercent / 100))
                }
            }.frame(height: featured ? 6 : 5)
        }
        .padding(.horizontal, featured ? 13 : 11)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(featured ? Color.primary.opacity(0.055) : Color.primary.opacity(0.025)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.primary.opacity(featured ? 0.09 : 0.05), lineWidth: 1))
    }

    private var resetCreditsRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "ticket")
                .foregroundStyle(.blue)
            Text(settings.text("reset.cards"))
                .font(.caption.weight(.semibold))
            if let credits = model.snapshot?.resetCredits {
                Text(settings.formatted("reset.cards.count", credits.availableCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            } else {
                Text("--")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let expiration = model.snapshot?.resetCredits?.earliestExpiration {
                Text(settings.formatted("reset.cards.expires", compactDate(expiration)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
    }

    private var footer: some View {
        HStack {
            Text(settings.text("threshold.hint")).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Button(action: openSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.plain).help(settings.text("settings"))
            Button(action: quit) { Image(systemName: "power") }
                .buttonStyle(.plain).help(settings.text("quit"))
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }

    private var insetDivider: some View {
        Divider().padding(.horizontal, 16)
    }

    private var planAndStatus: String {
        let plan = model.snapshot?.planType?.capitalized ?? "Plus"
        if model.lastError != nil { return "\(plan) · \(settings.text("stale.data"))" }
        if model.isRefreshing { return "\(plan) · \(settings.text("updating"))" }
        return "\(plan) · \(settings.text("just.updated"))"
    }

    private var tokenDisplay: (label: String, value: String, detail: String) {
        guard let usage = model.tokenUsage else {
            return (
                settings.text("token.usage"),
                "--",
                model.tokenUsageError == nil ? settings.text("token.waiting") : settings.text("token.unavailable")
            )
        }

        if let today = usage.bucket(startingOn: todayKey) {
            return (
                settings.text("token.today"),
                formattedTokens(today.tokens),
                model.tokenUsageError == nil
                    ? settings.text("token.server.updated")
                    : settings.text("token.showing.last")
            )
        }

        if let latest = usage.latestBucket {
            return (
                settings.text("token.latest"),
                formattedTokens(latest.tokens),
                settings.formatted("token.delayed", compactDate(latest.startDate))
            )
        }

        return (settings.text("token.usage"), "--", settings.text("token.unavailable"))
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func formattedTokens(_ tokens: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = settings.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: tokens)) ?? String(tokens)
    }

    private func compactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.locale
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    private func compactDate(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return dateString }

        let formatter = DateFormatter()
        formatter.locale = settings.locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    private func color(_ severity: QuotaSeverity) -> Color {
        switch severity {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
