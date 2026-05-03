import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    // ViewModels statt Repositories
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var incomeListViewModel: IncomeListViewModel
    @StateObject private var addIncomeViewModel: AddIncomeViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    
    init(
        incomeRepository: IncomeRepository,
        categoryRepository: CategoryRepository,
        appState: AppState
    ) {
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(incomeRepository: incomeRepository))
        _incomeListViewModel = StateObject(wrappedValue: IncomeListViewModel(incomeRepository: incomeRepository))
        _addIncomeViewModel = StateObject(wrappedValue: AddIncomeViewModel(
            incomeRepository: incomeRepository,
            categoryRepository: categoryRepository
        ))
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(appState: appState))
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Dashboard Tab
                DashboardView(viewModel: dashboardViewModel)
                    .tabItem {
                        Label(t("tab_dashboard"), systemImage: "chart.pie")
                    }
                    .tag(0)
                
                // Income List Tab
                IncomeListView(viewModel: incomeListViewModel)
                    .tabItem {
                        Label(t("tab_income"), systemImage: "list.bullet")
                    }
                    .tag(1)
                
                // Add Income Tab
                AddIncomeView(viewModel: addIncomeViewModel)
                    .tabItem {
                        Label(t("tab_add"), systemImage: "plus.circle")
                    }
                    .tag(2)
                
                // Settings Tab
                SettingsView(viewModel: settingsViewModel)
                    .tabItem {
                        Label(t("tab_settings"), systemImage: "gear")
                    }
                    .tag(3)
            }
            .tint(Color(red: 0, green: 1, blue: 0.533))
            
            // Lock Overlay
            if appState.isLocked {
                Color.black
                    .ignoresSafeArea()
                VStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0.533))
                    Text(t("app_locked"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(t("tap_to_unlock"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }
}

#Preview("Main Tabs") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.isLocked = false
        state.requiresPINSetup = false
        state.currentUser = User.sample
        return state
    }()

    return MainTabView(
        incomeRepository: IncomeRepository(),
        categoryRepository: CategoryRepository(),
        appState: appState
    )
    .environmentObject(appState)
}
