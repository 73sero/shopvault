import Foundation
import Combine

struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var autoLockTimeout: Int = 300
    @Published var currency: String = "USD"
    @Published var locale: String = "en_US"
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var showingLogoutConfirm = false
    @Published var saveSuccess: String?
    @Published var showingExportPasswordSheet = false
    @Published var exportPassphrase = ""
    @Published var exportPassphraseConfirmation = ""
    @Published var isExporting = false
    @Published var exportError: String?
    @Published var exportSuccess: String?
    @Published var exportShareItem: ExportShareItem?
    
    private let appState: AppState
    private let settingsRepository: AppSettingsRepository
    
    init(
        appState: AppState,
        settingsRepository: AppSettingsRepository? = nil
    ) {
        self.appState = appState
        self.settingsRepository = settingsRepository ?? AppSettingsRepository()
    }
    
    // MARK: - Public Methods
    
    func loadSettings(userId: String) {
        Task {
            do {
                let settings = try await settingsRepository.getOrCreateSettings(for: userId)
                autoLockTimeout = settings.autoLockTimeoutSeconds
                currency = settings.currency
                locale = settings.locale
                appState.applySettings(settings)
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    func saveSettings(userId: String) {
        isSaving = true
        saveError = nil
        saveSuccess = nil
        
        guard autoLockTimeout >= 60 else {
            saveError = t("min_timeout_error")
            isSaving = false
            return
        }

        let newSettings = AppSettings(
            userId: userId,
            autoLockTimeoutSeconds: autoLockTimeout,
            currency: currency,
            locale: locale,
            updatedAt: Date()
        )

        Task {
            do {
                try await settingsRepository.upsertSettings(newSettings)
                appState.applySettings(newSettings)
                saveSuccess = t("settings_saved")
                isSaving = false
            } catch {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
    
    func logout() {
        appState.handleLogout()
    }

    func prepareLaptopExport() {
        exportError = nil
        exportSuccess = nil
        exportPassphrase = ""
        exportPassphraseConfirmation = ""
        showingExportPasswordSheet = true
    }

    func exportDataForLaptop() {
        exportError = nil
        exportSuccess = nil

        guard exportPassphrase.count >= 12 else {
            exportError = t("export_password_too_short")
            return
        }

        guard exportPassphrase == exportPassphraseConfirmation else {
            exportError = t("export_password_mismatch")
            return
        }

        let passphrase = exportPassphrase
        isExporting = true

        Task {
            let authResult = await BiometricAuth.authenticateWithFallback(
                localizedReason: t("export_device_auth_reason")
            )

            switch authResult {
            case .success:
                break
            case .failure(let error):
                exportError = biometricMessage(for: error)
                clearExportPassphrases()
                isExporting = false
                return
            }

            do {
                let url = try DataExportService().createEncryptedExport(passphrase: passphrase)
                exportShareItem = ExportShareItem(url: url)
                exportSuccess = t("export_ready")
                clearExportPassphrases()
                showingExportPasswordSheet = false
                isExporting = false
            } catch {
                exportError = error.localizedDescription
                clearExportPassphrases()
                isExporting = false
            }
        }
    }

    func cancelLaptopExport() {
        clearExportPassphrases()
        showingExportPasswordSheet = false
    }
    
    // MARK: - Computed Properties
    
    var autoLockTimeoutMinutes: Double {
        Double(autoLockTimeout) / 60.0
    }
    
    var autoLockTimeoutDisplay: String {
        let minutes = autoLockTimeout / 60
        if minutes == 1 {
            return String(format: t("minutes_format"), minutes)
        } else if minutes > 0 {
            return String(format: t("minutes_format"), minutes)
        } else {
            return String(format: t("seconds_format"), autoLockTimeout)
        }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }

    private func clearExportPassphrases() {
        exportPassphrase = ""
        exportPassphraseConfirmation = ""
    }

    private func biometricMessage(for error: BiometricError) -> String {
        switch error {
        case .notAvailable:
            return t("device_auth_not_available")
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
}
