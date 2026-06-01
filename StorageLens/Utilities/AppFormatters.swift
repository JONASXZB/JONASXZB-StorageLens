import Foundation

enum AppFormatters {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.primaryLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.primaryLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.primaryLocale
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.primaryLocale
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static func fileSize(_ bytes: Int64?) -> String {
        guard let bytes else { return "待估算" }
        guard bytes > 0 else { return "0 KB" }
        return byteFormatter.string(fromByteCount: bytes)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "时长未知" }

        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = max((totalSeconds % 3600) / 60, hours == 0 ? 1 : 0)

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }

    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func monthTitle(for date: Date?) -> String {
        guard let date else { return "未知月份" }
        return monthFormatter.string(from: date)
    }

    static func monthKey(for item: MediaAssetItem) -> String {
        guard let date = item.creationDate else { return "unknown" }
        return monthKeyFormatter.string(from: date)
    }
}
