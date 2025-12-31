# 通知偏好设置 iOS 前端计划

**日期**: 2025-12-30
**状态**: 待实施
**依赖**: 通知中台 V1.5 后端 API

---

## 一、概述

基于后端 V1.5 新增的用户通知偏好 API，在 iOS 客户端设置页面新增「通知设置」功能，允许用户：
- 全局开关推送通知
- 按事件类型开关推送和站内通知

---

## 二、后端 API

### GET /api/notifications/preferences

获取用户通知偏好设置。

**响应**：
```json
{
  "respCode": 0,
  "datas": {
    "globalPushEnabled": true,
    "preferences": [
      {
        "eventCode": "comment_reply",
        "eventName": "评论回复",
        "eventGroup": "interaction",
        "pushEnabled": true,
        "inAppEnabled": true
      },
      {
        "eventCode": "comment_like",
        "eventName": "评论点赞",
        "eventGroup": "interaction",
        "pushEnabled": true,
        "inAppEnabled": true
      },
      {
        "eventCode": "new_comment",
        "eventName": "新评论",
        "eventGroup": "interaction",
        "pushEnabled": true,
        "inAppEnabled": true
      },
      {
        "eventCode": "sticker_received",
        "eventName": "收到贴纸",
        "eventGroup": "interaction",
        "pushEnabled": true,
        "inAppEnabled": true
      },
      {
        "eventCode": "system",
        "eventName": "系统通知",
        "eventGroup": "system",
        "pushEnabled": true,
        "inAppEnabled": true
      }
    ]
  }
}
```

### PUT /api/notifications/preferences

更新用户通知偏好设置。

**请求**：
```json
{
  "globalPushEnabled": true,
  "preferences": [
    {
      "eventCode": "comment_reply",
      "pushEnabled": false,
      "inAppEnabled": true
    }
  ]
}
```

**响应**：
```json
{
  "respCode": 0,
  "respMsg": "success"
}
```

---

## 三、UI 设计

### 入口位置

设置页面（SettingView.swift）新增「通知设置」行：

```
┌─────────────────────────────────┐
│  设置                           │
├─────────────────────────────────┤
│  账号管理                    >  │
│  通知设置                    >  │  ← 新增
│  清除缓存                       │
│  退出登录                       │
└─────────────────────────────────┘
```

### 通知设置页面布局

```
┌─────────────────────────────────┐
│  ←  通知设置                    │
├─────────────────────────────────┤
│                                 │
│  推送通知                       │
│  ┌─────────────────────────────┐│
│  │ 接收推送通知         🔘 ON  ││  ← 全局开关
│  └─────────────────────────────┘│
│                                 │
│  互动消息                       │  ← Section Header
│  ┌─────────────────────────────┐│
│  │ 评论回复             🔘 ON  ││
│  │ 评论点赞             🔘 ON  ││
│  │ 新评论               🔘 ON  ││
│  │ 收到贴纸             🔘 ON  ││
│  └─────────────────────────────┘│
│                                 │
│  系统消息                       │  ← Section Header
│  ┌─────────────────────────────┐│
│  │ 系统通知             🔘 ON  ││
│  └─────────────────────────────┘│
│                                 │
│  ⓘ 关闭推送后，您仍可在消息页   │
│    查看站内通知                 │
│                                 │
└─────────────────────────────────┘
```

### 交互规则

1. **全局开关**：关闭后，所有事件开关变为禁用状态（灰色）
2. **事件开关**：仅控制推送通知，站内通知始终开启
3. **实时保存**：切换开关后立即调用 API 保存
4. **加载状态**：首次进入显示加载指示器
5. **错误处理**：保存失败时 Toast 提示，开关回滚

---

## 四、数据模型

### NotificationPreference

```swift
/// 单个事件的通知偏好
struct NotificationEventPreference: Codable, Identifiable {
    let eventCode: String
    let eventName: String
    let eventGroup: String
    var pushEnabled: Bool
    var inAppEnabled: Bool

    var id: String { eventCode }
}
```

### NotificationPreferencesResponse

