import SwiftUI

struct AppLockView: View {
    @StateObject var viewModel: AppLockViewModel
    @State private var showPINEntry = false
    @State private var iconScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            AnimatedMeshGradientLockView()

            VStack(spacing: AppSpacing.xxl) {
                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.App.accentPrimary.opacity(glowOpacity))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(LinearGradient.appAccent)
                            .scaleEffect(iconScale)
                    }

                    Text("ShopVault")
                        .font(Font.App.title)
                        .foregroundStyle(Color.App.textPrimary)

                    Text("Secure Income Tracking")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textSecondary)
                }
                .staggeredAppear(index: 0)

                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    if viewModel.biometricAvailable {
                        GradientButton(
                            title: "Unlock with Face ID",
                            icon: "faceid",
                            action: { viewModel.attemptBiometricAuth() },
                            isDisabled: viewModel.isAuthenticating
                        )
                        .staggeredAppear(index: 1)
                    }

                    GradientButton(
                        title: "Use PIN",
                        icon: "lock.fill",
                        action: { showPINEntry = true },
                        isDisabled: viewModel.isAuthenticating,
                        style: .secondary
                    )
                    .staggeredAppear(index: 2)
                }

                if let error = viewModel.authError {
                    Text(error)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.danger)
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Color.App.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }

                Spacer()
            }
            .padding(AppSpacing.lg)
        }
        .sheet(isPresented: $showPINEntry) {
            PINEntryView(viewModel: viewModel, isPresented: $showPINEntry)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                iconScale = 1.05
                glowOpacity = 0.6
            }

            if viewModel.biometricAvailable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.attemptBiometricAuth()
                }
            }
        }
    }
}

struct PINEntryView: View {
    @ObservedObject var viewModel: AppLockViewModel
    @Binding var isPresented: Bool
    @FocusState private var isFocused: Bool
    @State private var shakeCount = 0

    var body: some View {
        ZStack {
            Color.App.bgPrimary.ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                HStack {
                    Text("Enter \(viewModel.requiredPINLength)-digit PIN")
                        .font(Font.App.title2)
                        .foregroundStyle(Color.App.textPrimary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.App.textSecondary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)

                SecureField("PIN", text: Binding(
                    get: { viewModel.pinEntry },
                    set: { viewModel.pinEntry = String($0.filter(\.isNumber).prefix(viewModel.requiredPINLength)) }
                ))
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .opacity(0)
                    .frame(height: 1)

                HStack(spacing: AppSpacing.md) {
                    ForEach(0..<viewModel.requiredPINLength, id: \.self) { index in
                        Circle()
                            .fill(index < viewModel.pinEntry.count
                                  ? Color.App.accentPrimary
                                  : Color.App.bgTertiary)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(index < viewModel.pinEntry.count
                                            ? Color.App.accentPrimary
                                            : Color.white.opacity(0.1),
                                            lineWidth: 1)
                            )
                            .scaleEffect(index < viewModel.pinEntry.count ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.pinEntry.count)
                            .shadow(color: index < viewModel.pinEntry.count
                                    ? Color.App.accentGlow : .clear,
                                    radius: 8)
                    }
                }
                .shake(shakeCount)
                .padding(.vertical, AppSpacing.lg)
                .onTapGesture { isFocused = true }

                GradientButton(
                    title: "Unlock",
                    icon: "lock.open.fill",
                    action: {
                        viewModel.attemptPINAuth()
                        if viewModel.authError != nil {
                            withAnimation(.default) {
                                shakeCount += 3
                            }
                            HapticManager.notification(.error)
                        }
                    },
                    isDisabled: viewModel.pinEntry.count != viewModel.requiredPINLength || viewModel.isAuthenticating || viewModel.isPINLockedOut
                )
                .padding(.horizontal, AppSpacing.md)

                if viewModel.isPINLockedOut {
                    Text("Too many attempts. Try again in \(viewModel.remainingLockoutSeconds) sec.")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.danger)
                        .padding(.horizontal, AppSpacing.md)
                }

                if let error = viewModel.authError {
                    Text(error)
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.danger)
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Color.App.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        .padding(.horizontal, AppSpacing.md)
                }

                Spacer()
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    AppLockView(viewModel: AppLockViewModel(
        keychainManager: KeychainManager(),
        userRepository: UserRepository(),
        categoryRepository: CategoryRepository(),
        appState: AppState()
    ))
}
