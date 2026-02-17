# 观之（Guanzhi）项目概述

**文档版本**: v4.3
**最后更新**: 2026-02-17（聚合列表排名排序 + 「最新」徽章系统）

---

## 术语说明

**详见** `04_TERMINOLOGY.md`

| 层面 | 术语 | 说明 |
|------|------|------|
| UI 文案 | **观之** | 用户可见的内容单位名称 |
| 代码/API/DB | Share | 内部技术模型名称（不改） |

---

## 项目简介

**观之**是一个基于位置的社交平台，用户可以在地图上发布和发现「观之」内容。项目采用 Monorepo 结构，包含 iOS 客户端、Java 后端服务和 Vue 管理后台。

---

## 项目结构

```
guanzhi/                          # 项目根目录
│
├── guanzhi/                      # iOS 客户端
│   ├── View/                     # SwiftUI 视图
│   │   └── UIElement/            # 可复用 UI 组件（ProfileHeaderView 等）
│   ├── Data/                     # 数据模型（SwiftData）
│   │   └── UserProfile.swift     # 统一用户档案模型（SSOT）
│   ├── Models/                   # 展示层模型
│   │   ├── UserProfileDisplayModel.swift   # UI 展示模型
│   │   └── UserProfileMapper.swift         # 数据映射
│   ├── ModelsForNetwork/         # 网络请求模型
│   │   ├── KeychainService.swift # Keychain 安全存储封装
│   │   ├── RequestSigner.swift   # API 请求签名（P3 加固）
│   │   └── CertificatePinning.swift # HTTPS 证书固定（P3 加固）
│   ├── ModelsForMap/             # 地图相关模型
│   ├── CameraViews/              # 相机视图
│   ├── CaptureFunctions/         # 拍摄功能
│   ├── Support/                  # 支持工具
│   │   ├── Logger.swift          # 调试日志工具（仅 DEBUG）
│   │   └── InputValidator.swift  # 统一输入验证库（P3 加固）
│   └── Configuration/            # 配置文件
│       └── Secrets.xcconfig.example  # 敏感配置模板
│
├── Server/onettoo/               # Java 后端
│   ├── src/main/java/            # Java 源码
│   │   └── com/example/onettoo/
│   │       ├── controller/       # 控制器
│   │       ├── service/          # 服务层
│   │       ├── mapper/           # MyBatis Mapper
│   │       ├── model/            # 数据模型
│   │       └── dto/              # 数据传输对象
│   ├── src/main/resources/       # 配置文件
│   └── .env.example              # 环境变量模板（2026-01-22 新增）
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
| Token 存储 | iOS Keychain（2026-01-22 安全升级）|

**打开方式**：
```bash
open guanzhi.xcworkspace
```

**安全存储**（2026-01-22 公测前安全修复）：
- **Token 存储**：登录 Token 存储在 iOS Keychain，不再使用 UserDefaults
- **敏感配置**：API Key 等通过 `Secrets.xcconfig` + `Info.plist` 注入，不硬编码
- **调试日志**：使用 `Logger` 工具，仅 DEBUG 模式输出
- **相关文件**：
  - `ModelsForNetwork/KeychainService.swift` - Keychain 操作封装
  - `Support/Logger.swift` - 条件日志工具
  - `Configuration/Secrets.xcconfig.example` - 敏感配置模板

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
| 敏感配置 | 环境变量（2026-01-22 安全升级）|

**本地启动**：
```bash
cd Server/onettoo
./mvnw spring-boot:run
# 服务端口: 8085
```

**敏感配置管理**（2026-01-22 公测前安全修复）：
- 敏感配置（JWT 密钥、API 凭证等）已迁移到环境变量
- 本地开发需创建 `.env` 文件，参考 `.env.example` 模板
- 生产环境通过 systemd 的 `EnvironmentFile` 加载
- **环境变量清单**：
  | 变量 | 说明 |
  |------|------|
  | `JWT_SECRET` | JWT 签名密钥 |
  | `KNIFE4J_USER` / `KNIFE4J_PWD` | API 文档认证 |
  | `ADMIN_PHONE` | 管理员手机号 |
  | `APNS_*` | APNs 推送配置 |
  | `CORS_ORIGINS` | 允许的跨域来源 |
- **生产环境安全**（2026-01-22 已验证）：
  - Druid 监控面板已关闭（返回 404 ✅）
  - Swagger UI 已关闭（返回 404 ✅）
  - Knife4j 已关闭（无法访问 ✅）
  - CORS 收敛为配置化白名单（外部配置文件 ✅）
  - 管理后台测试后门已移除（重新部署 ✅）

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

### 1. 观之系统（Share）

- 用户在地图上发布观之（文字、图片、Live Photo）
- 观之可被查看、点赞、评论
- 观之有"褪色"机制（随时间衰减）

### 2. 褪色系统（Fade）

- 观之发布后，随时间逐渐"褪色"
- 褪色速度受阅读量、标签、互动影响
- 管理后台提供褪色曲线模拟器

#### iOS 客户端褪色度显示（2026-01-06 更新）

**个人主页观之列表**（`ShareListView.swift`）：
- 第一个 Tab："全部观之" - 显示所有未删除的观之
- 第二个 Tab："已褪色" - 显示 `fadeScore >= 100` 的观之

**观之条目**（`ShareSingleView.swift`）：
- 标题限制为 2 行，超出部分显示省略号
- 在观之 ID 行上方显示 "褪色度：n%"
- 当 `fadeScore >= 90` 时，标签显示为红色
- `showNewBadge: Bool`：聚合列表中 48h 内发布的观之显示「最新」胶囊徽章（半透明黑底 + 白字，缩略图左上角）

**聚合列表数据流**（重要）：
```
服务器 ResponsedShare (fadeScore: Int?)
    ↓ 缓存到
