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
                        Text("私密释放空间 / Free up space, privately.")
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

                Section("清理建议 / Cleanup") {
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
                    title: "可清理",
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
