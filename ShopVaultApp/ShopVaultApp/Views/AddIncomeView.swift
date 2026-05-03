import SwiftUI

struct AddIncomeView: View {
    @StateObject var viewModel: AddIncomeViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(t("amount")).font(Font.App.caption).foregroundStyle(Color.App.textSecondary)
                            TextField("0\(viewModel.amountDecimalSeparator)00", text: $viewModel.amount)
                                .keyboardType(.decimalPad).font(Font.App.amountLarge).foregroundStyle(Color.App.accentPrimary)
                                .padding(AppSpacing.md).background(Color.App.bgTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(Color.App.accentPrimary.opacity(0.3), lineWidth: 1))
                                .focused($isAmountFocused)
                                .onChange(of: viewModel.amount) { _, _ in
                                    viewModel.normalizeAmountInput()
                                }
                        }
                        .glassCard().staggeredAppear(index: 0)

                        VStack(spacing: AppSpacing.md) {
                            FormField(label: t("source"), placeholder: t("source_placeholder"), text: $viewModel.source)

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(t("category")).font(Font.App.caption).foregroundStyle(Color.App.textSecondary)
                                Picker(t("category"), selection: $viewModel.selectedCategoryId) {
                                    Text(t("select")).tag(String?.none)
                                    ForEach(viewModel.categories) { category in
                                        Text(category.name).tag(String?(category.id))
                                    }
                                }
                                .pickerStyle(.menu).tint(Color.App.accentPrimary)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(t("date")).font(Font.App.caption).foregroundStyle(Color.App.textSecondary)
                                DatePicker(t("select_date"), selection: $viewModel.selectedDate, displayedComponents: .date)
                                    .tint(Color.App.accentPrimary).foregroundStyle(Color.App.textPrimary)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(t("notes_optional")).font(Font.App.caption).foregroundStyle(Color.App.textSecondary)
                                TextEditor(text: $viewModel.notes).frame(height: 80).padding(AppSpacing.xs)
                                    .background(Color.App.bgTertiary).clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                    .foregroundStyle(Color.App.textPrimary).scrollContentBackground(.hidden)
                            }
                        }
                        .glassCard().staggeredAppear(index: 1)

                        GradientButton(title: viewModel.saveButtonTitle, icon: "checkmark.circle.fill", action: {
                            if let userId = appState.currentUser?.id {
                                viewModel.saveEntry(userId: userId)
                            }
                        }, isDisabled: !viewModel.isFormValid, isLoading: viewModel.isSaving)
                        .staggeredAppear(index: 2)
                    }
                    .padding(AppSpacing.md)
                }
                .navigationTitle(t("add_income_title")).navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(t("done")) { dismiss() }.foregroundStyle(Color.App.textSecondary)
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(t("done")) {
                            isAmountFocused = false
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: AppSpacing.xs) {
                        if let message = viewModel.successMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.App.accentPrimary)
                                Text(message).font(Font.App.caption).foregroundStyle(Color.App.textPrimary)
                                Spacer()
                                Button(t("new")) { viewModel.startNewEntry() }.font(Font.App.caption).foregroundStyle(Color.App.accentPrimary)
                            }
                            .padding(AppSpacing.sm).glassCard(padding: AppSpacing.sm)
                        }
                        if let error = viewModel.saveError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.App.danger)
                                Text(error).font(Font.App.caption).foregroundStyle(Color.App.textPrimary)
                                Spacer()
                            }
                            .padding(AppSpacing.sm).background(Color.App.danger.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                        }
                    }
                    .padding(.horizontal, AppSpacing.md).padding(.bottom, AppSpacing.xs)
                }
                .onAppear {
                    viewModel.setLocale(appState.localeIdentifier)
                    if let userId = appState.currentUser?.id { viewModel.loadCategories(userId: userId) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isAmountFocused = true
                    }
                }
            }
        }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label).font(Font.App.caption).foregroundStyle(Color.App.textSecondary)
            TextField(placeholder, text: $text).padding(AppSpacing.sm)
                .background(Color.App.bgTertiary).clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .foregroundStyle(Color.App.textPrimary)
        }
    }
}

#Preview("Add Income") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        state.currencyCode = "USD"
        state.localeIdentifier = "en_US"
        return state
    }()

    return AddIncomeView(viewModel: AddIncomeViewModel(incomeRepository: IncomeRepository(), categoryRepository: CategoryRepository()))
        .environmentObject(appState)
}
