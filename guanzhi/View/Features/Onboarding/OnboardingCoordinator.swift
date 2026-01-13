//
//  OnboardingCoordinator.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/9.
//

import SwiftUI
import Combine

// MARK: - 引导步骤枚举

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
        case .tapAnnotation, .openStickerPanel:
            return true
        case .welcome, .useSticker, .publishReminder, .fadeExplanation:
            return false
        }
    }

    /// 自动关闭时间（nil = 常驻）
    var autoCloseTiming: TimeInterval? {
        switch self {
        case .welcome: return 3.0
        case .useSticker: return 10.0  // C2: 10秒自动消失
        case .publishReminder, .fadeExplanation: return 60.0
        case .tapAnnotation, .openStickerPanel: return nil
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
            return "点击下方的贴纸图标，查看可用贴纸。"
        case .useSticker:
            return "选一个符合这条观之的贴纸，拖动到屏幕中心使用它!"
        case .publishReminder:
            return "当到达你的宝藏地点时，别忘了点击屏幕底部的按钮，发布你的第一条观之。"
        case .fadeExplanation:
            return "每条观之都有它的\"褪色度\"，当褪色度到达100后，这条观之将在地图上消失。别人为观之贴上的有价值贴纸越多，它的褪色越缓慢。发布最有价值的观之来获得更多贴纸吧!"
        }
    }
}

// MARK: - 引导事件枚举

enum OnboardingEvent {
    // 页面生命周期
    case homePageAppeared                    // 主页出现
    case homePageFullyVisible                // 主页完全可见（无覆盖窗口）
    case detailPageAppeared                  // 详情页出现（coordinator 自己判断首次）
    case detailPageDisappeared               // 详情页消失
    case clusterListDismissed                // 聚合列表关闭

    // 用户交互
    case annotationTapped                    // 点击标注（普通或聚合列表条目）
    case stickerPanelOpened                  // 贴纸面板打开
    case stickerUsed                         // 贴纸使用成功
    case sharePublished                      // 发布观之成功
    case publishButtonTapped                 // 点击发布按钮

    // Banner 交互
    case bannerAutoClosed                    // Banner 自动关闭
    case skipAllRequested                    // 用户请求跳过全部
    case continueRequested                   // 用户请求继续

    // 系统
    case resetRequested                      // 设置页请求重置
}

// MARK: - Banner 状态

enum BannerState: Equatable {
    case hidden                              // 隐藏
    case showing(step: OnboardingStep)       // 显示某步骤
    case showingSuccess                      // 显示成功（绿底）
    case showingSkipConfirm                  // 显示跳过确认（内嵌按钮）
}

// MARK: - OnboardingCoordinator

