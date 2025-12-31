# 消息页面建设规划 V2

**文档版本**: v2.0
**创建日期**: 2025-12-30
**状态**: 待实施

---

## 一、概述

在 MapOverlayView 头像按钮下方的消息按钮点击后，跳转到消息页面，展示各类通知消息。页面框架与 MyView（个人主页）保持一致。

**参考设计**: 小红书消息页面

---

## 二、后端 API（已实现）

通知中台 V1.0 已提供以下 API：

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 通知列表 | GET | `/api/notifications` | 分页获取，支持状态筛选 |
| 未读数量 | GET | `/api/notifications/unread-count` | 获取未读总数 |
| 标记单条已读 | PUT | `/api/notifications/{id}/read` | 标记指定消息已读 |
| 标记全部已读 | PUT | `/api/notifications/read-all` | 标记所有消息已读 |

### 已支持的通知类型

| type | 说明 | 触发场景 |
|------|------|----------|
| `COMMENT_REPLY` | 评论回复 | 别人回复了你的评论 |
| `COMMENT_LIKE` | 评论点赞 | 别人点赞了你的评论 |
| `NEW_COMMENT` | 新评论 | 别人评论了你的分享 |
| `STICKER_RECEIVED` | 收到贴纸 | 别人给你的分享贴了贴纸 |
| `SYSTEM` | 系统通知 | 官方公告、账号相关 |

### NotificationVO 字段

```json
{
  "id": 123,
  "type": "COMMENT_REPLY",
  "content": "张三 回复了你: 这个地方太美了！",
  "shareId": 456,
  "commentId": 789,
  "fromUserId": 11,
  "fromUserName": "张三",
  "fromUserAvatar": "avatar.jpg",
  "status": "UNREAD",
  "createdAt": 1703923200000,
  "deepLink": "guanzhi://share/456/comment/789"
}
```

---

## 三、页面结构设计

### 整体布局

```
┌─────────────────────────────────┐
│  ←  消息                    ···  │  ← 导航栏（左返回，右更多）
├─────────────────────────────────┤
│  ┌─────────┐    ┌─────────┐     │
│  │  🔔互动  │    │  📢系统  │     │  ← 消息分类 Tab（2个）
│  │  (12)   │    │   (2)   │     │     括号内显示未读数
│  └─────────┘    └─────────┘     │
├─────────────────────────────────┤
│                                 │
│  消息列表（下拉刷新 + 上拉加载） │
│                                 │
│  ┌─────────────────────────────┐│
│  │ [头像]  用户昵称      3分钟前 ││
│  │ 回复了你：评论内容预览...   🔴││  ← 右侧红点（未读数）
│  │ [分享缩略图]                ││
│  └─────────────────────────────┘│
│                                 │
│  ┌─────────────────────────────┐│
│  │ [头像]  用户昵称      1小时前 ││
│  │ 给你的观之贴了「珍馐」     🔴││
│  │ [分享缩略图]                ││
│  └─────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

### 导航栏设计

与 MyView 保持一致：
- **左侧**: 返回按钮 (`icon-back`)
- **标题**: "消息" (居中)
- **右侧**: 更多按钮 (`icon-more`)
  - 点击弹出菜单，包含「全部已读」选项

### 消息分类 Tab

| 分类 | rawValue | 显示名称 | 包含的通知类型 |
|------|----------|----------|----------------|
| 互动 | `interaction` | "互动" | COMMENT_REPLY, COMMENT_LIKE, NEW_COMMENT, STICKER_RECEIVED |
| 系统 | `system` | "系统" | SYSTEM |

### 消息行设计

```
┌─────────────────────────────────────────────────┐
│  ┌────┐                                         │
│  │头像│  用户昵称                    3分钟前  🔴 │  ← 右侧红点（未读时显示）
│  └────┘                                    (5)  │     红点内显示未读数
│        回复了你：这个地方太美了！                │
│        ┌─────────────────────────────┐          │
│        │ [缩略图] 原分享标题预览...  │          │
│        └─────────────────────────────┘          │
└─────────────────────────────────────────────────┘
```

**未读红点规则**:
- 未读消息在行右侧显示红点
- 红点内显示未读数量
- 数量 > 999 时显示 "999+"
- 已读消息不显示红点

### 消息类型展示

| 类型 | 标题格式 | 缩略图 |
|------|----------|--------|
| COMMENT_REPLY | "{昵称} 回复了你" | 分享缩略图 |
| COMMENT_LIKE | "{昵称} 赞了你的评论" | 分享缩略图 |
| NEW_COMMENT | "{昵称} 评论了你的观之" | 分享缩略图 |
| STICKER_RECEIVED | "{昵称} 给你贴了「{贴纸名}」" | 分享缩略图 |
| SYSTEM | "系统通知" | App Logo |

---

## 四、数据模型设计

### 消息分类枚举

```swift
/// 消息分类（rawValue 用英文，UI 用 title）
enum MessageCategory: String, CaseIterable, Codable {
    case interaction  // 互动消息
    case system       // 系统消息

