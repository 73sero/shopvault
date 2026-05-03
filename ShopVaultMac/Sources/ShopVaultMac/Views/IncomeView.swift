import SwiftUI
import Charts

struct IncomeView: View {
    let dataset: VaultDataset

    @State private var searchText = ""
    @State private var selectedCategoryId: String? = nil

    // MARK: - Derived data

    private var allEntries: [VaultIncomeEntry] { dataset.income }

    private var filtered: [VaultIncomeEntry] {
        var result = allEntries
        if let cid = selectedCategoryId {
            result = result.filter { $0.categoryId == cid }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.source.lowercased().contains(q)
                    || ($0.notes?.lowercased().contains(q) ?? false)
                    || ($0.categoryName?.lowercased().contains(q) ?? false)
            }
        }
        return result
    }

    private var totalAll: Decimal {
        allEntries.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var totalFiltered: Decimal {
        filtered.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var avgEntry: Decimal {
        guard !allEntries.isEmpty else { return 0 }
        return totalAll / Decimal(allEntries.count)
    }

    private var categoriesInUse: [VaultCategory] {
        let usedIds = Set(allEntries.map { $0.categoryId })
        return dataset.categories.filter { usedIds.contains($0.id) }
    }

    private struct CategoryBreakdown: Identifiable {
        let id: String
        let name: String
        let color: Color
        let total: Decimal
        let count: Int
    }

    private var categoryBreakdown: [CategoryBreakdown] {
        let grouped = Dictionary(grouping: allEntries, by: \.categoryId)
        return grouped.compactMap { (cid, entries) -> CategoryBreakdown? in
            let name = entries.first?.categoryName ?? dataset.categoryById[cid]?.name ?? "—"
            let colorHex = entries.first?.categoryColor ?? dataset.categoryById[cid]?.color ?? "#4CAF50"
            let total = entries.reduce(Decimal.zero) { $0 + $1.amount }
            return CategoryBreakdown(
                id: cid,
                name: name,
                color: parseHexColor(colorHex),
                total: total,
                count: entries.count
            )
        }
        .sorted { $0.total > $1.total }
    }

    private var topCategoryName: String {
        categoryBreakdown.first?.name ?? "—"
    }

    private struct MonthBucket: Identifiable {
        let id = UUID()
        let month: Date
        let total: Decimal
    }

    private var monthlySeries: [MonthBucket] {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let months: [Date] = (0..<6).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: now)
        }.compactMap { date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        }

        return months.map { monthStart in
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            let total = allEntries
                .filter { $0.date >= monthStart && $0.date < nextMonth }
                .reduce(Decimal.zero) { $0 + $1.amount }
            return MonthBucket(month: monthStart, total: total)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                PageHeader(
                    title: "Einnahmen-Übersicht",
                    subtitle: "Alle Einnahmen über alle Kategorien · \(allEntries.count) Einträge",
                    trailing: AnyView(AppSearchBar(text: $searchText, placeholder: "Quelle, Notiz, Kategorie…"))
                )

                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    statsRow
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        monthlyChart
                            .frame(maxWidth: .infinity)
                        categoryBreakdownCard
                            .frame(width: 360)
                    }
                    listSection
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        let columns = [GridItem(.adaptive(minimum: 200), spacing: AppSpacing.md)]
        return LazyVGrid(columns: columns, spacing: AppSpacing.md) {
            StatTile(
                title: "Gesamteinnahmen",
                value: Format.eur(totalAll),
                subtitle: "\(allEntries.count) Einträge",
                color: Color.App.accentPrimary,
                icon: "eurosign.circle"
            )
            StatTile(
                title: "Ø pro Eintrag",
                value: Format.eur(avgEntry),
                color: Color.App.accentSecondary,
                icon: "chart.bar"
            )
            StatTile(
                title: "Top Kategorie",
                value: topCategoryName,
                subtitle: categoryBreakdown.first.map { Format.eur($0.total) },
                color: categoryBreakdown.first?.color ?? Color.App.categoryBlue,
                icon: "tag.fill"
            )
            StatTile(
                title: "Kategorien",
                value: "\(categoriesInUse.count)",
                subtitle: "in Benutzung",
                color: Color.App.categoryPurple,
                icon: "folder.fill"
            )
        }
    }

    // MARK: - Monthly chart

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Einnahmen pro Monat")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                    Text("Letzte 6 Monate · alle Kategorien")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
                Spacer()
            }

            Chart(monthlySeries) { bucket in
                BarMark(
                    x: .value("Monat", Format.monthShort(bucket.month)),
                    y: .value("Summe", NSDecimalNumber(decimal: bucket.total).doubleValue)
                )
                .foregroundStyle(LinearGradient.appAccent)
                .cornerRadius(6)
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel().foregroundStyle(Color.App.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.App.textTertiary)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Category breakdown (donut)

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Verteilung nach Kategorie")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)

            if categoryBreakdown.isEmpty {
                emptyHint("Noch keine Einnahmen")
            } else {
                Chart(categoryBreakdown) { entry in
                    SectorMark(
                        angle: .value("Summe", NSDecimalNumber(decimal: entry.total).doubleValue),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(entry.color)
                    .cornerRadius(3)
                }
                .frame(height: 160)
                .chartLegend(.hidden)

                VStack(spacing: AppSpacing.xs) {
                    ForEach(categoryBreakdown) { entry in
                        HStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 8, height: 8)
                            Text(entry.name)
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(Format.eur(entry.total))
                                .font(Font.App.caption)
                                .foregroundStyle(Color.App.textSecondary)
                            Text(percentage(for: entry))
                                .font(Font.App.monoCaption)
                                .foregroundStyle(Color.App.textTertiary)
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private func percentage(for entry: CategoryBreakdown) -> String {
        guard totalAll > 0 else { return "—" }
        let p = NSDecimalNumber(decimal: entry.total / totalAll).doubleValue * 100
        return String(format: "%.0f %%", p)
    }

    // MARK: - List section

    private var listSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Einträge")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textPrimary)
                Spacer()
                Text("\(filtered.count) sichtbar · \(Format.eur(totalFiltered))")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }

            HStack(spacing: AppSpacing.xs) {
                categoryChip(label: "Alle", isSelected: selectedCategoryId == nil, color: Color.App.accentPrimary) {
                    selectedCategoryId = nil
                }
                ForEach(categoriesInUse) { c in
                    categoryChip(
                        label: c.name,
                        isSelected: selectedCategoryId == c.id,
                        color: parseHexColor(c.color)
                    ) {
                        selectedCategoryId = (selectedCategoryId == c.id) ? nil : c.id
                    }
                }
                Spacer()
            }

            if filtered.isEmpty {
                emptyHint(searchText.isEmpty && selectedCategoryId == nil ? "Noch keine Einnahmen" : "Keine Treffer")
            } else {
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(filtered) { entry in
                        IncomeRow(entry: entry)
                    }
                }
            }
        }
        .glassCard()
    }

    private func categoryChip(label: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .font(Font.App.caption)
                    .foregroundStyle(isSelected ? Color.App.textPrimary : Color.App.textSecondary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.18) : Color.App.bgTertiary.opacity(0.6))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSelected ? color.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func emptyHint(_ text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textTertiary)
                .padding(.vertical, AppSpacing.lg)
            Spacer()
        }
    }
}

private struct IncomeRow: View {
    let entry: VaultIncomeEntry

    private var categoryColor: Color {
        parseHexColor(entry.categoryColor ?? "#4CAF50")
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(categoryColor)
                .frame(width: 10, height: 10)
                .padding(8)
                .background(categoryColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.source)
                    .font(Font.App.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.App.textPrimary)
                HStack(spacing: AppSpacing.xs) {
                    Text(entry.categoryName ?? "—")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(categoryColor)
                    Text("·")
                        .foregroundStyle(Color.App.textTertiary)
                    Text(Format.mediumDate(entry.date))
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                    if let notes = entry.notes, !notes.isEmpty {
                        Text("·")
                            .foregroundStyle(Color.App.textTertiary)
                        Text(notes)
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(Format.eur(entry.amount))
                .font(Font.App.amountSmall)
                .foregroundStyle(Color.App.accentPrimary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }
}

func parseHexColor(_ hex: String) -> Color {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let value = UInt64(s, radix: 16) else {
        return Color.App.accentPrimary
    }
    let r = Double((value >> 16) & 0xFF) / 255.0
    let g = Double((value >> 8) & 0xFF) / 255.0
    let b = Double(value & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
}
