//
//  StickerSummaryOverlay.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/12.
//
//  贴纸统计详细覆层 - 点击顶部展示条后弹出
//  显示当前分享收集到的所有贴纸详细统计信息
//

import SwiftUI

/// 贴纸统计详细覆层
struct StickerSummaryOverlay: View {
    /// 贴纸统计项列表
    let items: [StickerSummaryItem]

    /// 关闭回调
    var onClose: () -> Void = {}

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                if items.isEmpty {
                    emptyStateView
                } else {
                    gridView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("贴纸统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        onClose()
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("还没有收到贴纸")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("快来为这条观之贴上第一张贴纸吧")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }

    /// 网格视图
    private var gridView: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 100), spacing: 16)
            ],
            spacing: 20
        ) {
            ForEach(items) { item in
                stickerDetailCard(for: item)
            }
        }
        .padding(20)
    }

    /// 单个贴纸详情卡片
    private func stickerDetailCard(for item: StickerSummaryItem) -> some View {
        VStack(spacing: 12) {
            // 大图标
            StickerThumbnail(definition: item.definition, size: 56)

            // 名称
            Text(item.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            // 数量
            Text(String(localized: "\(item.count) 次"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("有数据") {
    StickerSummaryOverlay(
        items: [
            StickerSummaryItem(kind: .like, count: 128),
            StickerSummaryItem(kind: .neutral, count: 56),
            StickerSummaryItem(kind: .mijing, count: 23),
            StickerSummaryItem(kind: .zhenxiu, count: 12)
        ],
        onClose: {}
    )
}

#Preview("空状态") {
    StickerSummaryOverlay(
        items: [],
        onClose: {}
    )
}
#endif
