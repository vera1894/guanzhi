# 通知中台 + 推送系统规划文档

**文档版本**: v4.0
**创建日期**: 2025-12-29
**更新日期**: 2025-12-31
**角色**: 后端架构师 + 通知中台设计师 (Claude Code)
**状态**: ✅ V2.0 已部署 (2025-12-31)

---

## 一、项目背景

### 1.1 当前状态
- **现有推送**: 无（JPush 代码为历史遗留，从未实际使用）
- **清理任务**: 移除 jpushId 字段和 JPush 相关代码
- **目标**: 建立可扩展的通知中台，首期支持 APNs 直连，未来可接入其他推送服务（如 FCM、华为/小米等）

### 1.2 技术确认
| 项目 | 值 | 说明 |
|------|-----|------|
| MySQL 版本 | 待实施时确认 | 需 5.7+ 以支持 JSON 类型，建表前先查实际 RDS 版本 |
| Spring Boot | 2.6.3 | - |
| MyBatis-Plus | 3.5.1 | - |
| Java | 17 | - |

> **注意**: 在真正建表/改表前，需先通过 `SELECT VERSION();` 确认实际 MySQL 版本。

---

## 二、API 端点目录（排除 Doodle 遗留功能）

### 2.1 用户模块 (UserController) - 8 个端点
| 方法 | 路径 | 说明 | 通知相关 |
|------|------|------|---------|
| POST | `/user/sendCode` | 发送验证码 | - |
| POST | `/user/checkCodeOrLogin` | 登录验证 | - |
| POST | `/user/setName` | 设置昵称 | - |
| GET | `/user/nameExisted` | 检查昵称 | - |
| GET | `/user/info` | 获取用户信息 | - |
| POST | `/user/updateAvatar` | 更新头像 | - |
| GET | `/user/avatarUploadUrl` | 获取上传链接 | - |
| GET | `/user/check` | 检查登录状态 | - |

### 2.2 分享模块 (GuanZhiController) - 18 个端点
| 方法 | 路径 | 说明 | 通知相关 |
|------|------|------|---------|
| GET | `/shares` | 获取分享列表 | - |
| POST | `/shares` | 创建分享 | - |
| GET | `/shares/{shareId}` | 获取分享详情 | - |
| DELETE | `/shares/{shareId}` | 删除分享 | - |
| GET | `/shares/map` | 地图获取分享 | - |
| GET | `/shares/uploadUrl` | 获取上传链接 | - |
| POST | `/shares/{shareId}/checkin` | 打卡 | ✓ share_checkin |
| GET | `/shares/{shareId}/checkins` | 获取打卡列表 | - |
| POST | `/shares/{shareId}/report` | 举报分享 | - |
| GET | `/shares/me/latest` | 我的最新分享 | - |
| GET | `/shares/me/history` | 我的历史分享 | - |
| GET | `/shares/me/checkins` | 我的打卡记录 | - |
| GET | `/my/shares` | 我的分享 | - |
| GET | `/my/checkins` | 我的打卡 | - |
| GET | `/users/{userId}/shares` | 指定用户分享 | - |
| GET | `/users/{userId}/checkins` | 指定用户打卡 | - |
| GET | `/users/{userId}/profile` | 用户资料 | - |
| POST | `/shares/{shareId}/sticker-stat` | 贴纸统计 | - |

### 2.3 评论模块 (CommentController) - 7 个端点
| 方法 | 路径 | 说明 | 通知相关 |
|------|------|------|---------|
| GET | `/shares/{shareId}/comments` | 获取评论列表 | - |
| POST | `/shares/{shareId}/comments` | 发表评论 | ✓ share_new_comment, comment_reply |
| DELETE | `/comments/{commentId}` | 删除评论 | - |
| POST | `/comments/{commentId}/like` | 点赞评论 | ✓ comment_like |
| DELETE | `/comments/{commentId}/like` | 取消点赞 | - |
| GET | `/comments/{commentId}/replies` | 获取回复 | - |
| GET | `/shares/{shareId}/comments/count` | 评论数量 | - |

