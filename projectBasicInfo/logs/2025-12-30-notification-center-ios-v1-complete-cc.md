# 通知中台 V1.0 iOS 端完整实现

**日期**: 2025-12-30
**操作员**: Claude Code
**状态**: 已完成

---

## 概述

完成 iOS 客户端消息页面开发，实现通知中台 V1.0 的前端功能。包括消息列表展示、未读红点管理、分类切换、标记已读等核心功能。

---

## 新增文件

### 消息页面模块 (`guanzhi/View/MessagePages/`)

| 文件 | 说明 |
|------|------|
| `MessagesView.swift` | 消息主页面，含 ViewModel |
| `MessageTabBar.swift` | 消息分类 Tab 组件（互动/系统）|
| `MessageRowView.swift` | 单条消息行组件 |
| `NotificationBadgeManager.swift` | 全局未读红点管理器 + NotificationBadge 组件 |

### 网络模型 (`guanzhi/ModelsForNetwork/`)

| 文件 | 说明 |
|------|------|
| `NotificationModels.swift` | 通知相关数据模型 |
| `NotificationService.swift` | 通知 API 服务 |

---

## 核心功能实现

### 1. 消息页面 (MessagesView)

**功能**：
- 导航栏：左侧返回按钮、标题"消息"、右侧更多按钮
- 分类 Tab：互动消息、系统消息，显示各分类未读数
- 消息列表：分页加载、下拉刷新、上拉加载更多
- 空状态提示

**导航栏样式修复**：
- 使用 `icon-back` 和 `icon-more` 自定义图标
- iOS 26+ 使用 `.sharedBackgroundVisibility(.hidden)` 移除白色背景

**更多菜单**：
- "全部已读" 选项（无未读时禁用）
- 使用 `confirmationDialog` 实现

### 2. 消息分类 Tab (MessageTabBar)

**分类定义**：
```swift
enum MessageCategory: String, CaseIterable, Codable {
    case interaction  // 互动消息
    case system       // 系统消息
}
```

**包含的通知类型**：
| 分类 | 通知类型 |
|------|----------|
| 互动 | COMMENT_REPLY, COMMENT_LIKE, NEW_COMMENT, STICKER_RECEIVED |
| 系统 | SYSTEM |

### 3. 消息行 (MessageRowView)

**展示信息**：
- 用户头像（系统消息显示 App Logo）
- 消息标题（格式化显示，如"张三 回复了你"）
- 消息内容预览
- 时间戳（智能格式化：刚刚/分钟前/小时前/昨天/天前/MM-dd）
- 未读红点

**消息类型标题格式**：
| 类型 | 格式 |
|------|------|
| COMMENT_REPLY | "{昵称} 回复了你" |
| COMMENT_LIKE | "{昵称} 赞了你的评论" |
| NEW_COMMENT | "{昵称} 评论了你的观之" |
| STICKER_RECEIVED | "{昵称} 给你贴了「{贴纸名}」" |
| SYSTEM | "系统通知" |

### 4. 未读红点管理 (NotificationBadgeManager)

**功能**：
- 全局单例，管理未读消息数量
- 定时刷新（每 60 秒）
- 响应 `.refreshUnreadBadge` 通知立即刷新
- 提供 `NotificationBadge` 视图组件

**使用方式**：
```swift
// 在任意视图中使用红点组件
NotificationBadge()
    .offset(x: 4, y: -4)

// 触发刷新
NotificationCenter.default.post(name: .refreshUnreadBadge, object: nil)
```

### 5. 通知服务 (NotificationService)

**API 接口**：
| 方法 | 功能 |
|------|------|
| `getNotifications(category:page:size:)` | 获取通知列表 |
| `getUnreadCount()` | 获取未读数量 |
| `markAsRead(id:)` | 标记单条已读 |
| `markAllAsRead()` | 标记全部已读 |

---

## 导航与路由集成

### Route 枚举扩展

```swift
// AppStateModel.swift
enum Route: Hashable, Codable {
    // ... 现有 case
    case messagesView  // 消息页面
}
```

### guanzhiApp.swift 导航目标

```swift
case .messagesView:
    MessagesView()
        .environment(appState)
        .environmentObject(navigationCoordinator)
        .environmentObject(userProfileManager)
```

### MapOverlayView 消息按钮

```swift
Button {
    navigationCoordinator.path.append(Route.messagesView)
    // ...
} label: {
    ZStack(alignment: .topTrailing) {
        Image("icon-notification")
        NotificationBadge()
            .offset(x: 4, y: -4)
    }
}
```

---

## 推送通知集成

### 通知点击处理 (guanzhiApp.swift)

