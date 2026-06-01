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
    private let similarPhotoSummaryLimit = 260

    func scanSummary() async throws -> ScanSummary {
        try ensurePhotoAccess()

        let allAssets = fetchAssets()
        let oneYearCutoff = OldMediaFilter.oneYear.cutoffDate

        var totalPhotos = 0
        var totalVideos = 0
        var screenshotCount = 0
        var largeVideoCount = 0
        var oldMediaCount = 0
        var estimatedScreenshotBytes: Int64 = 0
        var estimatedLargeVideoBytes: Int64 = 0
        var recentPhotoCandidates: [PHAsset] = []

        for asset in allAssets {
            if Task.isCancelled { break }

            switch asset.mediaType {
            case .image:
                totalPhotos += 1
                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    screenshotCount += 1
                    estimatedScreenshotBytes += estimatedFileSize(for: asset, kind: .screenshot)
                } else if recentPhotoCandidates.count < similarPhotoSummaryLimit {
                    recentPhotoCandidates.append(asset)
                }
            case .video:
                totalVideos += 1
                let estimatedBytes = estimatedFileSize(for: asset, kind: .video)
                if estimatedBytes >= largeVideoThreshold || asset.duration >= 180 {
                    largeVideoCount += 1
                    estimatedLargeVideoBytes += estimatedBytes
                }
            default:
                break
            }

            if let oneYearCutoff, (asset.creationDate ?? .distantFuture) < oneYearCutoff {
                oldMediaCount += 1
            }
        }

        let similarGroups = await similarPhotoGroups(
            from: recentPhotoCandidates,
            maximumAssets: similarPhotoSummaryLimit
        )

        return ScanSummary(
            totalPhotos: totalPhotos,
            totalVideos: totalVideos,
            screenshotCount: screenshotCount,
            largeVideoCount: largeVideoCount,
            similarGroupCount: similarGroups.count,
            oldMediaCount: oldMediaCount,
            estimatedLargeVideoBytes: estimatedLargeVideoBytes,
            estimatedScreenshotBytes: estimatedScreenshotBytes,
            generatedAt: Date()
        )
    }

    func fetchLargeVideos() async throws -> [MediaAssetItem] {
        try ensurePhotoAccess()

        var items: [MediaAssetItem] = []
        for asset in fetchAssets(mediaType: .video) {
            if Task.isCancelled { break }
            let item = makeItem(from: asset)
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
            items.append(makeItem(from: asset))
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
            items.append(makeItem(from: asset))
        }

        return items
    }

    func fetchSimilarPhotoGroups(maxAssets: Int = 500) async throws -> [SimilarPhotoGroup] {
        try ensurePhotoAccess()

        let photoAssets = fetchAssets(mediaType: .image)
            .filter { !$0.mediaSubtypes.contains(.photoScreenshot) }
            .prefix(maxAssets)

        return await similarPhotoGroups(from: Array(photoAssets), maximumAssets: maxAssets)
    }

    private func similarPhotoGroups(from assets: [PHAsset], maximumAssets: Int) async -> [SimilarPhotoGroup] {
        let photoAssets = assets
            .prefix(maximumAssets)
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }

        var groups: [[MediaAssetItem]] = []

        for asset in photoAssets {
            if Task.isCancelled { break }
            let item = makeItem(from: asset)

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

    private func makeItem(from asset: PHAsset) -> MediaAssetItem {
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
            estimatedFileSize: estimatedFileSize(for: asset, kind: kind),
            duration: asset.duration,
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight
        )
    }

    private func estimatedFileSize(for asset: PHAsset, kind: MediaAssetKind) -> Int64 {
        let pixelCount = max(Int64(asset.pixelWidth) * Int64(asset.pixelHeight), 1)

        switch kind {
        case .video:
            let bytesPerSecond: Int64
            switch pixelCount {
            case 8_000_000...:
                bytesPerSecond = 7_000_000
            case 2_000_000...:
                bytesPerSecond = 2_500_000
            default:
                bytesPerSecond = 1_000_000
            }
            let duration = max(Int64(asset.duration.rounded(.up)), 1)
            return max(duration * bytesPerSecond, 5 * 1024 * 1024)

        case .screenshot:
            return max(pixelCount / 2, 700 * 1024)

        case .photo:
            return max(pixelCount / 3, 900 * 1024)
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
