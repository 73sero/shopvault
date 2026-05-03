import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
            ZStack {
                AnimatedMeshGradientView()

                if viewModel.isLoading {
                    DashboardSkeletonView()
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(greeting)
                                    .font(Font.App.title)
                                    .foregroundStyle(Color.App.textPrimary)

                                Text(t("income_overview"))
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.md)
                            .staggeredAppear(index: 0)

                            if viewModel.recentEntries.isEmpty {
                                EmptyDashboardState(
                                    title: t("no_entries"),
                                    subtitle: t("add_first_entry"),
                                    actionTitle: t("add_first_entry_cta")
                                ) {
                                    NotificationCenter.default.post(name: .requestAddIncomeEntry, object: nil)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .staggeredAppear(index: 1)
                            } else {
                                VStack(spacing: AppSpacing.sm) {
                                    SummaryCard(
                                        title: t("this_week"),
                                        amount: viewModel.weeklyTotalFormatted(
                                            currencyCode: appState.currencyCode,
                                            localeIdentifier: appState.localeIdentifier
                                        ),
                                        icon: "calendar",
                                        color: Color.App.categoryBlue
                                    )
                                    .staggeredAppear(index: 1)

                                    SummaryCard(
                                        title: t("this_month"),
                                        amount: viewModel.monthlyTotalFormatted(
                                            currencyCode: appState.currencyCode,
                                            localeIdentifier: appState.localeIdentifier
                                        ),
                                        icon: "calendar.circle",
                                        color: Color.App.accentPrimary
                                    )
                                    .staggeredAppear(index: 2)

                                    SummaryCard(
                                        title: t("daily_average"),
                                        amount: viewModel.dailyAverageFormatted(
                                            currencyCode: appState.currencyCode,
                                            localeIdentifier: appState.localeIdentifier
                                        ),
                                        icon: "chart.line.uptrend.xyaxis",
                                        color: Color.App.categoryOrange
                                    )
                                    .staggeredAppear(index: 3)
                                }
                                .padding(.horizontal, AppSpacing.md)

                                if !viewModel.categoryBreakdown.isEmpty {
                                    CategoryDonutChart(
                                        breakdown: viewModel.categoryBreakdown,
                                        currencyCode: appState.currencyCode,
                                        localeIdentifier: appState.localeIdentifier
                                    )
                                        .staggeredAppear(index: 4)
                                        .padding(.horizontal, AppSpacing.md)
                                }

                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Text(t("recent_entries"))
                                        .font(Font.App.headline)
                                        .foregroundStyle(Color.App.textPrimary)
                                        .padding(.horizontal, AppSpacing.md)

                                    VStack(spacing: AppSpacing.xs) {
                                        ForEach(Array(viewModel.recentEntries.enumerated()), id: \.element.id) { index, entry in
                                            RecentEntryRow(
                                                entry: entry,
                                                currencyCode: appState.currencyCode,
                                                localeIdentifier: appState.localeIdentifier
                                            )
                                            .staggeredAppear(index: 5 + index)
                                        }
                                    }
                                    .padding(.horizontal, AppSpacing.md)
                                }
                            }

                            Spacer(minLength: AppSpacing.lg)
                        }
                        .padding(.vertical, AppSpacing.md)
                    }
                }
            }
            .onAppear {
                if let userId = appState.currentUser?.id {
                    viewModel.loadDashboardData(userId: userId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .incomeEntriesDidChange)) { _ in
                if let userId = appState.currentUser?.id {
                    viewModel.loadDashboardData(userId: userId)
                }
            }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return t("good_morning") != "good_morning" ? t("good_morning") : "Guten Morgen"
        case 12..<17: return t("good_afternoon") != "good_afternoon" ? t("good_afternoon") : "Guten Tag"
        case 17..<22: return t("good_evening") != "good_evening" ? t("good_evening") : "Guten Abend"
        default: return t("good_night") != "good_night" ? t("good_night") : "Gute Nacht"
        }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }
}

