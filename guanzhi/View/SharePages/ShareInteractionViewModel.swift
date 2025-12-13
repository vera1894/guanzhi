//
//  ShareInteractionViewModel.swift
//  guanzhi
//
//  Created by Claude Code on 2025/11/27.
//

import Foundation
import Combine

/// 投票状态枚举（与后端 voteType 对应）
enum VoteState: Int, Codable {
    case none    = -1  // 取消/默认状态（后端删除记录）
    case neutral = 0   // 无感/踩（后端支持，前端预留）
    case agree   = 1   // 赞同/点赞

    /// 切换到目标状态（用于 toggle 逻辑）
    func toggled(to target: VoteState) -> VoteState {
        return self == target ? .none : target
    }
}

/// 分享互动 ViewModel（点赞、打卡等）
///
/// 关键特性：
/// - 三态互斥：使用 VoteState 枚举强制状态唯一性
/// - 乐观更新：立即响应用户操作，后台同步服务器
/// - 竞态保护：通过全局唯一 operationId 确保只有最后一次操作生效
/// - 失败回滚：网络错误时恢复原始状态
/// - 数据同步：通过回调通知外层 ViewModel 更新
@MainActor
class ShareInteractionViewModel: ObservableObject {
    // MARK: - Published State

    /// 当前投票状态（核心状态，所有派生属性基于此）
    @Published var voteState: VoteState = .none

    /// 赞同数
    @Published var agreeCount: Int = 0

    /// 无感数（当前版本不显示，仅同步服务器数据）
    @Published var neutralCount: Int = 0

    /// 动画状态
    @Published var isAnimating: Bool = false

    /// 错误消息
    @Published var errorMessage: String? = nil

    /// 贴纸统计列表（用于顶部展示条）
    @Published var stickerSummaries: [StickerSummaryItem] = []

    /// 是否显示贴纸统计覆层
    @Published var isShowingStickerSummaryOverlay: Bool = false

    /// 用户可用的贴纸种类（基于权限，已过滤 isActive）
    @Published var availableStickerKinds: Set<StickerKind> = []

    /// 当前应显示的贴纸队列定义（应用互斥逻辑后）
    @Published var visibleStickerDefinitions: [StickerDefinition] = []

    // MARK: - Computed Properties（派生属性）

    /// 是否已点赞（只读，派生自 voteState）
    var isLiked: Bool { voteState == .agree }

    /// 是否已无感（只读，派生自 voteState）
    var isNeutral: Bool { voteState == .neutral }

    // MARK: - Private State

    private var currentShareId: Int64?
    private var originalVoteState: VoteState = .none
    private var originalAgreeCount: Int = 0
    private var originalNeutralCount: Int = 0

    /// ✅ 全局唯一的操作序号（点赞、无感、取消共用）
    private var operationId: Int = 0

    /// 状态变化回调（通知外层更新）
    private var onStateChanged: ((Int64, VoteState, Int, Int) -> Void)?

    // MARK: - Initialization

    /// 初始化状态（从 Share 对象加载）
    /// - Parameters:
    ///   - share: 分享对象
    ///   - onStateChanged: 状态变化回调 (shareId, voteState, agreeCount, neutralCount)
    func initialize(share: Share, onStateChanged: ((Int64, VoteState, Int, Int) -> Void)? = nil) {
        self.currentShareId = share.id
        self.agreeCount = share.agreeCount
        self.neutralCount = share.neutralCount

        // ✅ 从后端数据恢复状态
        if let userVoteType = share.currentUserVoteType {
            self.voteState = VoteState(rawValue: userVoteType) ?? .none
        } else {
            self.voteState = .none
        }

        self.onStateChanged = onStateChanged

        // 保存原始值，用于失败回滚
        self.originalVoteState = self.voteState
        self.originalAgreeCount = self.agreeCount
        self.originalNeutralCount = self.neutralCount

        // 重置错误和动画状态
        self.errorMessage = nil
        self.isAnimating = false

        #if DEBUG
        print("📊 [ShareInteraction] 初始化:")
        print("   - shareId: \(share.id)")
        print("   - share.currentUserVoteType: \(share.currentUserVoteType?.description ?? "nil")")
        print("   - 解析后 voteState: \(voteState)")
        print("   - agreeCount: \(agreeCount)")
        #endif

        // 构建贴纸统计列表
        rebuildStickerSummaries()

        // ✅ 重建可见贴纸队列（应用互斥逻辑）
        // 注意：此时 availableStickerKinds 可能还未计算，但 rebuildVisibleStickerDefinitions 会处理空集合情况
        rebuildVisibleStickerDefinitions()
    }

