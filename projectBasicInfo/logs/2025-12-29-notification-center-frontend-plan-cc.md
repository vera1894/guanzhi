# 前端推送中台任务规划

**文档版本**: v3 (含调研结果)
**创建日期**: 2025-12-29
**更新日期**: 2025-12-29
**角色**: 前端开发 (Claude Code - iOS)
**状态**: 调研完成，待实施

---

## 一、核心约束（开工前必须明确）

| 约束 | 说明 |
|------|------|
| **登录态绑定** | 设备注册/更新/注销必须在有登录态时执行，未登录时只向 APNs 注册获取 token，不调用后端 |
| **账号切换** | 切换账号时先调用 `/device/logout` 注销旧账号绑定，再用新账号注册 |
| **deviceId 缓存** | 注册成功后保存后端返回的 deviceId 到本地，注销时使用 |
| **冷启动延迟导航** | Deep link 先缓存，等主界面 ready 后再执行跳转 |
| **Badge 临时方案** | 当前先简单清零，标记 TODO 后续与未读通知数对齐 |

---

## 二、阶段 1：基础推送能力

| 任务 | 说明 | 备注 |
|------|------|------|
| **1.1 推送权限申请** | 在合适的业务时机请求权限（如首次评论、打开通知设置页） | 不在启动时立即弹窗 |
| **1.2 Device Token 获取** | 实现 `didRegisterForRemoteNotificationsWithDeviceToken`，本地缓存 token | 未登录时只缓存不上报 |
| **1.3 设备注册 API 对接** | 登录后调用 `POST /device/register`，保存返回的 deviceId | 需先检查登录态 |
| **1.4 Token 刷新处理** | Token 变更时调用 `PUT /device/token`，更新本地缓存 | 需已登录 |
| **1.5 登出注销设备** | 用户登出调用 `DELETE /device/logout?deviceToken={token}` | 使用缓存的 deviceToken |
| **1.6 账号切换处理** | 切换账号时：先注销 → 清除本地缓存 → 新账号注册 | 防止推送错乱 |

---

## 三、阶段 2：通知处理

| 任务 | 说明 | 备注 |
|------|------|------|
| **2.1 前台通知处理** | `willPresent` 回调，显示 Banner/Badge/Sound | - |
| **2.2 后台点击处理** | `didReceive` 回调，解析 deepLink 并导航 | - |
| **2.3 冷启动处理** | `launchOptions` 获取通知，缓存到 `pendingDeepLink` | 延迟到主界面 ready 后执行 |
| **2.4 Badge 同步** | 进入前台时清零 Badge | TODO: 后续改为与未读数 API 联动 |

### 冷启动导航流程

```
App 冷启动 → 保存 deepLink 到 pendingDeepLink
          → 等待主界面初始化完成
          → 检查并执行 pendingDeepLink
          → 清空 pendingDeepLink
```

---

## 四、阶段 3：Deep Link 导航

| 任务 | 说明 | 备注 |
|------|------|------|
| **3.1 URL Scheme 注册** | Info.plist 添加 `guanzhi` scheme | - |
| **3.2 统一 URL 处理中心** | 新 deep link 接入现有 `onOpenURL` / Router 系统 | 不另起分支 |
| **3.3 新增路由 Case** | Router 添加 `.shareComment(shareId, commentId)` | 复用现有导航逻辑 |
| **3.4 分享详情导航** | 跳转到分享页并定位/高亮评论 | - |
| **3.5 异常处理** | 分享/评论不存在时的降级策略 | TODO: 提示"原内容已删除" |

### 异常处理策略

| 场景 | 处理方式 |
|------|---------|
| 分享不存在 | 跳转失败，Toast 提示"内容不存在" |
| 评论已删除 | 正常打开分享，TODO: 顶部提示"原评论已删除" |
| 数据未加载完 | 先导航到分享详情页，页面内部加载数据后再定位评论 |

---

## 五、前置调研结果

### 5.1 调研总览

