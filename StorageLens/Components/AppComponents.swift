import Photos
import SwiftUI
import UIKit

struct SummaryMetricCard: View {
    let title: String
    let englishTitle: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(englishTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.bold())
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CleanupCategoryRow: View {
    let category: CleanupCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.headline)
                Text(category.englishTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(category.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(category.itemCount)")
                    .font(.headline)
                if let estimatedBytes = category.estimatedBytes {
                    Text(AppFormatters.fileSize(estimatedBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct MediaAssetRow: View {
    let item: MediaAssetItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                MediaThumbnailView(localIdentifier: item.id, sideLength: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.kind.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(item.kind.englishTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(AppFormatters.fileSize(item.estimatedFileSize))
                        if item.kind == .video {
                            Text(AppFormatters.duration(item.duration))
                        }
                        Text(item.creationDate.map(AppFormatters.date) ?? "日期未知")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }
}

struct MediaGridTile: View {
    let item: MediaAssetItem
    let isSelected: Bool
    let isRecommendedKeep: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topTrailing) {
                MediaThumbnailView(localIdentifier: item.id, sideLength: 112)
                    .aspectRatio(1, contentMode: .fit)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .white)
                    .shadow(radius: 2)
                    .padding(6)

                if isRecommendedKeep {
                    Text("建议保留")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.green, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }
}

struct MediaThumbnailView: View {
    let localIdentifier: String
    let sideLength: CGFloat
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: sideLength, height: sideLength)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: localIdentifier) {
            image = await ThumbnailProvider.thumbnail(
                for: localIdentifier,
                sideLength: sideLength,
                displayScale: displayScale
            )
        }
    }
}

struct SelectionSummaryBar: View {
    let selectedCount: Int
    let estimatedBytes: Int64
    let isWorking: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        if selectedCount > 0 {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已选择 \(selectedCount) 项")
                        .font(.headline)
                    Text("预计 \(AppFormatters.fileSize(estimatedBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: action) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Label(actionTitle, systemImage: "trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
            }
            .padding()
            .background(.bar)
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

private enum ThumbnailProvider {
    static func thumbnail(for localIdentifier: String, sideLength: CGFloat, displayScale: CGFloat) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let targetSize = CGSize(width: sideLength * displayScale, height: sideLength * displayScale)
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}
