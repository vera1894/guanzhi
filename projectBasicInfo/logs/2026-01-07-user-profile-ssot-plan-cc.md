# 用户档案 SSOT 统一方案实施计划

**日期**：2026-01-07
**角色**：CC (Claude Code)
**状态**：待实施
**版本**：v3（根据 GPT 二次审查优化）

---

## 背景

### 问题现象
- 当前用户主页 OneCode 下方显示等级标签
- 其他用户主页没有等级显示

### 根因分析
1. **数据模型分裂**：`LocalUserProfile` 有 `levelCode`，`OtherUserProfile` 没有
2. **存储链路分裂**：当前用户落 SwiftData，他人只存内存（刷新/重进会丢失）
3. **UI 代码重复**：MyView/OthersView 各自拼头部信息

### 目标
- 一次彻底解决，不分阶段补洞
- 建立 SSOT（Single Source of Truth）用户档案管理
- 统一 UI 组件，未来新增字段不再出现"只我有、他人没有"

---

## 一、SSOT 规则定义（核心约束）

### 1.1 数据权威顺序
```
Network (UserFullInfoModel)
    ↓ 统一保存（MainActor）
SwiftData (UserProfile)
    ↓ @Query 查询
UI (UserProfileDisplayModel → ProfileHeaderView)
```

### 1.2 账号切换数据隔离策略
**采用方案**：登出/切换账号时清空 `UserProfile` 表

理由：
- 开发期最稳，避免 ownerUserId 增加复杂度
- 防止 A 账号看到 B 账号缓存的他人资料

**必须覆盖的路径**：
- 手动登出
- Token 失效被动登出
- 切换账号

### 1.3 Optional 字段策略
- **存储层**：所有字段使用 Optional（`String?`），与后端 API 保持一致
- **展示层**：在 `UserProfileDisplayModel` 中做 fallback（如 `nickname ?? "未知用户"`）
- **禁止**：在存储层写死 fallback 值（避免国际化/文案变化需迁移数据）

### 1.4 UI 数据绑定策略（关键决策：选择 @Query 主路线）
**主路线**：View 端使用 `@Query` 按 userId 查询 UserProfile
- SwiftData 自动触发 UI 刷新，无需手动管理
- Manager 只发布 `currentUserId: Int` / `viewedUserId: Int`，**不发布 UserProfile 引用**
- **禁止**：UI 直接读取 SwiftData 模型字段，必须通过 DisplayModel

### 1.5 ModelContext 生命周期与线程约束（关键决策）
- **注入点**：App 启动时在根 View 通过 `.environment(\.modelContext)` 注入
- **线程约束**：所有保存操作必须在 `@MainActor` 下执行
- **Manager 约束**：`UserProfileManager` 整体标记 `@MainActor`，避免跨线程 context 使用

### 1.6 TitleDO 存储策略（关键决策：直接用 Data）
**采用方案**：使用 `titleDOSData: Data?`（JSON 编码），不用 `[TitleDO]?`

理由：
- 一次到位，省掉"验证后再改"的返工
- 避免 SwiftData 数组存储的潜在兼容问题
- TitleDO 未来可能演进，Data 存储更灵活

**编码注意**：当 `titleDOS == nil` 时，`titleDOSData` 应为 `nil`，而不是编码成 `"null"`
```swift
// 正确写法
titleDOSData = userInfo.titleDOS.flatMap { try? JSONEncoder().encode($0) }

// 错误写法（会把 nil 编码成 "null"）
// titleDOSData = try? JSONEncoder().encode(userInfo.titleDOS)
```

### 1.7 currentUserId 事实源统一（关键决策）
**采用方案**：全走 `OTOLoginStatusManager.shared.getUserID()`

理由：
- 现有登录系统已基于 `OTOLoginStatusManager` 构建
- 避免两套"当前用户 id"的事实源冲突
- Manager 不再发布 `currentUserId`，只发布 `viewedUserId`（他人页面用）

**View 获取当前用户 id**：
```swift
let currentUserId = OTOLoginStatusManager.shared.getUserID()
```

### 1.8 头像加载策略（统一处理）
**问题**：MyView 有头像缓存，OthersView 用占位图，导致"组件统一但体验不统一"