    // MARK: - Actions

    /// 切换点赞状态（乐观更新 + 后台同步）
    func toggleLike() {
        vote(to: .agree)
    }

    /// 切换无感状态（当前版本不调用，预留接口）
    func toggleNeutral() {
        vote(to: .neutral)
    }

    /// 统一投票入口（供外部调用）
    /// 所有入口（底部贴纸拖动、右侧按钮、顶部展示条）都应该通过这个方法更新
    func setVote(_ targetState: VoteState) {
        vote(to: targetState)
    }

    // MARK: - Private Methods

    /// ✅ 核心投票逻辑（点赞、无感、取消共用）
    private func vote(to targetState: VoteState) {
        guard let shareId = currentShareId else {
            #if DEBUG
            print("⚠️ [ShareInteraction] 操作失败：shareId 为空")
            #endif
            return
        }

        // 清除之前的错误消息
        errorMessage = nil

        // ✅ 1. 增加全局操作序号（防止竞态）
        operationId += 1
        let currentOp = operationId

        #if DEBUG
        print("🎯 [ShareInteraction] 操作 #\(currentOp): vote to \(targetState)")
        #endif

        // 2. 计算新状态（toggle 逻辑）
        let oldState = voteState
        let newState = oldState.toggled(to: targetState)

        // 3. 乐观更新 UI（立即响应）
        updateLocalState(from: oldState, to: newState)
        isAnimating = true

        // 4. 启动动画（0.5秒后重置）
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            // ✅ 只有当前操作仍然有效时才重置动画
            if currentOp == self.operationId {
                self.isAnimating = false
            }
        }

