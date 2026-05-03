import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var pin = ""
    @State private var confirmPIN = ""
    @State private var selectedPINLength = 6
    @State private var enableBiometricUnlock = true
    @State private var biometricType: LABiometryType = LABiometryType.none
    @State private var biometricCanAuthenticate = false
    @State private var setupError: String?
    @State private var isSavingPIN = false
    @State private var appLockViewModel: AppLockViewModel?
    @State private var showingLocalStoreResetConfirmation = false

    private let previewBiometricTypeOverride: LABiometryType?
    private let previewBiometricEnabledOverride: Bool?

    init(
        previewBiometricTypeOverride: LABiometryType? = nil,
        previewBiometricEnabledOverride: Bool? = nil,
        previewInitialPINLength: Int = 6
    ) {
        self.previewBiometricTypeOverride = previewBiometricTypeOverride
        self.previewBiometricEnabledOverride = previewBiometricEnabledOverride
        _selectedPINLength = State(initialValue: previewInitialPINLength)
        _enableBiometricUnlock = State(initialValue: previewBiometricEnabledOverride ?? true)
    }

    var body: some View {
        ZStack {
            if appState.isAuthenticated && appState.requiresPINSetup {
                ZStack {
                    AnimatedMeshGradientLockView()

                    VStack(spacing: AppSpacing.lg) {
                        Spacer()

                        VStack(spacing: AppSpacing.sm) {
                            ZStack {
                                Circle().fill(Color.App.accentPrimary.opacity(0.2)).frame(width: 100, height: 100).blur(radius: 20)
                                Image(systemName: "shield.lefthalf.filled").font(.system(size: 44, weight: .medium)).foregroundStyle(LinearGradient.appAccent)
                            }
                            Text(t("pin_setup_title")).font(Font.App.title).foregroundStyle(Color.App.textPrimary)
                            Text(t("pin_setup_subtitle")).font(Font.App.caption).foregroundStyle(Color.App.textSecondary).multilineTextAlignment(.center)
                        }
                        .staggeredAppear(index: 0)

                        VStack(spacing: AppSpacing.sm) {
                            Picker(t("pin_length_label"), selection: $selectedPINLength) {
                                Text(t("pin_length_4")).tag(4)
                                Text(t("pin_length_6")).tag(6)
                                Text(t("pin_length_8")).tag(8)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedPINLength) { _, newLength in
                                pin = String(pin.filter(\.isNumber).prefix(newLength))
                                confirmPIN = String(confirmPIN.filter(\.isNumber).prefix(newLength))
                            }

                            SecureField(String(format: t("pin_digits_placeholder"), selectedPINLength), text: Binding(
                                get: { pin },
                                set: { pin = sanitizePINInput($0) }
                            ))
                            .keyboardType(.numberPad).padding(AppSpacing.md).background(Color.App.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.small).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .foregroundStyle(Color.App.textPrimary)

                            SecureField(t("pin_confirm_placeholder"), text: Binding(
                                get: { confirmPIN },
                                set: { confirmPIN = sanitizePINInput($0) }
                            ))
                            .keyboardType(.numberPad).padding(AppSpacing.md).background(Color.App.bgTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.small).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .foregroundStyle(Color.App.textPrimary)

                            if biometricType != LABiometryType.none {
                                Toggle(isOn: $enableBiometricUnlock) {
                                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                        Text(biometricToggleTitle)
                                            .font(Font.App.caption)
                                            .foregroundStyle(Color.App.textPrimary)
                                        Text(biometricCanAuthenticate ? t("biometric_setup_hint") : t("biometric_setup_unavailable_hint"))
                                            .font(Font.App.smallCaption)
                                            .foregroundStyle(Color.App.textSecondary)
                                    }
                                }
                                .tint(Color.App.accentPrimary)
                                .disabled(!biometricCanAuthenticate)
                                .padding(AppSpacing.md)
                                .background(Color.App.bgTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.small).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            }
                        }
                        .staggeredAppear(index: 1)

                        if let setupError {
                            Text(setupError).font(Font.App.caption).foregroundStyle(Color.App.danger)
                                .padding(AppSpacing.sm).frame(maxWidth: .infinity)
                                .background(Color.App.danger.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        }

                        GradientButton(title: isSavingPIN ? t("saving") : t("pin_save"), icon: "checkmark.shield.fill", action: savePIN, isDisabled: !canSavePIN, isLoading: isSavingPIN)
                            .staggeredAppear(index: 2)

                        Spacer()
                    }
                    .padding(AppSpacing.lg)
                    .onAppear {
                        preparePINSetupOptions()
                    }
                }
            } else if appState.isAuthenticated && appState.needsOnboarding && !appState.isLocked {
                OnboardingView(viewModel: OnboardingViewModel())
            } else if appState.isAuthenticated {
                ZStack {
                    NavigationStack {
                        HubView(viewModel: HubViewModel())
                            .navigationDestination(for: String.self) { destination in
                                switch destination {
                                case "shop":
                                    ShopView()
                                case "finance":
                                    FinanceView()
                                default:
                                    EmptyView()
                                }
                            }
                    }

                    if appState.isLocked {
                        AppLockView(viewModel: getOrCreateLockViewModel())
                            .zIndex(1)
                    }
                }
            } else if appState.isLocked {
                AppLockView(viewModel: getOrCreateLockViewModel())
            } else {
                ZStack {
                    Color.App.bgPrimary.ignoresSafeArea()
                    if let error = appState.authenticationError {
                        VStack(spacing: AppSpacing.md) {
                            Text(error)
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.danger)
                                .multilineTextAlignment(.center)

                            GradientButton(
                                title: t("retry"),
                                icon: "arrow.clockwise",
                                action: { appState.requestInitializationRetry() },
                                isDisabled: appState.isResettingLocalStore,
                                style: .secondary
                            )

                            if appState.canResetLocalStore {
                                Text(t("local_store_reset_explanation"))
                                    .font(Font.App.smallCaption)
                                    .foregroundStyle(Color.App.textSecondary)
                                    .multilineTextAlignment(.center)

                                GradientButton(
                                    title: appState.isResettingLocalStore ? t("resetting") : t("reset_local_data"),
                                    icon: "exclamationmark.triangle.fill",
                                    action: { showingLocalStoreResetConfirmation = true },
                                    isDisabled: appState.isResettingLocalStore,
                                    isLoading: appState.isResettingLocalStore,
                                    style: .danger
                                )
                            }
                        }
                        .padding(AppSpacing.lg)
                    } else {
                        ProgressView(t("initializing"))
                            .tint(Color.App.accentPrimary)
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }
            }
        }
        .alert(t("reset_local_data"), isPresented: $showingLocalStoreResetConfirmation) {
            Button(t("cancel"), role: .cancel) {}
            Button(t("reset_local_data"), role: .destructive) {
                appState.requestLocalStoreRecoveryReset()
            }
        } message: {
            Text(t("local_store_reset_confirmation"))
        }
    }

    private var canSavePIN: Bool {
        pin.count == selectedPINLength
            && confirmPIN.count == selectedPINLength
            && pin == confirmPIN
            && pin.allSatisfy(\.isNumber)
            && !isSavingPIN
    }

    private func savePIN() {
        setupError = nil
        pin = sanitizePINInput(pin)
        confirmPIN = sanitizePINInput(confirmPIN)
        guard pin.count == selectedPINLength, confirmPIN.count == selectedPINLength else {
            setupError = String(format: t("pin_exact_digits_error"), selectedPINLength); return
        }
        guard pin.allSatisfy(\.isNumber), confirmPIN.allSatisfy(\.isNumber) else {
            setupError = String(format: t("pin_exact_digits_error"), selectedPINLength); return
        }
        guard pin == confirmPIN else { setupError = t("pin_mismatch_error"); return }
        guard let user = appState.currentUser else { setupError = t("user_not_found"); return }
        isSavingPIN = true
        Task {
            do {
                let keychainManager = KeychainManager()
                let userRepository = UserRepository()
                let hashedPIN = keychainManager.hashPIN(pin, length: selectedPINLength)
                let updatedUser = User(
                    id: user.id,
                    biometricEnabled: biometricType != LABiometryType.none && biometricCanAuthenticate ? enableBiometricUnlock : false,
                    pinHash: hashedPIN,
                    createdAt: user.createdAt,
                    updatedAt: Date()
                )
                try await userRepository.updateUser(updatedUser)
                appState.completePINSetup(with: updatedUser)
                HapticManager.notification(.success)
                pin = ""; confirmPIN = ""; isSavingPIN = false
            } catch {
                setupError = error.localizedDescription; isSavingPIN = false
            }
        }
    }

    private var biometricToggleTitle: String {
        switch biometricType {
        case .faceID:
            return t("enable_face_id_unlock")
        case .touchID:
            return t("enable_touch_id_unlock")
        default:
            return t("enable_biometric_unlock")
        }
    }

    private func getOrCreateLockViewModel() -> AppLockViewModel {
        if let existing = appLockViewModel {
            return existing
        }
        let vm = AppLockViewModel(
            keychainManager: KeychainManager(),
            userRepository: UserRepository(),
            categoryRepository: CategoryRepository(),
            appState: appState
        )
        appLockViewModel = vm
        return vm
    }

    private func preparePINSetupOptions() {
        if let previewBiometricTypeOverride {
            biometricType = previewBiometricTypeOverride
            biometricCanAuthenticate = previewBiometricTypeOverride != LABiometryType.none
        } else {
            biometricType = BiometricAuth.biometricTypeForSetup()
            biometricCanAuthenticate = BiometricAuth.isAvailable()
        }

        if biometricType == LABiometryType.none || !biometricCanAuthenticate {
            enableBiometricUnlock = false
        } else {
            enableBiometricUnlock = previewBiometricEnabledOverride ?? appState.currentUser?.biometricEnabled ?? true
        }
    }

    private func sanitizePINInput(_ input: String) -> String {
        String(input.filter(\.isNumber).prefix(selectedPINLength))
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }
}