**采用方案**：ProfileHeaderView 接受 `avatarPath: String?`，内部统一处理加载

```swift
struct ProfileHeaderView: View {
    let profile: UserProfileDisplayModel
    let mode: ProfileMode
    let cachedAvatarImage: Image?  // 已缓存的头像（当前用户）
    // ...

    private var displayAvatar: Image {
        if let cached = cachedAvatarImage {
            return cached
        }
        // 未来：可扩展为 AsyncImage 加载他人头像
        return Image("例子")
    }
}
```

**未来扩展**：可引入 `AvatarLoaderView` 组件统一处理加载态/占位态

### 1.9 清表触发点完善
**必须覆盖的路径**：
1. 手动登出按钮
2. Token 失效被动登出
3. 切换账号
4. **App 冷启动时 token 已过期**（新增）

**启动时检查逻辑**：
```swift
// 在 App 启动时检查
if !OTOLoginStatusManager.shared.isLoggedIn {
    try? userProfileManager.clearAllUserProfiles()
}
```

**异常安全**：`removeItem(at:)` 已用 `try?`，确保不影响主流程

### 1.10 View Update 周期安全（避免 Publishing 警告）
**风险**：`onAppear` 立即触发网络请求 → 回调立即改 SwiftData → 卡在 View update 周期

**解决方案**：在 `onAppear` 的 Task 中使用延迟或确保在 MainActor 外部完成网络请求后再回写

```swift
.onAppear {
    Task {
        // 网络请求在后台完成
        try await userProfileManager.fetchUserFullInfo(userId: userId)
        // saveToUserProfile 内部已标记 @MainActor，会自动切回主线程
    }
}
```

**额外保护**：避免短时间多次写库，可在 Manager 中增加节流逻辑（可选）

---

## 二、字段设计

### 2.1 统一数据模型 `UserProfile`

| 字段 | 类型 | 来源 | 说明 |
|------|------|------|------|
| `id` | `Int` | API | 主键，唯一标识 |
| `name` | `String?` | API | OneCode 原始值 |
| `nickname` | `String?` | API | 昵称 |
| `phone` | `String?` | API | 手机号 |
| `photo` | `String?` | API | 头像路径 |
| `code` | `String?` | API | 用户码 |
| `createDate` | `Int64?` | API | 创建时间 |
| `jpushId` | `String?` | API | 极光推送 ID |
| `titleDOSData` | `Data?` | API | 称号列表（JSON 编码） |
| `levelCode` | `String?` | API | 等级代码 |
| `pointsTotal` | `Int?` | API | 总积分 |
| `platform` | `String?` | API | 平台（扩展） |
| `lastUpdated` | `Date?` | 本地 | 缓存更新时间 |

### 2.2 统一展示模型 `UserProfileDisplayModel`

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `Int` | 用户 ID |
| `displayNickname` | `String` | 昵称（fallback: "未知用户"） |
| `displayOneCode` | `String` | 处理后的 OneCode（遮挡后） |
| `isOneCodeMasked` | `Bool` | OneCode 是否被遮挡 |
| `avatarPath` | `String?` | 头像路径 |
| `levelName` | `String` | 等级中文名（通过 UserLevelMapping） |
| `titleDOS` | `[TitleDO]?` | 称号列表（从 Data 解码） |

### 2.3 Mapper 扩展（分离映射逻辑）
**新建文件**：`Models/UserProfileMapper.swift`

将 `toDisplayModel()` 映射逻辑放到单独文件，避免 UI 改动污染数据层：
```swift
extension UserProfile {
    func toDisplayModel() -> UserProfileDisplayModel { ... }
}
```

---

## 三、实施步骤（同一 PR 完成）

### Step 1：新建统一数据模型
**新建文件**：`Data/UserProfile.swift`

