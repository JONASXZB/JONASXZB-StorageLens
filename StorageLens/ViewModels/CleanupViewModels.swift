import Combine
import Foundation

enum OldMediaFilter: String, CaseIterable, Identifiable {
    case sixMonths
    case oneYear
    case twoYears

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sixMonths:
            return "6 个月+"
        case .oneYear:
            return "1 年+"
        case .twoYears:
            return "2 年+"
        }
    }

    var cutoffDate: Date? {
        let months: Int
        switch self {
        case .sixMonths:
            months = -6
        case .oneYear:
            months = -12
        case .twoYears:
            months = -24
        }
        return Calendar.current.date(byAdding: .month, value: months, to: Date())
    }
}

enum OldMediaSort: String, CaseIterable, Identifiable {
    case estimatedSize
    case date

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estimatedSize:
            return "按大小"
        case .date:
            return "按日期"
        }
    }
}

@MainActor
final class LargeVideosViewModel: ObservableObject {
    @Published private(set) var items: [MediaAssetItem] = []
    @Published var selectedIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isDeleting = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner
    private let deletionService: PhotoDeletionService

    init(
        scanner: PhotoLibraryScanner = PhotoLibraryScanner(),
        deletionService: PhotoDeletionService = PhotoDeletionService()
    ) {
        self.scanner = scanner
        self.deletionService = deletionService
    }

    var selectedEstimatedBytes: Int64 {
        items
            .filter { selectedIDs.contains($0.id) }
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await scanner.fetchLargeVideos()
            selectedIDs = selectedIDs.intersection(Set(items.map(\.id)))
        } catch {
            message = UserMessage(title: "无法载入大视频", message: error.localizedDescription)
        }
    }

    func toggleSelection(for item: MediaAssetItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        Haptics.selectionChanged()
    }

    func deleteSelected() async {
        let ids = selectedIDs
        let itemCount = ids.count
        let estimatedBytes = selectedEstimatedBytes
        guard !ids.isEmpty else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await deletionService.deleteAssets(withLocalIdentifiers: ids)
            Haptics.cleanupSucceeded()
            selectedIDs.removeAll()
            await load()
            message = UserMessage(
                title: "已删除所选视频",
                message: "已删除 \(itemCount) 个项目，预计释放 \(AppFormatters.fileSize(estimatedBytes))。"
            )
        } catch {
            message = UserMessage(title: "删除失败", message: error.localizedDescription)
        }
    }
}

@MainActor
final class ScreenshotsViewModel: ObservableObject {
    @Published private(set) var groups: [ScreenshotMonthGroup] = []
    @Published var selectedIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isDeleting = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner
    private let deletionService: PhotoDeletionService

    init(
        scanner: PhotoLibraryScanner = PhotoLibraryScanner(),
        deletionService: PhotoDeletionService = PhotoDeletionService()
    ) {
        self.scanner = scanner
        self.deletionService = deletionService
    }

    var allItems: [MediaAssetItem] {
        groups.flatMap(\.items)
    }

    var selectedEstimatedBytes: Int64 {
        allItems
            .filter { selectedIDs.contains($0.id) }
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await scanner.fetchScreenshots()
            groups = Dictionary(grouping: items) { item in
                AppFormatters.monthKey(for: item)
            }
                .map { key, items in
                    ScreenshotMonthGroup(
                        id: key,
                        title: AppFormatters.monthTitle(for: items.first?.creationDate),
                        items: items
                    )
                }
                .sorted { $0.id > $1.id }
            selectedIDs = selectedIDs.intersection(Set(items.map(\.id)))
        } catch {
            message = UserMessage(title: "无法载入截图", message: error.localizedDescription)
        }
    }

    func toggleSelection(for item: MediaAssetItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        Haptics.selectionChanged()
    }

    func toggleMonth(_ group: ScreenshotMonthGroup) {
        let groupIDs = Set(group.items.map(\.id))
        if groupIDs.isSubset(of: selectedIDs) {
            selectedIDs.subtract(groupIDs)
        } else {
            selectedIDs.formUnion(groupIDs)
        }
        Haptics.selectionChanged()
    }

    func deleteSelected() async {
        let ids = selectedIDs
        let itemCount = ids.count
        let estimatedBytes = selectedEstimatedBytes
        guard !ids.isEmpty else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await deletionService.deleteAssets(withLocalIdentifiers: ids)
            Haptics.cleanupSucceeded()
            selectedIDs.removeAll()
            await load()
            message = UserMessage(
                title: "已删除所选截图",
                message: "已删除 \(itemCount) 个项目，预计释放 \(AppFormatters.fileSize(estimatedBytes))。"
            )
        } catch {
            message = UserMessage(title: "删除失败", message: error.localizedDescription)
        }
    }
}

