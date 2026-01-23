# 用户引导系统实施计划（修订版 v2.1）

**日期**: 2026-01-09
**作者**: Claude Code
**状态**: ✅ 已实施（2026-01-23 完成状态重载修复）
**版本**: v2.1（修复4个关键问题 + 5个体验建议 + 4个联调修复）

> **后续修复**：参见 `2026-01-23-onboarding-state-reload-fix-plan.md`，解决了重新登录后 userId 变化导致的状态读取错误问题。

---

## 修订记录

### v2.1 修订内容（2026-01-09）

**4个联调修复（防止返工）：**
1. **homePageAppeared 竞态修复** - 对 homeFlow step 使用 `allowOverride=true`，避免从详情返回时被 C1/C2 优先级挡住
2. **Sheet 恢复策略** - 添加 `wasSearchSheetVisibleBeforeBlock` 记录旧值，解除 block 时恢复旧值而非强制 true
3. **Banner 顶部间距优化** - 只让背景 `.ignoresSafeArea()`，内容层正常使用 SafeArea，避免 inset 失真
4. **文案术语统一** - E 里的"分享"改为"发布"，与项目术语规范保持一致

### v2 修订内容（2026-01-09）

**4个关键问题修复：**
1. **B断流问题** - `handleHomePageAppeared()` 改为 `showNextNeededStepOnHome()`，按顺序恢复到第一个未完成步骤
2. **版本迁移无效** - `key()` 不再包含 version，改用独立的 `savedVersion` 字段做迁移判定
3. **Sheet自动弹出** - block 开始时清空 `isShowingSearchView`，解除 block 只在 `homePageFullyVisible` 时恢复
4. **Banner顶部间距** - 使用 `GeometryReader` 读取 `safeAreaInsets.top`，移除硬编码 44

**5个体验建议修复：**
- A. E文案不被截断 - 对 E 特判，不设 lineLimit
- B. Banner统一挂载 - 在 app 根视图放一次 Banner overlay
- C. C1首次判定 - 以 `completedSteps.contains(.openStickerPanel)` 为准，不依赖 View @State
- D. 跳过确认 - 保持内嵌按钮方案
- E. 事件优先级 - 定义优先级策略，E 可覆盖 D

---

## 一、需求概述

### 1.1 核心流程

在用户完成 **提示A-提示B** 之前，主页下方的搜索栏 sheet 暂时隐藏。引导过程使用页面顶部的信息栏进行提示。

| 步骤 | 触发条件 | 信息栏内容 | 完成条件 | 样式 |
|------|---------|-----------|---------|------|
| A | 首次进入主页 | 欢迎分享和探索真实世界的地点! | 自动关闭（短时间） | 黄底，自动关闭 |
| B | 提示A消失后 | 试着操作地图来点击查看地图上的观之。 | 点击任意观之标注（含聚合列表条目） | 黄底，常驻，可跳过 |
| C1 | 首次进入观之详情页 | 点击贴纸图标，查看可用的贴纸。 | 点击贴纸按钮 | 黄底，常驻，可跳过 |
| C2 | 完成C1后 | 选一个符合这条观之的贴纸，拖动到屏幕中心使用它! | 使用贴纸 | 黄底，常驻，可跳过 |
| D | 完成A-B后，回到主页 | 当你到达你的宝藏地点时，别忘了去试试发布你的第一条观之。 | 自动关闭（长时间） | 黄底，长时间自动关闭 |
| E | 首次发布观之后 | 每条观之都有它的"褪色度"... | 自动关闭（长时间） | 黄底，长时间自动关闭 |

### 1.2 完成动画

用户完成步骤后（B/C1/C2），信息栏变绿底，文字变为"💯✅"，短时间后自动关闭。

### 1.3 跳过机制

- 常驻提示（B/C1/C2）显示关闭按钮
- 点击关闭按钮：在 Banner 内显示"跳过全部提示"和"继续提示"两个选项（不使用系统 Alert）
- 跳过后可在设置中重新查看

---

## 二、架构设计（事件驱动状态机）

### 2.1 核心组件