```swift
import SwiftData
import Foundation

@Model
class UserProfile {
    @Attribute(.unique) var id: Int
    var name: String?
    var nickname: String?
    var phone: String?
    var photo: String?
    var code: String?
    var createDate: Int64?
    var jpushId: String?
    var titleDOSData: Data?      // JSON 编码存储
    var levelCode: String?
    var pointsTotal: Int?
    var platform: String?
    var lastUpdated: Date?

    init(id: Int, name: String? = nil, nickname: String? = nil,
         phone: String? = nil, photo: String? = nil, code: String? = nil,
         createDate: Int64? = nil, jpushId: String? = nil,
         titleDOSData: Data? = nil, levelCode: String? = nil,
         pointsTotal: Int? = nil, platform: String? = nil) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.phone = phone
        self.photo = photo
        self.code = code
        self.createDate = createDate
        self.jpushId = jpushId
        self.titleDOSData = titleDOSData
        self.levelCode = levelCode
        self.pointsTotal = pointsTotal
        self.platform = platform
        self.lastUpdated = Date()
    }

    /// 解码 TitleDO 数组
    var titleDOS: [TitleDO]? {
        guard let data = titleDOSData else { return nil }
        return try? JSONDecoder().decode([TitleDO].self, from: data)
    }
}
```

### Step 2：新建统一展示模型 + Mapper
**新建文件**：`Models/UserProfileDisplayModel.swift`

```swift
import Foundation

struct UserProfileDisplayModel {
    let id: Int
    let displayNickname: String
    let displayOneCode: String
    let isOneCodeMasked: Bool
    let avatarPath: String?
    let levelName: String
    let titleDOS: [TitleDO]?
}
```

**新建文件**：`Models/UserProfileMapper.swift`

```swift
import Foundation

extension UserProfile {
    /// 转换为展示模型（映射逻辑与数据层分离）
    func toDisplayModel() -> UserProfileDisplayModel {
        let masked = (name == phone) || (name == nil) || (name?.isEmpty == true)
        return UserProfileDisplayModel(
            id: id,
            displayNickname: nickname ?? "未知用户",
            displayOneCode: masked ? "⬛️⬛️⬛️⬛️" : (name ?? "⬛️⬛️⬛️⬛️"),
            isOneCodeMasked: masked,
            avatarPath: photo,
            levelName: UserLevelMapping.getName(for: levelCode),
            titleDOS: titleDOS
        )
    }
}
```

### Step 3：修改 UserProfileManager（只写新表）
**修改文件**：`UserProfileManager.swift`

#### 3.1 修改属性（只发布 viewedUserId）
```swift
// 移除：@Published var otherUserProfile: UserFullInfoModel?

// 新增：只发布他人 userId，View 用 @Query 自己查
// 注意：不发布 currentUserId，统一用 OTOLoginStatusManager.shared.getUserID()
@Published var viewedUserId: Int?
```

#### 3.2 新增统一保存方法
```swift
/// 统一保存到 UserProfile（唯一写入路径）
@MainActor
private func saveToUserProfile(userInfo: UserFullInfoModel) throws {
    guard let context = context else { return }

    // 编码 TitleDO 数组（注意：nil 时应为 nil，不是 "null"）
    let titleDOSData = userInfo.titleDOS.flatMap { try? JSONEncoder().encode($0) }

    let existing = findUserProfile(userId: userInfo.id)
    if let existing = existing {
        // 更新
        existing.name = userInfo.name
        existing.nickname = userInfo.nickname
        existing.phone = userInfo.phone
        existing.photo = userInfo.photo
        existing.code = userInfo.code
        existing.createDate = userInfo.createDate
        existing.jpushId = userInfo.jpushId
        existing.titleDOSData = titleDOSData
        existing.levelCode = userInfo.levelCode
        existing.pointsTotal = userInfo.pointsTotal
        existing.platform = userInfo.platform
        existing.lastUpdated = Date()
    } else {
        // 新建
        let newUser = UserProfile(
            id: userInfo.id,
            name: userInfo.name,
            nickname: userInfo.nickname,
            phone: userInfo.phone,
            photo: userInfo.photo,
            code: userInfo.code,
            createDate: userInfo.createDate,
            jpushId: userInfo.jpushId,
            titleDOSData: titleDOSData,
            levelCode: userInfo.levelCode,
            pointsTotal: userInfo.pointsTotal,
            platform: userInfo.platform
        )
        context.insert(newUser)
    }

    try context.save()
}

@MainActor
private func findUserProfile(userId: Int) -> UserProfile? {
    guard let context = context else { return nil }
    let descriptor = FetchDescriptor<UserProfile>(
        predicate: #Predicate { $0.id == userId }
    )
    return (try? context.fetch(descriptor))?.first
}
```

