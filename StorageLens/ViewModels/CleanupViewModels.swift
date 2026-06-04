import Combine
import Foundation

@MainActor
final class ReviewBasketStore: ObservableObject {
    @Published private(set) var itemsByID: [String: ReviewBasketItem] = [:]
    @Published private(set) var isDeleting = false
    @Published var message: UserMessage?
    @Published var cleanupResult: CleanupResult?

    private let deletionService: PhotoDeletionService

    init(deletionService: PhotoDeletionService = PhotoDeletionService()) {
        self.deletionService = deletionService
    }

    var items: [ReviewBasketItem] {
        itemsByID.values.sorted {
            ($0.item.estimatedFileSize ?? 0, $0.item.creationDate ?? .distantPast) >
                ($1.item.estimatedFileSize ?? 0, $1.item.creationDate ?? .distantPast)
        }
    }

    var itemCount: Int { itemsByID.count }

    var estimatedBytes: Int64 {
        itemsByID.values.compactMap(\.item.estimatedFileSize).reduce(0, +)
    }

    var includedCategoryTitles: String {
        let kinds = Set(itemsByID.values.map(\.categoryKind))
        return CleanupCategoryKind.allCases
            .filter { kinds.contains($0) }
            .map(\.title)
            .joined(separator: "、")
    }

    func add(_ items: [MediaAssetItem], from categoryKind: CleanupCategoryKind) {
        for item in items {
            itemsByID[item.id] = ReviewBasketItem(item: item, categoryKind: categoryKind)
        }
        Haptics.selectionChanged()
    }

    func remove(_ item: ReviewBasketItem) {
        itemsByID.removeValue(forKey: item.id)
        Haptics.selectionChanged()
    }

    func clear() {
        itemsByID.removeAll()
    }

    func deleteAll() async {
        let ids = Set(itemsByID.keys)
        let deletedCount = ids.count
        let deletedBytes = estimatedBytes
        guard !ids.isEmpty else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await deletionService.deleteAssets(withLocalIdentifiers: ids)
            itemsByID.removeAll()
            cleanupResult = CleanupResult(deletedCount: deletedCount, estimatedBytes: deletedBytes)
            Haptics.cleanupSucceeded()
        } catch {
            message = UserMessage(title: "删除失败", message: error.localizedDescription)
        }
    }
}

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

enum ScreenshotAgeFilter: String, CaseIterable, Identifiable {
    case all
    case threeMonths
    case sixMonths
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .threeMonths:
            return "3 个月+"
        case .sixMonths:
            return "6 个月+"
        case .oneYear:
            return "1 年+"
        }
    }

    var cutoffDate: Date? {
        let months: Int
        switch self {
        case .all:
            return nil
        case .threeMonths:
            months = -3
        case .sixMonths:
            months = -6
        case .oneYear:
            months = -12
        }
        return Calendar.current.date(byAdding: .month, value: months, to: Date())
    }
}