SearchViewModel.cachedResponsedShares [shareId: ResponsedShare]
    ↓ 存入 SwiftData
Share (fadeScore: Int)
    ↓ 转换为
CustomAnnotation.annotationData
    ↓ 聚合列表读取时
SearchView.convertAnnotationsToShares() 优先从缓存获取
    ↓ 排名排序（2026-02-17 新增）
ClusterShareRanker.rank() → 置顶区(48h内≤3条) + 排名区(finalScore降序)
```

**关键文件**：
- `SearchView.swift:convertAnnotationsToShares()` - 聚合列表数据转换
- `SearchViewModel.swift:cachedResponsedShares` - 服务器数据缓存
- `ShareSingleView.swift` - 观之条目视图（含褪色度标签、最新徽章）
- `ShareListView.swift` - 个人主页观之列表（含 Tab 切换）
- `ClusterShareRanker.swift` - 聚合列表排名工具类（评分公式 + 置顶逻辑）

#### 褪色白化效果（Fade Veil）（2026-01-06 实现）

当观之 `fadeScore >= 90` 时，缩略图自动应用"发白"视觉效果，提示用户该观之即将褪色。

**效果**：
- 降低饱和度（saturation = 0.15）
- 叠加白色蒙版（Screen 混合，opacity = 0.24）

**应用范围**：
| 场景 | 是否白化 |
|------|----------|
| 地图单标注（CustomMKAnnotationView）| 是 |
| 个人列表（ShareSingleView）| 是 |
| 聚合列表项（ShareSingleView）| 是 |
| 聚合图标（ClusterAnnotationView）| **否** |

**核心实现**：
```
View/Shared/FadeVeilProcessor.swift     # Core Image 处理器（参数集中管理）
ModelsForMap/SearchViewModel.swift      # ImageCache 统一 API
  ├── ImageVariant.original             # 原图（聚合图标用）
  └── ImageVariant.fadeVeil(fadeScore:) # 白化图（单标注/列表用）
```

**缓存策略**：
- 使用 `ImageVariant.cacheKeySuffix` 区分缓存
- 版本号 `FadeVeilProcessor.version`（当前 `fv_v1`）
- 修改参数后需 bump 版本号，否则旧缓存不会更新

**相关文档**：`projectBasicInfo/logs/2026-01-06-fade-veil-processor-complete-cc.md`

#### fadeScore=100 隐藏（2026-01-06 实现）

当观之 `fadeScore >= 100` 时，在首页地图相关区域不再可见，但详情页和个人主页仍可访问。

**可见性规则**：
| 场景 | fadeScore=100 |
|------|---------------|
| 首页地图单标注 | **不可见** |
| 首页地图聚合标注 | **不可见**（成员被过滤） |
| 首页地图聚合列表 | **不可见** |
| 个人主页列表 | 可见（"已褪色" Tab） |
| 详情页 / Deep Link | 可访问 |

**技术实现**：
- SSOT 唯一过滤点：`SearchViewModel.getAnnotations()`
- fadeScore 取值：`max(cached, local)` 确保不低估褪色度
- 只在 Home Map annotation pipeline 过滤，不影响数据层

**相关文档**：`projectBasicInfo/logs/2026-01-06-fade-score-100-hide-plan.md`

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
- 任何贴纸对同一条观之、同一用户，只允许使用一次，不可撤回
- 每个用户对每条观之只能使用一个贴纸（互斥）
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
└── ShareDetailView.swift            # 观之详情页
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
1. 进入观之详情页
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

支持观之的评论与回复功能：

**核心功能**：
- 一级评论 + 二级回复（含"回复 @B"语义）
- 评论点赞
- 三种排序：默认热度、最新、最多点赞
- 评论长度限制（1-230 字符）
- 频率限制：同一观之 10 秒 1 条；全局每天最多 200 条
- 回复触发站内通知 + APNs 推送
- **评论计数实时更新**：发布/删除评论后按钮计数即时刷新

**重要规则**：
- **无地理位置限制**：用户可在任意位置评论（不再需要在观之附近）
- 一级评论删除后，其二级回复继续展示
- 热度参数可配置（存入 fade_config 表）
- 回复、点赞对观之产生积分（接入后台配置）

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
- Deep Link 支持（从推送跳转到对应观之/评论）
- 登录/登出时自动注册/注销设备

**支持的通知类型**（共 12 种）：
| 类型 | 说明 | 触发场景 |
|------|------|----------|
| `NEW_COMMENT` | 新评论 | 别人评论了你的观之 |
| `COMMENT_REPLY` | 评论回复 | 别人回复了你的评论 |
| `COMMENT_LIKE` | 评论点赞 | 别人点赞了你的评论 |
| `STICKER_RECEIVED` | 收到贴纸 | 别人给你的观之贴了贴纸 |
| `SYSTEM` | 系统通知 | 官方公告、账号相关 |
| `LEVEL_UP` | 用户升级 | 用户等级提升时 |
| `USER_WARNED` | 用户被警告 | 管理员警告用户时 |
| `USER_FROZEN` | 用户被冻结 | 管理员冻结账户时 |
| `SHARE_REMOVED` | 观之被删除 | 观之因违规被删除时 |
| `REPORT_RESULT` | 举报处理结果 | 举报被处理后通知举报人 |
| `FADE_WARNING` | 观之即将褪色 | 观之褪色度达到90%时 |
| `FADE_COMPLETE` | 观之已褪色 | 观之完全褪色消失时 |

**APNs 环境**：
- DEBUG 模式：`sandbox`（开发环境）
- RELEASE 模式：`production`（生产环境）

**Channel 与 Provider 语义**（2026-01-08 统一）：

通知系统采用两层抽象设计：

| 层面 | 字段 | 可选值 | 说明 |
|------|------|--------|------|
| 业务层 | `channel` | `push` / `inApp` | 通知渠道类型 |
| 技术层 | `provider` | `apns` / `fcm` | 推送服务提供商（运行时决定）|

**设计原则**：
- 数据库模板表 `notification_template.channel` 存储业务层渠道
- 代码查询时使用 `channel='push'`（非 `apns`）
- 具体使用 APNs 还是 FCM 由运行时设备类型决定
- 这样设计便于未来扩展 Android 推送支持

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
- 点击消息跳转到对应观之/评论
- 系统消息详情 Sheet（点击系统消息弹出详情页）
- 标记已读（点击自动标记，本地状态即时更新）
- 全部已读（更多菜单中）
- 贴纸消息聚合（同一观之的多个贴纸通知合并显示）

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
guanzhi://share/{shareId}/comment/{commentId}  # 跳转到观之评论
guanzhi://share/{shareId}                      # 跳转到观之详情
```

