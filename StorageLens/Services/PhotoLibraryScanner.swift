import Foundation
import Photos

enum PhotoLibraryScannerError: LocalizedError {
    case missingAccess

    var errorDescription: String? {
        switch self {
        case .missingAccess:
            return "需要照片访问权限后才能分析图库。"
        }
    }
}

final class PhotoLibraryScanner {
    private let largeVideoThreshold: Int64 = 100 * 1024 * 1024
    private let screenshotFallbackBytes: Int64 = 2 * 1024 * 1024

    func scanSummary() async throws -> ScanSummary {
        try ensurePhotoAccess()

        let allAssets = fetchAssets()
        let photos = allAssets.filter { $0.mediaType == .image }
        let videos = allAssets.filter { $0.mediaType == .video }
        let screenshots = photos.filter { $0.mediaSubtypes.contains(.photoScreenshot) }

        let largeVideos = try await fetchLargeVideos()
        let oldMedia = try await fetchOldMedia(olderThan: .oneYear)
        let similarGroups = try await fetchSimilarPhotoGroups(maxAssets: 260)
        let largeVideoBytes = largeVideos.compactMap(\.estimatedFileSize).reduce(0, +)

        return ScanSummary(
            totalPhotos: photos.count,
            totalVideos: videos.count,
            screenshotCount: screenshots.count,
            largeVideoCount: largeVideos.count,
            similarGroupCount: similarGroups.count,
            oldMediaCount: oldMedia.count,
            estimatedLargeVideoBytes: largeVideoBytes,
            estimatedScreenshotBytes: Int64(screenshots.count) * screenshotFallbackBytes,
            generatedAt: Date()
        )
    }

    func fetchLargeVideos() async throws -> [MediaAssetItem] {
        try ensurePhotoAccess()

        var items: [MediaAssetItem] = []
        for asset in fetchAssets(mediaType: .video) {
            if Task.isCancelled { break }
            let item = await makeItem(from: asset, includeFileSize: true)
            let isProbablyLarge = (item.estimatedFileSize ?? 0) >= largeVideoThreshold || item.duration >= 180
            if isProbablyLarge {
                items.append(item)
            }
        }

        return items.sorted {
            ($0.estimatedFileSize ?? 0, $0.duration) > ($1.estimatedFileSize ?? 0, $1.duration)
        }
    }

    func fetchScreenshots() async throws -> [MediaAssetItem] {
        try ensurePhotoAccess()

        var items: [MediaAssetItem] = []
        let screenshots = fetchAssets(mediaType: .image)
            .filter { $0.mediaSubtypes.contains(.photoScreenshot) }

        for asset in screenshots {
            if Task.isCancelled { break }
            items.append(await makeItem(from: asset, includeFileSize: true))
        }

        return items.sorted {
            ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
        }
    }

    func fetchOldMedia(olderThan filter: OldMediaFilter) async throws -> [MediaAssetItem] {
        try ensurePhotoAccess()
        guard let cutoffDate = filter.cutoffDate else { return [] }

        let oldAssets = fetchAssets()
            .filter { ($0.creationDate ?? .distantFuture) < cutoffDate }

        var items: [MediaAssetItem] = []
        for asset in oldAssets {
            if Task.isCancelled { break }
            let shouldEstimateSize = asset.mediaType == .video
            items.append(await makeItem(from: asset, includeFileSize: shouldEstimateSize))
        }

        return items
    }

    func fetchSimilarPhotoGroups(maxAssets: Int = 500) async throws -> [SimilarPhotoGroup] {
        try ensurePhotoAccess()

        let photoAssets = fetchAssets(mediaType: .image)
            .filter { !$0.mediaSubtypes.contains(.photoScreenshot) }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
            .prefix(maxAssets)

        var groups: [[MediaAssetItem]] = []

        for asset in photoAssets {
            if Task.isCancelled { break }
            let item = await makeItem(from: asset, includeFileSize: true)

            if let lastGroup = groups.indices.last,
               let previous = groups[lastGroup].last,
               isProbablySimilar(previous, item) {
                groups[lastGroup].append(item)
            } else {
                groups.append([item])
            }
        }

        let similarGroups = groups
            .filter { $0.count > 1 }
            .enumerated()
            .map { index, items in
                let dateText = items.first?.creationDate.map(AppFormatters.date) ?? "日期未知"
                return SimilarPhotoGroup(
                    id: "similar-\(index)-\(items.first?.id ?? UUID().uuidString)",
                    title: "\(dateText) 的相似照片",
                    items: items
                )
            }

        return Array(similarGroups.reversed())
    }

    func asset(for localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    private func ensurePhotoAccess() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryScannerError.missingAccess
        }
    }

    private func fetchAssets(mediaType: PHAssetMediaType? = nil) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if let mediaType {
            options.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)
        }

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func makeItem(from asset: PHAsset, includeFileSize: Bool) async -> MediaAssetItem {
        let kind: MediaAssetKind
        if asset.mediaType == .video {
            kind = .video
        } else if asset.mediaSubtypes.contains(.photoScreenshot) {
            kind = .screenshot
        } else {
            kind = .photo
        }

        return MediaAssetItem(
            id: asset.localIdentifier,
            kind: kind,
            estimatedFileSize: includeFileSize ? await estimatedFileSize(for: asset) : nil,
            duration: asset.duration,
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight
        )
    }

    private func estimatedFileSize(for asset: PHAsset) async -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        var totalBytes: Int64 = 0
        var hasValue = false

        for resource in resources {
            if Task.isCancelled { break }
            if let byteCount = await byteCount(for: resource) {
                totalBytes += byteCount
                hasValue = true
            }
        }

        return hasValue ? totalBytes : nil
    }

    private func byteCount(for resource: PHAssetResource) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            var totalBytes: Int64 = 0

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    totalBytes += Int64(data.count)
                },
                completionHandler: { error in
                    continuation.resume(returning: error == nil ? totalBytes : nil)
                }
            )
        }
    }

    private func isProbablySimilar(_ lhs: MediaAssetItem, _ rhs: MediaAssetItem) -> Bool {
        guard let lhsDate = lhs.creationDate, let rhsDate = rhs.creationDate else { return false }
        guard Calendar.current.isDate(lhsDate, inSameDayAs: rhsDate) else { return false }
        guard abs(lhsDate.timeIntervalSince(rhsDate)) <= 10 else { return false }

        let widthDelta = abs(lhs.pixelWidth - rhs.pixelWidth)
        let heightDelta = abs(lhs.pixelHeight - rhs.pixelHeight)
        guard widthDelta <= 64, heightDelta <= 64 else { return false }

        guard let lhsSize = lhs.estimatedFileSize, let rhsSize = rhs.estimatedFileSize else {
            return true
        }
        let larger = max(lhsSize, rhsSize)
        let smaller = max(min(lhsSize, rhsSize), 1)
        return Double(larger - smaller) / Double(smaller) <= 0.18
    }
}
