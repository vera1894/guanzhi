# Onboarding 状态重载修复计划

**日期**: 2026-01-23
**作者**: Claude Code
**状态**: ✅ 已实施
**版本**: v3 (经 Codex 两轮审核)

---

## 问题描述

### 问题 1: 引导提示在重新登录后突然出现
- **现象**: 用户在个人资料页待一会儿，回到主页时，引导提示突然出现
- **根本原因**: `OnboardingCoordinator` 在 `init()` 时只加载一次状态，此时 `userId` 可能为 0 或 -1（guest），导致读取了错误用户的持久化数据

### 问题 2: 底部 Sheet 和 MapOverlayView 隐藏后不恢复
- **现象**: 即使跳过引导后，底部 sheet 和 MapOverlayView 也不出现
- **根本原因**: `handleHomePageFullyVisible()` 中有 guard 检查 A-B 是否完成，如果 `completedSteps` 为空（因问题 1），会提前返回，不会恢复 `isShowingSearchView`

---

## 核心设计

### 解决思路
1. **在 `setUserID()` 中发送通知** - 这是 userId 确定已设置的可靠时机
2. **OnboardingCoordinator 监听通知** - 在 userId 设置后重新加载正确用户的数据
3. **清理旧状态再加载** - 避免残留的 banner/状态影响新数据

### 前置条件
- ✅ `OTOLoginStatusManager` 已是 `ObservableObject` + `@Published isLoggedIn`
- ✅ `userDidLogout` 通知已存在

---

## 修改清单

### 1. UserLoginModel.swift - 添加 userIdDidSet 通知

**位置**: `Notification.Name` extension 和 `setUserID()` 方法

```swift
// 在 Notification.Name extension 中添加：
extension Notification.Name {
    static let userDidLogout = Notification.Name("com.guanzhi.userDidLogout")
    // ✅ 新增：用户 ID 设置成功通知（用于 Onboarding 重新加载）
    static let userIdDidSet = Notification.Name("com.guanzhi.userIdDidSet")
}

// 修改 setUserID 方法：
func setUserID(_ userId: Int) {
    UserDefaults.standard.set(userId, forKey: "userId")

    // ✅ 新增：发送通知，让 OnboardingCoordinator 重新加载正确用户的数据
    if userId > 0 {
        NotificationCenter.default.post(name: .userIdDidSet, object: nil, userInfo: ["userId": userId])
    }
}
```

---

### 2. OnboardingCoordinator.swift - 监听通知并重新加载

**新增属性和方法**:

```swift
import Combine

@MainActor
class OnboardingCoordinator: ObservableObject {
    // ... 现有属性 ...

    // ✅ 新增：用于监听通知
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadState()
        setupNotificationObservers()

        // ✅ 新增：初始化后检查，如果 userId 已有效但状态是 guest 的，重新加载
        // 处理极端情况：通知在 init 前触发
        let currentUserId = OTOLoginStatusManager.shared.getUserID()
        if currentUserId > 0 {
            // 延迟一帧确保 init 完成
            DispatchQueue.main.async { [weak self] in
                self?.reloadStateForCurrentUser()
            }
        }
    }

    // ✅ 新增方法：设置通知监听
    private func setupNotificationObservers() {
        // 监听 userId 设置成功（登录流程完成）
        NotificationCenter.default.publisher(for: .userIdDidSet)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }

                if let userId = notification.userInfo?["userId"] as? Int, userId > 0 {
                    #if DEBUG
                    print("📚 [Onboarding] 收到 userIdDidSet 通知，userId=\(userId)，重新加载状态")
                    #endif
                    self.reloadStateForCurrentUser()
                }
            }
            .store(in: &cancellables)

        // 监听登出
        NotificationCenter.default.publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }

                #if DEBUG
                print("📚 [Onboarding] 收到 userDidLogout 通知，重置状态")
                #endif
                self.resetToGuestState()
            }
            .store(in: &cancellables)
    }

    // ✅ 新增方法：为当前用户重新加载状态
    private func reloadStateForCurrentUser() {
        // 【关键】先清理旧状态，避免残留
        hideBanner()
        currentStep = nil
        hasPendingPublishReminder = false

        // 【关键】调用 loadState() 而不是直接读 persistence
        // 这样能复用版本迁移逻辑
        loadState()

        #if DEBUG
        print("📚 [Onboarding] 重新加载完成:")
        print("   - hasSkippedAll: \(hasSkippedAll)")
        print("   - completedSteps: \(completedSteps.map { $0.rawValue })")
        #endif

        // 如果已完成或已跳过，确保 UI 正常显示
        if hasSkippedAll || !shouldBlockHomeSheet {
            appState?.isShowingSearchView = true
        } else {
            // 【Codex 建议】如果 A/B 未完成且当前无 banner，触发显示
            if bannerState == .hidden {
                showNextNeededStepOnHome()
            }
        }
    }

    // ✅ 新增方法：重置到 guest 状态（登出时）
    private func resetToGuestState() {
        // 清理当前显示状态
        hideBanner()
        currentStep = nil
        hasPendingPublishReminder = false

        // 【Codex 建议】调用 loadState() 复用版本迁移逻辑
        // 此时 userId 已被清除，会读取 -1 (guest) 的数据
        loadState()

        #if DEBUG
        print("📚 [Onboarding] 重置为 guest 状态完成")
        #endif
    }

    // ... 其他现有方法保持不变 ...
}
```