```
┌─────────────────────────────────────────────────────────────────┐
│                    OnboardingCoordinator                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ 状态机核心                                                   │ │
│  │ - currentStep: OnboardingStep?                              │ │
│  │ - completedSteps: Set<OnboardingStep>                       │ │
│  │ - hasSkippedAll: Bool                                       │ │
│  │ - bannerState: BannerState                                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ 事件处理                                                     │ │
│  │ - handleEvent(_ event: OnboardingEvent)                     │ │
│  │ - showNextNeededStepOnHome()  ← 关键：恢复到第一个未完成步骤  │ │
│  │ - skipAllSteps()                                            │ │
│  │ - resetOnboarding()                                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 控制
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│            OnboardingBannerView（统一挂载在 App 根视图）          │
│  独立视图组件，不依赖 ToastManager                                │
│  - 支持黄底/绿底切换                                              │
│  - 支持常驻/自动关闭                                              │
│  - 动态高度（E 不限行数，其他最多3行）                            │
│  - 内嵌"跳过全部/继续"按钮（非系统 Alert）                        │
│  - 使用 safeAreaInsets.top 动态计算顶部间距                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 独立于
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ToastManager                                │
│  保持现有功能不变，不做任何修改                                    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 状态机定义

```swift
// ═══════════════════════════════════════════════════════════════
// 引导步骤枚举
// ═══════════════════════════════════════════════════════════════
enum OnboardingStep: String, CaseIterable, Codable {
    case welcome           // A: 欢迎
    case tapAnnotation     // B: 点击标注
    case openStickerPanel  // C1: 打开贴纸面板
    case useSticker        // C2: 使用贴纸
    case publishReminder   // D: 发布提醒
    case fadeExplanation   // E: 褪色度说明

    /// 主页流程步骤（按顺序）
    static let homeFlowSteps: [OnboardingStep] = [.welcome, .tapAnnotation]

    /// 是否为常驻类型（需要用户主动完成或跳过）
    var isPersistent: Bool {
        switch self {
        case .tapAnnotation, .openStickerPanel, .useSticker:
            return true
        case .welcome, .publishReminder, .fadeExplanation:
            return false
        }
    }

    /// 自动关闭时间（nil = 常驻）
    var autoCloseTiming: TimeInterval? {
        switch self {
        case .welcome: return 3.0
        case .publishReminder, .fadeExplanation: return 60.0
        case .tapAnnotation, .openStickerPanel, .useSticker: return nil
        }
    }

    /// 是否允许无限行数（E 文案较长）
    var allowsUnlimitedLines: Bool {
        self == .fadeExplanation
    }

    /// 事件优先级（数字越大优先级越高）
    var priority: Int {
        switch self {
        case .welcome: return 10
        case .tapAnnotation: return 20
        case .openStickerPanel: return 30
        case .useSticker: return 40
        case .publishReminder: return 50
        case .fadeExplanation: return 60  // E 可覆盖 D
        }
    }

