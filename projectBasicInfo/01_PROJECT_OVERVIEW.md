# 观之（Guanzhi）项目概述

**文档版本**: v2.8
**最后更新**: 2026-01-03（Sheet与导航层级冲突修复）

---

## 项目简介

**观之**是一个基于位置的社交分享平台，用户可以在地图上分享和发现内容。项目采用 Monorepo 结构，包含 iOS 客户端、Java 后端服务和 Vue 管理后台。

---

## 项目结构

```
guanzhi/                          # 项目根目录
│
├── guanzhi/                      # iOS 客户端
│   ├── View/                     # SwiftUI 视图
│   ├── Data/                     # 数据模型
│   ├── ModelsForNetwork/         # 网络请求模型
│   ├── ModelsForMap/             # 地图相关模型
│   ├── CameraViews/              # 相机视图
│   └── CaptureFunctions/         # 拍摄功能
│
├── Server/onettoo/               # Java 后端
│   ├── src/main/java/            # Java 源码
│   │   └── com/example/onettoo/
│   │       ├── controller/       # 控制器
│   │       ├── service/          # 服务层
│   │       ├── mapper/           # MyBatis Mapper
│   │       ├── model/            # 数据模型
│   │       └── dto/              # 数据传输对象
│   └── src/main/resources/       # 配置文件
│
├── admin-web/                    # 管理后台（Vue 3）
│   ├── src/views/                # 页面组件
│   ├── src/router/               # 路由配置
│   ├── src/utils/                # 工具函数
│   └── dist/                     # 构建产物
│
├── projectBasicInfo/             # 项目基础信息（本目录）
├── 重要项目信息/                  # 开发文档
└── 后端升级设计文档/              # 设计文档
```

---

## 技术栈

### iOS 客户端 (`guanzhi/`)

| 项目 | 技术 |
|------|------|
| 框架 | SwiftUI |
| 最低版本 | iOS 17.0 |
| 架构模式 | MVVM |
| 网络请求 | Alamofire |
| 包管理 | CocoaPods |
| 状态管理 | ObservableObject + Environment |

**打开方式**：
```bash
open guanzhi.xcworkspace
```

**缓存管理注意事项**：
- 媒体文件缓存存储在 `Library/Caches/` 目录
- iOS 会在设备存储空间不足时**自动清理** Caches 目录
- 代码中访问缓存文件时，**必须先验证文件存在性**（`FileManager.fileExists`）
- 详见：`projectBasicInfo/logs/2026-01-02-thumbnail-cache-invalidation-fix-cc.md`

### Java 后端 (`Server/onettoo/`)

| 项目 | 技术 |
|------|------|
| 框架 | Spring Boot 2.6.3 |
| JDK | Java 17 |
| ORM | MyBatis-Plus 3.5.1 |
| 安全 | Spring Security + JWT |
| 数据库 | MySQL 9.x |
| 缓存 | Redis |
| 连接池 | Druid 1.2.20 |

**本地启动**：
```bash
cd Server/onettoo
./mvnw spring-boot:run
# 服务端口: 8085
```

### 管理后台 (`admin-web/`)

| 项目 | 技术 |
|------|------|
| 框架 | Vue 3 |
| 构建工具 | Vite |
| UI 库 | Element Plus |
| 图表 | ECharts |
| HTTP | Axios |
| 路由 | Vue Router |
| 状态管理 | Pinia |

**本地开发**：
```bash
cd admin-web
npm install
npm run dev
# 访问: http://localhost:5173
```

**生产构建**：
```bash
npm run build
# 产物目录: dist/
# 部署路径: /guanzhi-admin/
```

---

## 核心功能模块

### 1. 分享系统（Share）

- 用户在地图上发布分享（文字、图片、Live Photo）
- 分享可被查看、点赞、评论
- 分享有"褪色"机制（随时间衰减）

### 2. 褪色系统（Fade）

- 分享发布后，随时间逐渐"褪色"
- 褪色速度受阅读量、标签、互动影响
- 管理后台提供褪色曲线模拟器

### 3. 积分与等级系统

- 用户行为产生积分（发布、点赞、评论等）
- 积分累计可升级等级
- 等级影响贴标签额度等权益

### 4. 贴纸系统（Sticker System）

统一的贴纸（Sticker）系统，所有贴纸（包括原 vote 类的赞同/无感和 tag 类的秘境/珍馐等）现在都使用相同的技术实现。