    var title: String {
        switch self {
        case .interaction: return "互动"
        case .system: return "系统"
        }
    }

    var icon: String {
        switch self {
        case .interaction: return "bell.fill"
        case .system: return "megaphone.fill"
        }
    }
}
```

### 通知类型枚举

```swift
/// 通知类型（与后端 NotificationDO.TYPE_* 对应）
enum NotificationType: String, Codable {
    case commentReply = "COMMENT_REPLY"
    case commentLike = "COMMENT_LIKE"
    case newComment = "NEW_COMMENT"
    case stickerReceived = "STICKER_RECEIVED"
    case system = "SYSTEM"

    /// 所属分类
    var category: MessageCategory {
        switch self {
        case .system:
            return .system
        default:
            return .interaction
        }
    }
}
```

### 通知消息模型

```swift
/// 通知消息（对应后端 NotificationVO）
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
    let createdAt: Int64         // 毫秒时间戳（后端原始值）
    let deepLink: String?

    /// 转换为 Date（UI 展示用）
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
    }

    /// 是否未读
    var isUnread: Bool {
        status == "UNREAD"
    }
}
```

### 未读数统计模型

```swift
/// 未读数统计
struct UnreadCount: Codable {
    let interaction: Int  // 互动消息未读数
    let system: Int       // 系统消息未读数
    let total: Int        // 总未读数
}
```

---

## 五、文件结构

```
guanzhi/View/MessagePages/
├── MessagesView.swift              # 消息主页面
├── MessageTabBar.swift             # 分类 Tab 组件
├── MessageListView.swift           # 消息列表组件
├── MessageRowView.swift            # 单条消息行组件
├── MessageMoreMenu.swift           # 更多按钮菜单（含全部已读）
└── UnreadBadgeView.swift           # 未读红点组件

guanzhi/ModelsForNetwork/
├── NotificationService.swift       # 通知 API 服务
└── NotificationModels.swift        # 通知相关数据模型
```

---

## 六、导航集成

### Route 枚举扩展

```swift
enum Route: Hashable, Codable {
    // ... 现有 case
    case messagesView  // 消息页面（MVP 不带参数）
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
        appState.isShowingSearchView = false
    }
} label: {
    Image("icon-notification")
        .resizable()
        .scaledToFit()
        .frame(width: 46, height: 46)
}
.buttonStyle(ButtonStyle_l())
.overlay(alignment: .topTrailing) {
    // 未读红点（显示总未读数）
    if unreadTotal > 0 {
        UnreadBadgeView(count: unreadTotal)
            .offset(x: 8, y: -4)
    }
}
```

### Deep Link 扩展

```swift
// handleDeepLink 中添加 message 路由
if url.host == "message" {
    // guanzhi://message/{messageId}
    // MVP 先只跳转到消息页，不高亮
    navigationCoordinator.path.append(Route.messagesView)
}
```

---

## 七、API 对接

### OTORequest 扩展

```swift
enum OTORequest {
    // ... 现有 case

    /// 获取通知列表
    case getNotifications(category: String?, status: String?, page: Int, size: Int)

    /// 获取未读数量
    case getUnreadCount

