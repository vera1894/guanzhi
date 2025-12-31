# 推送通知功能实现与修复记录

**日期**: 2025-12-30
**状态**: 已完成

---

## 概述

实现 iOS 原生 APNs 推送通知功能，并修复了过程中发现的多个问题。

---

## 一、已解决的问题

### 1. DeviceApiResponse JSON 解码类型不匹配

**问题描述**：
设备注册 API 返回的 `datas` 字段是数字类型（如 `1`），但客户端使用 `String?` 解码，导致 `typeMismatch` 错误。

**错误日志**：
```
typeMismatch(Swift.String, ... debugDescription: "Expected to decode String but found number instead.")
```

**修复文件**：`guanzhi/ModelsForNetwork/DeviceService.swift`

**修复方法**：
将所有 `DeviceApiResponse<String?>` 改为 `DeviceApiResponse<Int?>`：
```swift
// 修改前
let response = try decoder.decode(DeviceApiResponse<String?>.self, from: data)

// 修改后
let response = try decoder.decode(DeviceApiResponse<Int?>.self, from: data)
```

**涉及函数**：
- `registerDevice(deviceToken:)`
- `updateDeviceToken(oldToken:newToken:)`
- `logoutDevice()`

---

### 2. App 重启后 userId = 0 问题

**问题描述**：
用户登录后，Token 被持久化到 UserDefaults，但 userId 在异步获取用户信息完成前页面已跳转，导致 userId 未保存。App 重启后显示已登录状态，但 userId 为 0。

**修复文件**：`guanzhi/View/FrontPages/SearchView.swift`

**修复方法**：
在 `.onAppear` 中添加 userId 恢复逻辑：
```swift
.onAppear {
    Task {
        var myUserId = OTOLoginStatusManager.shared.getUserID()

        // 如果已登录但 userId 为 0，从后端获取
        if myUserId == 0 && OTOLoginStatusManager.shared.isLoggedIn {
            print("⚠️ SearchView: userId 为 0，尝试从后端获取...")
            myUserId = try await fetchAndSaveCurrentUserId()
        }

        if myUserId > 0 {
            try await userProfileManager.fetchUserFullInfo(userId: myUserId)
            // ...
        }
    }
}
```

**新增函数**：
```swift
/// 从后端获取当前用户 ID 并保存到本地
private func fetchAndSaveCurrentUserId() async throws -> Int
```

---

### 3. SearchViewModel context 为 nil 导致崩溃

**问题描述**：
`SearchViewModel` 的 `context` 属性是隐式解包可选值 (`ModelContext!`)，在某些情况下（如冷启动从推送通知进入）可能在 `context` 被设置之前就被访问，导致崩溃。

**错误日志**：
```
Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value
```

**修复文件**：`guanzhi/ModelsForMap/SearchViewModel.swift`

**修复方法**：
在所有访问 `context` 的函数开头添加 nil 检查：
```swift
guard context != nil else {
    print("⚠️ SearchViewModel.xxx: context 为 nil，跳过")
    return  // 或 return []、return nil 等
}
```

**已添加保护的函数**（共 10 个）：
1. `saveSharesToDatabase(shares:)`
2. `getSharesInRegion(_:)`
3. `getThumbnailURL(for:)`
4. `updateMediaFiles(for:)`
5. `saveMediaFiles(for:)`
6. `loadFromLocal(shareId:)`
7. `deleteShare(shareId:)`
8. `downloadMediaFile(mediaFile:)` (MainActor.run 内)
9. `loadSourceImage(for:)`
10. `createMediaItem(from:)`

---

## 二、推送通知实现架构

### iOS 客户端

**核心文件**：
```
guanzhi/ModelsForNetwork/DeviceService.swift    # 设备注册服务（单例）
guanzhi/guanzhiApp.swift                        # AppDelegate 推送配置
guanzhi/View/FrontPages/SearchView.swift        # 登录后触发设备注册
```

**流程**：
1. App 启动时注册推送权限
2. 获取 APNs Device Token
3. 用户登录后，调用 `DeviceService.shared.registerDevice()` 注册设备
4. 收到推送时，解析 Deep Link 并导航到对应页面
5. 用户登出时，调用 `DeviceService.shared.logoutDevice()` 注销设备

**APNs 环境判断**：
```swift
#if DEBUG
let environment = "sandbox"
#else
let environment = "production"
#endif
```

### 后端 API

| 接口 | 方法 | 路径 |
|------|------|------|
| 注册设备 | POST | `/api/device/register` |
| 注销设备 | POST | `/api/device/logout` |

### Deep Link 格式

```
guanzhi://share/{shareId}/comment/{commentId}
```

---

## 三、注意事项

1. **APNs 环境必须匹配**：
   - iOS DEBUG 模式发送 `sandbox` → 后端必须用 `api.sandbox.push.apple.com`
   - iOS RELEASE 模式发送 `production` → 后端必须用 `api.push.apple.com`

2. **Token 格式**：
   - Device Token 是 64 位十六进制字符串
   - 每次 App 重装或系统更新后可能变化

3. **冷启动处理**：
   - Deep Link 在冷启动时会延迟 0.5 秒处理，确保 UI 初始化完成
   - 未登录时 Deep Link 会被缓存，登录后再处理

---

## 四、测试验证

- [x] 设备注册成功
- [x] userId 重启后正确恢复
- [x] 推送通知收到
- [x] 点击推送跳转到正确页面
- [x] 无崩溃（context nil 保护生效）