| 调研项 | 状态 | 关键发现 |
|--------|------|---------|
| 网络层封装 | ✅ 完成 | `OTONetwork.request()` + `OTORequest` 枚举模式 |
| 登录态管理 | ✅ 完成 | `OTOLoginStatusManager` 单例管理 Token 和登录状态 |
| 导航系统 | ✅ 完成 | `NavigationStack` + `Route` 枚举 + `NavigationCoordinator` |
| URL/Deep Link | ✅ 完成 | **目前未实现**，需新增 |
| 本地存储 | ✅ 完成 | `UserDefaults` (Token/UserID) + `SwiftData` (用户信息) |

### 5.2 网络层封装

**核心文件**：
- `/guanzhi/ModelsForNetwork/NetworkService.swift` - OTONetwork 核心请求类
- `/guanzhi/ModelsForNetwork/OTORequests.swift` - API 端点枚举定义

**使用方式**：
```swift
// 1. 在 OTORequests.swift 中添加新的 case
enum OTORequest {
    case registerDevice(deviceToken: String, bundleId: String, deviceId: String?, ...)
}

extension OTORequest {
    var request: OTORequestBaseModel {
        case .registerDevice(let deviceToken, let bundleId, let deviceId, ...):
            return .init(
                path: "/device/register",
                method: .post,
                param: ["deviceToken": deviceToken, "bundleId": bundleId, ...]
            )
    }
}

// 2. 调用方式
let data = try await OTONetwork.request(.registerDevice(...))
let response = try JSONDecoder().decode(OTOResponseModel<T>.self, from: data)
```

**Token 自动注入**：`NetworkService.swift` 会自动从 `OTOLoginStatusManager` 获取 Token 并添加到请求头。

### 5.3 登录态管理

**核心文件**：`/guanzhi/ModelsForNetwork/UserLoginModel.swift`

**关键类**：`OTOLoginStatusManager` (单例)

```swift
// 检查登录状态
if OTOLoginStatusManager.shared.isLoggedIn {
    // 用户已登录
}

// 获取 Token
let token = OTOLoginStatusManager.shared.getToken()

// 获取用户 ID
let userId = OTOLoginStatusManager.shared.getUserID()

// 登出
OTOLoginStatusManager.shared.logout()
```

**登出位置**：`/guanzhi/View/MyPages/SettingView.swift` - 需在此处添加设备注销逻辑

### 5.4 导航系统

**核心文件**：
- `/guanzhi/AppStateModel.swift` - Route 枚举定义 + NavigationCoordinator
- `/guanzhi/guanzhiApp.swift` - NavigationStack 配置

**现有 Route 枚举**：
```swift
enum Route: Hashable, Codable {
    case myView
    case othersView(userId: Int)
    case settingView
    case shareDetailView(annotationID: String)  // ← 可复用
    case editProfileView
    case accountManagementView
}
```

**跳转方式**：
```swift
// 跳转到分享详情
navigationCoordinator.path.append(Route.shareDetailView(annotationID: "\(shareId)"))

// 返回
navigationCoordinator.path.removeLast()
```

**分享详情页**：`/guanzhi/View/SharePages/ShareDetailView.swift`
- 参数：`annotationID: String` (分享 ID)
- 数据加载：`searchViewModel.loadShareDetail(for: shareId)`

### 5.5 URL/Deep Link 处理

**当前状态**：**完全缺失**

**需要添加**：

1. **Info.plist 配置**：
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>guanzhi</string>
        </array>
    </dict>
