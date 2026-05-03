import SwiftUI

struct FinanceView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddIncome = false

    var body: some View {
        ZStack {
            AnimatedMeshGradientView()

            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    menuItem(
                        icon: "chart.pie.fill",
                        title: "Dashboard",
                        description: "Einnahmen-Übersicht & Statistiken"
                    ) {
                        DashboardView(viewModel: DashboardViewModel(incomeRepository: IncomeRepository()))
                    }

                    Button {
                        showAddIncome = true
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.App.categoryBlue)
                                .frame(width: 44, height: 44)
                                .background(Color.App.categoryBlue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("Einnahme erfassen")
                                    .font(Font.App.headline)
                                    .foregroundStyle(Color.App.textPrimary)

                                Text("Neue Einnahme hinzufügen")
                                    .font(Font.App.smallCaption)
                                    .foregroundStyle(Color.App.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.App.textSecondary.opacity(0.5))
                        }
                        .glassCard()
                    }

                    menuItem(
                        icon: "list.bullet",
                        title: "Alle Einnahmen",
                        description: "Einnahmen durchsuchen & filtern"
                    ) {
                        IncomeListView(viewModel: IncomeListViewModel(incomeRepository: IncomeRepository()))
                    }

                    menuItem(
                        icon: "gear",
                        title: "Einstellungen",
                        description: "App-Einstellungen verwalten"
                    ) {
                        SettingsView(viewModel: SettingsViewModel(appState: appState))
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
            }
        }
        .navigationTitle("Finanzen")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showAddIncome) {
            AddIncomeView(viewModel: AddIncomeViewModel(incomeRepository: IncomeRepository(), categoryRepository: CategoryRepository()))
        }
    }

    @ViewBuilder
    private func menuItem<Destination: View>(icon: String, title: String, description: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.App.categoryBlue)
                    .frame(width: 44, height: 44)
                    .background(Color.App.categoryBlue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)

                    Text(description)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.App.textSecondary.opacity(0.5))
            }
            .glassCard()
        }
    }
}
