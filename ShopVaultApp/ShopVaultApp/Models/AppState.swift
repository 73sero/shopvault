import Foundation
import Combine
import SwiftUI

/// Global app state managed by root App
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLocked = false
    @Published var requiresPINSetup = false
    @Published var categories: [Category] = []
    @Published var lowStockCount: Int = 0
    @Published var salesCategoryId: String?
    @Published var needsOnboarding: Bool = false

    // Security state
    @Published var lastLockTime: Date?
    @Published var isBiometricAvailable = false
    @Published var showingPINEntry = false
    @Published var authenticationError: String?
    @Published var canResetLocalStore = false
    @Published var isResettingLocalStore = false
    @Published var autoLockTimeoutSeconds = 300
    @Published var currencyCode = "USD"
    @Published var localeIdentifier = "en_US"
    var retryInitialization: (() -> Void)?
    var resetLocalStoreForRecovery: (() -> Void)?
    
    private var lockTimer: Timer?
    
    nonisolated init() {}
    
    // MARK: - Authentication
    
    func handleAuthentication(user: User, categories: [Category]) {
        self.currentUser = user
        self.categories = categories
        self.isAuthenticated = true
        self.requiresPINSetup = user.pinHash == nil
        self.isLocked = false
        self.authenticationError = nil
        self.canResetLocalStore = false
        self.lastLockTime = Date()
        startAutoLockTimer()
    }

    func initializeSession(user: User, categories: [Category]) {
        self.currentUser = user
        self.categories = categories
        self.isAuthenticated = true
        self.requiresPINSetup = user.pinHash == nil
        self.isLocked = user.pinHash != nil
        self.authenticationError = nil
        self.canResetLocalStore = false
        self.lastLockTime = Date()

        stopAutoLockTimer()
        if !isLocked && !requiresPINSetup {
            startAutoLockTimer()
        }
    }

    func completePINSetup(with user: User) {
        self.currentUser = user
        self.requiresPINSetup = false
        self.isLocked = false
        self.authenticationError = nil
        self.canResetLocalStore = false
        self.lastLockTime = Date()
        resetAutoLockTimer()
    }

    func applySettings(_ settings: AppSettings) {
        autoLockTimeoutSeconds = max(60, settings.autoLockTimeoutSeconds)
        currencyCode = settings.currency
        needsOnboarding = !settings.onboardingCompleted
        localeIdentifier = settings.locale
        resetAutoLockTimer()
    }

    func requirePINSetup(with user: User) {
        self.currentUser = user
        self.isAuthenticated = true
        self.requiresPINSetup = true
        self.isLocked = false
        self.authenticationError = nil
        self.canResetLocalStore = false
        self.lastLockTime = Date()
        resetAutoLockTimer()
    }
    
    func handleLogout() {
        self.currentUser = nil
        self.isAuthenticated = false
        self.isLocked = true
        self.requiresPINSetup = false
        self.categories = []
        stopAutoLockTimer()
        self.authenticationError = nil
        self.canResetLocalStore = false
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        guard isAuthenticated else { return }

        switch phase {
        case .background:
            isLocked = true
            stopAutoLockTimer()
        case .active:
            if !requiresPINSetup && !isLocked {
                resetAutoLockTimer()
            }
        default:
            break
        }
    }
    
    func setAuthenticationError(_ error: String, canResetLocalStore: Bool = false) {
        self.authenticationError = error
        self.canResetLocalStore = canResetLocalStore
    }

    func clearAuthenticationError() {
        self.authenticationError = nil
        self.canResetLocalStore = false
    }

    func requestInitializationRetry() {
        retryInitialization?()
    }

    func requestLocalStoreRecoveryReset() {
        resetLocalStoreForRecovery?()
    }
    
    // MARK: - CRM

    func refreshLowStockCount() {
        Task {
            do {
                let count = try await ProductRepository().getLowStockCount()
                self.lowStockCount = count
            } catch {
                print("Failed to refresh low stock count: \(error)")
            }
        }
    }

    // MARK: - Auto-Lock
    
    private func startAutoLockTimer() {
        lockTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoLockTimeoutSeconds), repeats: false) { _ in
            Task { @MainActor [weak self] in
                self?.isLocked = true
            }
        }
    }
    
    private func stopAutoLockTimer() {
        lockTimer?.invalidate()
        lockTimer = nil
    }
    
    func resetAutoLockTimer() {
        stopAutoLockTimer()
        if isAuthenticated {
            startAutoLockTimer()
        }
    }
}
