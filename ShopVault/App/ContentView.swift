import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddIncome = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            if appState.isAuthenticated && appState.requiresPINSetup {
                PINSetupView(viewModel: PINSetupViewModel(
                    keychainManager: KeychainManager(),
                    userRepository: UserRepository(),
                    appState: appState
                ))
            } else if appState.isAuthenticated && !appState.isLocked {
                TabView(selection: $selectedTab) {
                    DashboardView(viewModel: DashboardViewModel(
                        incomeRepository: IncomeRepository()
                    ))
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.pie.fill")
                    }
                    .tag(0)

                    IncomeListView(viewModel: IncomeListViewModel(
                        incomeRepository: IncomeRepository()
                    ))
                    .tabItem {
                        Label("Income", systemImage: "list.bullet")
                    }
                    .tag(1)

                    Color.clear
                        .tabItem {
                            Label("Add", systemImage: "plus.circle.fill")
                        }
                        .tag(2)

                    SettingsView(viewModel: SettingsViewModel(appState: appState))
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
                }
                .tint(Color.App.accentPrimary)
                .onChange(of: selectedTab) { _, newValue in
                    if newValue == 2 {
                        showAddIncome = true
                        selectedTab = 0
                    }
                    HapticManager.selection()
                }
                .sheet(isPresented: $showAddIncome) {
                    AddIncomeView(viewModel: AddIncomeViewModel(
                        incomeRepository: IncomeRepository(),
                        categoryRepository: CategoryRepository()
                    ))
                }
            } else if appState.isLocked {
                AppLockView(viewModel: AppLockViewModel(
                    keychainManager: KeychainManager(),
                    userRepository: UserRepository(),
                    categoryRepository: CategoryRepository(),
                    appState: appState
                ))
            } else {
                ZStack {
                    Color.App.bgPrimary.ignoresSafeArea()
                    if let error = appState.authenticationError {
                        Text(error)
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.danger)
                            .multilineTextAlignment(.center)
                            .padding(AppSpacing.lg)
                    } else {
                        ProgressView("Initialisiere...")
                            .tint(Color.App.accentPrimary)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
