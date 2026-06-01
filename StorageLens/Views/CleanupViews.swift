import SwiftUI

struct LargeVideosView: View {
    @StateObject private var viewModel = LargeVideosViewModel()
    @State private var showsDeleteConfirmation = false

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("正在分析大视频...")
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    systemImage: "video.slash",
                    title: "暂未发现大视频",
                    message: "找到超过约 100 MB 或时长较长的视频后会显示在这里。"
                )
            } else {
                ForEach(viewModel.items) { item in
                    MediaAssetRow(
                        item: item,
                        isSelected: viewModel.selectedIDs.contains(item.id),
                        onToggle: { viewModel.toggleSelection(for: item) }
                    )
                }
            }
        }
        .navigationTitle("大视频")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(viewModel.selectedIDs.isEmpty || viewModel.isDeleting)
                .accessibilityLabel("删除所选大视频")
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: viewModel.isDeleting,
                actionTitle: "删除所选"
            ) {
                showsDeleteConfirmation = true
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog("确认删除所选视频？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("删除所选视频", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这些项目会从系统照片图库中删除。请确认你已经选好了要移除的内容。")
        }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct ScreenshotsView: View {
    @StateObject private var viewModel = ScreenshotsViewModel()
    @State private var showsDeleteConfirmation = false

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if viewModel.isLoading && viewModel.groups.isEmpty {
                    ProgressView("正在整理截图...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if viewModel.groups.isEmpty {
                    EmptyStateView(
                        systemImage: "rectangle.on.rectangle.slash",
                        title: "没有可整理的截图",
                        message: "检测到屏幕截图后，会按月份显示在这里。"
                    )
                    .padding(.top, 48)
                } else {
                    ForEach(viewModel.groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.title)
                                        .font(.headline)
                                    Text("\(group.items.count) 张截图")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    viewModel.toggleMonth(group)
                                } label: {
                                    Label("全选", systemImage: "checkmark.circle")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("选择 \(group.title) 的全部截图")
                            }

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(group.items) { item in
                                    MediaGridTile(
                                        item: item,
                                        isSelected: viewModel.selectedIDs.contains(item.id),
                                        isRecommendedKeep: false,
                                        onToggle: { viewModel.toggleSelection(for: item) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("屏幕截图")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(viewModel.selectedIDs.isEmpty || viewModel.isDeleting)
                .accessibilityLabel("删除所选截图")
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: viewModel.isDeleting,
                actionTitle: "删除所选"
            ) {
                showsDeleteConfirmation = true
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog("确认删除所选截图？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("删除所选截图", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除前请确认这些截图不再需要。")
        }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct SimilarPhotosView: View {
    @StateObject private var viewModel = SimilarPhotosViewModel()
    @State private var showsDeleteConfirmation = false

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("按拍摄时间、尺寸和估算文件大小寻找可能相似的照片。StorageLens 只给出线索，最终由你手动选择。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if viewModel.isLoading && viewModel.groups.isEmpty {
                    ProgressView("正在查找相似照片...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if viewModel.groups.isEmpty {
                    EmptyStateView(
                        systemImage: "square.stack.3d.up.slash",
                        title: "暂未发现相似照片",
                        message: "后续可以加入更精确的相似度算法；当前版本不会自动删除任何照片。"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(viewModel.groups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.title)
                                    .font(.headline)
                                Text("\(group.items.count) 张，预计可删 \(AppFormatters.fileSize(group.estimatedDuplicateBytes))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                viewModel.selectLikelyDuplicates(in: group)
                            } label: {
                                Label("选择可删", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.bordered)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(group.items) { item in
                                    MediaGridTile(
                                        item: item,
                                        isSelected: viewModel.selectedIDs.contains(item.id),
                                        isRecommendedKeep: item.id == group.recommendedKeepID,
                                        onToggle: { viewModel.toggleSelection(for: item) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("相似照片")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(viewModel.selectedIDs.isEmpty || viewModel.isDeleting)
                .accessibilityLabel("删除所选相似照片")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if viewModel.selectedRecommendedKeepCount > 0 {
                    Label("已选中建议保留的照片", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }

                SelectionSummaryBar(
                    selectedCount: viewModel.selectedIDs.count,
                    estimatedBytes: viewModel.selectedEstimatedBytes,
                    isWorking: viewModel.isDeleting,
                    actionTitle: "删除所选"
                ) {
                    showsDeleteConfirmation = true
                }
            }
            .background(.bar)
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog("确认删除所选照片？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button(viewModel.selectedRecommendedKeepCount > 0 ? "仍然删除所选照片" : "删除所选照片", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(viewModel.deleteConfirmationMessage)
        }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct OldMediaView: View {
    @StateObject private var viewModel = OldMediaViewModel()
    @State private var showsDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                Picker("时间范围", selection: $viewModel.filter) {
                    ForEach(OldMediaFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                Picker("排序", selection: $viewModel.sort) {
                    ForEach(OldMediaSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            }

            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("正在查找旧媒体...")
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.checkmark",
                    title: "没有符合条件的旧媒体",
                    message: "调整时间范围后可以重新查看。"
                )
            } else {
                Section("结果 / Results") {
                    ForEach(viewModel.items) { item in
                        MediaAssetRow(
                            item: item,
                            isSelected: viewModel.selectedIDs.contains(item.id),
                            onToggle: { viewModel.toggleSelection(for: item) }
                        )
                    }
                }
            }
        }
        .navigationTitle("旧媒体")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(viewModel.selectedIDs.isEmpty || viewModel.isDeleting)
                .accessibilityLabel("删除所选旧媒体")
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: viewModel.isDeleting,
                actionTitle: "删除所选"
            ) {
                showsDeleteConfirmation = true
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onChange(of: viewModel.filter) { _, _ in
            Task { await viewModel.load() }
        }
        .confirmationDialog("确认删除所选旧媒体？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("删除所选旧媒体", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除前请确认这些较早的照片或视频不再需要。")
        }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}
