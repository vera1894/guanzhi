# 通知中台 MVP 实施记录

**日期**: 2025-12-29
**执行者**: Claude Code (Backend CC)
**状态**: 已完成并部署

---

## 概述

实现了基于 APNs 的通知中台 MVP，支持评论回复推送通知。

---

## 后端 API 接口

### 1. 设备注册

**用途**: iOS 客户端启动时注册设备 token

```
POST /api/device/register
Authorization: Bearer {token}
Content-Type: application/json

Request Body:
{
    "deviceToken": "APNs设备Token (必填)",
    "deviceId": "设备唯一标识IDFV (可选)",
    "deviceName": "设备名称如iPhone 15 Pro (可选)",
    "deviceModel": "设备型号如iPhone16,1 (可选)",
    "osVersion": "系统版本如17.2 (可选)",
    "appVersion": "App版本如1.0.0 (可选)",
    "bundleId": "App Bundle ID (必填: com.onetto)",
    "environment": "APNs环境 (可选, 默认production)"
}

Response:
{
    "code": 200,
    "msg": "success",
    "data": null
}
```

### 2. 更新设备 Token

**用途**: 设备 token 变更时更新

```
PUT /api/device/token
Authorization: Bearer {token}
Content-Type: application/json

Request Body:
{
    "oldToken": "旧的设备Token",
    "newToken": "新的设备Token"
}

Response:
{
    "code": 200,
    "msg": "success",
    "data": null
}
```

### 3. 设备登出

**用途**: 用户登出时停用设备推送

```
DELETE /api/device/logout?deviceToken={token}
Authorization: Bearer {token}

Response:
{
    "code": 200,
    "msg": "success",
    "data": null
}
```

---

## 推送通知格式

### APNs Payload 结构

```json
{
    "aps": {
        "alert": {
            "title": "观之",
            "body": "用户名 回复了你: 评论内容..."
        },
        "badge": 1,
        "sound": "default"
    },
    "deepLink": "guanzhi://share/{shareId}/comment/{commentId}",
    "type": "COMMENT_REPLY"
}
```

### Deep Link 格式

```
guanzhi://share/{shareId}/comment/{commentId}
```

**参数说明**:
- `shareId`: 分享(帖子) ID
- `commentId`: 评论 ID

### 通知类型

| type | 说明 |
|------|------|
| COMMENT_REPLY | 评论回复通知 |
| COMMENT_LIKE | 评论点赞通知 |
| NEW_COMMENT | 新评论通知（有人评论了你的分享） |
| SYSTEM | 系统通知 |

---

## iOS 客户端实现要点

### 1. 设备注册时机

```swift
// AppDelegate 或 App 初始化时
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

    // 调用后端 API 注册设备
    DeviceService.register(
        deviceToken: token,
        bundleId: Bundle.main.bundleIdentifier ?? "com.onetto",
        deviceId: UIDevice.current.identifierForVendor?.uuidString,
        deviceName: UIDevice.current.name,
        deviceModel: UIDevice.modelName,
        osVersion: UIDevice.current.systemVersion,
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    )
}
```

### 2. Deep Link 处理

```swift
// 处理推送点击
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           didReceive response: UNNotificationResponse,
                           withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo

    if let deepLink = userInfo["deepLink"] as? String,
       let url = URL(string: deepLink) {
        // 解析 guanzhi://share/{shareId}/comment/{commentId}
        handleDeepLink(url)
    }

    completionHandler()
}

func handleDeepLink(_ url: URL) {
    guard url.scheme == "guanzhi",
          url.host == "share" else { return }

    let pathComponents = url.pathComponents
    // pathComponents: ["/", "{shareId}", "comment", "{commentId}"]

    if pathComponents.count >= 4,
       let shareId = Int(pathComponents[1]),
       pathComponents[2] == "comment",
       let commentId = Int(pathComponents[3]) {
        // 导航到对应的分享详情页，并定位到评论
        navigateToShare(shareId: shareId, highlightCommentId: commentId)
    }
}
```

### 3. 冷启动处理

```swift
// 检查是否从推送启动
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    if let notification = launchOptions?[.remoteNotification] as? [String: Any],
       let deepLink = notification["deepLink"] as? String {
        // 保存待处理的 deep link，登录后处理
        PendingDeepLinkManager.shared.pendingLink = deepLink
    }

    return true
}
```