#### 3.3 修改 fetchUserFullInfo（只写新表，不双写）
```swift
// 统一写入新表，不再区分 current/other
try saveToUserProfile(userInfo: userData)

if isCurrentLoggedUser(userId: userId) {
    // 旧表暂时保留写入（过渡期，可加 DEBUG 开关控制）
    #if DEBUG
    try saveToSwiftData(userInfo: userData)
    self.localUserProfile = findLocalUserInSwiftData(userId: userId)
    #endif
    // 不发布 currentUserId，View 直接用 OTOLoginStatusManager
} else {
    self.viewedUserId = userId
}
```

#### 3.4 修改清空方法（覆盖所有登出路径）
```swift
/// 清空所有用户档案（登出/切换账号/token失效/冷启动无token时调用）
@MainActor
func clearAllUserProfiles() throws {
    guard let context = context else { return }

    // 清空 UserProfile 表
    let descriptor = FetchDescriptor<UserProfile>()
    let allProfiles = try context.fetch(descriptor)
    for profile in allProfiles {
        context.delete(profile)
    }

    try context.save()

    // 重置状态
    self.viewedUserId = nil
    self.avatarImage = nil
    self.localUserProfile = nil  // 旧模型也清空

    // 清除头像缓存（异常安全）
    try? FileManager.default.removeItem(at: getAvatarCacheURL())
}
```

#### 3.5 新增启动时检查（App 冷启动时 token 已过期）
```swift
/// 在 App 启动时调用，确保未登录时清空缓存
@MainActor
func checkAndClearIfNotLoggedIn() {
    if !OTOLoginStatusManager.shared.isLoggedIn {
        try? clearAllUserProfiles()
    }
}
```

### Step 4：新建通用头部组件
**新建文件**：`View/Profile/ProfileHeaderView.swift`

```swift
import SwiftUI

enum ProfileMode {
    case me        // 显示"修改资料"按钮
    case other     // 未来：显示"关注/私信"按钮
}

struct ProfileHeaderView: View {
    let profile: UserProfileDisplayModel
    let mode: ProfileMode
    let cachedAvatarImage: Image?  // 已缓存的头像（当前用户传入，他人传 nil）
    let onAvatarTap: (() -> Void)?
    let onActionTap: (() -> Void)?

    /// 统一头像展示逻辑
    private var displayAvatar: Image {
        if let cached = cachedAvatarImage {
            return cached
        }
        // 未来可扩展：根据 profile.avatarPath 用 AsyncImage 加载
        return Image("例子")
    }

    var body: some View {
        HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
            // 头像
            Button(action: { onAvatarTap?() }) {}
                .buttonStyle(AvatarStyle_l(
                    isEnabled: true,
                    profileImage: displayAvatar,
                    borderThickness: 4
                ))

            VStack(alignment: .leading) {
                // 昵称
                Text(profile.displayNickname)
                    .font(.headline)

                // OneCode
                Text("OneCode: \(profile.displayOneCode)")
                    .font(.subheadline)

                // 等级
                Text("等级：「\(profile.levelName)」")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 操作按钮
            if mode == .me {
                Button(action: { onActionTap?() }) {
                    Text("修改资料")
                }
                .buttonStyle(ButtonStyle_capsuleHugPrimary_s(isEnabled: true))
            }
            // mode == .other 时，未来可添加关注/私信按钮
        }
        .padding(.horizontal)
        .padding(.top, Constants.spacingSpacingXs)
    }
}
```

### Step 5：重构 MyView（使用 @Query 按 id 过滤）
**修改文件**：`MyView.swift`