---

### 3. OnboardingCoordinator.handleHomePageFullyVisible() - 修复恢复逻辑

**修改现有方法**:

```swift
func handleHomePageFullyVisible(isClusterListShowing: Bool) {
    // ✅ 修复：如果已跳过全部，直接恢复 UI 并返回
    if hasSkippedAll {
        withAnimation(.easeInOut(duration: 0.3)) {
            appState?.isShowingSearchView = true
        }
        return
    }

    // A-B 都完成后
    let basicSteps: Set<OnboardingStep> = [.welcome, .tapAnnotation]
    guard basicSteps.isSubset(of: completedSteps) else {
        // A-B 未完成，不恢复 UI（保持 gating 行为）
        // 但如果当前没有 banner 显示，需要触发显示
        if bannerState == .hidden {
            showNextNeededStepOnHome()
        }
        return
    }

    // 【关键】此时才恢复 sheet 和 MapOverlayView 显示
    withAnimation(.easeInOut(duration: 0.3)) {
        appState?.isShowingSearchView = true
    }

    // 显示 D（如果未完成）- 保持原有逻辑不变
    if !completedSteps.contains(.publishReminder) {
        if isClusterListShowing {
            hasPendingPublishReminder = true
            #if DEBUG
            print("📚 [Onboarding] D 待定：等待聚合列表关闭")
            #endif
        } else {
            #if DEBUG
            print("📚 [Onboarding] 显示 D")
            #endif
            showStep(.publishReminder)
        }
    }
}
```

---

### 4. SearchView.swift - 优化 onChange 逻辑

**【Codex 建议】保持原有的 1.0s 延迟，避免 D 提示时机问题**

修改现有的两个 `onChange`：

```swift
// 修改：统一延迟常量（保持 1.0s）
private let kHomePageVisibleDelay: TimeInterval = 1.0

.onChange(of: navigationCoordinator.path.isEmpty) { oldValue, isEmpty in
    // 从任何页面返回（导航模式）：path 从非空变成空
    if isEmpty && !oldValue && !searchViewModel.isShareDetailOverlayShown {
        DispatchQueue.main.asyncAfter(deadline: .now() + kHomePageVisibleDelay) {
            onboardingCoordinator.handleHomePageFullyVisible(isClusterListShowing: isShowingClusterList)
        }
    }
}

.onChange(of: searchViewModel.isShareDetailOverlayShown) { oldValue, isShowing in
    // 从详情页返回（overlay 模式）：isShowing 从 true 变成 false
    if !isShowing && oldValue && navigationCoordinator.path.isEmpty {
        DispatchQueue.main.asyncAfter(deadline: .now() + kHomePageVisibleDelay) {
            onboardingCoordinator.handleHomePageFullyVisible(isClusterListShowing: isShowingClusterList)
        }
    }
}
```

**注意**: SearchView 是 struct，可以在其中定义 `private func` 和 `private let` 常量。

---

## 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `UserLoginModel.swift` | 1. 添加 `userIdDidSet` 通知名<br>2. `setUserID()` 中发送通知 |
| `OnboardingCoordinator.swift` | 1. 添加 `cancellables` 属性<br>2. 新增 `setupNotificationObservers()`<br>3. 新增 `reloadStateForCurrentUser()` - 调用 `loadState()`<br>4. 新增 `resetToGuestState()` - 调用 `loadState()`<br>5. `init()` 中添加初始检查<br>6. 修复 `handleHomePageFullyVisible()` |
| `SearchView.swift` | 保持 1.0s 延迟（使用常量） |

---

## 撤回的修改

根据 Codex 建议，以下修改**不做**：

| 原方案 | 撤回原因 |
|--------|----------|
| Banner 加 `userId > 0` 判断 | 会造成"没有 banner + UI 也被隐藏"的死状态 |
| `showStep()` 只在 welcome 时隐藏 UI | 这是产品行为变更，不是修复 |
| 将延迟从 1.0s 改为 0.3s | 可能导致 D 提示提前出现或 flicker |

---

## Codex 审核要点确认

| 审核点 | 处理方式 |
|--------|----------|
| `resetToGuestState()` 要走 `loadState()` | ✅ 已改为调用 `loadState()` |
| `reloadStateForCurrentUser()` 要补回 A/B 显示 | ✅ 添加了 `showNextNeededStepOnHome()` 调用 |
| 延迟时间保持 1.0s | ✅ 保持原有延迟 |
| init() 后检查 userId | ✅ 已添加初始化后检查 |

---

## 测试场景

1. **新用户首次登录** - 应显示完整引导流程
2. **老用户重新登录** - 应加载之前的引导进度
3. **从个人资料页返回** - UI 应正确恢复
4. **跳过引导后** - sheet 和 MapOverlayView 应正常显示
5. **登出后重新登录同一账号** - 引导状态应保持
6. **登出后登录不同账号** - 应加载新账号的引导状态

