import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var autoLockTimeout: Int = 300
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var showingLogoutConfirm = false
    
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    func saveSettings() {
        isSaving = true
        saveError = nil
        
        // TODO: Persist settings to database
        // For now, just validate
        guard autoLockTimeout >= 60 else {
            saveError = "Minimum timeout is 60 seconds"
            isSaving = false
            return
        }
        
        // Simulate save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSaving = false
        }
    }
    
    func logout() {
        appState.handleLogout()
    }
    
    // MARK: - Computed Properties
    
    var autoLockTimeoutMinutes: Double {
        Double(autoLockTimeout) / 60.0
    }
    
    var autoLockTimeoutDisplay: String {
        let minutes = autoLockTimeout / 60
        if minutes == 1 {
            return "1 minute"
        } else if minutes > 0 {
            return "\(minutes) minutes"
        } else {
            return "\(autoLockTimeout) seconds"
        }
    }
}