### 2.4 贴纸模块 (StickerController) - 3 个端点
| 方法 | 路径 | 说明 | 通知相关 |
|------|------|------|---------|
| GET | `/shares/{shareId}/stickers` | 获取贴纸列表 | - |
| POST | `/shares/{shareId}/stickers/use` | 使用贴纸 | ✓ sticker_received |
| GET | `/stickers/names` | 贴纸名称 | - |

### 2.5 管理模块 (AdminController) - 17 个端点
| 方法 | 路径 | 说明 | 通知相关 |
|------|------|------|---------|
| GET | `/admin/users` | 用户列表 | - |
| GET | `/admin/users/{userId}` | 用户详情 | - |
| POST | `/admin/users/{userId}/warn` | 警告用户 | ✓ user_warned |
| POST | `/admin/users/{userId}/freeze` | 冻结用户 | ✓ user_frozen |
| POST | `/admin/users/{userId}/unfreeze` | 解冻用户 | - |
| GET | `/admin/shares` | 分享列表 | - |
| GET | `/admin/shares/{shareId}` | 分享详情 | - |
| DELETE | `/admin/shares/{shareId}` | 删除分享 | ✓ share_removed_illegal |
| GET | `/admin/reports` | 举报列表 | - |
| GET | `/admin/reports/{reportId}` | 举报详情 | - |
| POST | `/admin/reports/{reportId}/handle` | 处理举报 | ✓ report_result |
| GET | `/admin/comments` | 评论列表 | - |
| DELETE | `/admin/comments/{commentId}` | 删除评论 | - |
| GET | `/admin/stats/overview` | 统计概览 | - |
| GET | `/admin/stats/daily` | 每日统计 | - |
| POST | `/admin/announcement` | 发布公告 | ✓ system_announcement |
| GET | `/admin/config` | 获取配置 | - |

### 2.6 巡检模块 (AdminInspectorController) - 4 个端点
| 方法 | 路径 | 说明 | 通知相关 |
|------|------|------|---------|
| GET | `/admin/inspector/queue` | 待审队列 | - |
| POST | `/admin/inspector/approve` | 批准 | - |
| POST | `/admin/inspector/reject` | 拒绝 | - |
| GET | `/admin/inspector/stats` | 审核统计 | - |

### 2.7 配置模块 (ConfigController) - 1 个端点
| 方法 | 路径 | 说明 | 通知相关 |
|------|------|------|---------|
| GET | `/config/app` | App 配置 | - |

---

## 三、通知事件目录

### 3.1 核心交互事件（P0 优先级）✅ 全部完成

| 事件标识 | 触发场景 | 接收者 | 当前状态 |
|---------|---------|--------|---------|
| `NEW_COMMENT` | 分享收到新评论 | 分享作者 | ✅ 已实现 |
| `COMMENT_REPLY` | 评论被回复 | 被回复者 | ✅ 已实现 |
| `COMMENT_LIKE` | 评论被点赞 | 评论作者 | ✅ 已实现 |
| `STICKER_RECEIVED` | 分享收到贴纸 | 分享作者 | ✅ 已实现 |

### 3.2 社交激励事件（P1 优先级）🔄 部分完成

| 事件标识 | 触发场景 | 接收者 | 当前状态 |
|---------|---------|--------|---------|
| `share_checkin` | 分享被打卡 | 分享作者 | ⏸️ 暂缓（iOS 无 UI） |
| `LEVEL_UP` | 用户升级 | 升级用户 | ✅ 已实现 |
| `medal_earned` | 获得徽章 | 获得用户 | ⏸️ 暂缓（iOS 无 UI） |

### 3.3 管理通知事件（P2 优先级）✅ 全部完成

| 事件标识 | 触发场景 | 接收者 | 当前状态 |
|---------|---------|--------|---------|
| `USER_WARNED` | 被警告 | 被警告用户 | ✅ 已实现 |
| `USER_FROZEN` | 被冻结 | 被冻结用户 | ✅ 已实现 |
| `SHARE_REMOVED` | 分享被删除 | 分享作者 | ✅ 已实现 |
| `REPORT_RESULT` | 举报处理结果 | 举报人 | ✅ 已实现 |

### 3.4 系统事件（P3 优先级）✅ 全部完成

| 事件标识 | 触发场景 | 接收者 | 当前状态 |
|---------|---------|--------|---------|
| `SYSTEM` | 系统公告 | 全体/指定用户 | ✅ 已实现 |

