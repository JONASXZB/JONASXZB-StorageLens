# StorageLens

StorageLens 是一个原生 iPhone 应用，用来帮助用户查看照片图库中可能占用较多空间的内容，并手动选择要删除的项目。界面以中文为主，关键术语保留少量英文辅助。

## 语言原则

- 全程以中文为主显示。
- 英文只作为品牌名、技术名词或辅助说明出现。
- 用户关键操作、权限说明、删除确认和错误提示必须优先使用中文。
- 不提供独立英文本地化，避免英文系统环境下覆盖中文主界面。
- 代码中的主语言配置集中在 `StorageLens/Utilities/AppLanguage.swift`。

## 它能做什么

- 分析用户已授权的照片图库。
- 找出大视频、屏幕截图、旧媒体和可能相似的照片。
- 按月份整理截图，支持多选和删除确认。
- 删除前始终要求用户明确确认。

## 它不能做什么

- 不清理 iOS 系统数据。
- 不清理其他 App 的缓存。
- 不声称“清理系统垃圾”“加速 iPhone”或“删除隐藏缓存”。
- 不会自动删除照片或视频。

## 隐私模型

所有分析都在本机完成。你的照片不会上传。

All analysis happens on device. Your photos are not uploaded.

所有分析都在本机完成，没有后端、登录、广告 SDK 或分析 SDK。应用只处理用户通过系统权限授权的照片图库内容。

## 技术栈

- Swift
- SwiftUI
- PhotoKit
- MVVM
- iOS 17+

## 构建说明

1. 使用完整 Xcode 打开 `StorageLens.xcodeproj`。
2. 选择 iPhone 模拟器或真机。
3. 运行 `StorageLens` target。

当前机器的开发者目录如果指向 Command Line Tools，需要先安装并选择完整 Xcode：

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