**有 Deep Link 的通知**：
```swift
// 解析 guanzhi://share/{shareId}/comment/{commentId}
// 跳转到分享详情页
navigationCoordinator.path.append(Route.shareComment(shareId:commentId:))
```

**无 Deep Link 的通知**（如系统消息）：
```swift
// 跳转到消息页面
NotificationCenter.default.post(name: .openMessagesPage, object: nil)
```

### 前台通知处理

```swift
// 收到通知时刷新红点
NotificationCenter.default.post(name: .refreshUnreadBadge, object: nil)
```

### 通知名称定义

```swift
extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
    static let openMessagesPage = Notification.Name("openMessagesPage")
    static let refreshUnreadBadge = Notification.Name("refreshUnreadBadge")
}
```

---

## 数据模型

### NotificationMessage

```swift
struct NotificationMessage: Identifiable, Codable {
    let id: Int64
    let type: NotificationType
    let content: String
    let shareId: Int64?
    let commentId: Int64?
    let fromUserId: Int?
    let fromUserName: String?
    let fromUserAvatar: String?
    let status: String           // "UNREAD" / "READ"
    let createdAt: Int64         // 毫秒时间戳
    let deepLink: String?
}
```

### UnreadCount

```swift
struct UnreadCount: Codable {
    let interaction: Int?  // 互动消息未读数
    let system: Int?       // 系统消息未读数
    let total: Int         // 总未读数
}
```

---

## 问题修复

### 1. 返回按钮白色背景

**问题**：MessagesView 返回按钮有圆形白色背景
**修复**：添加 iOS 26 条件判断，使用 `.sharedBackgroundVisibility(.hidden)`

### 2. 更多按钮图标

**问题**：使用系统图标，与 ShareDetailView 不一致
**修复**：改用 `Image("icon-more")`

### 3. 全部已读按钮状态

**问题**：无未读消息时，全部已读选项应禁用
**修复**：添加 `.disabled(!hasUnreadMessages)` 修饰符

### 4. 系统消息点击无响应

**问题**：点击系统通知（无 Deep Link）不跳转到消息页
**修复**：在 `userNotificationCenter(_:didReceive:)` 中添加无 Deep Link 时跳转消息页逻辑

### 5. 主页红点不刷新

**问题**：收到推送后主页消息按钮红点不更新
**修复**：
- NotificationBadgeManager 监听 `.refreshUnreadBadge` 通知
- 前台收到推送时发送该通知

---

## Xcode 项目集成

新增文件需手动添加到 `project.pbxproj`：

1. **PBXBuildFile** - 添加编译引用
2. **PBXFileReference** - 添加文件引用
3. **PBXGroup** - 创建 MessagePages 分组
4. **PBXSourcesBuildPhase** - 添加到编译阶段

---

## 验证结果

- [x] 编译成功
- [x] 消息页面正常显示
- [x] 分类切换正常
- [x] 下拉刷新正常
- [x] 点击消息跳转正常
- [x] 标记已读正常
- [x] 全部已读正常
- [x] 红点刷新正常
- [x] 推送点击跳转正常

---

## V1.0 功能总结

### 后端（已完成）

- [x] 通知数据库模型
- [x] 评论回复通知
- [x] 评论点赞通知
- [x] 新评论通知
- [x] 收到贴纸通知
- [x] 系统通知（管理后台触发）
- [x] APNs 推送服务
- [x] 通知列表 API
- [x] 未读数量 API
- [x] 标记已读 API

### iOS 端（已完成）

- [x] 消息页面 UI
- [x] 消息分类 Tab
- [x] 消息列表（分页+刷新）
- [x] 未读红点组件
- [x] 红点管理器（全局状态）
- [x] 点击消息跳转
- [x] 标记已读
- [x] 全部已读
- [x] 推送通知点击处理
- [x] Deep Link 解析

---

## 后续迭代方向

| 功能 | 优先级 | 说明 | 状态 |
|------|--------|------|------|
| SwiftData 本地缓存 | P1 | 离线查看已读消息 | 待定 |
| 消息高亮定位 | P1 | 从 Deep Link 跳转后定位到对应评论 | ✅ 已完成 (2025-12-31) |
| 进入前台自动刷新 | P1 | 30秒间隔防止频繁请求 | ✅ 已完成 (2025-12-31) |
| ~~消息按日期分组~~ | ~~P2~~ | ~~今天/昨天/更早~~ | ❌ 已取消 |
| 贴纸通知聚合 | P2 | "张三等3人给你贴了贴纸" | ✅ 已完成 (2025-12-31) |

---

**文档结束**
