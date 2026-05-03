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
    
    // Security state
    @Published var lastLockTime: Date?
    @Published var isBiometricAvailable = false
    @Published var showingPINEntry = false
    @Published var authenticationError: String?
    
    private var lockTimer: Timer?
    private let autoLockTimeoutSeconds = 300  // 5 minutes
    
    nonisolated init() {}
    
    // MARK: - Authentication
    
    func handleAuthentication(user: User, categories: [Category]) {
        self.currentUser = user
        self.categories = categories
        self.isAuthenticated = true
        self.requiresPINSetup = user.pinHash == nil
        self.isLocked = false
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
    
    func setAuthenticationError(_ error: String) {
        self.authenticationError = error
    }
    
    // MARK: - Auto-Lock
    
    private func startAutoLockTimer() {
        lockTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoLockTimeoutSeconds), repeats: false) { [weak self] _ in
            Task { @MainActor in
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
