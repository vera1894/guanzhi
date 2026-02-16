//
//  ClusterShareRanker.swift
//  guanzhi
//
//  Created by Claude Code on 2026/2/16.
//
//  聚合列表排名工具类
//  - 借鉴 X/Twitter 加权互动评分 + 时间衰减 + 褪色度健康度
//  - 48h 内新发布的观之置顶（最多 3 条）
//

import Foundation

struct ClusterShareRanker {

    /// 48 小时阈值（秒）
    static let newThresholdSeconds: TimeInterval = 48 * 3600

    /// 置顶区最大条数
    static let maxPinnedCount = 3

    // MARK: - 权重常量

    private static let weightAgree: Double = 1.0
    private static let weightCheckin: Double = 3.0
    private static let weightComment: Double = 5.0
    private static let weightNeutral: Double = -2.0

    /// 时间衰减半衰期（秒）：7 天
    private static let halfLifeSeconds: Double = 168 * 3600

    /// 褪色度影响系数
    private static let fadeImpactFactor: Double = 0.3

    // MARK: - 排名结果

    struct RankedResult {
        /// 48h 内最新置顶（按 createDate 降序，最多 3 条）
        let pinnedShares: [ResponsedShare]
        /// 其余观之（按 finalScore 降序）
        let rankedShares: [ResponsedShare]
    }

    // MARK: - 公开方法

    /// 对一组观之进行排名，返回置顶区 + 排名区
    static func rank(_ shares: [ResponsedShare]) -> RankedResult {
        let now = Date()

        // 分组：48h 内 vs 其余
        var newShares: [ResponsedShare] = []
        var otherShares: [ResponsedShare] = []

        for share in shares {
            if isNew(share, now: now) {
                newShares.append(share)
            } else {
                otherShares.append(share)
            }
        }

        // 置顶区：按 createDate 降序，最多 3 条
        newShares.sort { $0.createDate > $1.createDate }
        let pinned = Array(newShares.prefix(maxPinnedCount))

        // 超出 3 条的新内容进入排名区
        let overflow = Array(newShares.dropFirst(maxPinnedCount))
        let allRanked = overflow + otherShares

        // 排名区：按 finalScore 降序
        let ranked = allRanked.sorted { score($0, now: now) > score($1, now: now) }

        return RankedResult(pinnedShares: pinned, rankedShares: ranked)
    }

    /// 计算单条观之的最终评分
    static func score(_ share: ResponsedShare, now: Date = Date()) -> Double {
        let agree = Double(share.agreeCount ?? 0)
        let checkin = Double(share.checkinCount ?? 0)
        let comment = Double(share.commentCount ?? 0)
        let neutral = Double(share.neutralCount ?? 0)

        let interactionScore = weightAgree * agree
            + weightCheckin * checkin
            + weightComment * comment
            + weightNeutral * neutral

        // createDate 是毫秒时间戳
        let createDate = Date(timeIntervalSince1970: Double(share.createDate) / 1000.0)
        let ageSeconds = now.timeIntervalSince(createDate)
        let recencyMultiplier = pow(0.5, ageSeconds / halfLifeSeconds)

        let fadeScore = Double(share.fadeScore ?? 0)
        let healthMultiplier = 1.0 - fadeImpactFactor * (fadeScore / 100.0)

        return (1.0 + max(0, interactionScore)) * recencyMultiplier * healthMultiplier
    }

    /// 判断是否为「最新」（48h 内发布）
    static func isNew(_ share: ResponsedShare, now: Date = Date()) -> Bool {
        let createDate = Date(timeIntervalSince1970: Double(share.createDate) / 1000.0)
        return now.timeIntervalSince(createDate) <= newThresholdSeconds
    }
}
