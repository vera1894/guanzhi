# 2026-02-22~23 多语言支持（中英文 i18n）实施记录

## 背景
观之 app 所有 UI 文案均为硬编码中文，需要添加英语支持，使 app 根据设备语言自动切换中英文。核心映射：「观之」→「siiimo」。

## 方案
使用 Xcode 15+ String Catalog（`.xcstrings`），单个 JSON 文件包含中英文翻译，`sourceLanguage: "zh-Hans"`。

## 新建文件（4 个）

| 文件 | 说明 |
|------|------|
| `Localization/Localizable.xcstrings` | 主翻译目录，~350 条字符串，310+ 有英文翻译 |
| `Localization/InfoPlist.xcstrings` | App 名称（观之/siiimo）+ 权限说明 |
| `Localization/UserAgreement_en.txt` | 英文用户协议 |
| `View/UIElement/NotificationStyles/ToastMessages.swift` | Toast 通知消息集中管理（17 条） |

## 实施轮次

### Round 1（02-22）：基础 i18n 框架
- 新建 3 个 Localization 文件
- 修改 ~25 个 Swift 文件（navigationTitle、String(localized:)、placeholder 等）
- 初始 ~130 条 xcstrings 条目

### Round 2（02-22）：补充遗漏字符串
- 用户测试发现大量字符串仍为中文
- 新增 ~170 条 xcstrings 条目

### Round 3（02-22）：修复缺失翻译
- 71 个 key 缺少英文翻译 + 15 条遗漏字符串

### Round 4（02-22）：服务端中文数据本地化
- 贴纸名称：客户端 `StickerKind.displayName` 用 `String(localized:)` + locale 条件映射
- 通知内容：`NotificationModels` 新增 `localizedContent` / `localizedTitle`
- 通知事件名：`eventNameMapping` 字典（eventCode → 本地化名称）

### Round 5（02-23）：贴纸名称系统修复
- **根因**：`StickerDefinition.dynamicDisplayName` 缺少 locale 检查，始终调用 `StickerNameService`（返回中文）
- **修复**：添加 `Locale.current.language.languageCode?.identifier == "zh"` 检查
- 修复 `StickerSummaryBar`、`StickerSummaryOverlay`、`StickerPage` 中的硬编码中文
- 通知贴纸名称提取：`extractLocalizedStickerName(from:)` + `stickerChineseNames` 字典

### Round 6（02-23）：通知设置 + 地址本地化
- 修复 `eventNameMapping` 遗漏 `"SYSTEM"` 键
- `AddressLocalizer` 扩展支持 `(shareId, latitude, longitude)` 参数
- `ShareSingleView` 集成 AddressLocalizer，所有列表视图自动生效

### Round 7（02-23）：Toast/Banner 审计
- 审计全部 Toast 通知和 Onboarding 内容
- 修复 3 处 Toast 缺少 `String(localized:)` 包装

### Round 8（02-23）：Toast 消息集中管理
- **新建 `ToastMessages.swift`**：17 条消息按功能分 5 区（资料编辑/用户信息/评论/分享操作/系统）
- **更新 11 个文件调用点**：`toastManager.show(ToastMessages.xxx)` 替代内联构造
- **删除 6 个文件的 `showNotification(message:)` 辅助方法**
- **附带修复**：`ShareDetailsCardView` 的 `"分享链接已复制"` 从硬编码中文改为 `String(localized:)`

## 修改文件完整清单

### 自动本地化无需改代码的（仅需在 xcstrings 中添加翻译）
- `LocationPickerSheet.swift`、`MessageView.swift`、`OnboardingBannerView.swift`、`LiveBadge.swift`

### navigationBarTitle → navigationTitle（7 处）
- `SettingView.swift`、`AccountManagementView.swift`、`MyView.swift`、`NetworkDiagnosticView.swift`、`MessagesView.swift`、`EditProfileView.swift`

### String(localized:) 包装（~50+ 处）
- `NetworkService.swift`、`StickerAvailability.swift`、`InputValidator.swift`、`CommentViewModel.swift`、`UserLoginModel.swift`、`UserProfileManager.swift`、`AppVersionManager.swift`、`LocationService.swift`、`StickerKind.swift`、`OnboardingCoordinator.swift`

### 服务端数据本地化
- `StickerDefinition.swift` — `dynamicDisplayName` 添加 locale 检查
- `NotificationModels.swift` — `localizedTitle`、`localizedContent`、`extractLocalizedStickerName`、`eventNameMapping`（含 SYSTEM）
- `MessageRowView.swift` — 使用 `message.localizedTitle`
- `MessagesView.swift` — 使用 `message.localizedTitle` / `message.localizedContent`
- `AddressLocalizer.swift` — 扩展支持坐标参数 + 中文 locale 跳过
- `ShareSingleView.swift` — 集成 AddressLocalizer

### Toast 集中管理
- **新建** `ToastMessages.swift`
- **更新** `EditNameView.swift`、`EditOneCodeView.swift`、`EditAvatarView.swift`、`MyView.swift`、`OthersView.swift`、`AccountManagementView.swift`、`CommentCellView.swift`、`ShareDetailsCardView.swift`、`SearchView.swift`、`SettingView.swift`、`guanzhiApp.swift`

### 其他
- `StickerSummaryBar.swift`、`StickerSummaryOverlay.swift`、`StickerPage.swift` — 贴纸 UI 文案
- `SheetView.swift`、`MainToolbar.swift`、`LogInView.swift`、`NameView.swift` — placeholder
- `Info.plist` — CFBundleDisplayName

## 关键技术要点

### 自动 vs 手动本地化
- SwiftUI `Text("字面量")` 自动本地化，`Text(变量)` 不自动 → 需 `Text(LocalizedStringKey(变量))`
- `LocalizedError.errorDescription` 返回 `String?`，不自动 → 需 `String(localized:)`
- `.navigationBarTitle()` 不自动，`.navigationTitle()` 自动
- 自定义 UIKit TextField placeholder 不自动 → 传参时 `String(localized:)`

### 服务端中文数据处理模式
- Locale 检测：`Locale.current.language.languageCode?.identifier == "zh"`
- 中文环境：使用服务端原始数据（`StickerNameService`、原始 address）
- 非中文环境：使用客户端本地化数据（`StickerKind.displayName`、`AddressLocalizer`）
- 通知内容：解析服务端中文 `content` 中的「」括号提取贴纸名 → 匹配 `stickerChineseNames` 字典 → 替换为本地化名称

## 不处理的项
- POI 搜索关键词（功能性搜索词）
- 后端 respMsg（客户端使用本地化通用错误提示）
- Debug 日志中的中文
- 代码注释

## 最终状态
- Localizable.xcstrings：~350 条 key，310+ 有英文翻译（88%+ 覆盖率）
- ToastMessages.swift：17 条集中管理的 Toast 消息
- 用户需将 `Localization/` 文件夹和 `ToastMessages.swift` 拖入 Xcode 项目导航器