**注意**：文档中提到的具体贴纸名称（如秘境、珍馐、玩趣等）仅作为参考示例。实际贴纸的名称、数量可通过管理后台随时增删和修改，以服务器 `tag_definition` 表中的配置为准。

**重要变更（2025-12-22/24）**：
- 旧投票系统（`share_vote` 表 + `guanzhi.agree_count/neutral_count`）**已完全废弃**
- 所有贴纸数据统一存储在 `share_sticker_action` 表
- 贴纸统计仅从 `share_sticker_action` 表获取，不再累加旧投票数据
- iOS 客户端已完全移除对旧投票系统的依赖：
  - 移除 `VoteState` 枚举及相关属性
  - 移除 `voteShare` API 和 `ShareService.voteShare()` 方法
  - 移除 `StickerKind.isVoteType` / `isTagType` 属性
  - 所有贴纸统一使用 `tagCode` 标识

**核心规则**：
- 任何贴纸对同一条分享、同一用户，只允许使用一次，不可撤回
- 每个用户对每条分享只能使用一个贴纸（互斥）
- 所有贴纸（包括赞同、无感）遵循统一的互斥规则，无特殊处理

#### iOS 客户端实现架构

**核心文件**：
```
guanzhi/View/Features/StickerKit/
├── Models/
│   ├── StickerKind.swift           # 贴纸种类枚举（统一标识）
│   ├── StickerDefinition.swift     # 贴纸视觉定义（图标、名称、优先级）
│   ├── StickerAvailability.swift   # 贴纸可用性模型（从服务器获取）
│   └── StickerSummaryItem.swift    # 贴纸统计项
├── Views/
│   ├── StickerFieldView.swift      # 底部贴纸队列（SpriteKit）
│   ├── StickerSummaryBar.swift     # 顶部贴纸统计条
│   ├── UsedStickerStatusBar.swift  # "已使用贴纸"状态条
│   └── StickerThumbnail.swift      # 贴纸缩略图
└── SpriteKit/
    └── StickerScene.swift          # 贴纸拖动交互场景

guanzhi/View/SharePages/
├── ShareInteractionViewModel.swift  # 贴纸交互核心 ViewModel
└── ShareDetailView.swift            # 分享详情页
```

**核心 ViewModel：`ShareInteractionViewModel`**

关键属性（2025-12-24 更新）：
```swift
@Published var currentUserSticker: UsedStickerInfo?  // 当前用户已使用的贴纸
@Published var stickerSummaries: [StickerSummaryItem] = []  // 贴纸统计列表
@Published var stickerAvailabilities: [StickerAvailability] = []  // 服务器返回的可用性
@Published var visibleStickerDefinitions: [StickerDefinition] = []  // 可见贴纸队列
```

**已移除的过时代码（2025-12-24）**：
- `VoteState` 枚举 - 已删除
- `voteState` 属性 - 已删除
- `_agreeCount` / `_neutralCount` 私有属性 - 已删除
- `voteShare` API - 已删除

关键方法：
```swift
// 统一贴纸使用入口（所有贴纸类型）
func useSticker(_ kind: StickerKind)

// 从服务器加载贴纸可用性
func loadStickerAvailability(shareId: Int64) async

// 重建可见贴纸队列（应用互斥规则）
func rebuildVisibleStickerDefinitions()

// 重建贴纸统计列表
func rebuildStickerSummaries()
```

**数据流程**：
```
1. 进入分享详情页
   ↓
2. initialize(share:) - 重置所有状态
   ↓
3. loadStickerAvailability(shareId:) - 从服务器获取可用性
   ↓
4. applyStickerAvailability(_:) - 应用数据
   ├── 设置 currentUserSticker（如果 alreadyApplied=true）
   ├── 构建 availableStickerKinds
   └── 调用 rebuildVisibleStickerDefinitions() 和 rebuildStickerSummaries()
   ↓
5. UI 更新
   ├── 顶部：StickerSummaryBar（显示 stickerSummaries）
   ├── 底部：StickerFieldView（显示 visibleStickerDefinitions）
   │   └── 或 UsedStickerStatusBar（如果 currentUserSticker != nil）
   └── 右侧：InteractionOverlayView（显示点赞按钮）
```