enum MediaSort: String, CaseIterable, Identifiable {
    case estimatedSize
    case date
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estimatedSize:
            return "按大小"
        case .date:
            return "按日期"
        case .duration:
            return "按时长"
        }
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
    @Published var sort: MediaSort = .estimatedSize {
        didSet { applySort() }
    }
    @Published private(set) var isLoading = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner

    init(scanner: PhotoLibraryScanner = PhotoLibraryScanner()) {
        self.scanner = scanner
    }

    var selectedEstimatedBytes: Int64 {
        selectedItems
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    var selectedItems: [MediaAssetItem] {
        items
            .filter { selectedIDs.contains($0.id) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await scanner.fetchLargeVideos()
            applySort()
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

    private func applySort() {
        items.sort(using: sort)
    }
}

@MainActor
final class ScreenshotsViewModel: ObservableObject {
    @Published private(set) var groups: [ScreenshotMonthGroup] = []
    @Published var selectedIDs: Set<String> = []
    @Published var filter: ScreenshotAgeFilter = .all
    @Published private(set) var isLoading = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner

    init(scanner: PhotoLibraryScanner = PhotoLibraryScanner()) {
        self.scanner = scanner
    }

    var allItems: [MediaAssetItem] {
        groups.flatMap(\.items)
    }

    var selectedEstimatedBytes: Int64 {
        selectedItems
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    var selectedItems: [MediaAssetItem] {
        allItems
            .filter { selectedIDs.contains($0.id) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedItems = try await scanner.fetchScreenshots()
            let filteredItems = loadedItems.filter { item in
                guard let cutoffDate = filter.cutoffDate else { return true }
                return (item.creationDate ?? .distantFuture) < cutoffDate
            }
            groups = Dictionary(grouping: filteredItems) { item in
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
            selectedIDs = selectedIDs.intersection(Set(filteredItems.map(\.id)))
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

    func isMonthFullySelected(_ group: ScreenshotMonthGroup) -> Bool {
        let groupIDs = Set(group.items.map(\.id))
        return !groupIDs.isEmpty && groupIDs.isSubset(of: selectedIDs)
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

}

@MainActor
final class ScreenRecordingsViewModel: ObservableObject {
    @Published private(set) var items: [MediaAssetItem] = []
    @Published var selectedIDs: Set<String> = []
    @Published var sort: MediaSort = .estimatedSize {
        didSet { applySort() }
    }
    @Published private(set) var isLoading = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner

    init(scanner: PhotoLibraryScanner = PhotoLibraryScanner()) {
        self.scanner = scanner
    }

    var selectedEstimatedBytes: Int64 {
        selectedItems.compactMap(\.estimatedFileSize).reduce(0, +)
    }

    var selectedItems: [MediaAssetItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await scanner.fetchScreenRecordings()
            applySort()
            selectedIDs = selectedIDs.intersection(Set(items.map(\.id)))
        } catch {
            message = UserMessage(title: "无法载入屏幕录制", message: error.localizedDescription)
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

    private func applySort() {
        items.sort(using: sort)
    }
}

@MainActor
final class LivePhotosViewModel: ObservableObject {
    @Published private(set) var items: [MediaAssetItem] = []
    @Published var selectedIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner

    init(scanner: PhotoLibraryScanner = PhotoLibraryScanner()) {
        self.scanner = scanner
    }

    var selectedEstimatedBytes: Int64 {
        selectedItems.compactMap(\.estimatedFileSize).reduce(0, +)
    }

    var selectedItems: [MediaAssetItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await scanner.fetchLivePhotos()
            selectedIDs = selectedIDs.intersection(Set(items.map(\.id)))
        } catch {
            message = UserMessage(title: "无法载入 Live Photos", message: error.localizedDescription)
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
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner

    init(scanner: PhotoLibraryScanner = PhotoLibraryScanner()) {
        self.scanner = scanner
    }

    var selectedEstimatedBytes: Int64 {
        selectedItems
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    var selectedItems: [MediaAssetItem] {
        items
            .filter { selectedIDs.contains($0.id) }
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

private extension Array where Element == MediaAssetItem {
    mutating func sort(using sort: MediaSort) {
        switch sort {
        case .estimatedSize:
            self.sort {
                ($0.estimatedFileSize ?? 0, $0.creationDate ?? .distantPast) >
                    ($1.estimatedFileSize ?? 0, $1.creationDate ?? .distantPast)
            }
        case .date:
            self.sort {
                ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
            }
        case .duration:
            self.sort {
                ($0.duration, $0.estimatedFileSize ?? 0) > ($1.duration, $1.estimatedFileSize ?? 0)
            }
        }
    }
}

@MainActor
final class SimilarPhotosViewModel: ObservableObject {
    @Published private(set) var groups: [SimilarPhotoGroup] = []
    @Published var selectedIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner

    init(scanner: PhotoLibraryScanner = PhotoLibraryScanner()) {
        self.scanner = scanner
    }

    var allItems: [MediaAssetItem] {
        groups.flatMap(\.items)
    }

    var selectedEstimatedBytes: Int64 {
        selectedItems
            .compactMap(\.estimatedFileSize)
            .reduce(0, +)
    }

    var selectedItems: [MediaAssetItem] {
        allItems
            .filter { selectedIDs.contains($0.id) }
    }

    var selectedRecommendedKeepCount: Int {
        groups.reduce(0) { count, group in
            guard let keepID = group.recommendedKeepID else { return count }
            return selectedIDs.contains(keepID) ? count + 1 : count
        }
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

    func selectLikelyDuplicates(in group: SimilarPhotoGroup) {
        let keepID = group.recommendedKeepID
        let duplicateIDs = group.items
            .map(\.id)
            .filter { $0 != keepID }

        selectedIDs.formUnion(duplicateIDs)
        if let keepID {
            selectedIDs.remove(keepID)
        }
        Haptics.selectionChanged()
    }
}