---

## 实施记录

### 实施日期
2026-01-23

### 实际修改的文件

| 文件 | 修改内容 |
|------|----------|
| `UserLoginModel.swift` | 1. 添加 `userIdDidSet` 通知名<br>2. `setUserID()` 中发送通知并打印 DEBUG 日志 |
| `OnboardingCoordinator.swift` | 1. 添加 `cancellables` 属性<br>2. 新增 `setupNotificationObservers()` 方法<br>3. 新增 `reloadStateForCurrentUser()` 方法（含 appState nil 检查）<br>4. 新增 `resetToGuestState()` 方法<br>5. 新增 `checkAndRestoreUIStateIfNeeded()` 方法<br>6. `init()` 中调用 `setupNotificationObservers()` 并添加初始 userId 检查<br>7. 修复 `handleHomePageFullyVisible()` - 添加 `hasSkippedAll` 检查<br>8. 添加大量 DEBUG 日志用于调试 |
| `guanzhiApp.swift` | 在 `.onAppear` 中调用 `checkAndRestoreUIStateIfNeeded()` |
| `SearchView.swift` | 1. 添加 `.animation()` 修饰符确保 MapOverlayView transition 正确触发<br>2. 在 `onChange(of: isShowingClusterList)` 中恢复 `isShowingSearchView`<br>3. 从 `onDismiss` 中移除 `isShowingSearchView` 设置（避免 asyncAfter 导致动画不触发） |

---

## 追加修复记录

### 问题 3: 从个人资料页返回时 UI 不恢复

**发现时间**: 实施后测试

**现象**: 重新登录后，进入个人主页，再返回主页时，底部 sheet 和 MapOverlayView 隐藏

**根本原因**:
1. `OnboardingCoordinator.init()` 在 `guanzhiApp.body` 渲染时执行
2. 但 `appState` 是在 `.onAppear` 中注入的
3. 当 `reloadStateForCurrentUser()` 执行时，`appState` 可能还是 nil
4. 导致 `appState?.isShowingSearchView = true` 无效

**修复方案**:
1. 在 `guanzhiApp.swift` 的 `.onAppear` 中，注入 `appState` 后立即调用 `checkAndRestoreUIStateIfNeeded()`
2. 在 `reloadStateForCurrentUser()` 中检查 `appState` 是否为 nil，如果是则跳过 UI 操作

### 问题 4: 聚合列表关闭后 MapOverlayView 不出现

**发现时间**: 问题 3 修复后测试

**现象**: 点击聚合标注 → 聚合列表 → 点击条目 → 详情页 → 返回 → 聚合列表 → 点击空白关闭 → 底部 sheet 正常，但 MapOverlayView 隐藏

**根本原因**:
1. `AnimatedOverlaySheet.dismissWithAnimation()` 在 `asyncAfter` 中调用 `onDismiss`
2. 此时 SwiftUI 的动画事务已经结束
3. `onDismiss` 中的 `withAnimation` 无法正确触发 MapOverlayView 的 transition

**修复方案**:
1. 在 MapOverlayView 的 overlay 后添加 `.animation(.easeInOut(duration: 0.2), value: appState.isShowingSearchView)`
2. 将 `isShowingSearchView = true` 从 `onDismiss` 移到 `onChange(of: isShowingClusterList)` 中
3. 这样状态变化发生在 SwiftUI 的正常更新周期中，动画能正确触发

---

## 最终修改汇总

### UserLoginModel.swift
```swift
// 添加通知名
static let userIdDidSet = Notification.Name("com.guanzhi.userIdDidSet")

// setUserID() 中发送通知
func setUserID(_ userId: Int) {
    UserDefaults.standard.set(userId, forKey: "userId")
    if userId > 0 {
        NotificationCenter.default.post(name: .userIdDidSet, object: nil, userInfo: ["userId": userId])
    }
}
```

### OnboardingCoordinator.swift
- `setupNotificationObservers()` - 监听 `userIdDidSet` 和 `userDidLogout`
- `reloadStateForCurrentUser()` - 重新加载用户状态（含 appState nil 检查）
- `resetToGuestState()` - 登出时重置
- `checkAndRestoreUIStateIfNeeded()` - appState 注入后检查并恢复 UI
- `handleHomePageFullyVisible()` - 添加 `hasSkippedAll` 优先检查

### guanzhiApp.swift
```swift
.onAppear {
    onboardingCoordinator.appState = appState
    onboardingCoordinator.checkAndRestoreUIStateIfNeeded()  // ✅ 新增
    ...
}
```

### SearchView.swift
```swift
// MapOverlayView overlay 后添加动画
.animation(.easeInOut(duration: 0.2), value: appState.isShowingSearchView)

// onChange 中恢复 UI
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

// onDismiss 中移除 isShowingSearchView 设置
onDismiss: {
    if !shouldRestoreClusterList {
        clusterAnnotations = []
        // isShowingSearchView 的恢复移到 onChange 中处理
    }
}
```