#### 6.5 通知名称定义

```swift
extension Notification.Name {
    // Deep Link 和消息页面
    static let handleDeepLink = Notification.Name("handleDeepLink")
    static let openMessagesPage = Notification.Name("openMessagesPage")
    static let refreshUnreadBadge = Notification.Name("refreshUnreadBadge")

    // 登录状态管理（2026-01-23 新增）
    static let userDidLogout = Notification.Name("com.guanzhi.userDidLogout")
    static let userIdDidSet = Notification.Name("com.guanzhi.userIdDidSet")
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

**频率控制配置**（2026-01-13 更新）：
| 事件 | 频率限制 | 冷却时间 | 可关闭 | 说明 |
|------|----------|----------|--------|------|
| 评论回复 | 20次/小时 | 30秒 | ✅ | |
| 评论点赞 | 30次/小时 | 60秒 | ✅ | |
| 新评论 | 20次/小时 | 30秒 | ✅ | |
| 收到贴纸 | 15次/小时 | 60秒 | ✅ | |
| 系统通知 | 无限制 | 无 | ✅ | |
| 用户升级 | 无限制 | 无 | ✅ | |
| 用户被警告 | 无限制 | 无 | ❌ | 管理类必达通知 |
| 用户被冻结 | 无限制 | 无 | ❌ | 管理类必达通知 |
| 观之被删除 | 无限制 | 无 | ❌ | 管理类必达通知 |
| 举报处理结果 | 无限制 | 无 | ❌ | 管理类必达通知 |
| 褪色预警 | 每share1次 | 24小时 | ✅ | 唯一索引幂等 |
| 完全褪色 | 每share1次 | 无 | ✅ | 唯一索引幂等 |

**幂等说明**（2026-01-13 新增）：
- `FADE_WARNING` 和 `FADE_COMPLETE` 通过 `notification` 表的唯一索引 `(user_id, type, share_id)` 保证每条观之只通知一次
- 管理类通知（警告/冻结/删除/举报结果）不受用户偏好影响，确保必达

**新增 API**：
| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 获取偏好 | GET | `/api/notifications/preferences` | 获取用户通知偏好 |
| 更新偏好 | PUT | `/api/notifications/preferences` | 批量更新偏好设置 |

**相关文档**：
- V1.0：`projectBasicInfo/logs/2025-12-30-notification-center-ios-v1-complete-cc.md`
- V1.5：`projectBasicInfo/logs/2025-12-30-notification-center-v1.5-complete-cc.md`

### 7. 用户档案 SSOT 系统（2026-01-07）

**状态**：已完成

统一的用户档案管理系统，解决了之前"自己主页显示等级，他人主页不显示"的问题。

#### 问题背景

原架构存在数据分裂：
- `LocalUserProfile`（当前用户）有 `levelCode` 字段
- `OtherUserProfile`（他人）缺失该字段
- 存储路径分裂：当前用户存 SwiftData，他人只存内存
- UI 代码重复：MyView 和 OthersView 各自实现 header

#### SSOT 解决方案

| 组件 | 路径 | 说明 |
|------|------|------|
| `UserProfile` | `Data/UserProfile.swift` | 统一 SwiftData 模型（@Model） |
| `UserProfileDisplayModel` | `Models/UserProfileDisplayModel.swift` | UI 展示层模型 |
| `UserProfileMapper` | `Models/UserProfileMapper.swift` | 数据映射 + OneCode 遮挡规则 |
| `ProfileHeaderView` | `View/UIElement/ProfileHeaderView.swift` | 统一头部组件 |

#### 核心架构

```
服务器 API → UserFullInfoModel
    ↓ saveToUserProfile()