### 3.5 褪色提醒事件（新增）✅ 已完成

| 事件标识 | 触发场景 | 接收者 | 当前状态 |
|---------|---------|--------|---------|
| `FADE_WARNING` | 分享褪色度达90% | 分享作者 | ✅ 已实现 |
| `FADE_COMPLETE` | 分享完全褪色 | 分享作者 | ✅ 已实现 |

---

## 四、通知事件注册表设计

### 4.1 数据库表结构

#### notification_event_config（事件配置表）
```sql
CREATE TABLE notification_event_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    event_code VARCHAR(50) NOT NULL UNIQUE COMMENT '事件标识',
    event_name VARCHAR(100) NOT NULL COMMENT '事件名称（中文）',
    event_group VARCHAR(50) NOT NULL COMMENT '事件分组: interaction/social/admin/system',
    is_enabled TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否启用',

    -- 渠道配置
    channels JSON NOT NULL COMMENT '启用的渠道列表 ["apns", "in_app"]',

    -- 频率控制
    frequency_limit INT DEFAULT 0 COMMENT '频率限制（每小时次数，0=不限）',
    cooldown_seconds INT DEFAULT 0 COMMENT '冷却时间（秒）',

    -- 合并配置
    allow_batch TINYINT(1) DEFAULT 0 COMMENT '是否允许合并',
    batch_window_minutes INT DEFAULT 0 COMMENT '合并时间窗口（分钟）',
    batch_threshold INT DEFAULT 0 COMMENT '触发合并的阈值',

    -- 默认模板
    default_title_template VARCHAR(200) COMMENT '默认标题模板',
    default_body_template VARCHAR(500) COMMENT '默认内容模板',

    -- Deep Link
    deep_link_pattern VARCHAR(200) COMMENT 'Deep Link 模板',

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_event_group (event_group),
    INDEX idx_is_enabled (is_enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='通知事件配置表';
```

#### notification_template（通知模板表）
```sql
CREATE TABLE notification_template (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    event_code VARCHAR(50) NOT NULL COMMENT '事件标识',
    channel VARCHAR(20) NOT NULL COMMENT '渠道: apns/in_app',
    locale VARCHAR(10) DEFAULT 'zh_CN' COMMENT '语言',

    title_template VARCHAR(200) NOT NULL COMMENT '标题模板',
    body_template VARCHAR(500) NOT NULL COMMENT '内容模板',

    -- APNs 特有配置
    apns_category VARCHAR(50) COMMENT 'APNs category',
    apns_sound VARCHAR(50) DEFAULT 'default' COMMENT '提示音',
    apns_thread_id VARCHAR(100) COMMENT '线程ID模板',

    is_active TINYINT(1) DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_event_channel_locale (event_code, channel, locale)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='通知模板表';
```

#### user_device（用户设备表）- 替换 jpushId
```sql
CREATE TABLE user_device (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL COMMENT '用户ID',
    device_token VARCHAR(255) NOT NULL COMMENT 'APNs Device Token',
    device_id VARCHAR(100) COMMENT '设备唯一标识（IDFV）',
    device_name VARCHAR(100) COMMENT '设备名称',
    device_model VARCHAR(50) COMMENT '设备型号',
    os_version VARCHAR(20) COMMENT '系统版本',
    app_version VARCHAR(20) COMMENT 'App版本',
    bundle_id VARCHAR(100) NOT NULL COMMENT 'Bundle ID',
    environment VARCHAR(20) DEFAULT 'production' COMMENT 'sandbox/production',

    is_active TINYINT(1) DEFAULT 1 COMMENT '是否活跃',
    last_active_at DATETIME COMMENT '最后活跃时间',

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_device_token (device_token),
    INDEX idx_user_id (user_id),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户设备表';
```

