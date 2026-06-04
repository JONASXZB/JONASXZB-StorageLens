import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var permissionManager: PhotoLibraryPermissionManager

    var body: some View {
        List {
            Section("权限 / Permissions") {
                LabeledContent("照片访问", value: permissionManager.statusTitle)

                if permissionManager.status == .limited {
                    Button {
                        permissionManager.presentLimitedLibraryPicker()
                    } label: {
                        Label("选择更多照片", systemImage: "photo.stack")
                    }
                }

                Button {
                    permissionManager.openAppSettings()
                } label: {
                    Label("打开系统设置", systemImage: "gearshape")
                }
            }

            Section("语言 / Language") {
                LabeledContent("主语言", value: AppLanguage.primaryLanguageName)
                LabeledContent("辅助说明", value: AppLanguage.auxiliaryLanguageName)
            }

            Section("隐私 / Privacy") {
                NavigationLink {
                    PrivacyView()
                } label: {
                    Label("隐私说明", systemImage: "lock.shield")
                }
            }

            Section("关于 / About") {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("关于 StorageLens", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("设置")
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("所有分析都在本机完成。", systemImage: "iphone")
                    Label("照片不会上传到服务器。", systemImage: "icloud.slash")
                    Label("删除前始终需要你确认。", systemImage: "hand.tap")
                }
                .font(.body)
            }

            Section("英文辅助 / English") {
                Text("所有分析都在本机完成。你的照片不会上传。\nAll analysis happens on device. Your photos are not uploaded.")
                    .foregroundStyle(.secondary)
            }

            Section("边界 / Boundaries") {
                Text("StorageLens 只分析你授权的照片图库，不处理 iOS 系统数据，也不会读取其他 App 的缓存。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("隐私说明")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack(alignment: .center, spacing: 14) {
                    Image("StorageLensMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("StorageLens")
                            .font(.title2.bold())
                        Text("一个帮助你查看照片图库占用空间的本机 iPhone 应用。")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("技术 / Stack") {
                LabeledContent("界面", value: "SwiftUI")
                LabeledContent("照片访问", value: "PhotoKit")
                LabeledContent("最低系统", value: "iOS 17+")
                LabeledContent("网络服务", value: "无")
            }

            Section("不会做的事 / Cannot Do") {
                Text("不会处理 iOS 系统数据，不会读取其他 App 的缓存，也不会自动删除照片。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(PhotoLibraryPermissionManager())
    }
}
