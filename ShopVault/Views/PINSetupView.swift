import SwiftUI

struct PINSetupView: View {
    @StateObject var viewModel: PINSetupViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case pin
        case confirm
    }

    var body: some View {
        ZStack {
            AnimatedMeshGradientLockView()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.App.accentPrimary.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)

                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(LinearGradient.appAccent)
                    }

                    Text("PIN einrichten")
                        .font(Font.App.title)
                        .foregroundStyle(Color.App.textPrimary)

                    Text("Diese PIN brauchst du spaeter zum Entsperren der App.")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .staggeredAppear(index: 0)

                VStack(spacing: AppSpacing.sm) {
                    SecureField("6-stellige PIN", text: Binding(
                        get: { viewModel.pin },
                        set: { viewModel.pin = String($0.prefix(6).filter(\.isNumber)) }
                    ))
                        .keyboardType(.numberPad)
                        .padding(AppSpacing.md)
                        .background(Color.App.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(Color.App.textPrimary)
                        .focused($focusedField, equals: .pin)

                    SecureField("PIN bestaetigen", text: Binding(
                        get: { viewModel.confirmPIN },
                        set: { viewModel.confirmPIN = String($0.prefix(6).filter(\.isNumber)) }
                    ))
                        .keyboardType(.numberPad)
                        .padding(AppSpacing.md)
                        .background(Color.App.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(Color.App.textPrimary)
                        .focused($focusedField, equals: .confirm)
                }
                .staggeredAppear(index: 1)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.danger)
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Color.App.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }

                GradientButton(
                    title: viewModel.isSaving ? "Speichere..." : "PIN speichern",
                    icon: "checkmark.shield.fill",
                    action: { viewModel.savePIN() },
                    isDisabled: !viewModel.canSubmit,
                    isLoading: viewModel.isSaving
                )
                .staggeredAppear(index: 2)

                Spacer()
            }
            .padding(AppSpacing.lg)
        }
        .onAppear {
            focusedField = .pin
        }
    }
}

#Preview {
    PINSetupView(viewModel: PINSetupViewModel(
        keychainManager: KeychainManager(),
        userRepository: UserRepository(),
        appState: AppState()
    ))
}
