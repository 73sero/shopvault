import SwiftUI

struct MainTabView: View {
    let incomeRepository: IncomeRepository
    let categoryRepository: CategoryRepository
    @EnvironmentObject var appState: AppState
    
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Dashboard Tab
                DashboardView(incomeRepository: incomeRepository)
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.pie")
                    }
                    .tag(0)
                
                // Income List Tab
                IncomeListView(incomeRepository: incomeRepository)
                    .tabItem {
                        Label("History", systemImage: "list.bullet")
                    }
                    .tag(1)
                
                // Add Income Tab
                AddIncomeView(
                    incomeRepository: incomeRepository,
                    categoryRepository: categoryRepository
                )
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }
                .tag(2)
                
                // Settings Tab
                SettingsView(appState: appState)
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
            }
            .tint(Color(red: 0, green: 1, blue: 0.533))
            
            // Lock Overlay (if needed)
            if appState.isLocked {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0.533))
                    
                    Text("App Locked")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Tap to unlock")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .onTapGesture {
                    appState.isLocked = false
                    appState.resetAutoLockTimer()
                }
            }
        }
    }
}

#Preview {
    MainTabView(
        incomeRepository: IncomeRepository(),
        categoryRepository: CategoryRepository()
    )
    .environmentObject(AppState())
}
