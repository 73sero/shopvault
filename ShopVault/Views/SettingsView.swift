import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        // Security Section
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: "Security", icon: "lock.shield.fill")

                            VStack(spacing: AppSpacing.sm) {
                                HStack {
                                    Text("Auto-Lock Timeout")
                                        .font(Font.App.body)
                                        .foregroundStyle(Color.App.textPrimary)
                                    Spacer()
                                    Text(viewModel.autoLockTimeoutDisplay)
                                        .font(Font.App.caption)
                                        .foregroundStyle(Color.App.accentPrimary)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.autoLockTimeout) },
                                        set: { viewModel.autoLockTimeout = Int($0) }
                                    ),
                                    in: 60...600,
                                    step: 60
                                )
                                .tint(Color.App.accentPrimary)
                            }
                            .glassCard()
                        }
                        .staggeredAppear(index: 0)

                        // About Section
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: "About", icon: "info.circle.fill")

                            VStack(spacing: 0) {
                                SettingsRow(label: "App Version", value: "1.0.0")
                                Divider().overlay(Color.white.opacity(0.05))
                                SettingsRow(label: "Build", value: "1")
                            }
                            .glassCard(padding: 0)
                        }
                        .staggeredAppear(index: 1)

                        // Logout
                        GradientButton(
                            title: "Logout",
                            icon: "arrow.backward.circle.fill",
                            action: { viewModel.showingLogoutConfirm = true },
                            style: .danger
                        )
                        .staggeredAppear(index: 2)
                    }
                    .padding(AppSpacing.md)
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .alert("Logout?", isPresented: $viewModel.showingLogoutConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Logout", role: .destructive) {
                        viewModel.logout()
                    }
                } message: {
                    Text("You will be returned to the lock screen.")
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.App.accentPrimary)

            Text(title)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
        }
        .padding(.horizontal, AppSpacing.xxs)
    }
}

struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(Font.App.body)
                .foregroundStyle(Color.App.textPrimary)
            Spacer()
            Text(value)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)
        }
        .padding(AppSpacing.md)
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(appState: AppState()))
        .environmentObject(AppState())
}