```swift
/// 偏好设置响应
struct NotificationPreferencesData: Codable {
    let globalPushEnabled: Bool
    let preferences: [NotificationEventPreference]
}

struct NotificationPreferencesResponse: Codable {
    let respCode: Int
    let respMsg: String?
    let datas: NotificationPreferencesData?
}
```

### NotificationPreferencesUpdateRequest

```swift
/// 偏好设置更新请求
struct PreferenceUpdate: Codable {
    let eventCode: String
    let pushEnabled: Bool
    let inAppEnabled: Bool
}

struct NotificationPreferencesUpdateRequest: Codable {
    let globalPushEnabled: Bool?
    let preferences: [PreferenceUpdate]?
}
```

---

## 五、文件结构

```
guanzhi/View/MyPages/
├── SettingView.swift                    # 修改：新增通知设置入口
└── NotificationSettingsView.swift       # 新增：通知设置页面

guanzhi/ModelsForNetwork/
├── NotificationModels.swift             # 修改：新增偏好相关模型
└── NotificationService.swift            # 修改：新增偏好 API 方法
```

---

## 六、API 对接

### NotificationService 扩展

```swift
extension NotificationService {
    /// 获取用户通知偏好
    func getPreferences() async throws -> NotificationPreferencesData {
        let response: NotificationPreferencesResponse = try await NetworkService.shared.request(
            OTORequest.getNotificationPreferences.request
        )
        guard response.respCode == 0, let data = response.datas else {
            throw NetworkError.serverError(response.respMsg ?? "获取通知偏好失败")
        }
        return data
    }

    /// 更新全局推送开关
    func updateGlobalPushEnabled(_ enabled: Bool) async throws {
        let request = NotificationPreferencesUpdateRequest(
            globalPushEnabled: enabled,
            preferences: nil
        )
        let response: NotificationActionResponse = try await NetworkService.shared.request(
            OTORequest.updateNotificationPreferences(request).request
        )
        guard response.respCode == 0 else {
            throw NetworkError.serverError(response.respMsg ?? "更新失败")
        }
    }

    /// 更新单个事件偏好
    func updateEventPreference(eventCode: String, pushEnabled: Bool) async throws {
        let request = NotificationPreferencesUpdateRequest(
            globalPushEnabled: nil,
            preferences: [
                PreferenceUpdate(eventCode: eventCode, pushEnabled: pushEnabled, inAppEnabled: true)
            ]
        )
        let response: NotificationActionResponse = try await NetworkService.shared.request(
            OTORequest.updateNotificationPreferences(request).request
        )
        guard response.respCode == 0 else {
            throw NetworkError.serverError(response.respMsg ?? "更新失败")
        }
    }
}
```

### OTORequest 扩展

```swift
enum OTORequest {
    // ... 现有 case

    /// 获取通知偏好
    case getNotificationPreferences

    /// 更新通知偏好
    case updateNotificationPreferences(NotificationPreferencesUpdateRequest)
}

extension OTORequest {
    var request: OTORequestBaseModel {
        switch self {
        // ... 现有 case

        case .getNotificationPreferences:
            return .init(path: "/notifications/preferences", method: .get, param: [:])

        case .updateNotificationPreferences(let body):
            return .init(path: "/notifications/preferences", method: .put, param: body.toDictionary())
        }
    }
}
```

---

## 七、ViewModel 设计

