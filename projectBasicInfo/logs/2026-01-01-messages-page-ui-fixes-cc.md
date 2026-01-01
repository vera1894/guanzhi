# 2026-01-01 消息页面 UI 问题修复

## 概述

修复消息中心页面的多个 UI 问题，包括角标阴影、Tab 红点显示、系统消息详情页面、已读状态同步等。

## 修复的问题

### 1. 主页消息图标角标阴影 ✅

**问题**：主页消息图标上的通知角标继承了按钮的黄色阴影效果

**解决方案**：将 `NotificationBadge` 移到按钮外层的 `ZStack` 中，避免继承按钮样式的阴影

**修改文件**：`guanzhi/View/FrontPages/MapOverlayView.swift`

```swift
// 修改前：角标在按钮内部
Button { ... } label: {
    ZStack {
        Image("icon-notification")
        NotificationBadge()  // 会继承按钮阴影
    }
}

// 修改后：角标在按钮外层
ZStack(alignment: .topTrailing) {
    Button { ... } label: {
        Image("icon-notification")
    }
    .buttonStyle(ButtonStyle_l())

    NotificationBadge()  // 独立于按钮，无阴影
        .offset(x: 8, y: -4)
}
```

### 2. 消息页面 Tab 未读红点 ✅

**问题**：
- Tab 红点只在非选中状态显示，选中后消失
- 后端 API `/api/notifications/unread-count` 只返回 `{"count":1}`，不返回分类明细

**解决方案**：
- 移除 `!isSelected` 条件，有未读时始终显示红点
- 从消息列表直接计算各分类的未读状态，而不依赖 API

**修改文件**：
- `guanzhi/View/MessagePages/MessageTabBar.swift`
- `guanzhi/View/MessagePages/MessagesView.swift`

```swift
// MessageTabBar.swift - 移除选中条件
if hasUnread {  // 原来是 if !isSelected && hasUnread
    Circle()
        .fill(Color.red)
        .frame(width: 8, height: 8)
}

// MessagesViewModel - 添加 hasUnreadByCategory 计算
@Published var hasUnreadByCategory: [MessageCategory: Bool] = [:]

private func aggregateMessages() {
    // 计算各分类是否有未读消息
    var unreadByCategory: [MessageCategory: Bool] = [:]
    for category in MessageCategory.allCases {
        let hasUnread = messages.contains { $0.type.category == category && $0.isUnread }
        unreadByCategory[category] = hasUnread
    }
    hasUnreadByCategory = unreadByCategory
    // ...
}
```

### 3. 系统消息详情页面 ✅

**问题**：点击系统消息无反应，因为系统消息的 `deepLink="guanzhi://notifications"` 被传递给只处理 `guanzhi://share/...` 的函数

**解决方案**：在 `handleMessageTap` 中识别 `guanzhi://notifications` deepLink，显示详情 Sheet

**修改文件**：`guanzhi/View/MessagePages/MessagesView.swift`

```swift
private func handleMessageTap(_ message: NotificationMessage) {
    // ...
    if let deepLink = message.deepLink, !deepLink.isEmpty, let url = URL(string: deepLink) {
        if url.host == "notifications" || url.host == "notification" {
            // 系统消息 - 显示详情 Sheet
            selectedSystemMessage = message
        } else if url.host == "share" {
            handleDeepLink(url)
        } else {
            selectedSystemMessage = message
        }
    }
    // ...
}
```

### 4. 消息已读状态本地同步 ✅

**问题**：点击消息后 API 标记已读成功，但列表上的红点没有立即消失，需要退出页面才会更新

**解决方案**：
- 添加 `asRead()` 方法创建消息的已读版本
- 在 API 成功后直接更新本地 `messages` 数组
- 重新调用 `aggregateMessages()` 更新显示

**修改文件**：
- `guanzhi/ModelsForNetwork/NotificationModels.swift`
- `guanzhi/View/MessagePages/MessagesView.swift`

