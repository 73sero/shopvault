import SwiftUI

struct AddIncomeView: View {
    @StateObject var viewModel: AddIncomeViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        // Amount Card
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Amount")
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.textSecondary)

                            TextField("0.00", text: $viewModel.amount)
                                .keyboardType(.decimalPad)
                                .font(Font.App.amountLarge)
                                .foregroundStyle(Color.App.accentPrimary)
                                .padding(AppSpacing.md)
                                .background(Color.App.bgTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(Color.App.accentPrimary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .glassCard()
                        .staggeredAppear(index: 0)

                        // Details Card
                        VStack(spacing: AppSpacing.md) {
                            FormField(label: "Source", placeholder: "e.g. Freelance", text: $viewModel.source)

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("Category")
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textSecondary)

                                Picker("Category", selection: $viewModel.selectedCategoryId) {
                                    Text("Select...").tag(String?.none)
                                    ForEach(viewModel.categories) { category in
                                        Text(category.name).tag(String?(category.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.App.accentPrimary)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("Date")
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textSecondary)

                                DatePicker(
                                    "Select Date",
                                    selection: $viewModel.selectedDate,
                                    displayedComponents: .date
                                )
                                .tint(Color.App.accentPrimary)
                                .foregroundStyle(Color.App.textPrimary)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("Notes (optional)")
                                    .font(Font.App.caption)
                                    .foregroundStyle(Color.App.textSecondary)

                                TextEditor(text: $viewModel.notes)
                                    .frame(height: 80)
                                    .padding(AppSpacing.xs)
                                    .background(Color.App.bgTertiary)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                                    .foregroundStyle(Color.App.textPrimary)
                                    .scrollContentBackground(.hidden)
                            }
                        }
                        .glassCard()
                        .staggeredAppear(index: 1)

                        GradientButton(
                            title: "Save Entry",
                            icon: "checkmark.circle.fill",
                            action: {
                                if let userId = appState.currentUser?.id {
                                    viewModel.saveEntry(userId: userId)
                                    if viewModel.saveError == nil {
                                        HapticManager.notification(.success)
                                        dismiss()
                                    }
                                }
                            },
                            isDisabled: !viewModel.isFormValid,
                            isLoading: viewModel.isSaving
                        )
                        .staggeredAppear(index: 2)
                    }
                    .padding(AppSpacing.md)
                }
                .navigationTitle("Add Income")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .onAppear {
                    if let userId = appState.currentUser?.id {
                        viewModel.loadCategories(userId: userId)
                    }
                }
            }
        }
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)

            TextField(placeholder, text: $text)
                .padding(AppSpacing.sm)
                .background(Color.App.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .foregroundStyle(Color.App.textPrimary)
        }
    }
}

#Preview {
    AddIncomeView(viewModel: AddIncomeViewModel(
        incomeRepository: IncomeRepository(),
        categoryRepository: CategoryRepository()
    ))
    .environmentObject(AppState())
}