/// 引导状态机核心
///
/// 关键修复（v2.1）：
/// 1. showNextNeededStepOnHome：按顺序恢复到第一个未完成步骤，解决 B 断流问题
/// 2. homePageFullyVisible 时才恢复 sheet，避免自动乱弹
/// 3. 以 completedSteps 判断首次进入详情页，不依赖 View @State
/// 4. E 优先级高于 D，可覆盖
@MainActor
class OnboardingCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentStep: OnboardingStep? = nil
    @Published private(set) var bannerState: BannerState = .hidden
    @Published private(set) var hasSkippedAll: Bool = false
    @Published private(set) var completedSteps: Set<OnboardingStep> = []

    /// 是否有待显示的 D（等待聚合列表关闭）
    @Published private(set) var hasPendingPublishReminder: Bool = false

    /// 是否阻止主页底部 sheet 显示（A-B 未完成时为 true）
    var shouldBlockHomeSheet: Bool {
        guard !hasSkippedAll else { return false }
        let basicSteps: Set<OnboardingStep> = [.welcome, .tapAnnotation]
        return !basicSteps.isSubset(of: completedSteps)
    }

    /// 是否有 banner 正在显示
    var isBannerShowing: Bool {
        bannerState != .hidden
    }

    /// 是否所有引导步骤都已完成（可以显示欢迎语）
    var isAllStepsCompleted: Bool {
        guard !hasSkippedAll else { return true }
        // 只有当所有步骤都完成，且没有 banner 显示时才算完成
        let allSteps: Set<OnboardingStep> = [.welcome, .tapAnnotation, .openStickerPanel, .useSticker, .publishReminder, .fadeExplanation]
        return allSteps.isSubset(of: completedSteps) && !isBannerShowing
    }

    // MARK: - Private State

    private let persistence = OnboardingPersistence()
    private var autoCloseTimer: Timer?
    private var successAnimationTask: Task<Void, Never>?

    /// AppState 引用（用于控制 sheet）
    weak var appState: AppStateModel?

    // MARK: - Initialization

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

        #if DEBUG
        print("📚 [Onboarding] 加载状态:")
        print("   - hasSkippedAll: \(hasSkippedAll)")
        print("   - completedSteps: \(completedSteps.map { $0.rawValue })")
        print("   - savedVersion: \(persistence.savedVersion)")
        #endif
    }

    // MARK: - Event Handling

    func handleEvent(_ event: OnboardingEvent) {
        guard !hasSkippedAll else { return }

        #if DEBUG
        print("📚 [Onboarding] 收到事件: \(event)")
        #endif

        switch event {
        case .homePageAppeared:
            handleHomePageAppeared()

        case .homePageFullyVisible:
            // 注意：这个事件现在应该通过 handleHomePageFullyVisible(checkClusterListAfterDelay:) 直接调用
            // 保留此 case 以保持 switch 完整性，但实际逻辑在 SearchView 中直接调用
            break

        case .detailPageAppeared:
            handleDetailPageAppeared()

        case .detailPageDisappeared:
            handleDetailPageDisappeared()

        case .clusterListDismissed:
            handleClusterListDismissed()

        case .annotationTapped:
            handleAnnotationTapped()

        case .stickerPanelOpened:
            handleStickerPanelOpened()

        case .stickerUsed:
            handleStickerUsed()

        case .sharePublished:
            handleSharePublished()

        case .publishButtonTapped:
            handlePublishButtonTapped()

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

    // MARK: - Event Handlers

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
        // 主页流程都完成了，不显示 A-B 提示
    }

    /// 【关键修复2】主页完全可见时处理
    /// - Parameter isClusterListShowing: 聚合列表是否正在显示（调用方应在延迟后传入最新值）
    func handleHomePageFullyVisible(isClusterListShowing: Bool) {
        // A-B 都完成后
        let basicSteps: Set<OnboardingStep> = [.welcome, .tapAnnotation]
        guard basicSteps.isSubset(of: completedSteps) else { return }

        // 【关键】此时才恢复 sheet 和 MapOverlayView 显示
        // 使用 withAnimation 确保 MapOverlayView 的 transition 动画生效
        withAnimation(.easeInOut(duration: 0.3)) {
            appState?.isShowingSearchView = true
        }

        // 显示 D（如果未完成）
        if !completedSteps.contains(.publishReminder) {
            if isClusterListShowing {
                // 聚合列表正在显示，等它关闭后再显示 D
                hasPendingPublishReminder = true
                #if DEBUG
                print("📚 [Onboarding] D 待定：等待聚合列表关闭，isClusterListShowing=\(isClusterListShowing)")
                #endif
            } else {
                #if DEBUG
                print("📚 [Onboarding] 显示 D，isClusterListShowing=\(isClusterListShowing)")
                #endif
                showStep(.publishReminder)
            }
        }
    }

    /// 聚合列表关闭时处理
    private func handleClusterListDismissed() {
        // 如果有待显示的 D，现在显示它
        if hasPendingPublishReminder {
            hasPendingPublishReminder = false
            if !completedSteps.contains(.publishReminder) {
                showStep(.publishReminder)
            }
        }
    }

    /// 点击发布按钮时处理
    private func handlePublishButtonTapped() {
        // 点击发布按钮完成 D（用户已知道如何发布）
        if currentStep == .publishReminder {
            completedSteps.insert(.publishReminder)
            persistence.completedSteps = completedSteps
            hideBanner()

            #if DEBUG
            print("📚 [Onboarding] D 完成：用户点击发布按钮")
            #endif
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
        // 离开详情页时，标记 C1/C2 完成并隐藏 banner
        // 无论用户是否完成了贴纸操作，退出详情页即视为完成
        if currentStep == .openStickerPanel || currentStep == .useSticker {
            completedSteps.insert(.openStickerPanel)
            completedSteps.insert(.useSticker)
            persistence.completedSteps = completedSteps
            hideBanner()

            #if DEBUG
            print("📚 [Onboarding] C1/C2 完成：用户退出详情页")
            #endif
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

    // MARK: - Step Management

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

        // 【关键修复】取消之前的成功动画 Task，防止它错误地关闭新 banner
        successAnimationTask?.cancel()
        successAnimationTask = nil

        currentStep = step
        bannerState = .showing(step: step)

        #if DEBUG
        print("📚 [Onboarding] 显示步骤: \(step.rawValue)")
        #endif

        // 注意：不再在这里设置 autoCloseTimer
        // 自动关闭的逻辑由 AutoCloseTimerBanner 组件内部的 timer 处理
        // 它会调用 dismissCurrentBanner() 来完成步骤并推进
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
    }

    private func completeCurrentStep() {
        guard let step = currentStep else { return }

        completedSteps.insert(step)
        persistence.completedSteps = completedSteps

        #if DEBUG
        print("📚 [Onboarding] 完成步骤: \(step.rawValue)")
        #endif

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
        #if DEBUG
        print("📚 [Onboarding] advanceAfterStep 开始，步骤: \(step.rawValue)")
        #endif

        // 【关键修复】不要先调用 hideBanner()，避免状态快速变化导致 SwiftUI 问题
        // 让 showStep 直接覆盖当前状态，状态从 A 直接过渡到 B

        // 根据当前步骤决定下一步
        switch step {
        case .welcome:
            // A 完成后显示 B
            let shouldShowB = !completedSteps.contains(.tapAnnotation)
            #if DEBUG
            print("📚 [Onboarding] A 完成，是否显示 B: \(shouldShowB)")
            #endif
            if shouldShowB {
                showStep(.tapAnnotation, allowOverride: true)
                return  // 有下一步，不隐藏
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

        // 没有下一步要显示时才隐藏
        #if DEBUG
        print("📚 [Onboarding] 没有下一步，调用 hideBanner")
        #endif
        hideBanner()
    }

    private func hideBanner() {
        autoCloseTimer?.invalidate()
        currentStep = nil
        bannerState = .hidden
    }

    // MARK: - User Actions

    /// 显示跳过确认（Banner 内嵌按钮）
    func showSkipConfirm() {
        bannerState = .showingSkipConfirm
    }

    /// 关闭当前 Banner（用户手动关闭或倒计时结束）
    func dismissCurrentBanner() {
        guard let step = currentStep else {
            #if DEBUG
            print("📚 [Onboarding] dismissCurrentBanner 被调用但 currentStep 为 nil")
            #endif
            return
        }

        #if DEBUG
        print("📚 [Onboarding] dismissCurrentBanner 开始，当前步骤: \(step.rawValue)")
        #endif

        // 标记完成
        completedSteps.insert(step)
        persistence.completedSteps = completedSteps

        #if DEBUG
        print("📚 [Onboarding] 已完成步骤: \(completedSteps.map { $0.rawValue })")
        #endif

        // 推进到下一步
        advanceAfterStep(step)

        #if DEBUG
        print("📚 [Onboarding] dismissCurrentBanner 结束，当前状态: currentStep=\(String(describing: currentStep?.rawValue)), bannerState=\(bannerState)")
        #endif
    }

    /// 跳过全部提示
    func skipAllSteps() {
        hasSkippedAll = true
        persistence.hasSkippedAll = true
        hideBanner()

        // 恢复 sheet 显示
        appState?.isShowingSearchView = true

        #if DEBUG
        print("📚 [Onboarding] 用户跳过全部提示")
        #endif
    }

    /// 检查某个步骤是否已完成
    /// - Parameter step: 要检查的步骤
    /// - Returns: 是否已完成（或已跳过全部）
    func isStepCompleted(_ step: OnboardingStep) -> Bool {
        return hasSkippedAll || completedSteps.contains(step)
    }

    /// 重置引导（设置页调用）
    func resetOnboarding() {
        // 先隐藏当前显示的 banner
        hideBanner()

        hasSkippedAll = false
        completedSteps = []

        persistence.hasSkippedAll = false
        persistence.completedSteps = []

        #if DEBUG
        print("📚 [Onboarding] 重置引导")
        #endif

        // 重新开始（使用 allowOverride 强制显示，忽略优先级）
        showStep(.welcome, allowOverride: true)
    }
}