SwiftData UserProfile 表（所有用户统一存储）
    ↓ @Query
MyView / OthersView（自动刷新）
    ↓ toDisplayModel()
ProfileHeaderView（统一展示）
```

#### 数据模型字段

```swift
@Model
class UserProfile {
    @Attribute(.unique) var id: Int
    var name: String?           // OneCode
    var nickname: String?       // 昵称
    var phone: String?          // 手机号（用于遮挡判断）
    var photo: String?          // 头像路径
    var levelCode: String?      // 等级代码
    var pointsTotal: Int?       // 积分
    var titleDOSData: Data?     // 称号 JSON
    var lastUpdated: Date?      // 更新时间
}
```

#### ProfileHeaderView 使用

```swift
// 统一头部组件
ProfileHeaderView(
    displayModel: profile.toDisplayModel(),
    mode: .me,  // 或 .other
    cachedAvatarImage: cachedImage,
    onAvatarTap: { },
    onEditProfileTap: { },
    onOneCodeTap: { }
)
```

#### 生命周期管理

| 时机 | 操作 |
|------|------|
| 登录成功 | `saveToUserProfile()` 保存当前用户 |
| 查看他人 | `saveToUserProfile()` 保存他人信息 |
| 退出登录 | `clearAllUserProfiles()` 清空全表 |
| App 启动 | `checkAndClearIfNotLoggedIn()` 检查并清理 |

**相关文档**：`projectBasicInfo/logs/2026-01-07-user-profile-ssot-implementation-cc.md`

### 8. 用户引导系统（Onboarding System）

**状态**：已完成（2026-01-23 状态重载修复）

新用户引导系统，通过顶部信息栏逐步引导用户了解核心功能。

#### 引导流程

| 步骤 | 触发条件 | 提示内容 | 完成条件 | 样式 |
|------|---------|----------|---------|------|
| A | 首次进入主页 | 欢迎分享和探索真实世界的地点! | 自动关闭（3秒） | 黄底 |
| B | A 完成后 | 试着操作地图来点击查看地图上的观之 | 点击任意观之标注 | 黄底，可跳过 |
| C1 | 首次进入详情页 | 点击贴纸图标，查看可用的贴纸 | 点击贴纸按钮 | 黄底，可跳过 |
| C2 | C1 完成后 | 选一个符合这条观之的贴纸，拖动到屏幕中心使用它! | 使用贴纸 | 黄底，可跳过 |
| D | A-B 完成后返回主页 | 当你到达你的宝藏地点时，别忘了去试试发布... | 自动关闭（60秒） | 黄底 |
| E | 首次发布观之后 | 每条观之都有它的"褪色度"... | 自动关闭（60秒） | 黄底 |

#### 核心架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    OnboardingCoordinator                         │
│  - currentStep: OnboardingStep?                                  │
│  - completedSteps: Set<OnboardingStep>                           │
│  - hasSkippedAll: Bool                                           │
│  - shouldBlockHomeSheet: Bool（A-B 未完成时阻止 Sheet）           │
│                                                                  │
│  事件驱动：handleEvent(_ event: OnboardingEvent)                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              OnboardingBannerView（App 根视图统一挂载）           │
│  - 黄底/绿底（完成）切换                                          │
│  - 内嵌"跳过全部/继续"确认按钮                                    │
│  - GeometryReader 动态读取 safeAreaInsets.top                    │
└─────────────────────────────────────────────────────────────────┘
```

#### 核心文件

```
guanzhi/View/Features/Onboarding/
├── OnboardingCoordinator.swift      # 状态机核心（事件处理、状态管理）
├── OnboardingBannerView.swift       # Banner UI 组件
├── OnboardingPersistence.swift      # 持久化管理（UserDefaults，userId 隔离）
└── OnboardingHighlightModifier.swift # 高亮效果 ViewModifier
```

#### 状态重载机制（2026-01-23 修复）

解决"重新登录后返回主页时 UI 异常"问题。

**问题根因**：
1. `OnboardingCoordinator.init()` 时 `userId` 可能为 0（guest），读取了错误用户的持久化数据
2. `appState` 在 `.onAppear` 中才注入，通知处理时可能为 nil

**解决方案**：