</array>
```

2. **guanzhiApp.swift 添加 onOpenURL**：
```swift
.onOpenURL { url in
    handleDeepLink(url)
}
```

3. **新增 Route case**：
```swift
case shareComment(shareId: Int64, commentId: Int64)
```

### 5.6 本地存储

**存储方式**：`UserDefaults.standard`

**现有 Key**：
- `loginTokenKey` - 认证 Token
- `"userId"` - 用户 ID

**建议添加**：
```swift
// deviceToken 存储
UserDefaults.standard.set(deviceToken, forKey: "apnsDeviceToken")
UserDefaults.standard.string(forKey: "apnsDeviceToken")
```

---

## 六、实施建议

基于调研结果，建议按以下顺序实施：

| 顺序 | 任务 | 需修改的文件 |
|------|------|-------------|
| 1 | 添加设备注册 API 定义 | `OTORequests.swift` |
| 2 | 创建 DeviceService | 新建 `DeviceService.swift` |
| 3 | 添加 URL Scheme 配置 | `Info.plist` |
| 4 | 添加 onOpenURL 处理 | `guanzhiApp.swift` |
| 5 | 扩展 Route 枚举 | `AppStateModel.swift` |
| 6 | 实现推送通知处理 | `guanzhiApp.swift` 或新建 AppDelegate |
| 7 | 登出时注销设备 | `SettingView.swift` |

---

## 七、关键文件索引

| 文件 | 路径 | 用途 |
|------|------|------|
| **NetworkService.swift** | `/guanzhi/ModelsForNetwork/` | 网络请求核心 |
| **OTORequests.swift** | `/guanzhi/ModelsForNetwork/` | API 端点定义 |
| **UserLoginModel.swift** | `/guanzhi/ModelsForNetwork/` | 登录状态管理 |
| **AppStateModel.swift** | `/guanzhi/` | Route 枚举 + NavigationCoordinator |
| **guanzhiApp.swift** | `/guanzhi/` | App 入口，需添加 onOpenURL |
| **Info.plist** | `/guanzhi/` | 需添加 URL Scheme |
| **ShareDetailView.swift** | `/guanzhi/View/SharePages/` | 分享详情页 |
| **SettingView.swift** | `/guanzhi/View/MyPages/` | 登出逻辑，需添加设备注销 |
| **SearchViewModel.swift** | `/guanzhi/ModelsForMap/` | 分享数据加载 |

---

## 八、任务优先级与 TODO 标记

| 任务 | 优先级 | 状态 |
|------|--------|------|
| 阶段 1 全部任务 | P0 | MVP 必须 |
| 阶段 2.1-2.3 | P0 | MVP 必须 |
| 阶段 2.4 Badge 完整方案 | P1 | TODO - 后续迭代 |
| 阶段 3.1-3.4 | P0 | MVP 必须 |
| 阶段 3.5 异常提示 | P1 | TODO - 后续迭代 |

---

## 九、后端 API 参考

### 设备注册
```
POST /device/register
Authorization: Bearer {token}

Request:
{
    "deviceToken": "APNs设备Token (必填)",
    "deviceId": "设备唯一标识IDFV (可选)",
    "deviceName": "设备名称 (可选)",
    "deviceModel": "设备型号 (可选)",
    "osVersion": "系统版本 (可选)",
    "appVersion": "App版本 (可选)",
    "bundleId": "com.onetto (必填)",
    "environment": "production (可选)"
}
```

### 更新 Token
```
PUT /device/token
Authorization: Bearer {token}

Request:
{
    "oldToken": "旧的设备Token",
    "newToken": "新的设备Token"
}
```

### 设备登出
```
DELETE /device/logout?deviceToken={token}
Authorization: Bearer {token}
```

### Deep Link 格式
```
guanzhi://share/{shareId}/comment/{commentId}
```

### APNs Payload 结构
```json
{
    "aps": {
        "alert": { "title": "观之", "body": "用户名 回复了你: 评论内容..." },
        "badge": 1,
        "sound": "default"
    },
    "deepLink": "guanzhi://share/{shareId}/comment/{commentId}",
    "type": "COMMENT_REPLY"
}
```

---

## 十、产品决策待确认

| 问题 | 选项 | 建议 |
|------|------|------|
| 推送权限弹窗时机 | A. 首次启动 / B. 首次评论 / C. 打开通知设置页 | 建议 B 或 C |

---

**文档结束**

下一步：开始实施前端推送功能。