```swift
struct MyView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userProfileManager: UserProfileManager

    // 按当前用户 id 查询（避免全表拉进内存）
    // 注意：SwiftData @Query 的 filter 需要在编译时确定，
    // 这里用计算属性在 body 中过滤单条记录
    @Query private var profiles: [UserProfile]

    private var currentUserId: Int {
        OTOLoginStatusManager.shared.getUserID()
    }

    private var currentProfile: UserProfile? {
        // 单条过滤，性能可接受
        profiles.first { $0.id == currentUserId }
    }

    var body: some View {
        // ...
        if let profile = currentProfile {
            let displayModel = profile.toDisplayModel()
            ProfileHeaderView(
                profile: displayModel,
                mode: .me,
                cachedAvatarImage: avatarImage,  // 传入缓存的头像
                onAvatarTap: { isEditAvatarView.toggle() },
                onActionTap: { navigationCoordinator.path.append(Route.editProfileView) }
            )
        }
        // ...
    }
}
```

**优化方案（可选）**：如果 @Query 支持动态 predicate，可用 init 注入：
```swift
// 更高效的按 id 查询（需要 SwiftData 支持）
init() {
    let userId = OTOLoginStatusManager.shared.getUserID()
    _profiles = Query(filter: #Predicate<UserProfile> { $0.id == userId })
}
```

### Step 6：重构 OthersView（使用 @Query 按 id 过滤）
**修改文件**：`OthersView.swift`

```swift
struct OthersView: View {
    let userId: Int

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var userProfileManager: UserProfileManager

    // 按传入的 userId 查询
    @Query private var profiles: [UserProfile]

    private var viewedProfile: UserProfile? {
        profiles.first { $0.id == userId }
    }

    // 初始化时设置 predicate（更高效）
    init(userId: Int) {
        self.userId = userId
        // 动态 predicate 需要 SwiftData 支持，否则用 body 内过滤
        // _profiles = Query(filter: #Predicate<UserProfile> { $0.id == userId })
    }

    var body: some View {
        // ...
        if let profile = viewedProfile {
            let displayModel = profile.toDisplayModel()
            ProfileHeaderView(
                profile: displayModel,
                mode: .other,
                cachedAvatarImage: nil,  // 他人无缓存头像
                onAvatarTap: nil,
                onActionTap: nil
            )
        }
        // ...
        .onAppear {
            Task {
                try await userProfileManager.fetchUserFullInfo(userId: userId)
            }
        }
    }
}
```

### Step 7：注册新模型
**修改文件**：`guanzhiApp.swift`

```swift
.modelContainer(for: [
    UserProfile.self,           // 新增
    LocalUserProfile.self,      // 暂时保留（过渡期）
    // ...其他模型
])
```

### Step 8：确保登出路径调用清空方法
**检查并修改以下位置**：
- [ ] 手动登出按钮 → 调用 `clearAllUserProfiles()`
- [ ] Token 失效处理 → 调用 `clearAllUserProfiles()`
- [ ] 切换账号逻辑 → 调用 `clearAllUserProfiles()`
- [ ] App 启动时 → 调用 `checkAndClearIfNotLoggedIn()`（在 guanzhiApp.swift 或根 View 的 onAppear）

### Step 9：移除旧读取依赖（同 PR 完成）
- [ ] MyView 不再直接读取 `localUserProfile`
- [ ] OthersView 不再读取 `otherUserProfile: UserFullInfoModel?`
- [ ] 确认所有头部渲染通过 `ProfileHeaderView`
- [ ] 移除 Manager 中 `otherUserProfile: UserFullInfoModel?` 属性

---

## 四、文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| **新建** | `Data/UserProfile.swift` | 统一 SwiftData 模型 |
| **新建** | `Models/UserProfileDisplayModel.swift` | 统一展示模型 |
| **新建** | `Models/UserProfileMapper.swift` | 模型映射扩展（分离关注点） |
| **新建** | `View/Profile/ProfileHeaderView.swift` | 通用头部组件 |
| **修改** | `UserProfileManager.swift` | 统一保存 + 只发布 userId |
| **修改** | `MyView.swift` | 使用 @Query + ProfileHeaderView |
| **修改** | `OthersView.swift` | 使用 @Query + ProfileHeaderView |
| **修改** | `guanzhiApp.swift` | 注册新模型 |
| **修改** | 登出相关代码 | 调用 `clearAllUserProfiles()` |
| **弃用** | `LocalUserProfile.swift` | 保留文件，DEBUG 模式写入 |
| **弃用** | `OtherUserProfile.swift` | 不再使用 |

---

## 五、验证清单