@MainActor
final class OldMediaViewModel: ObservableObject {
    @Published private(set) var items: [MediaAssetItem] = []
    @Published var selectedIDs: Set<String> = []
    @Published var filter: OldMediaFilter = .oneYear
    @Published var sort: OldMediaSort = .estimatedSize {
        didSet { applySort() }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var isDeleting = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner
    private let deletionService: PhotoDeletionService

    init(
        scanner: PhotoLibraryScanner = PhotoLibraryScanner(),
        deletionService: PhotoDeletionService = PhotoDeletionService()
    ) {
        self.scanner = scanner
        self.deletionService = deletionService
    }

    var selectedEstimatedBytes: Int64 {
        items
            .filter { selectedIDs.contains($0.id) }
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await scanner.fetchOldMedia(olderThan: filter)
            applySort()
            selectedIDs = selectedIDs.intersection(Set(items.map(\.id)))
        } catch {
            message = UserMessage(title: "无法载入旧媒体", message: error.localizedDescription)
        }
    }

    func toggleSelection(for item: MediaAssetItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        Haptics.selectionChanged()
    }

    func deleteSelected() async {
        let ids = selectedIDs
        let itemCount = ids.count
        let estimatedBytes = selectedEstimatedBytes
        guard !ids.isEmpty else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await deletionService.deleteAssets(withLocalIdentifiers: ids)
            Haptics.cleanupSucceeded()
            selectedIDs.removeAll()
            await load()
            message = UserMessage(
                title: "已删除所选旧媒体",
                message: "已删除 \(itemCount) 个项目，预计释放 \(AppFormatters.fileSize(estimatedBytes))。"
            )
        } catch {
            message = UserMessage(title: "删除失败", message: error.localizedDescription)
        }
    }

    private func applySort() {
        switch sort {
        case .estimatedSize:
            items.sort {
                ($0.estimatedFileSize ?? 0, $0.creationDate ?? .distantPast) >
                    ($1.estimatedFileSize ?? 0, $1.creationDate ?? .distantPast)
            }
        case .date:
            items.sort {
                ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
            }
        }
    }
}

@MainActor
final class SimilarPhotosViewModel: ObservableObject {
    @Published private(set) var groups: [SimilarPhotoGroup] = []
    @Published var selectedIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isDeleting = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner
    private let deletionService: PhotoDeletionService

    init(
        scanner: PhotoLibraryScanner = PhotoLibraryScanner(),
        deletionService: PhotoDeletionService = PhotoDeletionService()
    ) {
        self.scanner = scanner
        self.deletionService = deletionService
    }

    var allItems: [MediaAssetItem] {
        groups.flatMap(\.items)
    }

    var selectedEstimatedBytes: Int64 {
        allItems
            .filter { selectedIDs.contains($0.id) }
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await scanner.fetchSimilarPhotoGroups()
            selectedIDs = selectedIDs.intersection(Set(allItems.map(\.id)))
        } catch {
            message = UserMessage(title: "无法载入相似照片", message: error.localizedDescription)
        }
    }

    func toggleSelection(for item: MediaAssetItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        Haptics.selectionChanged()
    }

    func deleteSelected() async {
        let ids = selectedIDs
        let itemCount = ids.count
        let estimatedBytes = selectedEstimatedBytes
        guard !ids.isEmpty else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await deletionService.deleteAssets(withLocalIdentifiers: ids)
            Haptics.cleanupSucceeded()
            selectedIDs.removeAll()
            await load()
            message = UserMessage(
                title: "已删除所选照片",
                message: "已删除 \(itemCount) 个项目，预计释放 \(AppFormatters.fileSize(estimatedBytes))。"
            )
        } catch {
            message = UserMessage(title: "删除失败", message: error.localizedDescription)
        }
    }
}
