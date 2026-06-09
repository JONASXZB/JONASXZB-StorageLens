import Combine
import Foundation
import Photos
import PhotosUI
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

    func presentLimitedLibraryPicker() {
        guard status == .limited else {
            openAppSettings()
            return
        }

        guard let presenter = UIApplication.shared.activeTopViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }
}

private extension UIApplication {
    var activeTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresentedViewController
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.topMostPresentedViewController ?? navigationController
        }

        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.topMostPresentedViewController ?? tabBarController
        }

        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }

        return self
    }
}