#### notification（通知记录表）- 扩展现有表
```sql
CREATE TABLE notification (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL COMMENT '接收用户ID',
    event_code VARCHAR(50) NOT NULL COMMENT '事件标识',

    -- 内容
    title VARCHAR(200) NOT NULL,
    body VARCHAR(500) NOT NULL,

    -- 关联数据
    payload JSON COMMENT '事件数据 {"shareId": 123, "commentId": 456}',
    deep_link VARCHAR(255) COMMENT '解析后的 Deep Link',

    -- 发送状态
    channel VARCHAR(20) NOT NULL COMMENT '发送渠道',
    status VARCHAR(20) DEFAULT 'pending' COMMENT 'pending/sent/delivered/failed/read',
    sent_at DATETIME COMMENT '发送时间',
    read_at DATETIME COMMENT '已读时间',

    -- 错误处理
    error_message VARCHAR(500) COMMENT '错误信息',
    retry_count INT DEFAULT 0 COMMENT '重试次数',

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_user_id (user_id),
    INDEX idx_user_status (user_id, status),
    INDEX idx_event_code (event_code),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='通知记录表';
```

#### user_notification_preference（用户通知偏好）
```sql
CREATE TABLE user_notification_preference (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    event_code VARCHAR(50) NOT NULL COMMENT '事件标识，* 表示全局',

    push_enabled TINYINT(1) DEFAULT 1 COMMENT '是否接收推送',
    in_app_enabled TINYINT(1) DEFAULT 1 COMMENT '是否显示站内通知',

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_user_event (user_id, event_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户通知偏好表';
```

---

## 五、Deep Link 规范

### 5.1 URL Scheme 定义
```
guanzhi://
```

### 5.2 路由规则

| 场景 | Deep Link 格式 | 说明 |
|------|---------------|------|
| 分享详情 | `guanzhi://share/{shareId}` | 打开分享详情页 |
| 评论详情 | `guanzhi://share/{shareId}/comment/{commentId}` | 打开分享并定位到评论 |
| 用户主页 | `guanzhi://user/{userId}` | 打开用户主页 |
| 通知列表 | `guanzhi://notifications` | 打开通知中心 |
| 设置页面 | `guanzhi://settings` | 打开设置页面 |

### 5.3 解析规则（GPT 建议补充）

**关键决策**: Deep Link 与 action_url 的区别

| 字段 | 前缀 | 处理方式 |
|------|------|---------|
| deep_link | `guanzhi://` | 原生路由，App 内导航 |
| action_url | `https://` | WebView 打开外部链接 |

**iOS 客户端解析逻辑**:
```swift
func handleNotificationAction(_ url: String) {
    if url.hasPrefix("guanzhi://") {
        // 原生路由
        let route = url.replacingOccurrences(of: "guanzhi://", with: "")
        navigateToRoute(route)
    } else if url.hasPrefix("https://") {
        // WebView 打开
        openWebView(url: url)
    }
}
```

### 5.4 iOS 冷启动/唤醒场景处理（GPT 建议补充）

| 场景 | 说明 | 处理方式 |
|------|------|---------|
| 冷启动 | App 完全关闭后点击通知 | `application(_:didFinishLaunchingWithOptions:)` 获取 `launchOptions[.remoteNotification]`，延迟到首页加载完成后处理 |
| 后台唤醒 | App 在后台时点击通知 | `userNotificationCenter(_:didReceive:withCompletionHandler:)` 直接处理 |
| 前台接收 | App 在前台时收到通知 | `userNotificationCenter(_:willPresent:withCompletionHandler:)` 显示 Banner 或自定义处理 |

**iOS 冷启动处理代码示例**:
```swift
// AppDelegate.swift
class AppDelegate: NSObject, UIApplicationDelegate {
    var pendingNotificationPayload: [AnyHashable: Any]?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 保存冷启动通知，等待首页就绪
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            pendingNotificationPayload = notification
        }
        return true
    }
}

// 首页 View 加载完成后处理
struct HomeView: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        // ...
        .onAppear {
            if let payload = appDelegate.pendingNotificationPayload {
                handleNotification(payload)
                appDelegate.pendingNotificationPayload = nil
            }
        }
    }
}
```

---

## 六、APNs 集成设计

### 6.1 认证方式
使用 **Token-Based (p8 key)** 认证：
- Team ID: `Z4GPL9AA5M`
- Key ID: `ZV4BR5MCAF`
- Bundle ID: `com.onetto`

