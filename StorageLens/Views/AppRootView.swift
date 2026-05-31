import Photos
import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var permissionManager: PhotoLibraryPermissionManager

    var body: some View {
        Group {
            if permissionManager.hasUsableAccess {
                HomeView()
            } else {
                PermissionView()
            }
        }
        .task {
            await permissionManager.refresh()
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(PhotoLibraryPermissionManager())
}
