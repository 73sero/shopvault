import SwiftUI

/// Sheet for creating or editing a Product.
/// Pass `existing: nil` to create a new product, or pass an existing one to edit.
struct ProductFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let existing: Product?
    let onSave: (Product) -> Void

    @State private var code: String
    @State private var name: String
    @State private var specification: String
    @State private var priceText: String
    @State private var stockText: String
    @State private var thresholdText: String
    @State private var isFavorite: Bool

    @State private var isSaving = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?
    private enum Field { case code, name, spec, price, stock, threshold }

    private let productRepository = ProductRepository()

    init(existing: Product? = nil, onSave: @escaping (Product) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _code = State(initialValue: existing?.code ?? "")
        _name = State(initialValue: existing?.name ?? "")
        _specification = State(initialValue: existing?.specification ?? "")
        _priceText = State(initialValue: existing.map { NSDecimalNumber(decimal: $0.price).stringValue } ?? "")
        _stockText = State(initialValue: existing.map { String($0.stock) } ?? "0")
        _thresholdText = State(initialValue: existing.map { String($0.lowStockThreshold) } ?? "3")
        _isFavorite = State(initialValue: existing?.isFavorite ?? false)
    }

    private var isEditing: Bool { existing != nil }

    private var canSave: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedPrice != nil
            && (parsedPrice ?? 0) > 0
            && !isSaving
    }

    private var parsedPrice: Decimal? {
        let s = priceText.replacingOccurrences(of: ",", with: ".")
        guard let d = Decimal(string: s), d > 0 else { return nil }
        return d
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.App.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        identitySection.staggeredAppear(index: 0)
                        pricingSection.staggeredAppear(index: 1)
                        stockSection.staggeredAppear(index: 2)
                        favoriteToggle.staggeredAppear(index: 3)

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        GradientButton(
                            title: isSaving
                                ? (isEditing ? "Wird gespeichert…" : "Wird angelegt…")
                                : (isEditing ? "Änderungen speichern" : "Produkt anlegen"),
                            icon: isEditing ? "checkmark.circle.fill" : "plus.circle.fill",
                            action: save,
                            isDisabled: !canSave,
                            isLoading: isSaving
                        )
                        .staggeredAppear(index: 4)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle(isEditing ? "Produkt bearbeiten" : "Neues Produkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.App.textSecondary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focusedField = nil }
                }
            }
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader(icon: "tag.fill", title: "Identität", color: Color.App.accentPrimary)

            labeledField(label: "Code") {
                TextField("z.B. ESP, TEE-S", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .code)
            }

            labeledField(label: "Name") {
                TextField("z.B. Espresso", text: $name)
                    .focused($focusedField, equals: .name)
            }

            labeledField(label: "Spezifikation (optional)") {
                TextField("z.B. 250ml, M, 5mg", text: $specification)
                    .focused($focusedField, equals: .spec)
            }
        }
        .glassCard()
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader(icon: "eurosign.circle.fill", title: "Preis", color: Color.App.accentSecondary)

            labeledField(label: "Verkaufspreis (\(appState.currencyCode))") {
                TextField("0,00", text: $priceText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .price)
            }
        }
        .glassCard()
    }

    private var stockSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader(icon: "shippingbox.fill", title: "Bestand", color: Color.App.categoryOrange)

            labeledField(label: "Aktueller Bestand") {
                TextField("0", text: $stockText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .stock)
            }

            labeledField(label: "Niedrig-Bestand-Warnung ab") {
                TextField("3", text: $thresholdText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .threshold)
            }

            Text("Du wirst gewarnt, wenn der Bestand diesen Wert erreicht.")
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textSecondary)
        }
        .glassCard()
    }

    private var favoriteToggle: some View {
        Toggle(isOn: $isFavorite) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.App.categoryOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorit")
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                    Text("Erscheint oben in der Produktliste")
                        .font(Font.App.smallCaption)
                        .foregroundStyle(Color.App.textSecondary)
                }
            }
        }
        .tint(Color.App.accentPrimary)
        .padding(AppSpacing.md)
        .background(Color.App.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
            Text(title)
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textSecondary)
            content()
                .font(Font.App.body)
                .foregroundStyle(Color.App.textPrimary)
                .padding(AppSpacing.sm)
                .background(Color.App.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.App.danger)
            Text(message)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textPrimary)
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(Color.App.danger.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
    }

    // MARK: - Save

    private func save() {
        focusedField = nil
        guard let price = parsedPrice else {
            errorMessage = "Bitte gib einen gültigen Preis ein."
            return
        }
        let stock = max(0, Int(stockText) ?? 0)
        let threshold = max(0, Int(thresholdText) ?? 3)

        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            do {
                let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let trimmedSpec = specification.trimmingCharacters(in: .whitespaces)

                let product = Product(
                    id: existing?.id ?? UUID().uuidString,
                    code: trimmedCode,
                    name: trimmedName,
                    specification: trimmedSpec,
                    price: price,
                    stock: stock,
                    lowStockThreshold: threshold,
                    isFavorite: isFavorite,
                    isActive: existing?.isActive ?? true,
                    createdAt: existing?.createdAt ?? Date(),
                    updatedAt: Date()
                )

                if isEditing {
                    try await productRepository.updateProduct(product)
                } else {
                    try await productRepository.insertProduct(product)
                }

                NotificationCenter.default.post(name: .stockDidChange, object: nil)
                HapticManager.notification(.success)
                onSave(product)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                HapticManager.notification(.error)
            }
        }
    }
}