```swift
// UserLoginModel.swift - 登录成功后发送通知
extension Notification.Name {
    static let userIdDidSet = Notification.Name("com.guanzhi.userIdDidSet")
}

func setUserID(_ userId: Int) {
    UserDefaults.standard.set(userId, forKey: "userId")
    if userId > 0 {
        NotificationCenter.default.post(name: .userIdDidSet, object: nil, userInfo: ["userId": userId])
    }
}

// OnboardingCoordinator.swift - 监听通知重新加载
private func setupNotificationObservers() {
    NotificationCenter.default.publisher(for: .userIdDidSet)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            if let userId = notification.userInfo?["userId"] as? Int, userId > 0 {
                self?.reloadStateForCurrentUser()
            }
        }
        .store(in: &cancellables)

    NotificationCenter.default.publisher(for: .userDidLogout)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.resetToGuestState()
        }
        .store(in: &cancellables)
}

// guanzhiApp.swift - appState 注入后检查并恢复 UI
.onAppear {
    onboardingCoordinator.appState = appState
    onboardingCoordinator.checkAndRestoreUIStateIfNeeded()
}
```

**关键方法**：
| 方法 | 说明 |
|------|------|
| `reloadStateForCurrentUser()` | userId 变化后重新加载正确用户的状态 |
| `resetToGuestState()` | 登出时重置到 guest 状态 |
| `checkAndRestoreUIStateIfNeeded()` | appState 注入后检查并恢复 UI |

#### MapOverlayView 动画修复（2026-01-23）

**问题**：聚合列表关闭后 MapOverlayView 不出现

**根因**：`AnimatedOverlaySheet.dismissWithAnimation()` 在 `asyncAfter` 中调用 `onDismiss`，此时 SwiftUI 动画事务已结束，`withAnimation` 无法触发 transition

**修复方案**：
```swift
// SearchView.swift

// 1. 添加 .animation() 修饰符确保 transition 触发
.overlay(alignment: .bottomTrailing) {
    if appState.isShowingSearchView {
        MapOverlayView(...)
            .transition(.move(edge: .trailing))
    }
}
.animation(.easeInOut(duration: 0.2), value: appState.isShowingSearchView)

// 2. 在 onChange 中恢复状态（而非 onDismiss）
.onChange(of: isShowingClusterList) { oldValue, isShowing in
    if !isShowing && oldValue {
        onboardingCoordinator.handleEvent(.clusterListDismissed)
        if !shouldRestoreClusterList {
            withAnimation(.easeOut(duration: 0.2)) {
                appState.isShowingSearchView = true
            }
        }
    }
}
```

**相关文档**：
- 系统设计：`projectBasicInfo/logs/2026-01-09-onboarding-system-plan-cc.md`
- 状态重载修复：`projectBasicInfo/logs/2026-01-23-onboarding-state-reload-fix-plan.md`

### 9. 登录状态管理（OTOLoginStatusManager）

**状态**：已完成（2026-01-23 优化）

统一的登录状态管理单例，使用 Keychain 安全存储 Token。

#### 核心特性

```swift
class OTOLoginStatusManager: ObservableObject {
    static let shared = OTOLoginStatusManager()

    @Published private(set) var isLoggedIn: Bool = false

    func login(token: String)      // 登录（存 Keychain）
    func logout()                  // 登出（清 Keychain + 发送通知）
    func getToken() -> String?     // 获取 Token
    func getUserID() -> Int        // 获取用户 ID
    func setUserID(_ userId: Int)  // 设置用户 ID（发送 userIdDidSet 通知）
    func isTokenExpired() -> Bool  // JWT 过期检查
}
```

#### 通知机制

```swift
extension Notification.Name {
    /// 用户登出通知（重置地图、Onboarding 等）
    static let userDidLogout = Notification.Name("com.guanzhi.userDidLogout")

    /// 用户 ID 设置成功通知（Onboarding 重新加载正确用户数据）
    static let userIdDidSet = Notification.Name("com.guanzhi.userIdDidSet")
}
```

#### UserLoginModel 重置（2026-01-23 新增）

登出时自动重置登录流程状态，避免残留旧手机号和倒计时。

```swift
class UserLoginModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 监听登出通知，重置登录流程状态
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                self?.reset()
            }
            .store(in: &cancellables)
    }

    func reset() {
        phone = ""
        code = ""
        nickName = ""
        loginState = 1
        time = 0
        // ... 其他状态重置
    }
}
```

### 10. 管理后台

- 褪色曲线模拟器（核心功能）
- 褪色规则配置
- 积分规则配置
- 等级定义管理（配额倍率、待生效配置）
- 贴纸定义管理（解锁等级、基础限额、待生效配置）
- **综合查询**（2025-12-24 新增）：支持按用户ID或观之ID查询所有关联数据明细

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
| 后端 API | https://onettoo.com/api/ |
| CDN | CloudFront `E37ZE0ABRM5VX9`（`/image/*` 缓存 7 天） |
| 域名 | onettoo.com → CloudFront → 源站 52.83.127.15 |
| SSL 证书 | IAM `onettoo-com-2026`，有效期至 2027-02-23 |
| 连接方式 | AWS SSM (非 SSH) |

