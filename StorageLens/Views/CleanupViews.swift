import SwiftUI

struct LargeVideosView: View {
    @StateObject private var viewModel = LargeVideosViewModel()
    @EnvironmentObject private var reviewBasket: ReviewBasketStore

    var body: some View {
        List {
            Section {
                Picker("排序", selection: $viewModel.sort) {
                    ForEach(MediaSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            }

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
                ReviewBasketLink()
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: false,
                actionTitle: "加入篮子"
            ) {
                reviewBasket.add(viewModel.selectedItems, from: .largeVideos)
                viewModel.selectedIDs.removeAll()
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct ScreenshotsView: View {
    @StateObject private var viewModel = ScreenshotsViewModel()
    @EnvironmentObject private var reviewBasket: ReviewBasketStore

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                Picker("时间范围", selection: $viewModel.filter) {
                    ForEach(ScreenshotAgeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

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
                ReviewBasketLink()
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: false,
                actionTitle: "加入篮子"
            ) {
                reviewBasket.add(viewModel.selectedItems, from: .screenshots)
                viewModel.selectedIDs.removeAll()
            }
        }
        .task(id: viewModel.filter) {
            await viewModel.load()
        }
        .refreshable { await viewModel.load() }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct ScreenRecordingsView: View {
    @StateObject private var viewModel = ScreenRecordingsViewModel()
    @EnvironmentObject private var reviewBasket: ReviewBasketStore

    var body: some View {
        List {
            Section {
                Text("这里显示可能的屏幕录制视频。识别基于本机尺寸和时长线索，可能并不完全准确。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("排序", selection: $viewModel.sort) {
                    ForEach(MediaSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            }

            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("正在查找屏幕录制...")
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    systemImage: "record.circle",
                    title: "暂未发现可能的屏幕录制",
                    message: "检测结果会以谨慎方式显示，你始终手动决定是否加入篮子。"
                )
            } else {
                Section("可能的屏幕录制 / Possible") {
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
        .navigationTitle("屏幕录制")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReviewBasketLink()
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: false,
                actionTitle: "加入篮子"
            ) {
                reviewBasket.add(viewModel.selectedItems, from: .screenRecordings)
                viewModel.selectedIDs.removeAll()
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct LivePhotosView: View {
    @StateObject private var viewModel = LivePhotosViewModel()
    @EnvironmentObject private var reviewBasket: ReviewBasketStore

    var body: some View {
        List {
            Section {
                Text("StorageLens 只帮助你查看和选择 Live Photos，不会转换、压缩或修改它们。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("正在查找 Live Photos...")
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    systemImage: "livephoto.slash",
                    title: "暂未发现 Live Photos",
                    message: "发现 Live Photos 后会显示在这里。"
                )
            } else {
                Section("Live Photos") {
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
        .navigationTitle("Live Photos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReviewBasketLink()
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: false,
                actionTitle: "加入篮子"
            ) {
                reviewBasket.add(viewModel.selectedItems, from: .livePhotos)
                viewModel.selectedIDs.removeAll()
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct SimilarPhotosView: View {
    @StateObject private var viewModel = SimilarPhotosViewModel()
    @EnvironmentObject private var reviewBasket: ReviewBasketStore

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
                                Text("\(group.items.count) 张，保留建议外估算 \(AppFormatters.fileSize(group.estimatedDuplicateBytes))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                viewModel.selectLikelyDuplicates(in: group)
                            } label: {
                                Label("选择建议项", systemImage: "checkmark.circle")
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
                ReviewBasketLink()
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
                    isWorking: false,
                    actionTitle: "加入篮子"
                ) {
                    reviewBasket.add(viewModel.selectedItems, from: .similarPhotos)
                    viewModel.selectedIDs.removeAll()
                }
            }
            .background(.bar)
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct ReviewBasketView: View {
    @EnvironmentObject private var reviewBasket: ReviewBasketStore
    @State private var showsDeleteConfirmation = false
    @State private var showsClearConfirmation = false

    var body: some View {
        List {
            if reviewBasket.items.isEmpty {
                EmptyStateView(
                    systemImage: "basket",
                    title: "篮子是空的",
                    message: "在各分类中选择项目并加入篮子后，再到这里统一确认删除。"
                )
            } else {
                Section("汇总 / Summary") {
                    LabeledContent("项目", value: "\(reviewBasket.itemCount)")
                    LabeledContent("估算大小", value: AppFormatters.fileSize(reviewBasket.estimatedBytes))
                    LabeledContent("包含分类", value: reviewBasket.includedCategoryTitles)
                }

                Section("待确认项目 / Review") {
                    ForEach(reviewBasket.items) { basketItem in
                        HStack(spacing: 12) {
                            MediaThumbnailView(localIdentifier: basketItem.item.id, sideLength: 56)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(basketItem.item.kind.title)
                                    .font(.headline)
                                Text("\(basketItem.categoryKind.title) · 估算 \(AppFormatters.fileSize(basketItem.item.estimatedFileSize))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(basketItem.item.creationDate.map(AppFormatters.date) ?? "日期未知")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                reviewBasket.remove(basketItem)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("从篮子移除")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Review Basket")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !reviewBasket.items.isEmpty {
                    Button("清空", role: .destructive) {
                        showsClearConfirmation = true
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !reviewBasket.items.isEmpty {
                SelectionSummaryBar(
                    selectedCount: reviewBasket.itemCount,
                    estimatedBytes: reviewBasket.estimatedBytes,
                    isWorking: reviewBasket.isDeleting,
                    actionTitle: "确认删除",
                    actionSystemImage: "trash"
                ) {
                    showsDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog("确认删除篮子中的项目？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("删除篮子中的项目", role: .destructive) {
                Task { await reviewBasket.deleteAll() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这些项目会从系统照片图库中删除。StorageLens 不会自动删除任何内容，只有你在这里确认后才会执行。")
        }
        .confirmationDialog("清空 Review Basket？", isPresented: $showsClearConfirmation, titleVisibility: .visible) {
            Button("清空篮子", role: .destructive) {
                reviewBasket.clear()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这只会移除待确认列表，不会删除照片图库中的任何项目。")
        }
        .sheet(item: $reviewBasket.cleanupResult) { result in
            CleanupResultView(result: result)
        }
        .alert(item: $reviewBasket.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}

struct CleanupResultView: View {
    let result: CleanupResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("删除完成")
                            .font(.title2.bold())
                        Text("已删除 \(result.deletedCount) 个项目，估算释放 \(AppFormatters.fileSize(result.estimatedBytes))。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                Section {
                    Text("已删除项目会进入系统照片的“最近删除”。如果需要恢复，请前往照片 App 查看。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("结果")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReviewBasketLink: View {
    @EnvironmentObject private var reviewBasket: ReviewBasketStore

    var body: some View {
        NavigationLink {
            ReviewBasketView()
        } label: {
            Label("Review Basket", systemImage: reviewBasket.itemCount > 0 ? "basket.fill" : "basket")
        }
        .accessibilityLabel("Review Basket，\(reviewBasket.itemCount) 项")
    }
}

struct OldMediaView: View {
    @StateObject private var viewModel = OldMediaViewModel()
    @EnvironmentObject private var reviewBasket: ReviewBasketStore

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
                ReviewBasketLink()
            }
        }
        .safeAreaInset(edge: .bottom) {
            SelectionSummaryBar(
                selectedCount: viewModel.selectedIDs.count,
                estimatedBytes: viewModel.selectedEstimatedBytes,
                isWorking: false,
                actionTitle: "加入篮子"
            ) {
                reviewBasket.add(viewModel.selectedItems, from: .oldMedia)
                viewModel.selectedIDs.removeAll()
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onChange(of: viewModel.filter) { _, _ in
            Task { await viewModel.load() }
        }
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("好")))
        }
    }
}
