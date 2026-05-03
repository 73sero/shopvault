import Foundation
import LocalAuthentication
import Combine

@MainActor
class AppLockViewModel: ObservableObject {
    @Published var pinEntry = ""
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var biometricAvailable = false
    @Published var biometryType: LABiometryType = .none
    @Published var requiredPINLength = 6
    @Published private(set) var remainingLockoutSeconds = 0
    var localeIdentifier: String { appState.localeIdentifier }
    
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

        Task {
            let result = await BiometricAuth.authenticate(
                localizedReason: t("biometric_unlock_reason")
            )

            switch result {
            case .success:
                await handleAuthentication()
            case .failure(let error):
                authError = message(for: error)
            }

            isAuthenticating = false
        }
    }
    
    // MARK: - PIN
    
    func attemptPINAuth() {
        isAuthenticating = true
        authError = nil

        if isPINBlocked {
            authError = String(format: t("pin_locked_try_later_seconds"), remainingLockoutSeconds)
            isAuthenticating = false
            return
        }

        guard pinEntry.count == requiredPINLength else {
            authError = String(format: t("pin_exact_digits_error"), requiredPINLength)
            isAuthenticating = false
            return
        }
        
        Task {
            do {
                // Verify PIN against stored hash
                guard let user = try await userRepository.getCurrentUser() else {
                    authError = t("user_not_found")
                    isAuthenticating = false
                    return
                }
                
                guard let storedHash = user.pinHash, keychainManager.verifyPIN(pinEntry, matches: storedHash) else {
                    registerFailedPINAttempt()
                    authError = isPINBlocked
                        ? String(format: t("pin_locked_try_later_seconds"), remainingLockoutSeconds)
                        : t("incorrect_pin")
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

    func resetPINWithDeviceAuth() {
        isAuthenticating = true
        authError = nil

        Task {
            let authResult = await BiometricAuth.authenticateWithFallback(
                localizedReason: t("pin_reset_auth_reason")
            )

            switch authResult {
            case .success:
                break
            case .failure(let error):
                authError = message(for: error)
                isAuthenticating = false
                return
            }

            do {
                guard let user = try await userRepository.getCurrentUser() else {
                    authError = t("user_not_found")
                    isAuthenticating = false
                    return
                }

                let updatedUser = User(
                    id: user.id,
                    biometricEnabled: user.biometricEnabled,
                    pinHash: nil,
                    createdAt: user.createdAt,
                    updatedAt: Date()
                )

                try await userRepository.updateUser(updatedUser)
                appState.requirePINSetup(with: updatedUser)
                resetFailedPINState()
                requiredPINLength = 6
                pinEntry = ""
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }
    
    // MARK: - Private
    
    func refreshBiometricAvailability() {
        checkBiometricAvailability()
    }

    var biometricUnlockTitleKey: String {
        switch biometryType {
        case .faceID:
            return "unlock_with_face_id"
        case .touchID:
            return "unlock_with_touch_id"
        default:
            return "unlock_with_biometrics"
        }
    }

    var biometricIconName: String {
        switch biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "person.crop.circle.badge.checkmark"
        }
    }

    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        let isDeviceBiometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        biometryType = context.biometryType

        guard isDeviceBiometricAvailable else {
            biometricAvailable = false
            return
        }

        biometricAvailable = appState.currentUser?.biometricEnabled ?? false
    }

    private func message(for error: BiometricError) -> String {
        switch error {
        case .notAvailable:
            return t("biometric_not_available")
        case .notEnrolled:
            return t("biometric_not_enrolled")
        case .authenticationFailed:
            return t("authentication_failed")
        case .userCancelled:
            return t("authentication_cancelled")
        case .lockedOut:
            return t("biometric_locked_out")
        case .unknown(let message):
            return message
        }
    }

    private func resolveRequiredPINLength() {
        if let hash = appState.currentUser?.pinHash {
            requiredPINLength = keychainManager.pinLength(from: hash)
        }
    }
    
    private func handleAuthentication() async {
        do {
            guard let user = try await userRepository.getCurrentUser() else {
                authError = t("failed_to_load_user")
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
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLockoutCountdown()
            }
        }
    }

    private func updateLockoutCountdown() {
        if isPINBlocked {
            return
        }

        lockoutTimer?.invalidate()
        lockoutTimer = nil
    }

    private func resetFailedPINState() {
        failedPINAttempts = 0
        lockoutUntil = nil
        remainingLockoutSeconds = 0
        lockoutTimer?.invalidate()
        lockoutTimer = nil
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }
}
