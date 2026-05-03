import Foundation
import SwiftUI

/// Persists which records the user has hidden in the local viewer.
/// Hides do NOT modify the original .shopvault file — they only filter the display.
/// State lives in UserDefaults so it survives app restarts.
@MainActor
@Observable
final class HiddenItemsStore {
    private let deliveriesKey = "hiddenDeliveryIds.v1"

    private(set) var hiddenDeliveryIds: Set<String> = []

    init() {
        load()
    }

    var hiddenDeliveryCount: Int { hiddenDeliveryIds.count }

    func isHidden(deliveryId: String) -> Bool {
        hiddenDeliveryIds.contains(deliveryId)
    }

    func hide(deliveryId: String) {
        hiddenDeliveryIds.insert(deliveryId)
        persist()
    }

    func unhide(deliveryId: String) {
        hiddenDeliveryIds.remove(deliveryId)
        persist()
    }

    func unhideAll() {
        hiddenDeliveryIds.removeAll()
        persist()
    }

    private func load() {
        let raw = UserDefaults.standard.array(forKey: deliveriesKey) as? [String] ?? []
        hiddenDeliveryIds = Set(raw)
    }

    private func persist() {
        UserDefaults.standard.set(Array(hiddenDeliveryIds), forKey: deliveriesKey)
    }
}