### 4. Badge 处理

Badge 数值由后端计算(未读通知数量)，客户端无需手动管理。

---

## 数据库变更

### 新增表: user_device

```sql
CREATE TABLE user_device (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    device_token VARCHAR(255) NOT NULL,
    device_id VARCHAR(100) NULL,
    device_name VARCHAR(100) NULL,
    device_model VARCHAR(50) NULL,
    os_version VARCHAR(20) NULL,
    app_version VARCHAR(20) NULL,
    bundle_id VARCHAR(100) NOT NULL,
    environment VARCHAR(20) DEFAULT 'production',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    last_active_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_device_token (device_token),
    INDEX idx_user_device_user (user_id),
    INDEX idx_user_device_active (user_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 触发推送的业务场景

### MVP 阶段 (已实现)

| 场景 | 触发条件 | 接收者 |
|------|----------|--------|
| 评论回复 | 用户回复他人评论 | 被回复评论的作者 |

### 已实现 (2025-12-29 更新)

| 场景 | 触发条件 | 接收者 |
|------|----------|--------|
| 新评论 | 用户评论分享 | 分享作者 |
| 系统通知 | 管理员发送 | 指定用户/全体用户 |

### 系统通知 API

```
POST /api/admin/notification/send
Authorization: Bearer {admin_token}
Content-Type: application/json

Request Body:
{
    "title": "通知标题 (必填)",
    "content": "通知内容 (必填)",
    "userIds": [1, 2, 3],  // 可选, 为空则发送给所有有设备的用户
    "deepLink": "guanzhi://path"  // 可选
}

Response:
{
    "code": 200,
    "msg": "success",
    "data": {
        "sentCount": 10,
        "targetType": "all"  // 或 "specific"
    }
}
```

---

## 服务器配置

### APNs 配置

| 项目 | 值 |
|------|-----|
| Team ID | Z4GPL9AA5M |
| Key ID | ZV4BR5MCAF |
| Bundle ID | com.onetto |
| 环境 | production |
| 密钥路径 | /home/ec2-user/AuthKey_ZV4BR5MCAF.p8 |

---

## Git 提交记录

```
commit 8519353
feat: 通知中台 MVP - APNs 推送支持

新增功能:
- 设备注册 API (DeviceController)
- APNs 推送服务 (ApnsPushService)
- 用户设备管理 (UserDeviceDO, DeviceService)
- 评论回复推送通知集成

清理历史遗留:
- 移除未使用的 JPush 整包代码
- 移除 UserDO.jpushId 字段
```

---

## 相关文件

### 后端新增文件

| 文件 | 用途 |
|------|------|
| DeviceController.java | 设备管理 REST API |
| DeviceService.java | 设备业务逻辑 |
| DeviceRegisterDTO.java | 设备注册请求 DTO |
| SystemNotificationDTO.java | 系统通知请求 DTO |
| UserDeviceDO.java | 设备实体类 |
| UserDeviceMapper.java | 设备数据访问层 |
| ApnsConfig.java | APNs 配置类 |
| ApnsPushService.java | APNs 推送服务 |

### 后端修改文件

| 文件 | 修改内容 |
|------|----------|
| CommentNotificationService.java | 集成 APNs 推送，新增新评论通知和系统通知方法 |
| ShareCommentServiceImpl.java | 添加新评论时通知分享作者 |
| AdminController.java | 添加系统通知 API |
| NotificationDO.java | 添加 NEW_COMMENT 和 SYSTEM 通知类型常量 |
| UserDO.java | 移除 jpushId 字段 |
| pom.xml | 添加 Pushy 依赖，移除 JPush |

---

## 注意事项

1. **设备 Token 唯一性**: 同一个 token 只能属于一个用户，重复注册会自动更新归属
2. **Token 失效处理**: APNs 返回 410/BadDeviceToken 时自动标记设备为非活跃
3. **推送不发送给自己**: 用户回复自己的评论不会触发推送
4. **Deep Link Scheme**: 需要在 iOS 项目的 Info.plist 中注册 `guanzhi` URL Scheme
