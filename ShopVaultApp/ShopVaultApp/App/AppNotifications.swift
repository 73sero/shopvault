import Foundation

extension Notification.Name {
    static let incomeEntriesDidChange = Notification.Name("incomeEntriesDidChange")
    static let requestAddIncomeEntry = Notification.Name("requestAddIncomeEntry")
    static let orderDidComplete = Notification.Name("orderDidComplete")
    static let orderDidChange = Notification.Name("orderDidChange")
    static let deliveryDidComplete = Notification.Name("deliveryDidComplete")
    static let deliveryDidChange = Notification.Name("deliveryDidChange")
    static let stockDidChange = Notification.Name("stockDidChange")
}