#Preview("PIN Setup") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.requiresPINSetup = true
        state.isLocked = false
        state.currentUser = User(id: "preview-user", biometricEnabled: true, pinHash: nil)
        state.localeIdentifier = "en_US"
        return state
    }()

    return ContentView(
        previewBiometricTypeOverride: .faceID,
        previewBiometricEnabledOverride: true,
        previewInitialPINLength: 6
    )
    .environmentObject(appState)
}

#Preview("PIN Setup DE ohne Biometrie") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.requiresPINSetup = true
        state.isLocked = false
        state.currentUser = User(id: "preview-user-de", biometricEnabled: false, pinHash: nil)
        state.localeIdentifier = "de_DE"
        state.currencyCode = "EUR"
        return state
    }()

    return ContentView(
        previewBiometricTypeOverride: LABiometryType.none,
        previewBiometricEnabledOverride: false,
        previewInitialPINLength: 4
    )
    .environmentObject(appState)
}

#Preview("Unlocked") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.requiresPINSetup = false
        state.isLocked = false
        state.currentUser = User.sample
        state.localeIdentifier = "de_DE"
        state.currencyCode = "EUR"
        return state
    }()

    return ContentView().environmentObject(appState)
}

#Preview("Locked") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.requiresPINSetup = false
        state.isLocked = true
        state.currentUser = User.sample
        return state
    }()

    return ContentView().environmentObject(appState)
}
