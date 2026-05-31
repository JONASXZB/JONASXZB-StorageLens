import UIKit

enum Haptics {
    static func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func cleanupSucceeded() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