```swift
// NotificationModels.swift - 添加 asRead 方法
extension NotificationMessage {
    func asRead() -> NotificationMessage {
        return NotificationMessage(
            // ... 复制所有字段
            statusCode: 1,  // 1 = READ
            // ...
        )
    }
}

// MessagesViewModel - 本地更新
func markAsRead(_ message: NotificationMessage) async {
    // ...
    if let index = messages.firstIndex(where: { $0.id == message.id }) {
        messages[index] = message.asRead()
        aggregateMessages()  // 重新聚合更新红点状态
    }
    // ...
}
```

### 5. Tab 切换时立即显示 loading ✅

**问题**：切换 Tab 时内容有 0.5s 延迟才切换，体验不佳

**解决方案**：在 `refresh()` 开始时立即清空旧数据，让 UI 显示 loading 状态

**修改文件**：`guanzhi/View/MessagePages/MessagesView.swift`

```swift
func refresh() async {
    currentPage = 1
    hasMore = true
    isLoading = true
    // 立即清空旧数据，让 UI 显示 loading 状态
    messages = []
    displayableMessages = []
    // ...
}
```

## 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `MapOverlayView.swift` | 移动 NotificationBadge 到按钮外层 |
| `MessageTabBar.swift` | 移除红点的 `!isSelected` 条件 |
| `MessagesView.swift` | 添加 hasUnreadByCategory、本地状态更新、Tab 切换立即 loading |
| `NotificationModels.swift` | 添加 `asRead()` 方法 |

## 测试验证

- [x] 主页消息图标角标无阴影
- [x] Tab 选中状态下红点仍显示
- [x] 点击系统消息弹出详情 Sheet
- [x] 点击消息后红点立即消失
- [x] Tab 切换立即显示 loading 状态

## 后端 API 修复 ✅ (2026-01-01)

**问题**：
- `/api/notifications` 不支持 `category` 参数过滤
- `/api/notifications/unread-count` 只返回 `{"count":1}`，不返回分类明细

**已修复**（同日后端部署）：

1. **添加 `category` 参数到 `getNotifications` API**
   - 请求：`GET /notifications?category=interaction` 或 `category=system`
   - 可选值：`all`（默认）、`interaction`（互动类）、`system`（系统类）

2. **修改 `getUnreadCount` 返回分类未读数**
   - 旧格式：`{ "count": 5 }`
   - 新格式：`{ "interaction": 3, "system": 2, "total": 5 }`

3. **添加 `category` 参数到 `markAllAsRead` API**
   - 请求：`PUT /notifications/read-all?category=interaction`
   - 可以只标记某一类通知为已读

**通知分类定义**：
| 分类 | 包含的通知类型 |
|------|---------------|
| `interaction` | NEW_COMMENT, COMMENT_REPLY, COMMENT_LIKE, STICKER_RECEIVED |
| `system` | SYSTEM, LEVEL_UP, USER_WARNED, USER_FROZEN, SHARE_REMOVED, REPORT_RESULT, FADE_WARNING, FADE_COMPLETE |

## 时区问题修复 ✅ (2026-01-01)

**问题**：通知时间显示比实际早 8 小时

**根因分析**：
| 文件 | 时区配置 | 结果 |
|------|----------|------|
| `CommentVO.java` | `@JsonFormat(timezone = "Asia/Shanghai")` ✅ | 正确返回北京时间 |
| `NotificationVO.java` | 无时区配置 ❌ | 返回 UTC 时间数组 |

**问题链**：
1. 服务器时区为 UTC
2. `NotificationVO.createdAt` 无 `@JsonFormat` 注解
3. Jackson 将 `LocalDateTime` 序列化为 UTC 时间数组 `[2026, 1, 1, 7, 0, 0]`
4. iOS 端假设是北京时间，导致时间早 8 小时

**修复**：
```java
// NotificationVO.java
@JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss", timezone = "Asia/Shanghai")
private LocalDateTime createdAt;
```

**预防措施**：
已在 `00_AGENT_RULES.md` 添加"Java 后端时间字段规范"章节，要求所有 VO/DTO 的 `LocalDateTime` 字段必须添加 `@JsonFormat` 注解并指定时区。