        // 5. 后台同步到服务器
        Task { @MainActor in
            do {
                let voteType = newState.rawValue  // -1/0/1

                #if DEBUG
                print("📤 [ShareInteraction] 发送请求 #\(currentOp): voteType=\(voteType)")
                #endif

                try await ShareService.shared.voteShare(
                    shareId: shareId,
                    voteType: voteType
                )

                // ✅ 关键：检查这个响应是否已经过期
                guard currentOp == self.operationId else {
                    #if DEBUG
                    print("⏭️ [ShareInteraction] 响应 #\(currentOp) 已过期，丢弃")
                    #endif
                    return
                }

                #if DEBUG
                print("✅ [ShareInteraction] 操作 #\(currentOp) 成功")
                #endif

                // 6. 成功后更新原始值（用于下次比较）
                self.originalVoteState = self.voteState
                self.originalAgreeCount = self.agreeCount
                self.originalNeutralCount = self.neutralCount

                // 7. 通知外层更新
                self.onStateChanged?(shareId, self.voteState, self.agreeCount, self.neutralCount)

            } catch {
                // ✅ 关键：只有最新操作失败才回滚
                guard currentOp == self.operationId else {
                    #if DEBUG
                    print("⏭️ [ShareInteraction] 错误响应 #\(currentOp) 已过期，丢弃")
                    #endif
                    return
                }

                #if DEBUG
                print("❌ [ShareInteraction] 操作 #\(currentOp) 失败: \(error.localizedDescription)")
                #endif

                // 8. 失败时回滚 UI
                await self.rollback(to: oldState)

                // 9. 显示错误提示
                self.errorMessage = "操作失败，请重试"

                // 3秒后自动清除错误消息
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if self.errorMessage == "操作失败，请重试" {
                        self.errorMessage = nil
                    }
                }
            }
        }
    }

    /// 更新本地状态（乐观更新）
    private func updateLocalState(from oldState: VoteState, to newState: VoteState) {
        // 先撤销旧状态的计数
        switch oldState {
        case .agree:
            agreeCount -= 1
        case .neutral:
            neutralCount -= 1
        case .none:
            break
        }

        // 再应用新状态的计数
        switch newState {
        case .agree:
            agreeCount += 1
        case .neutral:
            neutralCount += 1
        case .none:
            break
        }

        // 更新状态
        voteState = newState

        // 重建贴纸统计列表和可见贴纸队列
        rebuildStickerSummaries()
        rebuildVisibleStickerDefinitions()
    }

    /// 重建贴纸统计列表
    /// 从当前的 agreeCount / neutralCount 构建 StickerSummaryItem 数组
    /// 调用时机：初始化、投票状态变化后
    private func rebuildStickerSummaries() {
        var items: [StickerSummaryItem] = []

        // 添加赞同贴纸统计（如果有）
        if agreeCount > 0 {
            items.append(StickerSummaryItem(kind: .like, count: agreeCount))
        }

        // 添加无感贴纸统计（如果有）
        if neutralCount > 0 {
            items.append(StickerSummaryItem(kind: .neutral, count: neutralCount))
        }

        // 排序：按 StickerSummaryItem 的 Comparable 实现
        // 规则：count 降序 → priority 降序 → displayName 升序
        stickerSummaries = items.sorted()

        #if DEBUG
        print("📊 [ShareInteraction] 重建贴纸统计:")
        print("   - agreeCount: \(agreeCount), neutralCount: \(neutralCount)")
        print("   - summaries: \(stickerSummaries.map { "\($0.displayName)(\($0.count))" })")
        #endif
    }

    /// 回滚到指定状态
    private func rollback(to state: VoteState) async {
        await MainActor.run {
            self.voteState = state
            self.agreeCount = self.originalAgreeCount
            self.neutralCount = self.originalNeutralCount
            self.isAnimating = false

            // 重建贴纸统计列表和可见贴纸队列
            self.rebuildStickerSummaries()
            self.rebuildVisibleStickerDefinitions()

            #if DEBUG
            print("🔄 [ShareInteraction] 回滚: voteState=\(state), agreeCount=\(agreeCount)")
            #endif
        }
    }

    // MARK: - 贴纸可用性计算

    /// 计算用户可用的贴纸种类
    /// - Parameters:
    ///   - userTaggingAllowance: 用户的 taggingAllowance（从等级获取）
    ///   - activeTagCodes: 后端启用的标签 tagCode 列表（isActive=true，空集合表示全部启用）
    func computeAvailableStickerKinds(
        userTaggingAllowance: Int,
        activeTagCodes: Set<String> = []
    ) {
        // 投票类对所有人开放
        var available: Set<StickerKind> = [.like, .neutral]

        // 有标签权限时，添加启用的标签类贴纸
        if userTaggingAllowance > 0 {
            let activeTagKinds = StickerKind.allCases.filter { kind in
                guard kind.isTagType, let tagCode = kind.tagCode else { return false }
                // 空集合表示全部启用
                return activeTagCodes.isEmpty || activeTagCodes.contains(tagCode)
            }
            available.formUnion(activeTagKinds)
        }

        availableStickerKinds = available

        #if DEBUG
        print("📊 [ShareInteraction] 计算可用贴纸:")
        print("   - taggingAllowance: \(userTaggingAllowance)")
        print("   - available: \(available.map { $0.rawValue })")
        #endif

        // 重建可见贴纸队列
        rebuildVisibleStickerDefinitions()
    }

    /// 使用 UserLevelConfig 计算可用贴纸（便捷方法）
    /// - Parameter levelCode: 用户等级代码（如 "YOMIN", "CHONGLANG" 等）
    func computeAvailableStickerKinds(for levelCode: String?) {
        let allowance = UserLevelConfig.getTaggingAllowance(for: levelCode)
        computeAvailableStickerKinds(userTaggingAllowance: allowance)
    }

    /// 重建可见贴纸队列（应用互斥逻辑）
    /// 调用时机：初始化、投票状态变化、权限变化
    func rebuildVisibleStickerDefinitions() {
        var visible = availableStickerKinds

        // ✅ 互斥逻辑修正：已选择的贴纸应该隐藏，让用户可以改变选择
        // 用户已投 agree → 移除 like（已选），保留 neutral（可改选）
        // 用户已投 neutral → 移除 neutral（已选），保留 like（可改选）
        if voteState == .agree {
            visible.remove(.like)      // 已点赞，隐藏赞同贴纸
        } else if voteState == .neutral {
            visible.remove(.neutral)   // 已点无感，隐藏无感贴纸
        }

        // 转换为 StickerDefinition 并按 priority 降序排序
        visibleStickerDefinitions = visible
            .map { StickerDefinition.definition(for: $0) }
            .sorted { $0.priority > $1.priority }

        #if DEBUG
        print("📊 [ShareInteraction] 重建可见贴纸队列:")
        print("   - voteState: \(voteState)")
        print("   - available: \(availableStickerKinds.map { $0.rawValue })")
        print("   - visible: \(visibleStickerDefinitions.map { $0.displayName })")
        #endif
    }
}