struct DashboardSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Loading")
                        .font(Font.App.title)
                    Text("Loading overview")
                        .font(Font.App.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.md)

                VStack(spacing: AppSpacing.sm) {
                    ForEach(0..<3, id: \.self) { _ in
                        SummaryCard(
                            title: "Loading",
                            amount: "0.00",
                            icon: "calendar",
                            color: Color.App.bgTertiary
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                VStack(spacing: AppSpacing.xs) {
                    ForEach(0..<3, id: \.self) { _ in
                        RecentEntryRow(
                            entry: .sample,
                            currencyCode: "USD",
                            localeIdentifier: "en_US"
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}

struct EmptyDashboardState: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.App.textSecondary)

            VStack(spacing: AppSpacing.xxs) {
                Text(title)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Text(subtitle)
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GradientButton(
                title: actionTitle,
                icon: "plus.circle.fill",
                action: addAction
            )
        }
        .glassCard()
    }
}

struct SummaryCard: View {
    let title: String
    let amount: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)
                Text(amount)
                    .font(Font.App.amountMedium)
                    .foregroundStyle(Color.App.textPrimary)
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: color.opacity(0.4), radius: 8)
        }
        .glassCard()
    }
}

struct CategoryDonutChart: View {
    let breakdown: [(name: String, amount: Decimal, percentage: Double)]
    let currencyCode: String
    let localeIdentifier: String
    @State private var revealProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(t("category"))
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)

                Text(t("category_distribution_title"))
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
            }

            GeometryReader { proxy in
                let isWideLayout = proxy.size.width >= 340

                ZStack {
                    Chart(sortedBreakdown, id: \.name) { item in
                        SectorMark(
                            angle: .value("Amount", max(item.percentage, 0.1)),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .cornerRadius(6)
                        .foregroundStyle(by: .value("Category", item.name))
                    }
                    .chartLegend(.hidden)
                    .chartForegroundStyleScale(
                        domain: sortedBreakdown.map(\.name),
                        range: sortedBreakdown.map { categoryColor(for: $0.name) }
                    )
                    .opacity(0.6 + 0.4 * revealProgress)
                    .scaleEffect(0.96 + (0.04 * revealProgress))

                    VStack(spacing: AppSpacing.xxs) {
                        Text(t("total"))
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)

                        Text(AppFormatters.currency(totalAmount, currencyCode: currencyCode, localeIdentifier: localeIdentifier))
                            .font(isWideLayout ? Font.App.amountSmall : Font.App.caption)
                            .foregroundStyle(Color.App.textPrimary)
                            .multilineTextAlignment(.center)

                        if isWideLayout {
                            Text(String(format: "%.1f%%", topThreeCategories.first?.percentage ?? 0))
                                .font(Font.App.smallCaption)
                                .foregroundStyle(Color.App.accentPrimary)
                                .lineLimit(1)
                                .opacity(0.4 + 0.6 * revealProgress)
                        } else {
                            Text(String(format: "%.1f%%", topThreeCategories.first?.percentage ?? 0))
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.accentPrimary)
                                .opacity(0.4 + 0.6 * revealProgress)
                        }
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .frame(maxWidth: isWideLayout ? 120 : 90)
                }
            }
            .frame(height: 200)
        }
        .glassCard()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                revealProgress = 1
            }
        }
    }

    private var sortedBreakdown: [(name: String, amount: Decimal, percentage: Double)] {
        breakdown.sorted { $0.amount > $1.amount }
    }

    private var totalAmount: Decimal {
        sortedBreakdown.reduce(0) { $0 + $1.amount }
    }

    private var topThreeCategories: [(name: String, amount: Decimal, percentage: Double)] {
        Array(sortedBreakdown.prefix(3))
    }

    private func categoryColor(for name: String) -> Color {
        let palette: [Color] = [
            Color.App.accentPrimary,
            Color.App.categoryBlue,
            Color.App.categoryOrange,
            Color.App.categoryPurple,
            Color.App.categoryGreen
        ]

        let value = name.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return palette[abs(value) % palette.count]
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: localeIdentifier)
    }
}

struct RecentEntryRow: View {
    let entry: IncomeEntry
    let currencyCode: String
    let localeIdentifier: String

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2).fill(LinearGradient.appAccent).frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(entry.source).font(Font.App.headline).foregroundStyle(Color.App.textPrimary)
                Text(entry.formattedDate(localeIdentifier: localeIdentifier)).font(Font.App.smallCaption).foregroundStyle(Color.App.textSecondary)
            }
            Spacer()
            Text(entry.formattedAmount(currencyCode: currencyCode, localeIdentifier: localeIdentifier))
                .font(Font.App.amountSmall).foregroundStyle(Color.App.accentPrimary)
        }
        .glassCard(padding: AppSpacing.sm)
    }
}

#Preview("Dashboard") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        state.currencyCode = "USD"
        state.localeIdentifier = "en_US"
        return state
    }()

    return DashboardView(viewModel: DashboardViewModel(incomeRepository: IncomeRepository()))
        .environmentObject(appState)
}
