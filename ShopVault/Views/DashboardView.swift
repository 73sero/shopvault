import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshGradientView()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color.App.accentPrimary)
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            // Greeting Header
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(viewModel.greeting)
                                    .font(Font.App.title)
                                    .foregroundStyle(Color.App.textPrimary)

                                Text("Income Overview")
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.md)
                            .staggeredAppear(index: 0)

                            // Summary Cards
                            VStack(spacing: AppSpacing.sm) {
                                SummaryCard(
                                    title: "This Week",
                                    amount: viewModel.weeklyTotal,
                                    icon: "calendar",
                                    color: Color.App.categoryBlue
                                )
                                .staggeredAppear(index: 1)

                                SummaryCard(
                                    title: "This Month",
                                    amount: viewModel.monthlyTotal,
                                    icon: "calendar.circle",
                                    color: Color.App.accentPrimary
                                )
                                .staggeredAppear(index: 2)

                                SummaryCard(
                                    title: "Daily Average",
                                    amount: viewModel.dailyAverage,
                                    icon: "chart.line.uptrend.xyaxis",
                                    color: Color.App.categoryOrange
                                )
                                .staggeredAppear(index: 3)
                            }
                            .padding(.horizontal, AppSpacing.md)

                            // Category Breakdown Chart
                            if !viewModel.categoryBreakdown.isEmpty {
                                CategoryDonutChart(breakdown: viewModel.categoryBreakdown)
                                    .staggeredAppear(index: 4)
                                    .padding(.horizontal, AppSpacing.md)
                            }

                            // Recent Entries
                            if !viewModel.recentEntries.isEmpty {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Text("Recent Entries")
                                        .font(Font.App.headline)
                                        .foregroundStyle(Color.App.textPrimary)
                                        .padding(.horizontal, AppSpacing.md)

                                    VStack(spacing: AppSpacing.xs) {
                                        ForEach(Array(viewModel.recentEntries.enumerated()), id: \.element.id) { index, entry in
                                            RecentEntryRow(entry: entry)
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
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let amount: Decimal
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.textSecondary)

                CountUpText(amount)
                    .font(Font.App.amountMedium)
                    .foregroundStyle(Color.App.textPrimary)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: color.opacity(0.4), radius: 8)
        }
        .glassCard()
    }
}

// MARK: - Category Donut Chart

struct CategoryDonutChart: View {
    let breakdown: [(name: String, amount: Decimal, percentage: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Categories")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)

            Chart(breakdown, id: \.name) { item in
                SectorMark(
                    angle: .value("Amount", item.percentage),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(colorForCategory(item.name))
                .cornerRadius(4)
            }
            .frame(height: 180)

            // Legend
            HStack(spacing: AppSpacing.md) {
                ForEach(breakdown, id: \.name) { item in
                    HStack(spacing: AppSpacing.xxs) {
                        Circle()
                            .fill(colorForCategory(item.name))
                            .frame(width: 8, height: 8)

                        Text(item.name)
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }
            }
        }
        .glassCard()
    }

    private func colorForCategory(_ name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("freelance"): return Color.App.categoryBlue
        case let n where n.contains("passive"): return Color.App.categoryGreen
        case let n where n.contains("salary"): return Color.App.categoryOrange
        default: return Color.App.categoryPurple
        }
    }
}

// MARK: - Recent Entry Row

struct RecentEntryRow: View {
    let entry: IncomeEntry

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient.appAccent)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(entry.source)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)

                Text(entry.formattedDate())
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }

            Spacer()

            Text(entry.formattedAmount())
                .font(Font.App.amountSmall)
                .foregroundStyle(Color.App.accentPrimary)
        }
        .glassCard(padding: AppSpacing.sm)
    }
}

#Preview {
    DashboardView(viewModel: DashboardViewModel(
        incomeRepository: IncomeRepository()
    ))
    .environmentObject(AppState())
}
