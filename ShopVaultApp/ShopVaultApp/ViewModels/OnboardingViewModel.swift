import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case picker
        case confirm
    }

    @Published var step: Step = .welcome
    @Published var selectedTemplate: IndustryTemplate?
    @Published var isInstalling: Bool = false
    @Published var errorMessage: String?

    let templates: [IndustryTemplate] = IndustryTemplate.all

    private let appSettingsRepository: AppSettingsRepository
    private let databaseManager: DatabaseManager

    init(
        appSettingsRepository: AppSettingsRepository = AppSettingsRepository(),
        databaseManager: DatabaseManager = .shared
    ) {
        self.appSettingsRepository = appSettingsRepository
        self.databaseManager = databaseManager
    }

    var canAdvance: Bool {
        switch step {
        case .welcome: return true
        case .picker: return selectedTemplate != nil
        case .confirm: return !isInstalling
        }
    }

    func next() {
        if let nextRaw = Step(rawValue: step.rawValue + 1) {
            step = nextRaw
        }
    }

    func back() {
        if let prevRaw = Step(rawValue: step.rawValue - 1) {
            step = prevRaw
        }
    }

    /// Seeds the chosen template (if any products), marks onboarding complete,
    /// updates AppState, then calls completion.
    func install(userId: String, appState: AppState, completion: @escaping () -> Void) {
        guard let template = selectedTemplate else { return }

        isInstalling = true
        errorMessage = nil

        Task {
            do {
                // Seed products if the template has any (skip for `.empty`).
                if !template.products.isEmpty {
                    try databaseManager.seedProducts(template: template)
                }

                try await appSettingsRepository.markOnboardingComplete(userId: userId)

                appState.needsOnboarding = false
                appState.refreshLowStockCount()

                NotificationCenter.default.post(name: .stockDidChange, object: nil)

                isInstalling = false
                completion()
            } catch {
                errorMessage = error.localizedDescription
                isInstalling = false
            }
        }
    }
}