### 6.2 APNs 消息格式
```json
{
    "aps": {
        "alert": {
            "title": "{{title}}",
            "body": "{{body}}"
        },
        "badge": {{unread_count}},
        "sound": "default",
        "thread-id": "{{thread_id}}",
        "category": "{{category}}"
    },
    "deep_link": "guanzhi://share/123/comment/456",
    "event_code": "comment_reply",
    "payload": {
        "shareId": 123,
        "commentId": 456
    }
}
```

### 6.3 Badge 策略
- **badge 值 = 用户未读通知数量**
- 每次发送推送时从数据库查询未读数
- 用户打开 App 后同步清零

### 6.4 Device Token 生命周期

| 事件 | 触发时机 | 后端处理 |
|------|---------|---------|
| 注册 | App 首次启动/登录后 | 调用 `POST /device/register` |
| 更新 | Token 变化时 | 调用 `PUT /device/token` |
| 失效 | APNs 返回 410 | 标记 `is_active = false` |
| 登出 | 用户登出 | 调用 `DELETE /device/{deviceId}` |

---

## 七、API 接口设计

### 7.1 设备管理 API

#### 7.1.1 注册设备
```
POST /api/v1/device/register
Authorization: Bearer {jwt_token}  // 必须认证
```

**请求体**:
```json
{
    "deviceToken": "abc123...",
    "deviceId": "IDFV-xxx",
    "deviceName": "iPhone 15 Pro",
    "deviceModel": "iPhone16,1",
    "osVersion": "17.2",
    "appVersion": "1.0.0",
    "bundleId": "com.onetto",
    "environment": "production"
}
```

**认证要求**: 必须携带有效 JWT Token，Token 中包含 userId

#### 7.1.2 更新 Token
```
PUT /api/v1/device/token
Authorization: Bearer {jwt_token}
```

**请求体**:
```json
{
    "oldToken": "old_token...",
    "newToken": "new_token..."
}
```

#### 7.1.3 注销设备
```
DELETE /api/v1/device/{deviceId}
Authorization: Bearer {jwt_token}
```

### 7.2 通知 API

#### 7.2.1 获取通知列表
```
GET /api/v1/notifications?page=1&size=20&status=unread
Authorization: Bearer {jwt_token}
```

**认证要求**: 必须认证，仅返回当前用户的通知

#### 7.2.2 标记已读
```
PUT /api/v1/notifications/{notificationId}/read
Authorization: Bearer {jwt_token}
```

#### 7.2.3 批量标记已读
```
PUT /api/v1/notifications/read-all
Authorization: Bearer {jwt_token}
```

#### 7.2.4 获取未读数
```
GET /api/v1/notifications/unread-count
Authorization: Bearer {jwt_token}
```

### 7.3 用户偏好 API

#### 7.3.1 获取通知偏好
```
GET /api/v1/notifications/preferences
Authorization: Bearer {jwt_token}
```

#### 7.3.2 更新通知偏好
```
PUT /api/v1/notifications/preferences
Authorization: Bearer {jwt_token}
```

**请求体**:
```json
{
    "globalPush": true,
    "preferences": [
        {"eventCode": "comment_reply", "pushEnabled": true},
        {"eventCode": "sticker_received", "pushEnabled": false}
    ]
}
```

### 7.4 API 认证说明（GPT 建议补充）

| API 路径 | 认证要求 | 说明 |
|---------|---------|------|
| `POST /device/register` | **必须认证** | 需要 userId 关联设备 |
| `PUT /device/token` | **必须认证** | 需要 userId 验证所有权 |
| `DELETE /device/{id}` | **必须认证** | 需要 userId 验证所有权 |
| `GET /notifications` | **必须认证** | 仅返回当前用户通知 |
| `PUT /notifications/*` | **必须认证** | 只能操作自己的通知 |

---

## 八、后端服务架构

### 8.1 核心组件

