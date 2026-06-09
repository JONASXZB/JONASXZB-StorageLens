import Photos
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var permissionManager: PhotoLibraryPermissionManager
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("StorageLens")
                            .font(.largeTitle.bold())
                        Text("私密整理图库 / Review storage, privately.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    StorageOverviewCard(summary: viewModel.summary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    Label {
                        Text("On-device analysis · No photo upload")
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("整理建议 / Review") {
                    if viewModel.isLoading && viewModel.summary == nil {
                        ProgressView("正在分析照片图库...")
                    }

                    ForEach(viewModel.summary?.categories ?? ScanSummary.mock.categories) { category in
                        NavigationLink {
                            destination(for: category.kind)
                        } label: {
                            CleanupCategoryRow(category: category)
                        }
                    }
                }

                if permissionManager.status == .limited {
                    Section {
                        Label {
                            Text("当前为部分照片访问模式，分析结果只包含你允许 StorageLens 读取的项目。")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }

                        Button {
                            permissionManager.presentLimitedLibraryPicker()
                        } label: {
                            Label("选择更多照片", systemImage: "photo.stack")
                        }
                    }
                }

                if let summary = viewModel.summary {
                    Section("图库概览 / Library") {
                        LabeledContent("照片", value: "\(summary.totalPhotos)")
                        LabeledContent("视频", value: "\(summary.totalVideos)")
                        LabeledContent("上次分析", value: AppFormatters.time(summary.generatedAt))
                    }

                    Section("Storage Timeline") {
                        if let insightText = summary.insightText {
                            Text(insightText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(summary.topTimelineMonths) { month in
                            LabeledContent {
                                Text(AppFormatters.fileSize(month.estimatedBytes))
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(month.title)
                                    Text("\(month.itemCount) 项")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        NavigationLink {
                            StorageTimelineView(summary: summary)
                        } label: {
                            Label("查看全部月份", systemImage: "calendar")
                        }
                    }
                }
            }
            .navigationTitle("首页")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ReviewBasketLink()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .alert(item: $viewModel.message) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    @ViewBuilder
    private func destination(for kind: CleanupCategoryKind) -> some View {
        switch kind {
        case .largeVideos:
            LargeVideosView()
        case .screenshots:
            ScreenshotsView()
        case .screenRecordings:
            ScreenRecordingsView()
        case .livePhotos:
            LivePhotosView()
        case .oldMedia:
            OldMediaView()
        case .similarPhotos:
            SimilarPhotosView()
        }
    }
}

private struct StorageOverviewCard: View {
    let summary: ScanSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Storage Overview")
                        .font(.headline)
                    Text("照片图库估算概览")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                OverviewMetric(
                    title: "待整理估算",
                    value: AppFormatters.fileSize(summary?.estimatedCleanableBytes)
                )
                OverviewMetric(
                    title: "图库估算",
                    value: AppFormatters.fileSize(summary?.estimatedLibraryBytes)
                )
            }

            if let generatedAt = summary?.generatedAt {
                Text("上次分析 \(AppFormatters.time(generatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OverviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StorageTimelineView: View {
    let summary: ScanSummary

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Storage Timeline", systemImage: "calendar")
                        .font(.headline)

                    Text("按月份查看照片图库的估算占用。所有统计都来自本机 PhotoKit 元数据，不上传照片。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let insightText = summary.insightText {
                        Label(insightText, systemImage: "lightbulb")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if summary.timelineMonths.isEmpty {
                Section {
                    EmptyStateView(
                        systemImage: "calendar.badge.exclamationmark",
                        title: "暂无时间线数据",
                        message: "完成照片图库分析后，各月份估算占用会显示在这里。"
                    )
                }
            } else {
                Section("月份 / Months") {
                    ForEach(summary.timelineMonths) { month in
                        TimelineMonthRow(
                            month: month,
                            maximumBytes: summary.timelineMonths.first?.estimatedBytes ?? month.estimatedBytes
                        )
                    }
                }
            }
        }
        .navigationTitle("Storage Timeline")
    }
}

private struct TimelineMonthRow: View {
    let month: StorageTimelineMonth
    let maximumBytes: Int64

    private var fillFraction: Double {
        guard maximumBytes > 0 else { return 0 }
        return min(Double(month.estimatedBytes) / Double(maximumBytes), 1)
    }

    private var videoFraction: Double {
        guard month.estimatedBytes > 0 else { return 0 }
        return min(Double(month.estimatedVideoBytes) / Double(month.estimatedBytes), 1)
    }

    private var dominantMediaText: String {
        month.estimatedVideoBytes >= month.estimatedPhotoBytes ? "主要来自视频" : "主要来自照片"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(month.title)
                        .font(.headline)
                    Text("\(month.itemCount) 项 · \(dominantMediaText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(AppFormatters.fileSize(month.estimatedBytes))
                    .font(.headline)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.blue.opacity(0.25))
                        .frame(width: proxy.size.width * fillFraction)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.blue)
                        .frame(width: proxy.size.width * fillFraction * videoFraction)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Label("照片估算 \(AppFormatters.fileSize(month.estimatedPhotoBytes))", systemImage: "photo")
                Label("视频估算 \(AppFormatters.fileSize(month.estimatedVideoBytes))", systemImage: "video")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(month.title)，\(month.itemCount) 项，估算 \(AppFormatters.fileSize(month.estimatedBytes))，\(dominantMediaText)")
    }
}

private extension ScanSummary {
    static var mock: ScanSummary {
        ScanSummary(
            totalPhotos: 0,
            totalVideos: 0,
            screenshotCount: 0,
            screenRecordingCount: 0,
            livePhotoCount: 0,
            largeVideoCount: 0,
            similarGroupCount: 0,
            oldMediaCount: 0,
            estimatedCleanableBytes: 0,
            estimatedLargeVideoBytes: 0,
            estimatedScreenshotBytes: 0,
            estimatedScreenRecordingBytes: 0,
            estimatedLivePhotoBytes: 0,
            estimatedOldMediaBytes: 0,
            estimatedSimilarPhotoBytes: 0,
            timelineMonths: [],
            generatedAt: Date()
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(PhotoLibraryPermissionManager())
        .environmentObject(ReviewBasketStore())
}