**贴纸名称动态加载**（2025-12-24 实现）：
- 贴纸名称支持从服务器动态获取，通过 `StickerNameService` 管理
- API：`GET /api/config/sticker-names`（无需登录）
- 缓存策略：ETag + 24 小时本地缓存
- 回退机制：网络失败时使用硬编码默认值
- 使用方式：`StickerKind.dynamicDisplayName` 或 `StickerDefinition.dynamicDisplayName`

**相关文件**：
```
StickerKit/Services/StickerNameService.swift  # 名称服务（API + 缓存）
StickerKit/Models/StickerKind.swift           # dynamicDisplayName 属性
StickerKit/Models/StickerDefinition.swift     # dynamicDisplayName 属性
guanzhiApp.swift                              # App 启动时预加载
```

**配额计算**：
```
用户每日可用次数 = 贴纸的「基础限额」 × 用户等级的「配额倍率」
```

**等级解锁**：
- 每个贴纸可配置「解锁等级」（minLevelCode）
- 只有达到该等级的用户才能使用该贴纸
- 留空表示全员可用

**日切规则**：
- 时区：Asia/Shanghai
- 日切点：每天 04:00
- 配额重置时间：每天 04:00

**技术实现**：
- Redis Lua 脚本实现原子配额扣减
- 数据库唯一约束保证去重和互斥
- 04:00 定时任务应用待生效配置

### 5. 评论系统（Comment System）

**状态**：已完成（2025-12-25），计数实时更新修复（2026-01-02）

支持分享的评论与回复功能：

**核心功能**：
- 一级评论 + 二级回复（含"回复 @B"语义）
- 评论点赞
- 三种排序：默认热度、最新、最多点赞
- 评论长度限制（1-230 字符）
- 频率限制：同一分享 10 秒 1 条；全局每天最多 200 条
- 回复触发站内通知 + APNs 推送
- **评论计数实时更新**：发布/删除评论后按钮计数即时刷新

**重要规则**：
- **无地理位置限制**：用户可在任意位置评论（不再需要在分享附近）
- 一级评论删除后，其二级回复继续展示
- 热度参数可配置（存入 fade_config 表）
- 回复、点赞对分享产生积分（接入后台配置）

**iOS 实现要点**：
- `CommentViewModel` 通过 `onCommentCountChanged` 回调通知计数变化
- `ShareDetailsCardView` 接收回调并更新 `share.commentCount`

**相关文档**：
- `projectBasicInfo/logs/2025-12-22-comment-system-design-cc.md`
- `projectBasicInfo/logs/2026-01-02-comment-count-realtime-fix-cc.md`

### 6. 通知中台（Notification Center）

**状态**：V2.0 已完成（2025-12-31）

完整的推送通知和消息中心系统，支持 iOS 原生 APNs 推送、应用内消息页面、后台可配置和频率控制。

| 版本 | 功能 | 状态 |
|------|------|------|
| V1.0 | 基础推送、消息页面、Deep Link | 已完成 |
| V1.5 | 事件配置、模板管理、用户偏好、频率控制 | 已完成 |
| V2.0 | 管理通知、褪色提醒、用户升级通知 | 已完成 |

#### 6.1 推送通知（APNs）

**核心功能**：
- 设备 Token 注册与管理
- 多种通知类型推送
- Deep Link 支持（从推送跳转到对应分享/评论）
- 登录/登出时自动注册/注销设备

**支持的通知类型**（共 12 种）：
| 类型 | 说明 | 触发场景 |
|------|------|----------|
| `NEW_COMMENT` | 新评论 | 别人评论了你的分享 |
| `COMMENT_REPLY` | 评论回复 | 别人回复了你的评论 |
| `COMMENT_LIKE` | 评论点赞 | 别人点赞了你的评论 |
| `STICKER_RECEIVED` | 收到贴纸 | 别人给你的分享贴了贴纸 |
| `SYSTEM` | 系统通知 | 官方公告、账号相关 |
| `LEVEL_UP` | 用户升级 | 用户等级提升时 |
| `USER_WARNED` | 用户被警告 | 管理员警告用户时 |
| `USER_FROZEN` | 用户被冻结 | 管理员冻结账户时 |
| `SHARE_REMOVED` | 分享被删除 | 分享因违规被删除时 |
| `REPORT_RESULT` | 举报处理结果 | 举报被处理后通知举报人 |
| `FADE_WARNING` | 分享即将褪色 | 分享褪色度达到90%时 |
| `FADE_COMPLETE` | 分享已褪色 | 分享完全褪色消失时 |

