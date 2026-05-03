import SwiftUI

struct IncomeListView: View {
    @StateObject var viewModel: IncomeListViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Income Entries")
                            .font(Font.App.title)
                            .foregroundStyle(Color.App.textPrimary)

                        Text("Total: \(viewModel.totalFormatted)")
                            .font(Font.App.caption)
                            .foregroundStyle(Color.App.accentPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)

                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.App.textSecondary)

                        TextField("Search entries", text: $viewModel.searchText)
                            .foregroundStyle(Color.App.textPrimary)
                    }
                    .padding(AppSpacing.sm)
                    .background(Color.App.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)

                    if viewModel.filteredEntries.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "inbox")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.App.textSecondary.opacity(0.5))

                            Text("No entries yet")
                                .font(Font.App.headline)
                                .foregroundStyle(Color.App.textSecondary)

                            Text("Add your first income entry to get started")
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.textSecondary.opacity(0.7))
                        }
                        .padding(AppSpacing.xxl)
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.xs) {
                                ForEach(Array(viewModel.filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                    IncomeEntryRow(entry: entry, onDelete: {
                                        viewModel.deleteEntry(entry)
                                    })
                                    .staggeredAppear(index: index)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.lg)
                        }
                    }
                }
            }
            .onAppear {
                if let userId = appState.currentUser?.id {
                    viewModel.loadEntries(userId: userId)
                }
            }
        }
    }
}

struct IncomeEntryRow: View {
    let entry: IncomeEntry
    var onDelete: (() -> Void)? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient.appAccent)
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(entry.source)
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)

                HStack(spacing: AppSpacing.xs) {
                    Text(entry.formattedDate())
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)

                    if let notes = entry.notes, !notes.isEmpty {
                        Text("·")
                            .foregroundStyle(Color.App.textSecondary)
                        Text(notes)
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(entry.formattedAmount())
                .font(Font.App.amountSmall)
                .foregroundStyle(Color.App.accentPrimary)
        }
        .glassCard(padding: AppSpacing.sm)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    IncomeListView(viewModel: IncomeListViewModel(
        incomeRepository: IncomeRepository()
    ))
    .environmentObject(AppState())
}
