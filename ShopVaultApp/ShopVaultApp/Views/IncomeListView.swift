import SwiftUI

struct IncomeListView: View {
    @StateObject var viewModel: IncomeListViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(t("income_entries")).font(Font.App.title).foregroundStyle(Color.App.textPrimary)
                        Text(String(format: t("total_format"), viewModel.totalFormatted(currencyCode: appState.currencyCode, localeIdentifier: appState.localeIdentifier)))
                            .font(Font.App.caption).foregroundStyle(Color.App.accentPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(AppSpacing.md)

                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.App.textSecondary)
                        TextField(t("search_entries"), text: $viewModel.searchText).foregroundStyle(Color.App.textPrimary)
                    }
                    .padding(AppSpacing.sm).background(Color.App.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.small).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    .padding(.horizontal, AppSpacing.md).padding(.bottom, AppSpacing.sm)

                    if viewModel.filteredEntries.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "inbox").font(.system(size: 48)).foregroundStyle(Color.App.textSecondary.opacity(0.5))
                            Text(t("no_entries")).font(Font.App.headline).foregroundStyle(Color.App.textSecondary)
                            Text(t("add_first_entry")).font(Font.App.caption).foregroundStyle(Color.App.textSecondary.opacity(0.7))
                        }
                        .padding(AppSpacing.xxl).frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.groupedEntriesByMonth, id: \.monthStart) { section in
                                Section {
                                    ForEach(section.entries) { entry in
                                        IncomeEntryRow(entry: entry, currencyCode: appState.currencyCode, localeIdentifier: appState.localeIdentifier)
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) { viewModel.deleteEntry(entry) } label: {
                                                    Label(t("delete"), systemImage: "trash")
                                                }
                                            }
                                    }
                                } header: {
                                    Text(AppFormatters.monthYear(section.monthStart, localeIdentifier: appState.localeIdentifier))
                                        .font(Font.App.smallCaption)
                                        .foregroundStyle(Color.App.textSecondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .onAppear {
                if let userId = appState.currentUser?.id { viewModel.loadEntries(userId: userId) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .incomeEntriesDidChange)) { _ in
                if let userId = appState.currentUser?.id { viewModel.loadEntries(userId: userId) }
            }
            .safeAreaInset(edge: .bottom) {
                if let pendingDeletionEntry = viewModel.pendingDeletionEntry {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.App.danger)
                        Text(String(format: t("entry_deleted_from_source"), pendingDeletionEntry.source))
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button(t("undo")) {
                            viewModel.undoPendingDeletion()
                        }
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.accentPrimary)
                    }
                    .padding(AppSpacing.sm)
                    .glassCard(padding: AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xs)
                }
            }
    }

    private func t(_ key: String) -> String {
        L10n.tr(key, localeIdentifier: appState.localeIdentifier)
    }
}

struct IncomeEntryRow: View {
    let entry: IncomeEntry
    let currencyCode: String
    let localeIdentifier: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2).fill(LinearGradient.appAccent).frame(width: 3, height: 44)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(entry.source).font(Font.App.headline).foregroundStyle(Color.App.textPrimary)
                HStack(spacing: AppSpacing.xs) {
                    Text(entry.formattedDate(localeIdentifier: localeIdentifier)).font(Font.App.smallCaption).foregroundStyle(Color.App.textSecondary)
                    if let notes = entry.notes, !notes.isEmpty {
                        Text("\u{00B7}").foregroundStyle(Color.App.textSecondary)
                        Text(notes).font(Font.App.smallCaption).foregroundStyle(Color.App.textSecondary).lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(entry.formattedAmount(currencyCode: currencyCode, localeIdentifier: localeIdentifier))
                .font(Font.App.amountSmall).foregroundStyle(Color.App.accentPrimary)
        }
        .glassCard(padding: AppSpacing.sm)
    }
}

#Preview("Income List") {
    let appState: AppState = {
        let state = AppState()
        state.isAuthenticated = true
        state.currentUser = User.sample
        state.currencyCode = "EUR"
        state.localeIdentifier = "de_DE"
        return state
    }()

    return IncomeListView(viewModel: IncomeListViewModel(incomeRepository: IncomeRepository()))
        .environmentObject(appState)
}
