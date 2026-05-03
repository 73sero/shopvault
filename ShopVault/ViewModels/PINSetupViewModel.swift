import Foundation
import Combine

@MainActor
class PINSetupViewModel: ObservableObject {
    @Published var pin = ""
    @Published var confirmPIN = ""
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let keychainManager: KeychainManager
    private let userRepository: UserRepository
    private let appState: AppState

    init(
        keychainManager: KeychainManager,
        userRepository: UserRepository,
        appState: AppState
    ) {
        self.keychainManager = keychainManager
        self.userRepository = userRepository
        self.appState = appState
    }

    var canSubmit: Bool {
        pin.count == 6 && confirmPIN.count == 6 && !isSaving
    }

    func savePIN() {
        guard pin.count == 6, confirmPIN.count == 6 else {
            errorMessage = "Bitte 6-stellige PIN eingeben"
            return
        }

        guard pin == confirmPIN else {
            errorMessage = "PINs stimmen nicht ueberein"
            return
        }

        guard pin.allSatisfy(\.isNumber) else {
            errorMessage = "PIN darf nur Zahlen enthalten"
            return
        }

        guard let currentUser = appState.currentUser else {
            errorMessage = "Benutzer konnte nicht geladen werden"
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let hashedPIN = keychainManager.hashPIN(pin, length: 6)
                guard !hashedPIN.isEmpty else {
                    errorMessage = "PIN konnte nicht sicher gespeichert werden"
                    isSaving = false
                    return
                }
                let updatedUser = User(
                    id: currentUser.id,
                    biometricEnabled: currentUser.biometricEnabled,
                    pinHash: hashedPIN,
                    createdAt: currentUser.createdAt,
                    updatedAt: Date()
                )

                try await userRepository.updateUser(updatedUser)
                appState.completePINSetup(with: updatedUser)
                isSaving = false
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