**APNs 环境**：
- DEBUG 模式：`sandbox`（开发环境）
- RELEASE 模式：`production`（生产环境）

#### 6.2 消息页面（MessagesView）

**核心文件**：
```
guanzhi/View/MessagePages/
├── MessagesView.swift              # 消息主页面 + ViewModel
├── MessageTabBar.swift             # 分类 Tab 组件
├── MessageRowView.swift            # 单条消息行组件
└── NotificationBadgeManager.swift  # 全局红点管理器

guanzhi/ModelsForNetwork/
├── NotificationService.swift       # 通知 API 服务
└── NotificationModels.swift        # 通知数据模型
```

**页面功能**：
- 消息分类 Tab（互动/系统），选中/未选中状态均显示红点
- 消息列表（分页加载、下拉刷新、切换分类立即 loading）
- 未读红点（显示未读数量，>999 显示 999+）
- 点击消息跳转到对应分享/评论
- 系统消息详情 Sheet（点击系统消息弹出详情页）
- 标记已读（点击自动标记，本地状态即时更新）
- 全部已读（更多菜单中）
- 贴纸消息聚合（同一分享的多个贴纸通知合并显示）

**全局红点管理**：
```swift
// NotificationBadgeManager - 全局单例
@MainActor
class NotificationBadgeManager: ObservableObject {
    static let shared = NotificationBadgeManager()
    @Published var unreadCount: Int = 0

    func refresh() async  // 刷新未读数
}

// 触发刷新
NotificationCenter.default.post(name: .refreshUnreadBadge, object: nil)
```

#### 6.3 后端 API

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 注册设备 | POST | `/api/device/register` | 注册设备 Token |
| 注销设备 | POST | `/api/device/logout` | 登出时注销设备 |
| 通知列表 | GET | `/api/notifications` | 分页获取通知 |
| 未读数量 | GET | `/api/notifications/unread-count` | 获取未读数 |
| 标记已读 | PUT | `/api/notifications/{id}/read` | 标记单条已读 |
| 全部已读 | PUT | `/api/notifications/read-all` | 标记全部已读 |

#### 6.4 Deep Link 格式

```
guanzhi://share/{shareId}/comment/{commentId}  # 跳转到分享评论
guanzhi://share/{shareId}                      # 跳转到分享详情
```

#### 6.5 通知名称定义

```swift
extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
    static let openMessagesPage = Notification.Name("openMessagesPage")
    static let refreshUnreadBadge = Notification.Name("refreshUnreadBadge")
}
```

#### 6.6 V1.5 后台可配置功能（2025-12-30）

**新增数据库表**：
| 表名 | 用途 |
|------|------|
| `notification_event_config` | 事件配置（启用开关、频率限制、模板） |
| `notification_template` | 多渠道通知模板（支持变量替换） |
| `user_notification_preference` | 用户通知偏好设置 |

**核心服务**：
| 服务 | 功能 |
|------|------|
| `NotificationEventConfigService` | 事件配置管理，启动时加载到内存缓存 |
| `NotificationTemplateService` | 模板渲染，支持 `{{variableName}}` 变量替换 |
| `UserNotificationPreferenceService` | 用户偏好查询和管理 |
| `NotificationRateLimitService` | Redis 滑动窗口限流，防止通知轰炸 |

**频率控制配置**：
| 事件 | 频率限制 | 冷却时间 |
|------|----------|----------|
| 评论回复 | 20次/小时 | 30秒 |
| 评论点赞 | 30次/小时 | 60秒 |
| 新评论 | 20次/小时 | 30秒 |
| 收到贴纸 | 15次/小时 | 60秒 |
| 系统通知 | 无限制 | 无 |

**新增 API**：
| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取偏好 | GET | `/api/notifications/preferences` | 获取用户通知偏好 |
| 更新偏好 | PUT | `/api/notifications/preferences` | 批量更新偏好设置 |

**相关文档**：
- V1.0：`projectBasicInfo/logs/2025-12-30-notification-center-ios-v1-complete-cc.md`
- V1.5：`projectBasicInfo/logs/2025-12-30-notification-center-v1.5-complete-cc.md`

### 7. 管理后台

- 褪色曲线模拟器（核心功能）
- 褪色规则配置
- 积分规则配置
- 等级定义管理（配额倍率、待生效配置）
- 贴纸定义管理（解锁等级、基础限额、待生效配置）
- **综合查询**（2025-12-24 新增）：支持按用户ID或分享ID查询所有关联数据明细