详细连接信息见 `02_CONNECTIONS.private.md`

---

## API 路由说明

### 后端 API 路由模式

```
/user/**            # 用户相关（登录、验证码等）
/guan/**            # 观之业务 API（需登录）
/stickers/**        # 贴纸 API（需登录）
/shares/**          # 观之操作 API（需登录）
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
| 观之完整详情 | GET | `/admin/inspector/share/{shareId}/detail` | 返回观之信息+评论/贴纸/打卡/浏览/举报明细 |
| 用户完整详情 | GET | `/admin/inspector/user/{userId}/detail` | 返回用户信息+观之/评论/贴纸/打卡/奖章明细 |

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
/image/           → 静态文件 (/home/ec2-user/images/image/)
                    Cache-Control: public, max-age=604800, immutable
/guanzhi-admin/   → 静态文件 (/var/www/guanzhi-admin/)
/api/user/        → http://127.0.0.1:8085/user/
/api/admin/       → http://127.0.0.1:8085/api/admin/
/api/             → http://127.0.0.1:8085/ (去掉 /api 前缀)
/admin/inspector/ → http://127.0.0.1:8085/admin/inspector/
```

**CDN 架构**（2026-02-13）：
```
客户端 → onettoo.com (DNS CNAME) → CloudFront CDN
  ├── /image/* → CDN 缓存 7 天（命中直返，未命中回源 Nginx）
  └── 其他路径 → 直接透传到源站（TTL=0，不缓存）
```

---

## 数据库核心表

| 表名 | 用途 | 状态 |
|------|------|------|
| `user` | 用户信息 | 使用中 |
| `share` / `guanzhi` | 观之内容 | 使用中 |
| `fade_config` | 褪色配置 | 使用中 |
| `points_rule` | 积分规则 | 使用中 |
| `level_definition` | 等级定义（含 daily_multiplier 配额倍率）| 使用中 |
| `tag_definition` | 贴纸定义（含 min_level_code、base_daily_limit）| 使用中 |
| `share_sticker_action` | 贴纸使用记录（**唯一事实来源**）| 使用中 |
| `sticker_level_quota_override` | 等级-贴纸限额覆盖配置 | 使用中 |
| `share_view_log` | 观之浏览记录 | 使用中 |
| `admin_operation_log` | 管理操作日志 | 使用中 |
| `notification` | 通知消息记录（含唯一索引 `uk_user_type_share`）| 使用中（2026-01-13 更新）|
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

## 通用 UI 组件

### 1. OverlaySheet（Overlay 弹窗）

**位置**：`View/Shared/OverlaySheet/OverlaySheetContainer.swift`

**状态**：已完成（2026-01-05）

替代 SwiftUI Sheet 的 Overlay 弹窗组件，解决 Sheet 与 NavigationStack 的层级冲突问题。

**核心特性**：
- macOS 26 风格动画：缩放（1.06x → 1.0x）+ 淡入
- 自动适配设备屏幕圆角（使用 iOS 私有 API `_displayCornerRadius`）
- 毛玻璃背景（`.ultraThinMaterial`）
- 支持条件性动画跳过（进入/返回详情时瞬间出现）
- 固定 3/4 屏幕高度，12pt 边距

**使用方式**：
```swift
.overlaySheet(
    isPresented: $isPresented,
    cornerRadius: 0,        // 0 表示使用屏幕圆角
    heightFraction: 0.75,   // 高度占比
    edgeInset: 12,          // 边距
    skipAnimation: false,   // 是否跳过动画
    onDismiss: { }
) {
    // 内容视图
}
```

**应用场景**：
- `SearchView` 中的聚合列表（通过 `useOverlayForClusterList` 开关控制）

#### 聚合列表排名系统（2026-02-17）

聚合列表内的观之按加权互动评分排序，48h 内的最新内容置顶并显示「最新」徽章。

**排名公式**（借鉴 X/Twitter 加权互动评分思路）：
```
interactionScore = 1.0×agreeCount + 3.0×checkinCount + 5.0×commentCount - 2.0×neutralCount
recencyMultiplier = pow(0.5, ageSeconds / 168h)    // 7 天半衰期
healthMultiplier = 1.0 - 0.3 × (fadeScore / 100)   // 褪色度影响
finalScore = (1 + max(0, interactionScore)) × recencyMultiplier × healthMultiplier
```

**列表排序规则**：
| 区域 | 规则 | 最多条数 |
|------|------|---------|
| 置顶区 | 48h 内发布，按 createDate 降序 | 3 |
| 排名区 | 其余观之，按 finalScore 降序 | 无限制 |

- 置顶区观之不重复出现在排名区
- 置顶区观之在 `ShareSingleView` 中显示「最新」徽章

**聚合缩略图选择**（`ClusterAnnotationView.configure()`）：
- 优先选 48h 内最新成员的缩略图
- 没有则选 createDate 最大的（UIKit 层无法访问 cachedResponsedShares，使用简化策略）

**核心文件**：`ModelsForMap/ClusterShareRanker.swift`

### 2. UIKitListKit（UIKit 列表桥接）

