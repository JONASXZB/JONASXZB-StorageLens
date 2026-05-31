import SwiftUI

struct PermissionView: View {
    @EnvironmentObject private var permissionManager: PhotoLibraryPermissionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Image("StorageLensMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("允许访问照片")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)

                    Text("StorageLens 只分析你授权的照片图库，所有处理都在本机完成。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    PermissionPointRow(
                        systemImage: "iphone",
                        title: "本机分析",
                        detail: "照片只在你的 iPhone 上分析。",
                        englishDetail: "Photos are analyzed on device."
                    )
                    PermissionPointRow(
                        systemImage: "icloud.slash",
                        title: "不会上传照片",
                        detail: "不会把照片上传到服务器。",
                        englishDetail: "Photos are not uploaded."
                    )
                    PermissionPointRow(
                        systemImage: "checkmark.circle",
                        title: "由你决定删除内容",
                        detail: "删除前始终由你手动选择并确认。",
                        englishDetail: "You choose what to delete."
                    )
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if permissionManager.status == .limited {
                    Label("当前是部分访问模式，可在系统设置中调整可见照片。", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                }

                VStack(spacing: 12) {
                    Button {
                        Task { await permissionManager.requestAccess() }
                    } label: {
                        Label("请求照片访问权限", systemImage: "lock.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel("请求照片访问权限")

                    if permissionManager.status == .denied || permissionManager.status == .restricted {
                        Button {
                            permissionManager.openAppSettings()
                        } label: {
                            Label("打开系统设置", systemImage: "gearshape")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityLabel("打开系统设置")
                    }

                    Text("当前状态：\(permissionManager.statusTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("照片权限")
        }
    }
}

private struct PermissionPointRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let englishDetail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(englishDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PermissionView()
        .environmentObject(PhotoLibraryPermissionManager())
}