---

## 环境与部署

### 开发环境

| 组件 | 地址 |
|------|------|
| 前端 | http://localhost:5173 |
| 后端 | http://localhost:8085 |
| MySQL | localhost:3306/ONETTOO |
| Redis | localhost:6379 |

### 生产环境

| 组件 | 地址 |
|------|------|
| 服务器 | 52.83.127.15 (AWS 宁夏) |
| 管理后台 | http://52.83.127.15/guanzhi-admin/ |
| 后端 API | http://52.83.127.15:8085 |
| 连接方式 | AWS SSM (非 SSH) |

详细连接信息见 `02_CONNECTIONS.private.md`

---

## API 路由说明

### 后端 API 路由模式

```
/user/**            # 用户相关（登录、验证码等）
/guan/**            # 分享业务 API（需登录）
/stickers/**        # 贴纸 API（需登录）
/shares/**          # 分享操作 API（需登录）
/device/**          # 设备管理 API（推送通知，需登录）
/notifications/**   # 通知 API（需登录）
/api/admin/**       # 管理后台 API（需 ADMIN 权限）
/admin/inspector/** # 查询工具 API（含综合查询）
```

### 设备管理 API（2025-12-29 新增）

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 注册设备 | POST | `/api/device/register` | 注册设备 Token 用于推送 |
| 注销设备 | POST | `/api/device/logout` | 登出时注销设备 |

**注册设备请求**：
```json
{
  "deviceToken": "ae5ded893711615b7c17...",
  "bundleId": "com.onettoo",
  "deviceId": "CEFC11EF-BB81-4AFD-9FA3-AF3293FB80AE",
  "deviceName": "iPhone",
  "deviceModel": "iPhone16,2",
  "osVersion": "18.1",
  "appVersion": "1.0",
  "environment": "sandbox"  // sandbox 或 production
}
```

**注册设备响应**：
```json
{
  "respCode": 0,
  "respMsg": "success",
  "datas": 1  // 注意：返回数字类型
}
```

### 通知 API（2025-12-30 新增）

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 通知列表 | GET | `/api/notifications` | 分页获取，支持 category/status 筛选 |
| 未读数量 | GET | `/api/notifications/unread-count` | 返回各分类和总未读数 |
| 标记单条已读 | PUT | `/api/notifications/{id}/read` | 标记指定通知已读 |
| 全部已读 | PUT | `/api/notifications/read-all` | 标记所有通知已读 |

**通知列表请求参数**：
| 参数 | 类型 | 说明 |
|------|------|------|
| category | String | 可选，筛选分类（interaction/system）|
| status | String | 可选，筛选状态（UNREAD/READ）|
| page | Int | 页码，从 1 开始 |
| size | Int | 每页数量 |

**通知列表响应**：
```json
{
  "respCode": 0,
  "datas": {
    "total": 25,
    "list": [
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
    ]
  }
}
```

**未读数量响应**：
```json
{
  "respCode": 0,
  "datas": {
    "interaction": 10,
    "system": 2,
    "total": 12
  }
}
```

### 综合查询 API（2025-12-24 新增）

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 分享完整详情 | GET | `/admin/inspector/share/{shareId}/detail` | 返回分享信息+评论/贴纸/打卡/浏览/举报明细 |
| 用户完整详情 | GET | `/admin/inspector/user/{userId}/detail` | 返回用户信息+分享/评论/贴纸/打卡/奖章明细 |

### iOS App 贴纸相关 API

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取贴纸可用性 | GET | `/api/stickers/availability?shareId=X` | 返回所有贴纸的可用状态 |
| 使用贴纸 | POST | `/api/shares/{shareId}/stickers/use` | 使用贴纸，扣减配额 |

**获取贴纸可用性响应**：
```json
{
  "respCode": 0,
  "datas": {
    "stickers": [
      {
        "stickerId": "ZHENXIU",
        "stickerName": "珍馐",
        "group": "tag",
        "unlocked": true,
        "dailyLimit": 20,
        "usedToday": 5,
        "remainingToday": 15,
        "alreadyApplied": false,
        "minLevelCode": "YOMIN",
        "minLevelName": "游民"
      }
    ]
  }
}
```

**使用贴纸请求**：
```json
{ "stickerId": "ZHENXIU" }
```

