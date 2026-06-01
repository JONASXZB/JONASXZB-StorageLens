import Foundation
import Photos

enum MediaAssetKind: String, Hashable {
    case photo
    case video
    case screenshot

    var title: String {
        switch self {
        case .photo:
            return "照片"
        case .video:
            return "视频"
        case .screenshot:
            return "屏幕截图"
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
        return "\(kind.title)，\(dateText)，\(AppFormatters.fileSize(estimatedFileSize))"
    }
}

enum CleanupCategoryKind: String, CaseIterable, Identifiable {
    case largeVideos
    case screenshots
    case similarPhotos
    case oldMedia

    var id: String { rawValue }
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
    let largeVideoCount: Int
    let similarGroupCount: Int
    let oldMediaCount: Int
    let estimatedLargeVideoBytes: Int64
    let estimatedScreenshotBytes: Int64
    let generatedAt: Date

    var estimatedCleanableBytes: Int64 {
        estimatedLargeVideoBytes + estimatedScreenshotBytes
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
                kind: .similarPhotos,
                title: "相似照片",
                englishTitle: "Similar Photos",
                detail: "按时间和尺寸线索找出可能相似的照片",
                systemImage: "square.stack.3d.up",
                itemCount: similarGroupCount,
                estimatedBytes: nil
            ),
            CleanupCategory(
                kind: .oldMedia,
                title: "旧媒体",
                englishTitle: "Old Media",
                detail: "查看较久以前的照片和视频",
                systemImage: "calendar",
                itemCount: oldMediaCount,
                estimatedBytes: nil
            )
        ]
    }
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

struct UserMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
