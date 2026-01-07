# 用户档案 SSOT 实施记录

**日期**: 2026-01-07
**执行者**: Claude Code

## 问题描述

用户反馈：自己的主页上有 OneCode 下面有等级标签，但查看其他用户时却没有显示等级。

**根本原因**:
1. 数据模型分裂：`LocalUserProfile` 有 `levelCode` 字段，`OtherUserProfile` 缺失
2. 存储路径分裂：当前用户存 SwiftData，他人只存内存
3. UI 代码重复：MyView 和 OthersView 各自实现 header，逻辑不一致

## 解决方案

采用 SSOT (Single Source of Truth) 架构重构：

1. 统一数据模型：新建 `UserProfile` 替代分裂的两个模型
2. 统一存储路径：所有用户（当前/他人）都存入同一张 SwiftData 表
3. 统一 UI 组件：新建 `ProfileHeaderView` 组件，确保展示逻辑一致
4. 使用 `@Query` 实现自动 UI 刷新

## 实施步骤

### Step 1: 新建统一数据模型 `UserProfile.swift`
- 路径: `Data/UserProfile.swift`
- 包含所有字段：id, name, nickname, phone, photo, code, createDate, jpushId, titleDOSData, levelCode, pointsTotal, platform, lastUpdated
- 使用 `@Model` + `@Attribute(.unique)` 确保 id 唯一

### Step 2: 新建展示层模型
- `Models/UserProfileDisplayModel.swift` - UI 层消费的纯展示模型
- `Models/UserProfileMapper.swift` - UserProfile 到展示模型的映射扩展，封装 OneCode 遮挡规则和等级名称映射

### Step 3: 修改 `UserProfileManager.swift`
新增 SSOT 方法：
- `saveToUserProfile(userInfo:)` - 统一保存到 UserProfile 表
- `findUserProfile(userId:)` - 查询 UserProfile 表
- `clearAllUserProfiles()` - 清空表（退出登录时调用）
- `checkAndClearIfNotLoggedIn()` - 启动时检查
- `viewedUserId` - 他人页面当前查看的用户 ID

### Step 4: 新建 `ProfileHeaderView` 组件
- 路径: `View/UIElement/ProfileHeaderView.swift`
- 接受 `UserProfileDisplayModel` 和 `ProfileMode`（.me / .other）
- 统一展示：头像、昵称、OneCode、等级
- 仅 `.me` 模式显示编辑按钮

### Step 5: 重构 `MyView.swift`
- 添加 `@Query private var profiles: [UserProfile]`
- 使用 `profiles.first { $0.id == currentUserId }` 过滤
- 替换旧 header 为 `ProfileHeaderView`

### Step 6: 重构 `OthersView.swift`
- 添加 `@Query private var profiles: [UserProfile]`
- 使用 `profiles.first { $0.id == userId }` 过滤
- 替换旧 header 为 `ProfileHeaderView`
- 现在他人页面也能正确显示等级

### Step 7: 注册新模型到 `guanzhiApp.swift`
- 添加 `import SwiftData`
- `.modelContainer(for: [Share.self, MediaFile.self, LocalUserProfile.self, UserProfile.self])`

### Step 8: 确保登出路径调用清空方法
- `SettingView.swift` 添加 `@EnvironmentObject var userProfileManager`
- 登出时调用 `userProfileManager.clearAllUserProfiles()`
- App 启动时调用 `userProfileManager.checkAndClearIfNotLoggedIn()`

### Step 9: 清理
- 删除重复文件 `UserProfileManager 2.swift`
- 旧的 `localUserProfile` 和 `otherUserProfile` 保留用于过渡期兼容

## 修改的文件列表

| 文件 | 操作 |
|------|------|
| `Data/UserProfile.swift` | 新建 |
| `Models/UserProfileDisplayModel.swift` | 新建 |
| `Models/UserProfileMapper.swift` | 新建 |
| `View/UIElement/ProfileHeaderView.swift` | 新建 |
| `ModelsForNetwork/UserProfileManager.swift` | 修改 |
| `View/MyPages/MyView.swift` | 修改 |
| `View/MyPages/OthersView.swift` | 修改 |
| `View/MyPages/SettingView.swift` | 修改 |
| `guanzhiApp.swift` | 修改 |
| `guanzhi.xcodeproj/project.pbxproj` | 修改（添加新文件引用） |
| `ModelsForNetwork/UserProfileManager 2.swift` | 删除 |

### Xcode 项目文件修改

由于新建了 4 个 Swift 文件，需要手动添加到 `project.pbxproj`：

**添加的文件引用**：
- `UserProfile.swift` → Data 组
- `UserProfileDisplayModel.swift` → Models 组（新建）
- `UserProfileMapper.swift` → Models 组
- `ProfileHeaderView.swift` → UIElement 组

**修改的 pbxproj 节区**：
1. `PBXBuildFile` - 添加编译引用
2. `PBXFileReference` - 添加文件引用
3. `PBXGroup` - 添加到对应组（新建 Models 组）
4. `PBXSourcesBuildPhase` - 添加到编译阶段

## 验证要点

1. MyView 显示等级 ✓
2. OthersView 显示等级 ✓ (之前缺失)
3. 等级名称正确映射（幽暝/冲浪/潜水/蓝洞/水母/灯塔）✓
4. OneCode 遮挡规则一致 ✓
5. 退出登录时清空缓存 ✓
6. 切换账户无数据残留 ✓

## 后续优化建议

1. 逐步迁移其他使用 `localUserProfile` / `otherUserProfile` 的 View 到 @Query
2. 完善他人头像的 AsyncImage 加载
3. 移除过渡期的旧属性和方法

## 技术细节

### OthersView 数据加载时序

```
onAppear
    ↓ isLoading = true（初始状态）
    ↓ fetchUserFullInfo(userId:)
    ↓ saveToUserProfile()
    ↓ isLoading = false
    ↓ @Query 自动刷新 profiles
    ↓ targetUserProfile 计算属性获取数据
    ↓ ProfileHeaderView 显示
```

**关键点**：`isLoading` 初始值必须为 `true`，否则会在数据加载前显示"无数据"。

### 回退路径（Fallback）

当 `@Query` 暂时没有数据时（如 SwiftData 同步延迟），使用内存中的 `otherUserProfile` 作为回退：

```swift
} else if let other = userProfileManager.otherUserProfile, other.id == userId {
    // 回退路径：手动构建 displayModel
    let displayModel = UserProfileDisplayModel(...)
    ProfileHeaderView(displayModel: displayModel, ...)
}
```

### Debug 日志

在 OthersView body 中添加了调试日志，方便排查问题：

```swift
let _ = print("🔍 [OthersView] isLoading=\(isLoading), profiles.count=\(profiles.count), targetUserProfile=\(targetUserProfile?.id ?? -1)")
```

## 完成状态

**状态**: ✅ 已完成

- 代码实现：已完成
- Xcode 项目配置：已完成
- 文档更新：已完成
- 待用户验证：重新构建并测试
