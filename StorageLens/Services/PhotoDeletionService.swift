import Foundation
import Photos

final class PhotoDeletionService {
    func deleteAssets(withLocalIdentifiers identifiers: Set<String>) async throws -> Set<String> {
        guard !identifiers.isEmpty else { return [] }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(identifiers), options: nil)
        var resolvedIdentifiers: Set<String> = []
        fetchResult.enumerateObjects { asset, _, _ in
            resolvedIdentifiers.insert(asset.localIdentifier)
        }
        guard !resolvedIdentifiers.isEmpty else { return [] }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(fetchResult)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: CocoaError(.userCancelled))
                }
            }
        }
        return resolvedIdentifiers
    }
}
