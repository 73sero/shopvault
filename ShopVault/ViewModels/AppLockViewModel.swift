import Foundation
import LocalAuthentication
import Combine

@MainActor
class AppLockViewModel: ObservableObject {
    @Published var pinEntry = ""
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var biometricAvailable = false
    @Published var requiredPINLength = 6
    @Published private(set) var remainingLockoutSeconds = 0

    private let keychainManager: KeychainManager
    private let userRepository: UserRepository
    private let categoryRepository: CategoryRepository
    private let appState: AppState
    private let lockoutScheduleSeconds = [30, 300, 1800]
    private var failedPINAttempts = 0
    private var lockoutUntil: Date?
    private var lockoutTimer: Timer?

    init(
        keychainManager: KeychainManager,
        userRepository: UserRepository,
        categoryRepository: CategoryRepository,
        appState: AppState
    ) {
        self.keychainManager = keychainManager
        self.userRepository = userRepository
        self.categoryRepository = categoryRepository
        self.appState = appState
        checkBiometricAvailability()
        resolveRequiredPINLength()
    }

    deinit {
        lockoutTimer?.invalidate()
    }

    var isPINLockedOut: Bool {
        remainingLockoutSeconds > 0
    }

    // MARK: - Biometric

    func attemptBiometricAuth() {
        isAuthenticating = true
        authError = nil

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authError = "Biometric not available"
            isAuthenticating = false
            return
        }

        Task {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Unlock ShopVault"
                )

                if success {
                    await handleAuthentication()
                } else {
                    authError = "Authentication failed"
                }
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }

    // MARK: - PIN

    func attemptPINAuth() {
        isAuthenticating = true
        authError = nil

        if isPINBlocked {
            authError = "Too many attempts. Try again in \(remainingLockoutSeconds) sec."
            isAuthenticating = false
            return
        }

        guard pinEntry.count == requiredPINLength else {
            authError = "PIN must be exactly \(requiredPINLength) digits"
            isAuthenticating = false
            return
        }

        Task {
            do {
                guard let user = try await userRepository.getCurrentUser() else {
                    authError = "User not found"
                    isAuthenticating = false
                    return
                }

                guard let storedHash = user.pinHash,
                      keychainManager.verifyPIN(pinEntry, matches: storedHash) else {
                    registerFailedPINAttempt()
                    authError = isPINBlocked
                        ? "Too many attempts. Try again in \(remainingLockoutSeconds) sec."
                        : "Incorrect PIN"
                    pinEntry = ""
                    isAuthenticating = false
                    return
                }

                resetFailedPINState()
                await handleAuthentication()
                pinEntry = ""
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }

    // MARK: - Private

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        biometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    private func resolveRequiredPINLength() {
        if let hash = appState.currentUser?.pinHash {
            requiredPINLength = keychainManager.pinLength(from: hash)
            return
        }

        Task {
            if let user = try? await userRepository.getCurrentUser() {
                requiredPINLength = keychainManager.pinLength(from: user.pinHash)
            }
        }
    }

    private func handleAuthentication() async {
        do {
            guard let user = try await userRepository.getCurrentUser() else {
                authError = "Failed to load user"
                return
            }

            let categories = try await categoryRepository.getCategoriesForUser(user.id)
            appState.handleAuthentication(user: user, categories: categories)
        } catch {
            authError = error.localizedDescription
        }
    }

    private var isPINBlocked: Bool {
        guard let lockoutUntil else {
            remainingLockoutSeconds = 0
            return false
        }

        let seconds = max(0, Int(lockoutUntil.timeIntervalSinceNow.rounded(.up)))
        remainingLockoutSeconds = seconds
        if seconds == 0 {
            self.lockoutUntil = nil
            lockoutTimer?.invalidate()
            lockoutTimer = nil
            return false
        }

        return true
    }

    private func registerFailedPINAttempt() {
        failedPINAttempts += 1

        guard failedPINAttempts >= 3 else {
            return
        }

        let lockoutIndex = min(
            failedPINAttempts - 3,
            lockoutScheduleSeconds.count - 1
        )
        let seconds = lockoutScheduleSeconds[lockoutIndex]
        lockoutUntil = Date().addingTimeInterval(TimeInterval(seconds))
        remainingLockoutSeconds = seconds
        startLockoutTimer()
    }

    private func startLockoutTimer() {
        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }

                self.updateLockoutCountdown(using: timer)
            }
        }
    }

    private func updateLockoutCountdown(using timer: Timer) {
        if isPINBlocked {
            return
        }

        timer.invalidate()
    }

    private func resetFailedPINState() {
        failedPINAttempts = 0
        lockoutUntil = nil
        remainingLockoutSeconds = 0
        lockoutTimer?.invalidate()
        lockoutTimer = nil
    }
}
