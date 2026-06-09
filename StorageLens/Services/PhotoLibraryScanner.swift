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
        var screenRecordingCount = 0
        var livePhotoCount = 0
        var largeVideoCount = 0
        var oldMediaCount = 0
        var estimatedScreenshotBytes: Int64 = 0
        var estimatedScreenRecordingBytes: Int64 = 0
        var estimatedLivePhotoBytes: Int64 = 0
        var estimatedLargeVideoBytes: Int64 = 0
        var estimatedOldMediaBytes: Int64 = 0
        var timelineBuckets: [String: TimelineAccumulator] = [:]
        var reviewCandidateBytesByID: [String: Int64] = [:]
        var recentPhotoCandidates: [PHAsset] = []

        for asset in allAssets {
            if Task.isCancelled { break }
            let kind = mediaKind(for: asset)
            let estimatedBytes = estimatedFileSize(for: asset, kind: kind)
            let monthKey = AppFormatters.monthKey(for: asset.creationDate)
            timelineBuckets[monthKey, default: TimelineAccumulator(date: asset.creationDate)].add(
                asset: asset,
                estimatedBytes: estimatedBytes
            )

            switch asset.mediaType {
            case .image:
                totalPhotos += 1
                if kind == .screenshot {
                    screenshotCount += 1
                    estimatedScreenshotBytes += estimatedBytes
                    reviewCandidateBytesByID[asset.localIdentifier] = estimatedBytes
                } else if kind == .livePhoto {
                    livePhotoCount += 1
                    estimatedLivePhotoBytes += estimatedBytes
                    reviewCandidateBytesByID[asset.localIdentifier] = estimatedBytes
                } else if recentPhotoCandidates.count < similarPhotoSummaryLimit {
                    recentPhotoCandidates.append(asset)
                }
            case .video:
                totalVideos += 1
                if kind == .screenRecording {
                    screenRecordingCount += 1
                    estimatedScreenRecordingBytes += estimatedBytes
                    reviewCandidateBytesByID[asset.localIdentifier] = estimatedBytes
                }
                if estimatedBytes >= largeVideoThreshold || asset.duration >= 180 {
                    largeVideoCount += 1
                    estimatedLargeVideoBytes += estimatedBytes
                    reviewCandidateBytesByID[asset.localIdentifier] = estimatedBytes
                }
            default:
                break
            }

            if let oneYearCutoff, (asset.creationDate ?? .distantFuture) < oneYearCutoff {
                oldMediaCount += 1
                estimatedOldMediaBytes += estimatedBytes
                reviewCandidateBytesByID[asset.localIdentifier] = estimatedBytes
            }
        }

        let similarGroups = await similarPhotoGroups(
            from: recentPhotoCandidates,
            maximumAssets: similarPhotoSummaryLimit
        )
        let estimatedSimilarPhotoBytes = similarGroups.map(\.estimatedDuplicateBytes).reduce(0, +)
        for group in similarGroups {
            let keepID = group.recommendedKeepID
            for item in group.items where item.id != keepID {
                reviewCandidateBytesByID[item.id] = item.estimatedFileSize ?? 0
            }
        }

        return ScanSummary(
            totalPhotos: totalPhotos,
            totalVideos: totalVideos,
            screenshotCount: screenshotCount,
            screenRecordingCount: screenRecordingCount,
            livePhotoCount: livePhotoCount,
            largeVideoCount: largeVideoCount,
            similarGroupCount: similarGroups.count,
            oldMediaCount: oldMediaCount,
            estimatedCleanableBytes: reviewCandidateBytesByID.values.reduce(0, +),
            estimatedLargeVideoBytes: estimatedLargeVideoBytes,
            estimatedScreenshotBytes: estimatedScreenshotBytes,
            estimatedScreenRecordingBytes: estimatedScreenRecordingBytes,
            estimatedLivePhotoBytes: estimatedLivePhotoBytes,
            estimatedOldMediaBytes: estimatedOldMediaBytes,
            estimatedSimilarPhotoBytes: estimatedSimilarPhotoBytes,
            timelineMonths: timelineBuckets
                .map { key, value in
                    StorageTimelineMonth(
                        id: key,
                        title: AppFormatters.monthTitle(for: value.date),
                        estimatedBytes: value.estimatedBytes,
                        estimatedPhotoBytes: value.estimatedPhotoBytes,
                        estimatedVideoBytes: value.estimatedVideoBytes,
                        itemCount: value.itemCount
                    )
                }
                .sorted { $0.estimatedBytes > $1.estimatedBytes },
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

    func fetchScreenRecordings() async throws -> [MediaAssetItem] {
        try ensurePhotoAccess()

        var items: [MediaAssetItem] = []
        for asset in fetchAssets(mediaType: .video) {
            if Task.isCancelled { break }
            guard isLikelyScreenRecording(asset) else { continue }
            items.append(makeItem(from: asset))
        }

        return items.sorted {
            ($0.estimatedFileSize ?? 0, $0.creationDate ?? .distantPast) >
                ($1.estimatedFileSize ?? 0, $1.creationDate ?? .distantPast)
        }
    }

    func fetchLivePhotos() async throws -> [MediaAssetItem] {
        try ensurePhotoAccess()

        var items: [MediaAssetItem] = []
        let livePhotos = fetchAssets(mediaType: .image)
            .filter { $0.mediaSubtypes.contains(.photoLive) }

        for asset in livePhotos {
            if Task.isCancelled { break }
            items.append(makeItem(from: asset))
        }

        return items.sorted {
            ($0.estimatedFileSize ?? 0, $0.creationDate ?? .distantPast) >
                ($1.estimatedFileSize ?? 0, $1.creationDate ?? .distantPast)
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
            .filter { !$0.mediaSubtypes.contains(.photoLive) }
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
        let kind = mediaKind(for: asset)

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

    private func mediaKind(for asset: PHAsset) -> MediaAssetKind {
        if asset.mediaType == .video {
            return isLikelyScreenRecording(asset) ? .screenRecording : .video
        } else if asset.mediaSubtypes.contains(.photoScreenshot) {
            return .screenshot
        } else if asset.mediaSubtypes.contains(.photoLive) {
            return .livePhoto
        } else {
            return .photo
        }
    }

    private func estimatedFileSize(for asset: PHAsset, kind: MediaAssetKind) -> Int64 {
        let pixelCount = max(Int64(asset.pixelWidth) * Int64(asset.pixelHeight), 1)

        switch kind {
        case .video, .screenRecording:
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

        case .livePhoto:
            return max(pixelCount / 2, 2 * 1024 * 1024)

        case .photo:
            return max(pixelCount / 3, 900 * 1024)
        }
    }

    private func isLikelyScreenRecording(_ asset: PHAsset) -> Bool {
        guard asset.mediaType == .video else { return false }
        if asset.mediaSubtypes.contains(.videoScreenRecording) {
            return true
        }

        let cameraVideoSubtypes: PHAssetMediaSubtype = [
            .videoHighFrameRate,
            .videoTimelapse,
            .videoCinematic
        ]
        guard asset.mediaSubtypes.intersection(cameraVideoSubtypes).isEmpty,
              asset.duration >= 5 else {
            return false
        }

        let width = max(asset.pixelWidth, 1)
        let height = max(asset.pixelHeight, 1)
        let longSide = max(width, height)
        let shortSide = min(width, height)
        let aspectRatio = Double(longSide) / Double(shortSide)
        return longSide >= 1280 && aspectRatio >= 1.75 && aspectRatio <= 2.35
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

private struct TimelineAccumulator {
    let date: Date?
    private(set) var estimatedBytes: Int64 = 0
    private(set) var estimatedPhotoBytes: Int64 = 0
    private(set) var estimatedVideoBytes: Int64 = 0
    private(set) var itemCount: Int = 0

    mutating func add(asset: PHAsset, estimatedBytes: Int64) {
        self.estimatedBytes += estimatedBytes
        itemCount += 1
        if asset.mediaType == .video {
            estimatedVideoBytes += estimatedBytes
        } else {
            estimatedPhotoBytes += estimatedBytes
        }
    }
}
