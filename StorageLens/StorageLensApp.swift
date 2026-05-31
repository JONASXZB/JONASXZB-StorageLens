import Foundation
import SwiftUI

@main
struct StorageLensApp: App {
    @StateObject private var permissionManager = PhotoLibraryPermissionManager()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(permissionManager)
                .environment(\.locale, AppLanguage.primaryLocale)
        }
    }
}
