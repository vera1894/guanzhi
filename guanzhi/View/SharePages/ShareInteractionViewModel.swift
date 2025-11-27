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
    }

    /// 回滚到指定状态
    private func rollback(to state: VoteState) async {
        await MainActor.run {
            self.voteState = state
            self.agreeCount = self.originalAgreeCount
            self.neutralCount = self.originalNeutralCount
            self.isAnimating = false

            #if DEBUG
            print("🔄 [ShareInteraction] 回滚: voteState=\(state), agreeCount=\(agreeCount)")
            #endif
        }
    }
}
