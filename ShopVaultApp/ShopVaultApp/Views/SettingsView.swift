import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: t("security"), icon: "lock.shield.fill")
                            VStack(spacing: AppSpacing.sm) {
                                HStack {
                                    Text(t("auto_lock_timeout")).font(Font.App.body).foregroundStyle(Color.App.textPrimary)
                                    Spacer()
                                    Text(viewModel.autoLockTimeoutDisplay).font(Font.App.caption).foregroundStyle(Color.App.accentPrimary)
                                }
                                Slider(value: Binding(get: { Double(viewModel.autoLockTimeout) }, set: { viewModel.autoLockTimeout = Int($0) }), in: 60...600, step: 60)
                                    .tint(Color.App.accentPrimary)
                            }
                            .glassCard()
                        }
                        .staggeredAppear(index: 0)

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: t("laptop_access"), icon: "laptopcomputer")
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text(t("laptop_access_description"))
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textSecondary)
                                GradientButton(
                                    title: t("export_encrypted_data"),
                                    icon: "square.and.arrow.up",
                                    action: { viewModel.prepareLaptopExport() },
                                    isDisabled: viewModel.isExporting,
                                    isLoading: viewModel.isExporting,
                                    style: .secondary
                                )

                                if let success = viewModel.exportSuccess {
                                    Text(success).font(Font.App.caption).foregroundStyle(Color.App.accentPrimary)
                                }

                                if let error = viewModel.exportError {
                                    Text(error).font(Font.App.caption).foregroundStyle(Color.App.danger)
                                }
                            }
                            .glassCard()
                        }
                        .staggeredAppear(index: 1)

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: t("formatting"), icon: "textformat")
                            VStack(spacing: 0) {
                                HStack {
                                    Text(t("currency")).font(Font.App.body).foregroundStyle(Color.App.textPrimary)
                                    Spacer()
                                    Picker(t("currency"), selection: $viewModel.currency) {
                                        Text("USD").tag("USD"); Text("EUR").tag("EUR"); Text("GBP").tag("GBP")
                                    }.pickerStyle(.menu).tint(Color.App.accentPrimary)
                                }
                                .padding(AppSpacing.md)
                                Divider().overlay(Color.white.opacity(0.05))
                                HStack {
                                    Text(t("language")).font(Font.App.body).foregroundStyle(Color.App.textPrimary)
                                    Spacer()
                                    Picker(t("language"), selection: $viewModel.locale) {
                                        Text(t("lang_english_us")).tag("en_US"); Text(t("lang_german_de")).tag("de_DE"); Text(t("lang_english_gb")).tag("en_GB")
                                    }.pickerStyle(.menu).tint(Color.App.accentPrimary)
                                }
                                .padding(AppSpacing.md)
                            }
                            .glassCard(padding: 0)
                        }
                        .staggeredAppear(index: 2)

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: "Daten", icon: "tray.full.fill")
                            VStack(spacing: AppSpacing.sm) {
                                Button {
                                    HapticManager.impact(.light)
                                    viewModel.showingRestartOnboardingConfirm = true
                                } label: {
                                    SettingsActionRow(
                                        icon: "wand.and.stars",
                                        iconColor: Color.App.accentSecondary,
                                        title: "Onboarding-Wizard erneut starten",
                                        subtitle: "Wähle ein neues Branchen-Template aus"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().overlay(Color.white.opacity(0.05))

                                Button {
                                    HapticManager.impact(.medium)
                                    viewModel.showingDeleteAllConfirm = true
                                } label: {
                                    SettingsActionRow(
                                        icon: "trash.fill",
                                        iconColor: Color.App.danger,
                                        title: "Alle Daten löschen",
                                        subtitle: "Produkte, Kunden, Bestellungen, Lieferungen, Einnahmen — unwiderruflich"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .glassCard(padding: AppSpacing.sm)
                        }
                        .staggeredAppear(index: 3)

                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            SectionHeader(title: t("about"), icon: "info.circle.fill")
                            VStack(spacing: 0) {
                                SettingsRow(label: t("app_version"), value: "1.0.0")
                                Divider().overlay(Color.white.opacity(0.05))
                                SettingsRow(label: t("build"), value: "1")
                            }
                            .glassCard(padding: 0)
                        }
                        .staggeredAppear(index: 4)

                        GradientButton(title: t("logout"), icon: "arrow.backward.circle.fill", action: { viewModel.showingLogoutConfirm = true }, style: .danger)
                            .staggeredAppear(index: 5)
                    }
                    .padding(AppSpacing.md)
                }
                .navigationTitle(t("settings")).navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(viewModel.isSaving ? t("saving") : t("save")) {
                            if let userId = appState.currentUser?.id { viewModel.saveSettings(userId: userId) }
                        }
                        .disabled(viewModel.isSaving).foregroundStyle(Color.App.accentPrimary)
                    }
                }
                .alert(t("logout_confirm"), isPresented: $viewModel.showingLogoutConfirm) {
                    Button(t("cancel"), role: .cancel) {}
                    Button(t("logout"), role: .destructive) { viewModel.logout() }
                } message: { Text(t("logout_message")) }
                .alert("Onboarding erneut starten?", isPresented: $viewModel.showingRestartOnboardingConfirm) {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Starten") {
                        if let userId = appState.currentUser?.id {
                            viewModel.restartOnboarding(userId: userId, appState: appState)
                        }
                    }
                } message: {
                    Text("Du kannst danach ein neues Branchen-Template wählen oder leer starten. Bestehende Produkte, Bestellungen und Kunden werden nicht angetastet.")
                }
                .alert("Alle Daten löschen?", isPresented: $viewModel.showingDeleteAllConfirm) {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Endgültig löschen", role: .destructive) {
                        if let userId = appState.currentUser?.id {
                            viewModel.deleteAllData(userId: userId, appState: appState)
                        }
                    }
                } message: {
                    Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Produkte, Kunden, Bestellungen, Lieferungen und Einnahmen werden gelöscht. Dein Konto und PIN bleiben erhalten.")
                }
                .sheet(isPresented: $viewModel.showingExportPasswordSheet) {
                    ExportPasswordSheet(
                        viewModel: viewModel,
                        localeIdentifier: appState.localeIdentifier
                    )
                }
                .sheet(item: $viewModel.exportShareItem) { item in
                    ShareSheet(activityItems: [item.url])
                }
                .onAppear {
                    if let userId = appState.currentUser?.id { viewModel.loadSettings(userId: userId) }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: AppSpacing.xxs) {
                        if let success = viewModel.saveSuccess {
                            Text(success).font(Font.App.caption).foregroundStyle(Color.App.accentPrimary)
                        }
                        if let error = viewModel.saveError {
                            Text(error).font(Font.App.caption).foregroundStyle(Color.App.danger)
                        }
                    }
                    .padding(.bottom, AppSpacing.xs)
                }
            }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.App.accentPrimary)
            Text(title).font(Font.App.caption).foregroundStyle(Color.App.textSecondary).textCase(.uppercase).tracking(1)
        }
        .padding(.horizontal, AppSpacing.xxs)
    }
}

struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(Font.App.body).foregroundStyle(Color.App.textPrimary)
            Spacer()
            Text(value).font(Font.App.caption).foregroundStyle(Color.App.textSecondary)
        }
        .padding(AppSpacing.md)
    }
}

struct SettingsActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.App.body)
                    .foregroundStyle(Color.App.textPrimary)
                Text(subtitle)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.App.textSecondary.opacity(0.5))
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

struct ExportPasswordSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    let localeIdentifier: String

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(t("export_password_description"))
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textSecondary)

                    SecureField(t("export_password_placeholder"), text: $viewModel.exportPassphrase)
                        .textContentType(.newPassword)
                        .padding(AppSpacing.md)
                        .background(Color.App.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        .foregroundStyle(Color.App.textPrimary)

                    SecureField(t("export_password_confirm_placeholder"), text: $viewModel.exportPassphraseConfirmation)
                        .textContentType(.newPassword)
                        .padding(AppSpacing.md)
                        .background(Color.App.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        .foregroundStyle(Color.App.textPrimary)

                    if let error = viewModel.exportError {
                        Text(error)
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.danger)
                    }

                    GradientButton(
                        title: t("create_encrypted_export"),
                        icon: "lock.doc.fill",
                        action: { viewModel.exportDataForLaptop() },
                        isDisabled: viewModel.isExporting,
                        isLoading: viewModel.isExporting
                    )

                    Spacer()
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle(t("encrypted_export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("cancel")) {
                        viewModel.cancelLaptopExport()
                    }
                }
            }
        }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: localeIdentifier)
    }
}

#Preview("Settings") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        state.currencyCode = "EUR"
        state.localeIdentifier = "de_DE"
        state.autoLockTimeoutSeconds = 300
        return state
    }()

    return SettingsView(viewModel: SettingsViewModel(appState: appState))
        .environmentObject(appState)
}