```
com.cloud.onettoo.modules.notification/
├── controller/
│   ├── DeviceController.java          // 设备管理 API
│   └── NotificationController.java    // 通知 API
├── service/
│   ├── NotificationCenterService.java // 通知中台核心服务
│   ├── NotificationEventService.java  // 事件处理服务
│   ├── NotificationSenderService.java // 发送调度服务
│   └── ApnsPushService.java           // APNs 推送实现
├── model/
│   ├── NotificationEventConfig.java   // 事件配置实体
│   ├── NotificationTemplate.java      // 模板实体
│   ├── UserDevice.java                // 设备实体
│   ├── Notification.java              // 通知记录实体
│   └── UserNotificationPreference.java // 用户偏好实体
├── mapper/
│   ├── NotificationEventConfigMapper.java
│   ├── NotificationTemplateMapper.java
│   ├── UserDeviceMapper.java
│   ├── NotificationMapper.java
│   └── UserNotificationPreferenceMapper.java
├── event/
│   ├── NotificationEvent.java         // 事件基类
│   ├── CommentNotificationEvent.java  // 评论事件
│   └── StickerNotificationEvent.java  // 贴纸事件
└── config/
    └── ApnsConfig.java                // APNs 配置
```

### 8.2 事件发布流程

```
业务代码 → 发布 Spring Event → NotificationEventService 监听
    ↓
查询事件配置 → 检查是否启用
    ↓
检查用户偏好 → 检查是否屏蔽
    ↓
渲染模板 → 生成通知内容
    ↓
保存通知记录 → notification 表
    ↓
异步发送 → APNs / 其他渠道
```

### 8.3 APNs 发送实现

```java
@Service
public class ApnsPushService {

    private ApnsClient apnsClient;

    @PostConstruct
    public void init() {
        // 使用 Pushy 库
        apnsClient = new ApnsClientBuilder()
            .setApnsServer(ApnsClientBuilder.PRODUCTION_APNS_HOST)
            .setSigningKey(ApnsSigningKey.loadFromPkcs8File(
                new File(keyPath),
                teamId,
                keyId
            ))
            .build();
    }

    public void send(String deviceToken, ApnsPayload payload) {
        SimpleApnsPushNotification notification = new SimpleApnsPushNotification(
            deviceToken,
            bundleId,
            payload.toJson()
        );

        PushNotificationFuture<SimpleApnsPushNotification, PushNotificationResponse<SimpleApnsPushNotification>>
            future = apnsClient.sendNotification(notification);

        future.whenComplete((response, cause) -> {
            if (response != null && response.isAccepted()) {
                // 成功
            } else if (response != null && response.getRejectionReason().equals("Unregistered")) {
                // Token 失效，标记设备不活跃
                markDeviceInactive(deviceToken);
            } else {
                // 处理其他错误
            }
        });
    }
}
```

---

## 九、管理后台功能

### 9.1 通知事件管理
- 查看所有事件配置
- 启用/禁用事件
- 编辑事件模板
- 配置频率限制（可调节阈值）
- 配置合并规则

### 9.2 模板管理
- 多渠道模板配置
- 模板变量说明
- 模板预览功能

### 9.3 统计监控
- 通知发送量统计
- 送达率统计
- 点击率统计
- 失败原因分析

### 9.4 用户通知管理
- 查看用户通知历史
- 手动发送测试通知

---

## 十、最小可行版本（MVP）实施计划

### 10.1 优先级定义（GPT 建议补充）

根据 GPT 建议，采用"最小可行版本优先"策略：

| 阶段 | 名称 | 目标 | 预期结果 |
|------|------|------|---------|
| MVP | 核心功能 | 跑通完整链路 | 能发一条评论通知到 iPhone |
| V1.0 | 基础完善 | 覆盖 P0 事件 | 4 个核心事件全部上线 |
| V1.5 | 体验优化 | 管理后台 | 后台可配置，无需改代码 |
| V2.0 | 功能扩展 | P1/P2 事件 | 社交激励 + 管理通知 |

### 10.2 MVP 阶段 ✅ 已完成 (2025-12-29)

**目标**: 跑通 APNs 推送完整链路

**范围**:
- [x] user_device 表 + 基础 CRUD
- [x] 设备注册 API（单设备即可）
- [x] APNs 推送服务（Pushy 库实现）
- [x] comment_reply 事件（最简单的通知）
- [x] iOS 端接收并显示通知

### 10.3 V1.0 阶段 ✅ 已完成 (2025-12-30)

**目标**: P0 事件全覆盖 + 基础存储

**新增范围**:
- [x] notification 表 + 通知记录
- [x] notification_event_config 表（代码初始化配置）
- [x] 4 个 P0 事件全部实现
  - [x] NEW_COMMENT (分享收到新评论)
  - [x] COMMENT_REPLY (评论被回复)
  - [x] COMMENT_LIKE (评论被点赞)
  - [x] STICKER_RECEIVED (收到贴纸)