    /// 标记单条已读
    case markNotificationRead(id: Int64)

    /// 标记全部已读
    case markAllNotificationsRead
}

extension OTORequest {
    var request: OTORequestBaseModel {
        switch self {
        // ... 现有 case

        case .getNotifications(let category, let status, let page, let size):
            var params: [String: Any] = ["page": page, "size": size]
            if let category = category { params["category"] = category }
            if let status = status { params["status"] = status }
            return .init(path: "/notifications", method: .get, param: params)

        case .getUnreadCount:
            return .init(path: "/notifications/unread-count", method: .get, param: [:])

        case .markNotificationRead(let id):
            return .init(path: "/notifications/\(id)/read", method: .put, param: [:])

        case .markAllNotificationsRead:
            return .init(path: "/notifications/read-all", method: .put, param: [:])
        }
    }
}
```

---

## 八、交互流程

### 进入消息页

```
1. 点击消息按钮
   ↓
2. 导航到 MessagesView
   ↓
3. 调用 getUnreadCount 获取各分类未读数
   ↓
4. 调用 getNotifications 获取当前分类消息列表
   ↓
5. 渲染 UI
```

### 切换分类 Tab

```
1. 点击分类 Tab
   ↓
2. 切换 selectedCategory
   ↓
3. 重新调用 getNotifications（使用缓存或刷新）
   ↓
4. 更新列表
```

### 点击消息行

```
1. 点击消息行
   ↓
2. 调用 markNotificationRead 标记已读
   ↓
3. 更新本地状态（红点消失）
   ↓
4. 解析 deepLink，执行导航
   ↓
5. 跳转到分享详情页（定位评论）
```

### 全部已读

```
1. 点击更多按钮 → 选择「全部已读」
   ↓
2. 弹出确认弹窗（可选）
   ↓
3. 调用 markAllNotificationsRead
   ↓
4. 更新本地状态（所有红点消失）
   ↓
5. 更新未读计数
```

---

## 九、MVP 范围与待办

### MVP 必须实现

| 功能 | 状态 |
|------|------|
| 消息页面框架（导航栏、Tab、列表） | 待实施 |
| 互动/系统分类切换 | 待实施 |
| 消息列表展示（分页加载） | 待实施 |
| 下拉刷新 | 待实施 |
| 未读红点（含数量） | 待实施 |
| 点击跳转到分享详情 | 待实施 |
| 标记已读（点击自动） | 待实施 |
| 全部已读（更多菜单） | 待实施 |
| MapOverlayView 消息按钮红点 | 待实施 |

### 后续迭代

| 功能 | 优先级 |
|------|--------|
| SwiftData 本地缓存 | P1 |
| 消息高亮定位（从 Deep Link） | P1 |
| 进入前台自动刷新（30秒间隔） | P2 |
| 消息分组（按日期） | P2 |
| 贴纸通知聚合 | P2 |
| 空状态友好提示 | P2 |

---

## 十、决策记录

### 已确认的产品决策

| 问题 | 决策 |
|------|------|
| 消息存储 | MVP 不做 SwiftData 持久化，只做分页 + 内存缓存 |
| 实时性 | 靠"打开页面拉取 + 下拉刷新"，不接 WebSocket |
| 消息保留 | 后端控制（6个月/500条），前端无限分页 |
| 贴纸通知 | 先做"每次一条"，后端可做简单节流 |
| "全部已读"位置 | 放在右上角更多按钮的弹框菜单里 |
| 未读红点 | 显示在消息行右侧，红点内显示未读数，>999 显示 "999+" |

---

## 十一、时间线

| 阶段 | 内容 |
|------|------|
| 阶段 1 | 创建文件结构 + 数据模型 + API 定义 |
| 阶段 2 | MessagesView 页面框架 + 导航集成 |
| 阶段 3 | Tab 切换 + 消息列表 + 下拉刷新 |
| 阶段 4 | 未读红点 + 标记已读 + 全部已读 |
| 阶段 5 | MapOverlayView 红点 + Deep Link |

---

**文档结束**

下一步：确认规划后开始实施。
