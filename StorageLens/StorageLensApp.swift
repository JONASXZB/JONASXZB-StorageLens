import Foundation
import SwiftUI

@main
struct StorageLensApp: App {
    @StateObject private var permissionManager = PhotoLibraryPermissionManager()
    @StateObject private var reviewBasket = ReviewBasketStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(permissionManager)
                .environmentObject(reviewBasket)
                .environment(\.locale, AppLanguage.primaryLocale)
        }
    }
}