**位置**：`View/Shared/UIKitListKit/`

**状态**：已完成（2026-01-05）

解决 SwiftUI ScrollView 触底回弹（"缓缓回滑"）问题的 UIKit 列表组件。

**核心文件**：
```
UIKitListKit/
├── HostingTableView.swift           # SwiftUI Representable 桥接
├── HostingTableViewController.swift # UITableViewController 实现
└── TableEndFooterView.swift         # 列表底部 Footer
```

**核心特性**：
- 使用 `UIHostingConfiguration`（iOS 16+）承载 SwiftUI 行视图
- `bounces = false` 禁用底部回弹
- `alwaysBounceVertical = true` 确保条目较少时也可滑动
- 透明背景，支持毛玻璃效果透过
- 支持滚动位置恢复
- 预估行高优化

**使用方式**：
```swift
HostingTableView(
    items: items,
    idKeyPath: \.id,
    bouncesEnabled: false,
    showsSeparators: false
) { item in
    // SwiftUI 行视图
    RowView(item: item)
}
.onSelect { item in
    // 点击处理
}
.footer(.text("- 到底啦 -"))
```

**应用场景**：
- 聚合列表（ClusterList）中的观之列表

#### 聚合列表状态恢复机制（2026-01-23）

**问题场景**：从聚合列表进入详情页，再进入用户主页（OthersView），最后返回时，底部 sheet 和 MapOverlayView 错误地与聚合列表同时显示。

**根因**：
1. `@State` 变量在导航过程中因视图重建而丢失
2. 嵌套的 ShareDetailView（用户主页中点击其他观之）返回时也会触发恢复逻辑，过早清空保存的状态

**三层保护机制**：

| 层级 | 位置 | 保护措施 |
|------|------|----------|
| 1. 状态持久化 | `SearchViewModel` | 将 `savedClusterAnnotations` 等从 `@State` 移到 `@Published`，避免视图重建丢失 |
| 2. 导航栈检查 | `SearchView.restoreClusterListIfNeeded()` | 只有 `path.isEmpty` 时才恢复，防止嵌套详情页过早触发 |
| 3. 条件检查 | `ShareDetailView.onDisappear` | 检查 `shouldRestoreClusterList`，避免覆盖聚合列表恢复路径 |

**关键代码**：
```swift
// SearchViewModel.swift - 状态持久化
@Published var savedClusterAnnotations: [CustomAnnotation] = []
@Published var savedClusterListDetent: PresentationDetent = .medium
@Published var savedScrollToShareId: Int? = nil

// SearchView.swift - 导航栈检查
private func restoreClusterListIfNeeded() {
    guard navigationCoordinator.path.isEmpty else { return }  // ✅ 关键检查
    guard appState.shouldRestoreClusterList else { return }
    guard !searchViewModel.savedClusterAnnotations.isEmpty else { return }
    // 执行恢复...
}
```

**相关文档**：`projectBasicInfo/logs/2026-01-23-cluster-list-state-restoration-fix-cc.md`

### 3. ImagePlaceholder（图片占位符组件）

**位置**：`View/Shared/ImagePlaceholder.swift`

**状态**：已完成（2026-01-08）

统一的图片加载状态占位符组件，提供一致的加载中/失败视觉反馈。

**SF 符号**：
| 状态 | 符号 | 效果 |
|------|------|------|
| 加载中 | `wand.and.rays.inverse` | 变量颜色动画（迭代、反向）|
| 加载失败 | `photo.badge.exclamationmark` | 静态图标 |

**提供的组件**：
```swift
// SwiftUI 方形占位符（用于列表项）
ImagePlaceholderView(state: .loading, size: 120)
ImagePlaceholderView(state: .failed, size: 120)

// SwiftUI 圆形占位符（用于地图标注）
CircularImagePlaceholderView(state: .loading, size: 64)
CircularImagePlaceholderView(state: .failed, size: 64)

// UIKit 辅助方法（用于 MKAnnotationView）
ImagePlaceholderUIKit.configureForLoading(imageView, pointSize: 24)
ImagePlaceholderUIKit.configureForFailed(imageView, pointSize: 24)
```

**应用场景**：
| 视图 | 组件类型 |
|------|----------|
| `CustomMKAnnotationView` | UIKit（脉冲动画）|
| `ClusterAnnotationView` | UIKit（脉冲动画）|
| `MapAnnotationView` | SwiftUI 圆形 |
| `ShareSingleView` | SwiftUI 方形 |

**图片缓存通知机制**（2026-01-08）：

当图片加载失败显示占位符后，如果该图片稍后被其他地方成功加载（如详情页），标注视图会自动更新。

```swift
// ImageCache 发送通知
NotificationCenter.default.post(
    name: .imageCacheDidLoadImage,
    object: nil,
    userInfo: ["url": url]
)

// 标注视图监听并刷新
NotificationCenter.default.addObserver(
    forName: .imageCacheDidLoadImage, ...
) { notification in
    // 如果当前显示占位符且 URL 匹配，重新加载
}
```

### 4. 地图标注组件（MKMapView）

**位置**：`View/MapPages/`

