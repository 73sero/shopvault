import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AnimatedMeshGradientView()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)

                Group {
                    switch viewModel.step {
                    case .welcome: welcomeStep
                    case .picker: pickerStep
                    case .confirm: confirmStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(OnboardingViewModel.Step.allCases, id: \.self) { s in
                RoundedRectangle(cornerRadius: 2)
                    .fill(s.rawValue <= viewModel.step.rawValue
                          ? AnyShapeStyle(LinearGradient.appAccent)
                          : AnyShapeStyle(Color.white.opacity(0.08)))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xl)

                ZStack {
                    Circle()
                        .fill(LinearGradient.appAccent.opacity(0.18))
                        .frame(width: 140, height: 140)
                        .blur(radius: 22)
                    Circle()
                        .stroke(LinearGradient.appAccent, lineWidth: 1.5)
                        .frame(width: 110, height: 110)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(LinearGradient.appAccent)
                }

                VStack(spacing: AppSpacing.xs) {
                    Text("Welcome to ShopVault")
                        .font(Font.App.title)
                        .foregroundStyle(Color.App.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("A self-hosted, encrypted tracker for your products, customers, orders and income. Everything stays on your device.")
                        .font(Font.App.body)
                        .foregroundStyle(Color.App.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    featureRow(icon: "lock.fill", title: "AES-256-GCM encryption", subtitle: "SQLCipher database, Face ID unlock")
                    featureRow(icon: "iphone.and.arrow.right.outward", title: "Encrypted snapshot exports", subtitle: "Open them on your Mac with the companion viewer")
                    featureRow(icon: "chart.line.uptrend.xyaxis", title: "Inventory + CRM + income", subtitle: "Track stock, customers, orders and revenue in one place")
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer(minLength: AppSpacing.xl)
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.App.accentPrimary)
                .frame(width: 36, height: 36)
                .background(Color.App.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Text(subtitle)
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.sm)
        .glassCard()
    }

    // MARK: - Step 2: Industry Picker

    private var pickerStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Pick a starter template")
                        .font(Font.App.title)
                        .foregroundStyle(Color.App.textPrimary)
                    Text("We'll seed your inventory with realistic example products. You can edit or delete them later.")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textSecondary)
                }

                VStack(spacing: AppSpacing.xs) {
                    ForEach(viewModel.templates) { template in
                        templateCard(template)
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    private func templateCard(_ template: IndustryTemplate) -> some View {
        let isSelected = viewModel.selectedTemplate == template
        return Button {
            viewModel.selectedTemplate = template
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: template.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? Color.App.accentPrimary : Color.App.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected
                        ? Color.App.accentPrimary.opacity(0.18)
                        : Color.white.opacity(0.04)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.label)
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                    Text(template.tagline)
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                    if !template.products.isEmpty {
                        Text("\(template.products.count) example products")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.accentPrimary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.App.accentPrimary : Color.App.textSecondary.opacity(0.6))
            }
            .padding(AppSpacing.sm)
            .background(isSelected
                        ? AnyShapeStyle(Color.App.accentPrimary.opacity(0.10))
                        : AnyShapeStyle(Color.App.bgSecondary))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(
                        isSelected ? Color.App.accentPrimary.opacity(0.5) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Confirm

    private var confirmStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let template = viewModel.selectedTemplate {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Ready to install")
                            .font(Font.App.title)
                            .foregroundStyle(Color.App.textPrimary)
                        Text(template.products.isEmpty
                             ? "Starting with a clean slate. You can add products anytime from the Inventory tab."
                             : "We'll add \(template.products.count) example products. Edit or delete them anytime.")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textSecondary)
                    }

                    if !template.products.isEmpty {
                        VStack(spacing: AppSpacing.xs) {
                            ForEach(Array(template.products.enumerated()), id: \.offset) { _, p in
                                HStack(spacing: AppSpacing.sm) {
                                    Text(p.code)
                                        .font(Font.App.smallCaption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.App.accentPrimary)
                                        .padding(.horizontal, AppSpacing.xs)
                                        .padding(.vertical, 2)
                                        .background(Color.App.accentPrimary.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name)
                                            .font(Font.App.caption)
                                            .foregroundStyle(Color.App.textPrimary)
                                        if !p.specification.isEmpty {
                                            Text(p.specification)
                                                .font(Font.App.smallCaption)
                                                .foregroundStyle(Color.App.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Text(formatPrice(p.price))
                                        .font(Font.App.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.App.textPrimary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .glassCard()
                    }

                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.App.danger)
                            Text(error)
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.textPrimary)
                            Spacer()
                        }
                        .padding(AppSpacing.sm)
                        .background(Color.App.danger.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: AppSpacing.sm) {
            if viewModel.step != .welcome {
                Button {
                    viewModel.back()
                } label: {
                    Text("Back")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isInstalling)
            }

            Spacer()

            if viewModel.step == .confirm {
                GradientButton(
                    title: viewModel.isInstalling ? "Installing…" : "Install",
                    icon: "checkmark.circle.fill",
                    action: {
                        if let userId = appState.currentUser?.id {
                            viewModel.install(userId: userId, appState: appState) {}
                        }
                    },
                    isDisabled: !viewModel.canAdvance,
                    isLoading: viewModel.isInstalling
                )
                .frame(maxWidth: 240)
            } else {
                GradientButton(
                    title: viewModel.step == .welcome ? "Get started" : "Continue",
                    icon: "arrow.right",
                    action: { viewModel.next() },
                    isDisabled: !viewModel.canAdvance
                )
                .frame(maxWidth: 240)
            }
        }
        .padding(AppSpacing.lg)
    }

    private func formatPrice(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = appState.currencyCode
        f.locale = Locale(identifier: appState.localeIdentifier)
        return f.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