- [x] 通知列表 API
- [x] 未读数 API
- [x] Badge 同步

### 10.4 V1.5 阶段 ✅ 已完成 (2025-12-30)

**目标**: 管理后台可配置

**新增范围**:
- [x] notification_template 表
- [x] 管理后台 - 事件配置页面
- [x] 管理后台 - 模板编辑页面
- [x] 频率控制实现
- [x] 用户通知偏好

### 10.5 V2.0 阶段 ✅ 全部完成 (2025-12-31 已部署)

**目标**: 功能扩展

**已实现范围**:
- [x] LEVEL_UP (用户升级) - 集成到 UserServiceImpl.updateUserLevel
- [x] USER_WARNED (用户被警告) - 集成到 AdminController.updateUserStatus
- [x] USER_FROZEN (用户被冻结) - 集成到 AdminController.updateUserStatus
- [x] SHARE_REMOVED (分享被删除) - 集成到 AdminController.markShare + processReport
- [x] REPORT_RESULT (举报处理结果) - 集成到 AdminController.processReport
- [x] FADE_WARNING (分享即将褪色) - 集成到 FadeScoreTask (90%阈值)
- [x] FADE_COMPLETE (分享已褪色) - 集成到 FadeScoreTask (100%时触发)
- [x] SYSTEM (系统公告) - AdminController.sendSystemNotification 已存在

**暂不实现（待 iOS 前端支持）**:
- [ ] share_checkin (分享被打卡) - iOS 端尚无打卡 UI
- [ ] medal_earned (获得徽章) - iOS 端尚无徽章展示 UI

### 10.6 延后实现（GPT 建议）

以下功能标记为**延后实现**，不在初期规划中：

| 功能 | 原因 |
|------|------|
| 批量通知合并 | 需要定时任务 + 复杂逻辑，MVP 不需要 |
| 多渠道支持 | 华为/小米/FCM 等待 Android 版本开发时再加 |
| A/B 测试 | 用户量达到一定规模后再考虑 |
| 国际化模板 | 当前仅支持中文 |

---

## 十一、迁移计划

### 11.1 JPush 完全清理

> **决策**: 当前阶段不再依赖极光推送，iOS 端只需上传 APNs Token + deviceId，无需保留 jpushId 兼容逻辑。

| 步骤 | 内容 |
|------|------|
| 1 | 新增 user_device 表 |
| 2 | iOS 端仅上报 APNs Token（不再上报 jpushId） |
| 3 | 新通知使用 APNs 发送 |
| 4 | 直接移除 JPush 相关代码和依赖 |
| 5 | 移除 User 表 jpushId 字段 |

### 11.2 现有通知代码迁移

| 文件 | 处理方式 |
|------|---------|
| CommentNotificationService.java | 改为发布 Spring Event |
| JPushUtil.java | **直接删除**，由 ApnsPushService 替代 |
| NotificationDO.java | 扩展支持新事件类型 |
| User.jpushId 字段 | **直接删除**，由 user_device 表替代 |

---

## 十二、风险与规避

| 风险 | 概率 | 影响 | 规避措施 |
|------|------|------|---------|
| APNs Token 频繁变化 | 中 | 推送失败 | 提供 Token 更新 API，处理 410 响应 |
| 推送延迟/丢失 | 低 | 用户体验 | 站内信兜底，重要通知持久化 |
| 频率控制误伤 | 中 | 通知丢失 | 管理后台可调阈值，合理默认值 |
| 冷启动通知丢失 | 中 | 导航失败 | AppDelegate 暂存，首页就绪后处理 |

---

## 十三、后续迭代方向

1. **Android 支持**: FCM + 华为/小米厂商通道
2. **富媒体推送**: 图片、音频预览
3. **通知分组**: iOS 15+ Notification Summary
4. **A/B 测试**: 模板效果对比
5. **智能发送**: 基于用户活跃时间优化发送时机

---

## 附录 A：默认事件配置数据

> **注意**: 所有 INSERT 语句统一包含 `is_enabled` 字段，与表定义 `is_enabled TINYINT(1) NOT NULL DEFAULT 1` 保持一致。

