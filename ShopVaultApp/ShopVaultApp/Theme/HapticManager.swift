#if canImport(UIKit)
import UIKit

typealias HapticImpactStyle = UIImpactFeedbackGenerator.FeedbackStyle
typealias HapticNotificationType = UINotificationFeedbackGenerator.FeedbackType
#else
enum HapticImpactStyle {
    case light
    case medium
    case heavy
}

enum HapticNotificationType {
    case success
    case warning
    case error
}
#endif

enum HapticManager {
    static func impact(_ style: HapticImpactStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    static func notification(_ type: HapticNotificationType) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
        #endif
    }

    static func selection() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}
