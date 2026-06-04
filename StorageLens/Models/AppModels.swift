import Foundation
import Photos

enum MediaAssetKind: String, Hashable {
    case photo
    case video
    case screenshot
    case screenRecording
    case livePhoto

    var title: String {
        switch self {
        case .photo:
            return "照片"
        case .video:
            return "视频"
        case .screenshot:
            return "屏幕截图"
        case .screenRecording:
            return "可能的屏幕录制"
        case .livePhoto:
            return "Live Photo"
        }
    }

    var englishTitle: String {
        switch self {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        case .screenshot:
            return "Screenshot"
        case .screenRecording:
            return "Possible Screen Recording"
        case .livePhoto:
            return "Live Photo"
        }
    }

    var systemImage: String {
        switch self {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .screenshot:
            return "rectangle.on.rectangle"
        case .screenRecording:
            return "record.circle"
        case .livePhoto:
            return "livephoto"
        }
    }
}

struct MediaAssetItem: Identifiable, Hashable {
    let id: String
    let kind: MediaAssetKind
    let estimatedFileSize: Int64?
    let duration: TimeInterval
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int

    var pixelDescription: String {
        guard pixelWidth > 0, pixelHeight > 0 else { return "尺寸未知" }
        return "\(pixelWidth) x \(pixelHeight)"
    }

    var accessibilityLabel: String {
        let dateText = creationDate.map(AppFormatters.date) ?? "日期未知"
        return "\(kind.title)，\(dateText)，估算大小 \(AppFormatters.fileSize(estimatedFileSize))"
    }
}

enum CleanupCategoryKind: String, CaseIterable, Identifiable {
    case largeVideos
    case screenshots
    case screenRecordings
    case livePhotos
    case oldMedia
    case similarPhotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largeVideos:
            return "大视频"
        case .screenshots:
            return "屏幕截图"
        case .screenRecordings:
            return "屏幕录制"
        case .livePhotos:
            return "Live Photos"
        case .oldMedia:
            return "旧媒体"
        case .similarPhotos:
            return "相似照片"
        }
    }
}

struct CleanupCategory: Identifiable, Hashable {
    let kind: CleanupCategoryKind
    let title: String
    let englishTitle: String
    let detail: String
    let systemImage: String
    let itemCount: Int
    let estimatedBytes: Int64?

    var id: CleanupCategoryKind { kind }
}

struct ScanSummary: Hashable {
    let totalPhotos: Int
    let totalVideos: Int
    let screenshotCount: Int
    let screenRecordingCount: Int
    let livePhotoCount: Int
    let largeVideoCount: Int
    let similarGroupCount: Int
    let oldMediaCount: Int
    let estimatedCleanableBytes: Int64
    let estimatedLargeVideoBytes: Int64
    let estimatedScreenshotBytes: Int64
    let estimatedScreenRecordingBytes: Int64
    let estimatedLivePhotoBytes: Int64
    let estimatedOldMediaBytes: Int64
    let estimatedSimilarPhotoBytes: Int64
    let timelineMonths: [StorageTimelineMonth]
    let generatedAt: Date

    var estimatedLibraryBytes: Int64 {
        timelineMonths.map(\.estimatedBytes).reduce(0, +)
    }

    var topTimelineMonths: [StorageTimelineMonth] {
        timelineMonths.sorted { $0.estimatedBytes > $1.estimatedBytes }.prefix(3).map { $0 }
    }

    var insightText: String? {
        guard let topMonth = topTimelineMonths.first, topMonth.estimatedBytes > 0 else { return nil }
        let source = topMonth.estimatedVideoBytes >= topMonth.estimatedPhotoBytes ? "视频" : "照片"
        return "\(topMonth.title) 新增估算空间主要来自\(source)。"
    }

    var categories: [CleanupCategory] {
        [
            CleanupCategory(
                kind: .largeVideos,
                title: "大视频",
                englishTitle: "Large Videos",
                detail: "优先查看占用空间较大的视频",
                systemImage: "video.fill",
                itemCount: largeVideoCount,
                estimatedBytes: estimatedLargeVideoBytes
            ),
            CleanupCategory(
                kind: .screenshots,
                title: "屏幕截图",
                englishTitle: "Screenshots",
                detail: "按月份整理截图，手动选择删除",
                systemImage: "rectangle.on.rectangle",
                itemCount: screenshotCount,
                estimatedBytes: estimatedScreenshotBytes
            ),
            CleanupCategory(
                kind: .screenRecordings,
                title: "屏幕录制",
                englishTitle: "Screen Recordings",
                detail: "查看可能的屏幕录制视频",
                systemImage: "record.circle",
                itemCount: screenRecordingCount,
                estimatedBytes: estimatedScreenRecordingBytes
            ),
            CleanupCategory(
                kind: .livePhotos,
                title: "Live Photos",
                englishTitle: "Live Photos",
                detail: "只支持查看和手动删除，不转换格式",
                systemImage: "livephoto",
                itemCount: livePhotoCount,
                estimatedBytes: estimatedLivePhotoBytes
            ),
            CleanupCategory(
                kind: .oldMedia,
                title: "旧媒体",
                englishTitle: "Old Media",
                detail: "查看较久以前的照片和视频",
                systemImage: "calendar",
                itemCount: oldMediaCount,
                estimatedBytes: estimatedOldMediaBytes
            ),
            CleanupCategory(
                kind: .similarPhotos,
                title: "相似照片",
                englishTitle: "Similar Photos",
                detail: "按时间和尺寸线索找出可能相似的照片",
                systemImage: "square.stack.3d.up",
                itemCount: similarGroupCount,
                estimatedBytes: estimatedSimilarPhotoBytes
            )
        ]
    }
}

struct StorageTimelineMonth: Identifiable, Hashable {
    let id: String
    let title: String
    let estimatedBytes: Int64
    let estimatedPhotoBytes: Int64
    let estimatedVideoBytes: Int64
    let itemCount: Int
}

struct ScreenshotMonthGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let items: [MediaAssetItem]

    var estimatedBytes: Int64 {
        items.compactMap(\.estimatedFileSize).reduce(0, +)
    }
}

struct SimilarPhotoGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let items: [MediaAssetItem]

    var recommendedKeepID: String? {
        items.max { lhs, rhs in
            (
                lhs.pixelWidth * lhs.pixelHeight,
                lhs.estimatedFileSize ?? 0,
                lhs.creationDate ?? .distantPast
            ) < (
                rhs.pixelWidth * rhs.pixelHeight,
                rhs.estimatedFileSize ?? 0,
                rhs.creationDate ?? .distantPast
            )
        }?.id
    }

    var estimatedDuplicateBytes: Int64 {
        let keepID = recommendedKeepID
        return items
            .filter { $0.id != keepID }
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }
}

struct ReviewBasketItem: Identifiable, Hashable {
    let item: MediaAssetItem
    let categoryKind: CleanupCategoryKind

    var id: String { item.id }
}

struct CleanupResult: Identifiable, Hashable {
    let id = UUID()
    let deletedCount: Int
    let estimatedBytes: Int64
}

struct UserMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
