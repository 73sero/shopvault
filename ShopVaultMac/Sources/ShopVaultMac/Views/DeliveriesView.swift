import SwiftUI

struct DeliveriesView: View {
    let dataset: VaultDataset
    @Environment(HiddenItemsStore.self) private var hiddenStore

    @State private var selectedId: String?
    @State private var showHidden = false
    @State private var hideConfirmationId: String?

    private var visibleDeliveries: [VaultDelivery] {
        if showHidden {
            return dataset.deliveries
        }
        return dataset.deliveries.filter { !hiddenStore.isHidden(deliveryId: $0.id) }
    }

    private var hiddenCount: Int {
        dataset.deliveries.filter { hiddenStore.isHidden(deliveryId: $0.id) }.count
    }

    private var totalCost: Decimal {
        visibleDeliveries.reduce(Decimal.zero) { $0 + $1.totalCost }
    }

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(minWidth: 360, idealWidth: 400, maxWidth: 460)
            Divider().background(Color.white.opacity(0.05))
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Lieferung ausblenden?", isPresented: Binding(
            get: { hideConfirmationId != nil },
            set: { if !$0 { hideConfirmationId = nil } }
        )) {
            Button("Abbrechen", role: .cancel) {}
            Button("Ausblenden", role: .destructive) {
                if let id = hideConfirmationId {
                    hiddenStore.hide(deliveryId: id)
                    if selectedId == id {
                        selectedId = visibleDeliveries.first?.id
                    }
                }
                hideConfirmationId = nil
            }
        } message: {
            Text("Die Lieferung wird nur lokal im Viewer ausgeblendet. Die Snapshot-Datei bleibt unverändert. Du kannst sie jederzeit wieder einblenden.")
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: "Lieferungen",
                subtitle: "\(visibleDeliveries.count) sichtbar · Wareneinsatz \(Format.eur(totalCost))",
                trailing: AnyView(headerControls)
            )

            if visibleDeliveries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.xs) {
                        ForEach(visibleDeliveries) { d in
                            DeliveryRow(
                                delivery: d,
                                isSelected: selectedId == d.id,
                                isHidden: hiddenStore.isHidden(deliveryId: d.id)
                            )
                            .onTapGesture { selectedId = d.id }
                            .contextMenu {
                                if hiddenStore.isHidden(deliveryId: d.id) {
                                    Button {
                                        hiddenStore.unhide(deliveryId: d.id)
                                    } label: {
                                        Label("Wieder einblenden", systemImage: "eye")
                                    }
                                } else {
                                    Button(role: .destructive) {
                                        hideConfirmationId = d.id
                                    } label: {
                                        Label("Ausblenden", systemImage: "eye.slash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .onAppear {
            if selectedId == nil { selectedId = visibleDeliveries.first?.id }
        }
    }

    @ViewBuilder
    private var headerControls: some View {
        if hiddenCount > 0 {
            HStack(spacing: AppSpacing.xs) {
                Button {
                    showHidden.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showHidden ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 11))
                        Text("\(hiddenCount) ausgeblendet")
                            .font(Font.App.smallCaption)
                    }
                    .foregroundStyle(showHidden ? Color.App.accentPrimary : Color.App.textSecondary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(showHidden ? Color.App.accentPrimary.opacity(0.15) : Color.App.bgSecondary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            showHidden ? Color.App.accentPrimary.opacity(0.4) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)

                if showHidden {
                    Button {
                        hiddenStore.unhideAll()
                        showHidden = false
                    } label: {
                        Text("Alle einblenden")
                            .font(Font.App.smallCaption)
                            .foregroundStyle(Color.App.accentSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selectedId,
           let delivery = dataset.deliveries.first(where: { $0.id == id }) {
            DeliveryDetailPane(
                delivery: delivery,
                isHidden: hiddenStore.isHidden(deliveryId: id),
                onHide: { hideConfirmationId = id },
                onUnhide: { hiddenStore.unhide(deliveryId: id) }
            )
        } else {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "truck.box")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.App.textTertiary)
                Text("Wähle eine Lieferung")
                    .font(Font.App.headline)
                    .foregroundStyle(Color.App.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "truck.box")
                .font(.system(size: 36))
                .foregroundStyle(Color.App.textTertiary)
            Text("Keine sichtbaren Lieferungen")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textSecondary)
            if hiddenCount > 0 {
                Button("\(hiddenCount) ausgeblendete einblenden") {
                    showHidden = true
                }
                .buttonStyle(.plain)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.accentPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DeliveryRow: View {
    let delivery: VaultDelivery
    let isSelected: Bool
    let isHidden: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.App.categoryPurple.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.App.categoryPurple)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Text(Format.mediumDate(delivery.deliveredAt))
                        .font(Font.App.headline)
                        .foregroundStyle(Color.App.textPrimary)
                    if isHidden {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 9))
                            Text("Ausgeblendet")
                                .font(Font.App.smallCaption)
                        }
                        .foregroundStyle(Color.App.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }
                Text("\(delivery.items.count) Positionen · \(delivery.items.reduce(0) { $0 + $1.quantity }) Vials")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }
            Spacer()
            Text(Format.eur(delivery.totalCost))
                .font(Font.App.amountSmall)
                .foregroundStyle(isHidden ? Color.App.textTertiary : Color.App.categoryPink)
        }
        .padding(AppSpacing.sm)
        .background(
            isSelected
            ? AnyShapeStyle(Color.App.categoryPurple.opacity(0.10))
            : AnyShapeStyle(Color.App.bgSecondary)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(
                    isSelected ? Color.App.categoryPurple.opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
        .opacity(isHidden ? 0.55 : 1.0)
    }
}

private struct DeliveryDetailPane: View {
    let delivery: VaultDelivery
    let isHidden: Bool
    let onHide: () -> Void
    let onUnhide: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if isHidden { hiddenBanner }
                header
                if !delivery.items.isEmpty { itemsCard }
                if let notes = delivery.notes, !notes.isEmpty { notesCard(notes) }
                actionsCard
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var hiddenBanner: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "eye.slash.fill")
                .foregroundStyle(Color.App.textSecondary)
            Text("Diese Lieferung ist im Viewer ausgeblendet und wird in den Totalen nicht mitgezählt.")
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Lieferung")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
                    .textCase(.uppercase)
                Text(Format.mediumDate(delivery.deliveredAt))
                    .font(Font.App.title)
                    .foregroundStyle(Color.App.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.eur(delivery.totalCost))
                    .font(Font.App.amountLarge)
                    .foregroundStyle(Color.App.categoryPink)
                Text("Wareneinsatz")
                    .font(Font.App.smallCaption)
                    .foregroundStyle(Color.App.textSecondary)
            }
        }
        .glassCard()
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Positionen")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)
            ForEach(delivery.items) { item in
                HStack(spacing: AppSpacing.sm) {
                    Text(item.productCode ?? "?")
                        .font(Font.App.smallCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.App.categoryPurple)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.App.categoryPurple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(item.productName ?? "Produkt")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textPrimary)
                    Spacer()
                    Text("\(item.quantity)×")
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textSecondary)
                    Text(Format.eur(item.unitCost))
                        .font(Font.App.caption)
                        .foregroundStyle(Color.App.textTertiary)
                    Text(Format.eur(item.unitCost * Decimal(item.quantity)))
                        .font(Font.App.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.App.textPrimary)
                        .frame(width: 80, alignment: .trailing)
                }
                if item.id != delivery.items.last?.id {
                    Divider().background(Color.white.opacity(0.05))
                }
            }
        }
        .glassCard()
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Notiz")
                .font(Font.App.headline)
                .foregroundStyle(Color.App.textPrimary)
            Text(notes)
                .font(Font.App.caption)
                .foregroundStyle(Color.App.textSecondary)
                .textSelection(.enabled)
        }
        .glassCard()
    }

    private var actionsCard: some View {
        VStack(spacing: AppSpacing.xs) {
            if isHidden {
                Button(action: onUnhide) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "eye.fill")
                        Text("Wieder einblenden")
                    }
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.accentPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.App.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onHide) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "eye.slash.fill")
                        Text("Lieferung ausblenden")
                    }
                    .font(Font.App.caption)
                    .foregroundStyle(Color.App.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.App.danger.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .buttonStyle(.plain)
            }
            Text("Lokaler Filter — die .shopvault-Datei wird nicht verändert.")
                .font(Font.App.smallCaption)
                .foregroundStyle(Color.App.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, AppSpacing.xs)
    }
}