**使用贴纸成功响应**：
```json
{
  "respCode": 0,
  "datas": {
    "success": true,
    "remainingToday": 14,
    "usedToday": 6
  }
}
```

**使用贴纸失败响应**：
```json
{
  "respCode": 0,
  "datas": {
    "success": false,
    "remainingToday": 0,
    "errorCode": "QUOTA_EXCEEDED",
    "errorMessage": "今日「珍馐」使用次数已用完"
  }
}
```

### Nginx 代理规则（生产环境）

```
/guanzhi-admin/   → 静态文件 (/var/www/guanzhi-admin/)
/api/user/        → http://127.0.0.1:8085/user/
/api/admin/       → http://127.0.0.1:8085/api/admin/
/api/             → http://127.0.0.1:8085/ (去掉 /api 前缀)
/admin/inspector/ → http://127.0.0.1:8085/admin/inspector/
```

---

## 数据库核心表

| 表名 | 用途 | 状态 |
|------|------|------|
| `user` | 用户信息 | 使用中 |
| `share` / `guanzhi` | 分享内容 | 使用中 |
| `fade_config` | 褪色配置 | 使用中 |
| `points_rule` | 积分规则 | 使用中 |
| `level_definition` | 等级定义（含 daily_multiplier 配额倍率）| 使用中 |
| `tag_definition` | 贴纸定义（含 min_level_code、base_daily_limit）| 使用中 |
| `share_sticker_action` | 贴纸使用记录（**唯一事实来源**）| 使用中 |
| `sticker_level_quota_override` | 等级-贴纸限额覆盖配置 | 使用中 |
| `share_view_log` | 分享浏览记录 | 使用中 |
| `admin_operation_log` | 管理操作日志 | 使用中 |
| `notification` | 通知消息记录 | 使用中（2025-12-30 新增）|
| `device` | 设备 Token 注册 | 使用中（2025-12-29 新增）|
| `notification_event_config` | 通知事件配置（V1.5）| 使用中（2025-12-30 新增）|
| `notification_template` | 通知模板（V1.5）| 使用中（2025-12-30 新增）|
| `user_notification_preference` | 用户通知偏好（V1.5）| 使用中（2025-12-30 新增）|
| `share_vote` | ~~旧投票记录~~ | **已废弃** |

**废弃字段**（2025-12-22）：
- `guanzhi.agree_count` - 旧投票系统赞同计数，不再使用
- `guanzhi.neutral_count` - 旧投票系统无感计数，不再使用

---

## Git 仓库

### 远程仓库

- **Gitee**: https://gitee.com/cxy1992/onettoo/tree/Zaptain/

### 分支策略

- `master`: 生产环境
- `Zaptain`: 开发分支（当前工作分支）

### 注意事项

- 服务器无法直接 `git clone`（需认证）
- 部署文件通过 S3 presigned URL 传输

---

## 相关文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 项目结构说明 | `重要项目信息/项目结构说明.md` | 详细的代码结构说明 |
| V1进度总结 | `重要项目信息/V1项目进度总结.md` | 管理后台开发进度 |
| 部署指南 | `后端升级设计文档/docs/server-deployment-guide.md` | 服务器部署步骤 |
| 后端API文档 | `Server/onettoo/BACKEND_API_MODELS.md` | API 接口说明 |
| 通知中台V1.0 | `projectBasicInfo/logs/2025-12-30-notification-center-ios-v1-complete-cc.md` | 基础推送+消息页面 |
| 通知中台V1.5 | `projectBasicInfo/logs/2025-12-30-notification-center-v1.5-complete-cc.md` | 后台可配置+频率控制 |
| 通知中台V2.0 | `projectBasicInfo/logs/2025-12-31-notification-v2-events-cc.md` | 管理通知+褪色提醒 |
| 消息页面UI优化 | `projectBasicInfo/logs/2026-01-01-messages-page-ui-fixes-cc.md` | 红点/已读/详情页修复 |
| 缩略图缓存修复 | `projectBasicInfo/logs/2026-01-02-thumbnail-cache-invalidation-fix-cc.md` | iOS Caches 目录失效问题 |
| Sheet导航冲突修复 | `projectBasicInfo/logs/2026-01-03-sheet-navigation-conflict-fix-cc.md` | Sheet与NavigationStack层级问题 |

---

## 开发团队

- **项目负责人**: Zaptain
- **AI 协作**: Claude Code, Gemini, GPT