    /// 提示文案
    var message: String {
        switch self {
        case .welcome:
            return "欢迎分享和探索真实世界的地点!"
        case .tapAnnotation:
            return "试着操作地图来点击查看地图上的观之。"
        case .openStickerPanel:
            return "点击贴纸图标，查看可用的贴纸。"
        case .useSticker:
            return "选一个符合这条观之的贴纸，拖动到屏幕中心使用它!"
        case .publishReminder:
            return "当你到达你的宝藏地点时，别忘了去试试发布你的第一条观之。"
        case .fadeExplanation:
            return "每条观之都有它的\"褪色度\"，当褪色度到达100后，这条观之将在地图上消失。别人为观之贴上的有价值贴纸越多，它的褪色越缓慢。发布最有价值的观之来获得更多贴纸吧!"
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 引导事件枚举（业务层发送）
// ═══════════════════════════════════════════════════════════════
enum OnboardingEvent {
    // 页面生命周期
    case homePageAppeared                    // 主页出现
    case homePageFullyVisible                // 主页完全可见（无覆盖窗口）
    case detailPageAppeared                  // 详情页出现（不再传 isFirstTime，coordinator 自己判断）
    case detailPageDisappeared               // 详情页消失

    // 用户交互
    case annotationTapped                    // 点击标注（普通或聚合列表条目）
    case stickerPanelOpened                  // 贴纸面板打开
    case stickerUsed                         // 贴纸使用成功
    case sharePublished                      // 发布观之成功

    // Banner 交互
    case bannerAutoClosed                    // Banner 自动关闭
    case skipAllRequested                    // 用户请求跳过全部
    case continueRequested                   // 用户请求继续

    // 系统
    case resetRequested                      // 设置页请求重置
}

// ═══════════════════════════════════════════════════════════════
// Banner 状态
// ═══════════════════════════════════════════════════════════════
enum BannerState: Equatable {
    case hidden                              // 隐藏
    case showing(step: OnboardingStep)       // 显示某步骤
    case showingSuccess                      // 显示成功（绿底💯✅）
    case showingSkipConfirm                  // 显示跳过确认（内嵌按钮）
}
```

### 2.3 事件流转图

```
┌────────────────────────────────────────────────────────────────────────┐
│                          状态流转图（v2 修订）                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  [App启动] ──homePageAppeared──▶ [showNextNeededStepOnHome()]          │
│                                        │                               │
│            ┌───────────────────────────┴────────────────────────┐      │
│            ▼                                                    ▼      │
│     [hasSkippedAll=true]                    [检查第一个未完成步骤]       │
│     或 [A-B都已完成]                                │                   │
│            │                          ┌─────────────┴─────────────┐    │
│            ▼                          ▼                           ▼    │
│    [不显示A-B提示]              [A未完成→显示A]            [A完成B未完成→显示B] │
│            │                          │                           │    │
│            │                          ▼                           │    │
│            │                   [3s自动关闭]                        │    │
│            │                          │                           │    │
│            │                          ▼                           │    │
│            │                   [显示 B: tapAnnotation] ◀──────────┘    │
│            │                          │                                │
│            │              ┌───────────┼─────────────────┐              │
│            │              ▼           ▼                 ▼              │
│            │    [点击标注/聚合条目] [点击关闭]        [跳过全部]         │
│            │              │           │                 │              │
│            │              ▼           ▼                 │              │
│            │    [显示成功💯✅]  [显示跳过确认]          │              │
│            │              │           │                 │              │
│            │              ▼           │                 │              │
│            │    [进入详情页] ◀─────────┘                 │              │
│            │              │                             │              │
│            │              ▼                             │              │
│            │    [C1未完成？显示C1]                       │              │
│            │              │                             │              │
│            │       ┌──────┴──────┐                      │              │
│            │       ▼             ▼                      │              │
│            │ [点击贴纸按钮]  [跳过全部]                  │              │
│            │       │             │                      │              │
│            │       ▼             │                      │              │
│            │ [显示 C2: useSticker]                      │              │
│            │       │             │                      │              │
│            │ ┌─────┴─────┐       │                      │              │
│            │ ▼           ▼       │                      │              │
│            │[使用贴纸] [跳过全部] │                      │              │
│            │ │           │       │                      │              │
│            │ ▼           │       │                      │              │
│            │[显示成功💯✅]│       │                      │              │
│            │ │           │       │                      │              │
│            │ └─────┬─────┴───────┴──────────────────────┘              │
│            │       ▼                                                   │
│            │ [返回主页] ──homePageFullyVisible──▶                       │
│            │       │                                                   │
│            ├───────┼───────────────────────────────────────────────────┤
│            │       ▼                                                   │
│            │ [A-B已完成且D未完成？]                                      │
│            │       │                                                   │
│            │       ▼                                                   │
│            │ [恢复 isShowingSearchView = true]  ← 关键：此时才恢复 sheet │
│            │       │                                                   │
│            │       ▼                                                   │
│            │ [显示 D: publishReminder] (60s自动关闭)                    │
│            │       │                                                   │
│            │       ▼                                                   │
│            │ [用户发布观之]                                             │
│            │       │                                                   │
│            │       ▼                                                   │
│            │ [显示 E: fadeExplanation] (可覆盖D，优先级更高)            │
│            │       │                                                   │
│            │       ▼                                                   │
│            │ [引导完成]                                                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 三、文件结构设计

### 3.1 新建文件

```
guanzhi/View/Features/Onboarding/
├── OnboardingCoordinator.swift      # 状态机核心（事件处理、状态管理）
├── OnboardingBannerView.swift       # Banner UI 组件
├── OnboardingPersistence.swift      # 持久化管理（UserDefaults）
└── OnboardingHighlightModifier.swift # 高亮效果 ViewModifier
```

### 3.2 修改文件

| 文件 | 修改内容 |
|------|---------|
| `guanzhiApp.swift` | 注入 `OnboardingCoordinator` 环境对象 + **统一挂载 Banner overlay** |
| `SearchView.swift` | 发送事件、**移除 Banner overlay**、Sheet 控制逻辑 |
| `ShareDetailView.swift` | 发送事件、**移除 Banner overlay**、贴纸按钮高亮 |
| `ClusterShareListView.swift` | 聚合列表条目点击时发送 `annotationTapped` 事件 |
| `SheetView.swift` | 发布按钮高亮 |
| `SettingView.swift` | 添加"操作提示"入口 |

---

## 四、详细实现方案

### 4.1 OnboardingCoordinator（状态机核心）

```swift
// OnboardingCoordinator.swift

import SwiftUI
import Combine

@MainActor
class OnboardingCoordinator: ObservableObject {

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Published State
    // ═══════════════════════════════════════════════════════════════

    @Published private(set) var currentStep: OnboardingStep? = nil
    @Published private(set) var bannerState: BannerState = .hidden
    @Published private(set) var hasSkippedAll: Bool = false
    @Published private(set) var completedSteps: Set<OnboardingStep> = []

    /// 是否阻止主页底部 sheet 显示（A-B 未完成时为 true）
    var shouldBlockHomeSheet: Bool {
        guard !hasSkippedAll else { return false }
        let basicSteps: Set<OnboardingStep> = [.welcome, .tapAnnotation]
        return !basicSteps.isSubset(of: completedSteps)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Private State
    // ═══════════════════════════════════════════════════════════════

    private let persistence = OnboardingPersistence()
    private var autoCloseTimer: Timer?
    private var successAnimationTask: Task<Void, Never>?

    /// AppState 引用（用于控制 sheet）
    weak var appState: AppStateModel?

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Initialization
    // ═══════════════════════════════════════════════════════════════

    init() {
        loadState()
    }

    private func loadState() {
        hasSkippedAll = persistence.hasSkippedAll
        completedSteps = persistence.completedSteps

        // 检查版本升级
        if persistence.savedVersion < OnboardingPersistence.currentVersion {
            // 版本升级策略：保留 hasSkippedAll，清空 completedSteps
            // 这样用户不会被强制重看，但新功能引导会出现
            completedSteps = []
            persistence.completedSteps = []
            persistence.savedVersion = OnboardingPersistence.currentVersion
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Event Handling（核心状态机）
    // ═══════════════════════════════════════════════════════════════

    func handleEvent(_ event: OnboardingEvent) {
        guard !hasSkippedAll else { return }

        switch event {
        case .homePageAppeared:
            handleHomePageAppeared()

        case .homePageFullyVisible:
            handleHomePageFullyVisible()

        case .detailPageAppeared:
            handleDetailPageAppeared()

        case .detailPageDisappeared:
            handleDetailPageDisappeared()

        case .annotationTapped:
            handleAnnotationTapped()

        case .stickerPanelOpened:
            handleStickerPanelOpened()

        case .stickerUsed:
            handleStickerUsed()

        case .sharePublished:
            handleSharePublished()

        case .bannerAutoClosed:
            handleBannerAutoClosed()

        case .skipAllRequested:
            skipAllSteps()

        case .continueRequested:
            // 从跳过确认状态恢复到当前步骤显示
            if let step = currentStep {
                bannerState = .showing(step: step)
            }

        case .resetRequested:
            resetOnboarding()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Event Handlers
    // ═══════════════════════════════════════════════════════════════

    /// 【关键修复1】主页出现时恢复到第一个未完成步骤
    private func handleHomePageAppeared() {
        showNextNeededStepOnHome()
    }

    /// 恢复到主页流程中第一个未完成的步骤
    /// 解决"A完成但B未完成时，再次进入主页不显示B"的问题
    private func showNextNeededStepOnHome() {
        // 按顺序检查主页流程步骤
        for step in OnboardingStep.homeFlowSteps {
            if !completedSteps.contains(step) {
                showStep(step)
                return
            }
        }
        // 主页流程都完成了，不显示任何提示
    }

    /// 【关键修复3】主页完全可见时处理
    private func handleHomePageFullyVisible() {
        // A-B 都完成后
        let basicSteps: Set<OnboardingStep> = [.welcome, .tapAnnotation]
        guard basicSteps.isSubset(of: completedSteps) else { return }

        // 【关键】此时才恢复 sheet 显示
        appState?.isShowingSearchView = true

        // 显示 D（如果未完成）
        if !completedSteps.contains(.publishReminder) {
            showStep(.publishReminder)
        }
    }

    /// 【关键修复C】详情页出现（以 completedSteps 为准判断首次）
    private func handleDetailPageAppeared() {
        // 以 completedSteps 为准判断是否首次进入详情页
        // 不依赖 View 层的 @State
        if !completedSteps.contains(.openStickerPanel) {
            showStep(.openStickerPanel)
        }
    }

    private func handleDetailPageDisappeared() {
        // 离开详情页时隐藏 C 系列提示
        if currentStep == .openStickerPanel || currentStep == .useSticker {
            hideBanner()
        }
    }

    private func handleAnnotationTapped() {
        // 点击标注完成 B
        if currentStep == .tapAnnotation {
            completeCurrentStep()
        }
    }

    private func handleStickerPanelOpened() {
        // 打开贴纸面板完成 C1
        if currentStep == .openStickerPanel {
            completeCurrentStep()
            // 立即显示 C2
            if !completedSteps.contains(.useSticker) {
                showStep(.useSticker)
            }
        }
    }

    private func handleStickerUsed() {
        // 使用贴纸完成 C2
        // 注意：即使当前是 C1，用户直接使用贴纸也算完成 C2
        if currentStep == .openStickerPanel || currentStep == .useSticker {
            // 同时标记 C1 和 C2 完成
            completedSteps.insert(.openStickerPanel)
            completedSteps.insert(.useSticker)
            persistence.completedSteps = completedSteps
            showSuccessAnimation()
        }
    }

    /// 【体验修复E】发布观之后显示 E（优先级高于 D）
    private func handleSharePublished() {
        if !completedSteps.contains(.fadeExplanation) {
            // E 优先级高于 D，可以覆盖
            showStep(.fadeExplanation, allowOverride: true)
        }
    }

    private func handleBannerAutoClosed() {
        guard let step = currentStep else { return }

        // 标记完成
        completedSteps.insert(step)
        persistence.completedSteps = completedSteps

        // 推进到下一步
        advanceAfterStep(step)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Step Management
    // ═══════════════════════════════════════════════════════════════

    /// 显示步骤
    /// - Parameters:
    ///   - step: 要显示的步骤
    ///   - allowOverride: 是否允许覆盖当前显示的步骤（基于优先级）
    private func showStep(_ step: OnboardingStep, allowOverride: Bool = false) {
        // 检查优先级
        if let current = currentStep, !allowOverride {
            // 不允许覆盖时，只能显示更高优先级的步骤
            guard step.priority > current.priority else { return }
        }

        // 【关键修复3】开始显示引导时，清空 sheet 显示状态（防止积压）
        if shouldBlockHomeSheet {
            appState?.isShowingSearchView = false
        }

        currentStep = step
        bannerState = .showing(step: step)

        // 设置自动关闭定时器
        autoCloseTimer?.invalidate()
        if let timing = step.autoCloseTiming {
            autoCloseTimer = Timer.scheduledTimer(withTimeInterval: timing, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.handleEvent(.bannerAutoClosed)
                }
            }
        }
    }

    private func completeCurrentStep() {
        guard let step = currentStep else { return }

        completedSteps.insert(step)
        persistence.completedSteps = completedSteps

        // 常驻类型显示成功动画
        if step.isPersistent {
            showSuccessAnimation()
        } else {
            advanceAfterStep(step)
        }
    }

    private func showSuccessAnimation() {
        autoCloseTimer?.invalidate()
        bannerState = .showingSuccess

        successAnimationTask?.cancel()
        successAnimationTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            guard !Task.isCancelled else { return }

            if let step = currentStep {
                advanceAfterStep(step)
            }
        }
    }

    private func advanceAfterStep(_ step: OnboardingStep) {
        hideBanner()

        // 根据当前步骤决定下一步
        switch step {
        case .welcome:
            // A 完成后显示 B
            if !completedSteps.contains(.tapAnnotation) {
                showStep(.tapAnnotation)
            }
        case .tapAnnotation:
            // B 完成，等待进入详情页
            break
        case .openStickerPanel:
            // C1 完成后显示 C2（已在 handleStickerPanelOpened 处理）
            break
        case .useSticker:
            // C2 完成，等待返回主页
            break
        case .publishReminder:
            // D 完成，等待发布
            break
        case .fadeExplanation:
            // E 完成，引导结束
            break
        }
    }

    private func hideBanner() {
        autoCloseTimer?.invalidate()
        currentStep = nil
        bannerState = .hidden
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - User Actions
    // ═══════════════════════════════════════════════════════════════

    /// 显示跳过确认（Banner 内嵌按钮）
    func showSkipConfirm() {
        bannerState = .showingSkipConfirm
    }

    /// 跳过全部提示
    func skipAllSteps() {
        hasSkippedAll = true
        persistence.hasSkippedAll = true
        hideBanner()

        // 恢复 sheet 显示
        appState?.isShowingSearchView = true
    }

    /// 重置引导（设置页调用）
    func resetOnboarding() {
        hasSkippedAll = false
        completedSteps = []

        persistence.hasSkippedAll = false
        persistence.completedSteps = []

        // 重新开始
        showStep(.welcome)
    }
}
```

### 4.2 OnboardingPersistence（持久化）- 【关键修复2】

```swift
// OnboardingPersistence.swift

import Foundation

class OnboardingPersistence {

    /// 当前引导版本（修改引导流程时递增）
    static let currentVersion = 1

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Keys（【关键修复2】key 不包含 version）
    // ═══════════════════════════════════════════════════════════════

    private var userId: Int {
        let id = OTOLoginStatusManager.shared.getUserID()
        return id > 0 ? id : -1  // 未登录使用 -1 作为 guest key
    }

    /// 【关键修复2】key 不再包含 version，避免版本升级后读不到旧数据
    private func key(_ field: String) -> String {
        "onboarding_user\(userId)_\(field)"
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════

    var hasSkippedAll: Bool {
        get { UserDefaults.standard.bool(forKey: key("skippedAll")) }
        set { UserDefaults.standard.set(newValue, forKey: key("skippedAll")) }
    }

    var completedSteps: Set<OnboardingStep> {
        get {
            guard let data = UserDefaults.standard.data(forKey: key("completedSteps")),
                  let steps = try? JSONDecoder().decode(Set<OnboardingStep>.self, from: data)
            else { return [] }
            return steps
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key("completedSteps"))
            }
        }
    }

    /// 【关键修复2】独立的版本字段，用于迁移判定
    var savedVersion: Int {
        get { UserDefaults.standard.integer(forKey: key("version")) }
        set { UserDefaults.standard.set(newValue, forKey: key("version")) }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Migration
    // ═══════════════════════════════════════════════════════════════

    /// 用户登出时调用（清理当前用户数据，保留 guest 数据）
    func clearCurrentUserData() {
        // 只在 userId > 0 时清理，避免清理 guest 数据
        guard userId > 0 else { return }
        UserDefaults.standard.removeObject(forKey: key("skippedAll"))
        UserDefaults.standard.removeObject(forKey: key("completedSteps"))
        UserDefaults.standard.removeObject(forKey: key("version"))
    }
}
```

### 4.3 OnboardingBannerView（UI 组件）- 【关键修复4 + 体验修复A】

```swift
// OnboardingBannerView.swift

import SwiftUI

struct OnboardingBannerView: View {
    @EnvironmentObject var coordinator: OnboardingCoordinator
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            // 【关键修复4】动态获取 safeAreaInsets.top
            let topInset = geometry.safeAreaInsets.top

            VStack {
                Group {
                    switch coordinator.bannerState {
                    case .hidden:
                        EmptyView()

                    case .showing(let step):
                        bannerContent(
                            message: step.message,
                            backgroundColor: Color("color-primary"),
                            showCloseButton: step.isPersistent,
                            allowUnlimitedLines: step.allowsUnlimitedLines,
                            topInset: topInset
                        )

                    case .showingSuccess:
                        bannerContent(
                            message: "💯✅",
                            backgroundColor: Color.green,
                            showCloseButton: false,
                            allowUnlimitedLines: false,
                            topInset: topInset
                        )

                    case .showingSkipConfirm:
                        skipConfirmContent(topInset: topInset)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: coordinator.bannerState)

                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Banner Content
    // ═══════════════════════════════════════════════════════════════

    @ViewBuilder
    private func bannerContent(
        message: String,
        backgroundColor: Color,
        showCloseButton: Bool,
        allowUnlimitedLines: Bool,
        topInset: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // 【体验修复A】文字区域：E 不限行数，其他最多3行
                Text(message)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color("text-black"))
                    .lineLimit(allowUnlimitedLines ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 关闭按钮
                if showCloseButton {
                    Button {
                        coordinator.showSkipConfirm()
                    } label: {
                        Image("icon-close")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(ButtonStyle_m())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.top, topInset)  // 【关键修复4】使用动态 topInset
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                style: .continuous
            )
            .fill(backgroundColor)
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                style: .continuous
            )
            .stroke(Color.black, lineWidth: 4)
        )
        .compositingGroup()
        .shadow(color: backgroundColor.opacity(1), radius: 0, x: 2, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Skip Confirm Content（内嵌按钮，非系统 Alert）
    // ═══════════════════════════════════════════════════════════════

    @ViewBuilder
    private func skipConfirmContent(topInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            Text("要跳过操作提示吗？")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color("text-black"))

            Text("可以在系统设置中再次查看")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color("text-gray"))

            HStack(spacing: 12) {
                Button("继续提示") {
                    coordinator.handleEvent(.continueRequested)
                }
                .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))

                Button("跳过全部提示") {
                    coordinator.handleEvent(.skipAllRequested)
                }
                .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: true))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .padding(.top, topInset)  // 【关键修复4】使用动态 topInset
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                style: .continuous
            )
            .fill(Color("color-primary"))
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: 20, bottomTrailing: 20, topTrailing: 0),
                style: .continuous
            )
            .stroke(Color.black, lineWidth: 4)
        )
        .compositingGroup()
        .shadow(color: Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
```

### 4.4 OnboardingHighlightModifier（高亮效果）

```swift
// OnboardingHighlightModifier.swift

import SwiftUI

struct OnboardingHighlightModifier: ViewModifier {
    let isHighlighted: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var animationPhase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("color-primary"), lineWidth: 3)
                        .opacity(reduceMotion ? 1 : (0.5 + 0.5 * sin(animationPhase)))
                        .shadow(color: Color("color-primary").opacity(0.5), radius: reduceMotion ? 0 : 8)
                        .allowsHitTesting(false)  // 不挡点击
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                animationPhase = .pi
                            }
                        }
                }
            }
    }
}

extension View {
    func onboardingHighlight(_ isHighlighted: Bool) -> some View {
        modifier(OnboardingHighlightModifier(isHighlighted: isHighlighted))
    }
}
```

---

## 五、业务层集成

### 5.1 guanzhiApp.swift（【体验修复B】统一挂载 Banner）

```swift
// guanzhiApp.swift 修改要点

@main
struct guanzhiApp: App {
    @StateObject var onboardingCoordinator = OnboardingCoordinator()
    // ... 其他 StateObject ...

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationCoordinator.path) {
                SearchView(...)
                    .navigationDestination(for: Route.self) { ... }
            }
            // 【体验修复B】统一在 App 根视图挂载 Banner，避免多处重复
            .overlay(alignment: .top) {
                OnboardingBannerView()
                    .environmentObject(onboardingCoordinator)
            }
            .environmentObject(onboardingCoordinator)
            // ... 其他 environmentObject ...
            .onAppear {
                // 注入 appState 引用
                onboardingCoordinator.appState = appState
            }
        }
    }
}
```

### 5.2 SearchView 集成（简化版，移除 Banner overlay）

```swift
// SearchView.swift 修改要点

struct SearchView: View {
    @EnvironmentObject var onboardingCoordinator: OnboardingCoordinator

    var body: some View {
        ZStack {
            // ... 现有地图代码 ...
        }
        // 【体验修复B】不再需要 Banner overlay，已在 App 根视图统一挂载

        // 【关键修复3】底部 Sheet 控制
        .sheet(isPresented: Binding(
            get: {
                // 只有当 sheet 未被阻止时才显示
                appState.isShowingSearchView && !onboardingCoordinator.shouldBlockHomeSheet
            },
            set: { newValue in
                // 只在未被阻止时允许设置
                if !onboardingCoordinator.shouldBlockHomeSheet {
                    appState.isShowingSearchView = newValue
                }
            }
        )) {
            SheetView(...)
        }

        .onAppear {
            onboardingCoordinator.handleEvent(.homePageAppeared)
        }
        .onChange(of: navigationCoordinator.path.isEmpty) { _, isEmpty in
            if isEmpty && !appState.isInShareDetailView {
                onboardingCoordinator.handleEvent(.homePageFullyVisible)
            }
        }
    }

    // 修改标注点击处理
    private func handleAnnotationTap(...) {
        // 发送事件
        onboardingCoordinator.handleEvent(.annotationTapped)
        // ... 现有逻辑 ...
    }
}
```

### 5.3 ClusterShareListView 集成

```swift
// 在聚合列表条目点击时发送事件
ShareSingleView(share: share, onTap: {
    // 发送引导事件（关键：聚合列表点击也算完成 B）
    onboardingCoordinator.handleEvent(.annotationTapped)
    // ... 现有逻辑 ...
})
```

### 5.4 ShareDetailView 集成（【体验修复C】简化版）

```swift
// ShareDetailView.swift 修改要点

struct ShareDetailView: View {
    @EnvironmentObject var onboardingCoordinator: OnboardingCoordinator

    // 【体验修复C】不再需要 @State isFirstVisit，coordinator 自己判断

    var body: some View {
        ZStack {
            // ... 现有代码 ...
        }
        // 【体验修复B】不再需要 Banner overlay，已在 App 根视图统一挂载

        .onAppear {
            // 【体验修复C】不传 isFirstTime，coordinator 以 completedSteps 为准
            onboardingCoordinator.handleEvent(.detailPageAppeared)
        }
        .onDisappear {
            onboardingCoordinator.handleEvent(.detailPageDisappeared)
        }
        // 贴纸面板打开事件
        .onChange(of: interactionViewModel.isStickerPanelVisible) { _, isVisible in
            if isVisible {
                onboardingCoordinator.handleEvent(.stickerPanelOpened)
            }
        }
        // 贴纸使用成功事件
        .onChange(of: interactionViewModel.currentUserSticker?.kind) { oldKind, newKind in
            if oldKind == nil && newKind != nil {
                onboardingCoordinator.handleEvent(.stickerUsed)
            }
            // ... 现有收起面板逻辑 ...
        }
    }

    // 贴纸按钮添加高亮
    Button { ... }
        .onboardingHighlight(onboardingCoordinator.currentStep == .openStickerPanel)
}
```

### 5.5 SheetView 集成（发布按钮高亮）

```swift
// SheetView.swift 修改要点

struct SheetView: View {
    @EnvironmentObject var onboardingCoordinator: OnboardingCoordinator

    var body: some View {
        // ... 现有代码 ...

        Button(action: {
            appState.isShowingCameraView = true
            appState.isShowingSearchView = false
        }) {
            Text("📷 发布观之")
        }
        .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
        // 发布按钮高亮
        .onboardingHighlight(onboardingCoordinator.currentStep == .publishReminder)
    }
}
```

### 5.6 SettingView 集成

```swift
// SettingView.swift 修改要点

var items = [
    "账号与绑定",
    "通知设置",
    "操作提示",  // 新增
    "用户协议与隐私政策",
    "清理缓存",
    "退出登录",
    "系统版本"
]

@EnvironmentObject var onboardingCoordinator: OnboardingCoordinator
@State private var showResetOnboardingAlert = false

// handleAction 中添加：
case "操作提示":
    showResetOnboardingAlert = true

// 添加 alert：
.alert("要重新查看操作提示吗？", isPresented: $showResetOnboardingAlert) {
    Button("取消", role: .cancel) {}
    Button("查看") {
        onboardingCoordinator.handleEvent(.resetRequested)
        // 自动回到主页
        navigationCoordinator.path = NavigationPath()
    }
}
```

### 5.7 发布成功事件

```swift
// 在发布观之成功的回调中：
onboardingCoordinator.handleEvent(.sharePublished)
```

---

## 六、兜底策略

### 6.1 地图无标注时

在 `showNextNeededStepOnHome` 中可以检测，但建议：
- B 步骤的关闭确认中提供"跳过此步骤"选项
- 不做超时自动跳过，尊重用户选择

### 6.2 用户直接完成操作

已在 `handleStickerUsed` 中处理：即使当前是 C1，用户直接使用贴纸也会同时完成 C1 和 C2。

### 6.3 切账号处理

`OnboardingPersistence` 使用 `userId` 作为 key 的一部分，不同账号数据完全隔离。

### 6.4 未登录用户

使用 `userId = -1` 作为 guest key，登录后数据不会互相覆盖。

---

## 七、测试清单

### 7.1 流程测试

- [ ] A → B → 进入详情 → C1 → C2 → 返回主页 → D → 发布 → E
- [ ] 跳过全部提示后，所有引导不再显示
- [ ] 设置中重置后，重新开始引导
- [ ] 切换账号后，各账号引导状态独立

### 7.2 【关键修复验证】

- [ ] **B断流修复**：完成A后杀掉App重启，进入主页能显示B
- [ ] **版本迁移**：模拟升级 currentVersion，hasSkippedAll 保留，completedSteps 清空
- [ ] **Sheet不乱弹**：引导期间 sheet 不会突然弹出，只在 homePageFullyVisible 时恢复
- [ ] **顶部间距**：在不同设备（刘海/灵动岛/SE）上 Banner 顶部间距正确

### 7.3 边缘场景

- [ ] 聚合列表点击条目也能完成 B
- [ ] 用户直接使用贴纸（跳过 C1）也能完成 C2
- [ ] 未登录用户的引导状态独立
- [ ] App 杀掉重启，引导状态保持
- [ ] E 文案完整显示不被截断

### 7.4 UI 测试

- [ ] E 文案不被截断（allowsUnlimitedLines）
- [ ] 成功动画（绿底💯✅）
- [ ] 高亮动画尊重 Reduce Motion
- [ ] 高亮不挡点击

---

## 八、风险评估

| 风险点 | 等级 | 应对措施 |
|-------|------|---------|
| Toast 系统耦合 | 低 | 独立 OnboardingBannerView，不修改 Toast 系统 |
| Sheet 控制冲突 | **已修复** | block 开始时清空，homePageFullyVisible 时才恢复 |
| B断流问题 | **已修复** | showNextNeededStepOnHome 按顺序恢复 |
| 版本迁移失效 | **已修复** | key 不含 version，独立 savedVersion 字段 |
| 顶部间距不准 | **已修复** | GeometryReader 读取 safeAreaInsets.top |
| 贴纸使用检测 | 低 | 使用可靠的 `currentUserSticker` 变化信号 |
| 持久化数据丢失 | 低 | 版本升级保留 `hasSkippedAll`，用户选择不会丢失 |

---

## 九、实施顺序

1. **Phase 1**: 创建 Onboarding 模块基础文件
   - OnboardingCoordinator.swift（含 showNextNeededStepOnHome 修复）
   - OnboardingPersistence.swift（key 不含 version）
   - OnboardingBannerView.swift（动态 topInset + E 不限行数）
   - OnboardingHighlightModifier.swift

2. **Phase 2**: 集成到 App 根视图
   - guanzhiApp.swift 注入环境对象 + 统一 Banner overlay
   - 注入 appState 引用

3. **Phase 3**: 集成到主页
   - SearchView.swift 发送事件（移除 Banner overlay）
   - Sheet 控制逻辑（Binding get/set）
   - SheetView.swift 发布按钮高亮

4. **Phase 4**: 集成到详情页
   - ShareDetailView.swift 发送事件（移除 Banner overlay + isFirstVisit）
   - 贴纸按钮高亮

5. **Phase 5**: 补全剩余功能
   - ClusterShareListView 聚合点击事件
   - SettingView 重置入口
   - 发布成功事件

6. **Phase 6**: 测试与调优
   - 重点验证4个关键修复
   - 边缘场景测试
