import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var summary: ScanSummary?
    @Published private(set) var isLoading = false
    @Published var message: UserMessage?

    private let scanner: PhotoLibraryScanner

    init(scanner: PhotoLibraryScanner = PhotoLibraryScanner()) {
        self.scanner = scanner
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            summary = try await scanner.scanSummary()
        } catch {
            message = UserMessage(title: "无法完成分析", message: error.localizedDescription)
        }
    }
}
