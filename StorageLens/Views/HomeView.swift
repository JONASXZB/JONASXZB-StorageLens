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
                    SummaryMetricCard(
                        title: "已估算可清理空间",
                        englishTitle: "Estimated cleanable space",
                        value: AppFormatters.fileSize(viewModel.summary?.estimatedCleanableBytes),
                        systemImage: "internaldrive"
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
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

                Section {
                    Label {
                        Text("所有分析都在本机完成。照片不会上传。")
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let summary = viewModel.summary {
                    Section("图库概览 / Library") {
                        LabeledContent("照片", value: "\(summary.totalPhotos)")
                        LabeledContent("视频", value: "\(summary.totalVideos)")
                        LabeledContent("上次分析", value: AppFormatters.time(summary.generatedAt))
                    }
                }
            }
            .navigationTitle("首页")
            .toolbar {
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
        case .similarPhotos:
            SimilarPhotosView()
        case .oldMedia:
            OldMediaView()
        }
    }
}

private extension ScanSummary {
    static var mock: ScanSummary {
        ScanSummary(
            totalPhotos: 0,
            totalVideos: 0,
            screenshotCount: 0,
            largeVideoCount: 0,
            similarGroupCount: 0,
            oldMediaCount: 0,
            estimatedLargeVideoBytes: 0,
            estimatedScreenshotBytes: 0,
            generatedAt: Date()
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(PhotoLibraryPermissionManager())
}
