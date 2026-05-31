import Combine
import Foundation
import Photos
import UIKit

@MainActor
final class PhotoLibraryPermissionManager: ObservableObject {
    @Published private(set) var status: PHAuthorizationStatus

    init() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var hasUsableAccess: Bool {
        status == .authorized || status == .limited
    }

    var statusTitle: String {
        switch status {
        case .notDetermined:
            return "尚未请求权限"
        case .authorized:
            return "已允许完整访问"
        case .limited:
            return "已允许部分访问"
        case .denied:
            return "已拒绝访问"
        case .restricted:
            return "访问受限制"
        @unknown default:
            return "未知权限状态"
        }
    }

    func refresh() async {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccess() async {
        let newStatus = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        status = newStatus
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