```sql
-- P0 核心交互事件（默认启用 is_enabled=1）
INSERT INTO notification_event_config (event_code, event_name, event_group, channels, is_enabled, default_title_template, default_body_template, deep_link_pattern) VALUES
('share_new_comment', '分享收到新评论', 'interaction', '["apns", "in_app"]', 1, '{{commenterName}} 评论了你的分享', '{{commentContent}}', 'guanzhi://share/{{shareId}}/comment/{{commentId}}'),
('comment_reply', '评论被回复', 'interaction', '["apns", "in_app"]', 1, '{{replierName}} 回复了你', '{{replyContent}}', 'guanzhi://share/{{shareId}}/comment/{{commentId}}'),
('comment_like', '评论被点赞', 'interaction', '["apns", "in_app"]', 1, '{{likerName}} 赞了你的评论', '{{commentContent}}', 'guanzhi://share/{{shareId}}/comment/{{commentId}}'),
('sticker_received', '收到贴纸', 'interaction', '["apns", "in_app"]', 1, '{{senderName}} 给你的分享贴了 {{stickerName}}', '', 'guanzhi://share/{{shareId}}');

-- P1 社交激励事件（默认禁用 is_enabled=0，待后续开启）
INSERT INTO notification_event_config (event_code, event_name, event_group, channels, is_enabled, default_title_template, default_body_template, deep_link_pattern) VALUES
('share_checkin', '分享被打卡', 'social', '["apns", "in_app"]', 0, '{{checkerName}} 在你的分享地点打卡了', '', 'guanzhi://share/{{shareId}}'),
('level_up', '用户升级', 'social', '["apns", "in_app"]', 0, '恭喜升级！', '你已升至 {{level}} 级', 'guanzhi://user/{{userId}}'),
('medal_earned', '获得徽章', 'social', '["apns", "in_app"]', 0, '获得新徽章！', '{{medalName}}', 'guanzhi://user/{{userId}}');

-- P2 管理通知事件（默认禁用 is_enabled=0，待后续开启）
INSERT INTO notification_event_config (event_code, event_name, event_group, channels, is_enabled, default_title_template, default_body_template, deep_link_pattern) VALUES
('user_warned', '用户被警告', 'admin', '["apns", "in_app"]', 0, '账号警告', '{{reason}}', 'guanzhi://notifications'),
('user_frozen', '用户被冻结', 'admin', '["apns", "in_app"]', 0, '账号已冻结', '{{reason}}', 'guanzhi://notifications'),
('share_removed_illegal', '分享被删除', 'admin', '["apns", "in_app"]', 0, '内容已被移除', '{{reason}}', 'guanzhi://notifications'),
('report_result', '举报处理结果', 'admin', '["apns", "in_app"]', 0, '举报处理完成', '{{result}}', 'guanzhi://notifications');

-- P3 系统事件（默认禁用 is_enabled=0，待后续开启）
INSERT INTO notification_event_config (event_code, event_name, event_group, channels, is_enabled, default_title_template, default_body_template, deep_link_pattern) VALUES
('system_announcement', '系统公告', 'system', '["apns", "in_app"]', 0, '{{title}}', '{{content}}', '{{actionUrl}}');
```

---

## 附录 B：iOS 端集成要点

> **重要说明**: 以下 Swift 代码仅为示意，实际接入时需使用项目现有的网络层封装（如 `APIClient`、`GuanzhiService` 等），并确保携带登录态 Token / userId。

### B.1 Device Token 注册
```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

    // ⚠️ 示意代码 - 实际需使用项目现有网络层
    // NotificationService.shared.registerDevice(token: token)

    // 实际实现示例：
    // APIClient.shared.request(
    //     .registerDevice(token: token, deviceId: UIDevice.current.identifierForVendor?.uuidString)
    // )
}
```

### B.2 通知处理
```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    // 前台收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    // 点击通知
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deep_link"] as? String {
            // ⚠️ 需对接项目现有的路由系统
            handleDeepLink(deepLink)
        }
        completionHandler()
    }
}
```

---

**文档结束**

下一步：请审阅此规划文档，确认后可开始 MVP 阶段实施。