```swift
@MainActor
class NotificationSettingsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var globalPushEnabled = true
    @Published var preferences: [NotificationEventPreference] = []
    @Published var errorMessage: String?

    /// 按分组获取偏好
    var interactionPreferences: [NotificationEventPreference] {
        preferences.filter { $0.eventGroup == "interaction" }
    }

    var systemPreferences: [NotificationEventPreference] {
        preferences.filter { $0.eventGroup == "system" }
    }

    /// 加载偏好设置
    func loadPreferences() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await NotificationService.shared.getPreferences()
            globalPushEnabled = data.globalPushEnabled
            preferences = data.preferences
        } catch {
            errorMessage = "加载失败，请重试"
        }
    }

    /// 切换全局开关
    func toggleGlobalPush(_ enabled: Bool) async {
        let oldValue = globalPushEnabled
        globalPushEnabled = enabled  // 乐观更新

        do {
            try await NotificationService.shared.updateGlobalPushEnabled(enabled)
        } catch {
            globalPushEnabled = oldValue  // 回滚
            errorMessage = "保存失败"
        }
    }

    /// 切换事件开关
    func toggleEventPush(eventCode: String, enabled: Bool) async {
        guard let index = preferences.firstIndex(where: { $0.eventCode == eventCode }) else { return }

        let oldValue = preferences[index].pushEnabled
        preferences[index].pushEnabled = enabled  // 乐观更新

        do {
            try await NotificationService.shared.updateEventPreference(
                eventCode: eventCode,
                pushEnabled: enabled
            )
        } catch {
            preferences[index].pushEnabled = oldValue  // 回滚
            errorMessage = "保存失败"
        }
    }
}
```

---

## 八、视图实现

### NotificationSettingsView

```swift
struct NotificationSettingsView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        List {
            // 全局开关
            Section {
                Toggle("接收推送通知", isOn: $viewModel.globalPushEnabled)
                    .onChange(of: viewModel.globalPushEnabled) { _, newValue in
                        Task { await viewModel.toggleGlobalPush(newValue) }
                    }
            }

            // 互动消息
            Section("互动消息") {
                ForEach(viewModel.interactionPreferences) { pref in
                    eventToggleRow(pref)
                }
            }
            .disabled(!viewModel.globalPushEnabled)

            // 系统消息
            Section("系统消息") {
                ForEach(viewModel.systemPreferences) { pref in
                    eventToggleRow(pref)
                }
            }
            .disabled(!viewModel.globalPushEnabled)

            // 说明
            Section {
                Text("关闭推送后，您仍可在消息页查看站内通知")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    navigationCoordinator.path.removeLast()
                } label: {
                    Image("icon-back")
                }
                .buttonStyle(ButtonStyle_m())
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadPreferences()
        }
    }

    @ViewBuilder
    private func eventToggleRow(_ pref: NotificationEventPreference) -> some View {
        Toggle(pref.eventName, isOn: Binding(
            get: { pref.pushEnabled },
            set: { newValue in
                Task { await viewModel.toggleEventPush(eventCode: pref.eventCode, enabled: newValue) }
            }
        ))
    }
}
```

---

## 九、路由集成

### Route 枚举

```swift
enum Route: Hashable, Codable {
    // ... 现有 case
    case notificationSettingsView  // 通知设置
}
```

### guanzhiApp.swift

```swift
case .notificationSettingsView:
    NotificationSettingsView()
        .environmentObject(navigationCoordinator)
```

### SettingView.swift

```swift
// 在账号管理下方添加
Button {
    navigationCoordinator.path.append(Route.notificationSettingsView)
} label: {
    HStack {
        Text("通知设置")
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundColor(.gray)
    }
}
```

---

## 十、实施步骤

| 步骤 | 内容 | 预计改动 |
|------|------|----------|
| 1 | 新增数据模型（NotificationModels.swift） | 约 30 行 |
| 2 | 扩展 NotificationService（API 方法） | 约 40 行 |
| 3 | 扩展 OTORequest（新 case） | 约 10 行 |
| 4 | 新增 Route.notificationSettingsView | 约 5 行 |
| 5 | 新增 NotificationSettingsView.swift | 约 120 行 |
| 6 | 修改 SettingView.swift（添加入口） | 约 15 行 |
| 7 | 修改 guanzhiApp.swift（添加导航目标） | 约 5 行 |
| 8 | 编译测试 | - |

**总计新增/修改**：约 225 行代码

---

## 十一、测试要点

- [ ] 首次进入加载偏好设置
- [ ] 全局开关切换，子开关禁用状态正确
- [ ] 单个事件开关切换，API 调用成功
- [ ] 网络错误时开关回滚
- [ ] 导航栏返回按钮样式正确
- [ ] 页面滚动流畅

---

**文档结束**

下一步：确认后开始实施。