**状态**：已完成（2026-01-22 点击修复）

地图标注采用 MKMapView + 自定义 MKAnnotationView 实现，支持聚合和点击交互。

**核心文件**：
```
View/MapPages/
├── MKMapViewWrapper.swift          # UIViewRepresentable 包装器
├── MKMapViewCoordinator.swift      # MKMapViewDelegate 实现
├── CustomMKAnnotationView.swift    # 单个标注视图
└── ClusterAnnotationView.swift     # 聚合标注视图（缩略图：48h内最新优先）
```

**聚合抵抗机制**：

`CustomMKAnnotationView` 通过缩小 `frame`（碰撞盒）来减少聚合敏感度：
- 视觉尺寸：约 84×101pt
- 碰撞盒尺寸：12×17pt（通过 `clusterResistanceHorizontal/Vertical` 参数控制）
- 视觉内容通过子视图溢出显示（`clipsToBounds = false`）

**点击机制（重要）**：

⚠️ MKMapView 的 `didSelect` 使用 `frame` 而非 `point(inside:with:)` 判断点击，无法通过重写方法解耦。

| 标注类型 | 点击触发方式 | 原因 |
|---------|-------------|------|
| 单个标注 | `touchesEnded` → `onTap` 回调 | 绕过 didSelect，使用完整视觉区域 |
| 聚合标注 | `didSelect` | frame 本身就是完整尺寸 |

**相关文档**：`projectBasicInfo/logs/2026-01-22-map-annotation-tap-fix-cc.md`

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
| 聚合列表Overlay优化 | `projectBasicInfo/logs/2026-01-05-cluster-list-overlay-optimization-cc.md` | UIKitListKit + OverlaySheet 组件 |
| 褪色度UI显示修复 | `projectBasicInfo/logs/2026-01-06-fade-score-ui-fix-cc.md` | 聚合列表fadeScore修复 |
| 褪色白化效果 | `projectBasicInfo/logs/2026-01-06-fade-veil-processor-complete-cc.md` | fadeScore>=90缩略图白化 |
| fadeScore=100隐藏 | `projectBasicInfo/logs/2026-01-06-fade-score-100-hide-plan.md` | 已褪色观之Home Map不可见 |
| 用户档案SSOT重构 | `projectBasicInfo/logs/2026-01-07-user-profile-ssot-implementation-cc.md` | 统一用户数据模型+等级显示修复 |
| 图片占位符统一+通知修复 | `projectBasicInfo/logs/2026-01-08-image-placeholder-unification-cc.md` | 占位符组件+缓存通知+OneCode修复 |
| 通知术语统一 | `projectBasicInfo/logs/2026-01-08-notification-terminology-update-cc.md` | 通知模板"分享"→"观之" |
| 通知 channel 语义统一 | `projectBasicInfo/logs/2026-01-08-notification-channel-unification-cc.md` | apns→push 统一抽象层 |
| Time SSOT 时区统一方案 | `projectBasicInfo/logs/2026-01-10-time-ssot-plan-cc.md` | UTC 时区 SSOT 设计 |
| 后端时区修复完成 | `projectBasicInfo/logs/2026-01-11-backend-time-ssot-completion.md` | JDBC 时区配置 + 验证器 |
| 褪色通知幂等修复 | `projectBasicInfo/logs/2026-01-13-fade-notification-idempotent-fix-cc.md` | 唯一索引幂等 + 重复推送修复 |
| 地图标注点击修复 | `projectBasicInfo/logs/2026-01-22-map-annotation-tap-fix-cc.md` | touchesEnded 绕过 didSelect |
| 公测前安全审计与修复 | `projectBasicInfo/logs/2026-01-22-pre-beta-security-audit-cc.md` | P0/P1/P2/P3 安全审计 + 修复详情 + 部署验证 |
| 地图锁定修复计划 | `projectBasicInfo/logs/2026-01-23-map-locking-fix-plan.md` | 重新登录后地图锁定问题修复 |
| **Onboarding 状态重载修复** | `projectBasicInfo/logs/2026-01-23-onboarding-state-reload-fix-plan.md` | userId 变化后状态重载 + UI 恢复 + 登录流程重置 |
| **聚合列表状态恢复修复** | `projectBasicInfo/logs/2026-01-23-cluster-list-state-restoration-fix-cc.md` | 三层保护机制：状态持久化 + path.isEmpty 检查 + 条件检查 |
| 媒体上传下载优化 | `projectBasicInfo/logs/2026-02-13-media-upload-download-optimization-cc.md` | 并行上传+压缩、缩略图优先下载 |
| **查看体验+CDN优化** | `projectBasicInfo/logs/2026-02-13-viewing-experience-cdn-optimization-cc.md` | AsyncImage重试、字节级进度、缩略图缓存、CloudFront CDN |
| **聚合列表排名+最新徽章** | `projectBasicInfo/logs/2026-02-17-cluster-ranking-badge-cc.md` | 加权互动评分排序、48h置顶、最新徽章、缩略图优先选择 |

---

## 开发团队

- **项目负责人**: Zaptain
- **AI 协作**: Claude Code, Gemini, GPT