### 功能验证
- [ ] 当前用户主页：等级正常显示
- [ ] 任意他人主页：等级正常显示
- [ ] 退出 App 重进：他人等级仍存在（SwiftData 缓存）
- [ ] 网络慢时：先显示缓存，再刷新（无闪烁）
- [ ] MyView/OthersView 头部 UI 一致
- [ ] @Query 自动刷新：保存后 UI 立即更新

### 账号隔离验证
- [ ] 手动登出 → UserProfile 表清空
- [ ] Token 失效 → UserProfile 表清空
- [ ] 切换账号 → 不会看到前账号的他人资料

### 数据存储验证
- [ ] `titleDOSData: Data?` 正常存取（JSON 编解码）
- [ ] `titleDOS == nil` 时，`titleDOSData` 为 `nil`（不是 "null"）
- [ ] 重启 App 后数据仍可读取
- [ ] 所有保存操作在 MainActor 下执行

### 线程安全验证
- [ ] 无 "Publishing changes from within view updates" 警告
- [ ] ModelContext 只在主线程使用
- [ ] onAppear 中的 Task 不会触发 View update 周期冲突

### 事实源一致性验证
- [ ] MyView 使用 `OTOLoginStatusManager.shared.getUserID()` 获取 currentUserId
- [ ] Manager 不发布 currentUserId，只发布 viewedUserId

---

## 六、后续清理（可单独 PR）

1. 移除 `#if DEBUG` 中的旧表写入逻辑
2. 移除 `LocalUserProfile.swift` 文件
3. 移除 `OtherUserProfile.swift` 文件
4. 移除 `UserProfileManager` 中的 `localUserProfile` 属性
5. 移除 `saveToSwiftData()` 旧方法
6. 更新 `guanzhiApp.swift` 移除旧模型注册

---

## 七、关键决策总结

| 决策点 | 选择 | 理由 |
|--------|------|------|
| UI 绑定策略 | `@Query` 主路线 | SwiftData 自动触发刷新，更稳定 |
| @Query 过滤方式 | body 内 `profiles.first` | SwiftData 动态 predicate 支持有限，单条过滤性能可接受 |
| Manager 发布内容 | 只发布 `viewedUserId` | 避免两套 currentUserId 事实源 |
| currentUserId 事实源 | `OTOLoginStatusManager` | 现有登录系统已基于此构建 |
| TitleDO 存储 | `Data?` JSON 编码 | 一次到位，避免兼容问题 |
| TitleDO nil 编码 | `flatMap` 方式 | 避免 nil 被编码成 "null" 导致解码失败 |
| 账号隔离 | 清空整表 | 开发期最稳，实现简单 |
| 清表触发点 | 4 个路径全覆盖 | 包含冷启动 token 过期场景 |
| 双写策略 | 只写新表 | 简化逻辑，旧表 DEBUG 模式可选 |
| Mapper 位置 | 单独扩展文件 | 分离 UI 逻辑与数据层 |
| 头像策略 | 统一 displayAvatar 计算属性 | 当前用户用缓存，他人用占位图，未来可扩展 |

---

## 八、预计工作量

| 步骤 | 预计代码量 |
|------|-----------|
| Step 1 新模型 | ~50 行 |
| Step 2 展示模型+Mapper | ~50 行 |
| Step 3 Manager 改造 | ~80 行 |
| Step 4 ProfileHeaderView | ~60 行 |
| Step 5-6 视图重构 | ~60 行 |
| Step 7-9 注册+清理 | ~30 行 |

**总计**：约 330 行代码，一次 PR 完成

---

## 九、实施验收点（每步完成后检查）

| Step | 验收点 |
|------|--------|
| Step 1 | 编译通过，UserProfile 模型可创建实例 |
| Step 2 | `toDisplayModel()` 返回正确的展示数据 |
| Step 3 | `fetchUserFullInfo()` 成功写入 UserProfile 表 |
| Step 4 | ProfileHeaderView 单独预览正常 |
| Step 5 | MyView 显示当前用户等级 |
| Step 6 | OthersView 显示他人等级 |
| Step 7 | App 启动无崩溃 |
| Step 8 | 登出后 UserProfile 表清空 |
| Step 9 | 无旧模型依赖编译警告 |
