import SwiftUI

@main
struct ShopVaultApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    initializeApp()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    appState.handleScenePhaseChange(newPhase)
                }
        }
    }
    
    private func initializeApp() {
        Task {
            do {
                // Open database connection
                try DatabaseManager.shared.open()
                
                // Load user
                let userRepository = UserRepository()
                if let user = try await userRepository.getCurrentUser() {
                    let categoryRepository = CategoryRepository()
                    let categories = try await categoryRepository.getCategoriesForUser(user.id)
                    appState.initializeSession(user: user, categories: categories)
                } else {
                    // Create default user if none exists
                    let newUser = User()
                    try await userRepository.createUser(newUser)
                    
                    let categoryRepository = CategoryRepository()
                    try await categoryRepository.createDefaultCategories(for: newUser.id)
                    
                    let categories = try await categoryRepository.getCategoriesForUser(newUser.id)
                    appState.initializeSession(user: newUser, categories: categories)
                }
            } catch {
                #if DEBUG
                print("Initialization error: \(error.localizedDescription)")
                #endif

                if let dbError = error as? DatabaseError,
                   case .sqlcipherUnavailable = dbError {
                    appState.setAuthenticationError("SQLCipher missing: link SQLCipher instead of libsqlite3.")
                } else {
                    appState.setAuthenticationError("Failed to initialize app securely")
                }
            }
        }
    }
}
