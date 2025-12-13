//
//  StickerSummaryBar.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/12.
//
//  贴纸统计展示条 - 显示在 ShareDetailView 顶部
//  视觉风格：无背景悬浮样式，贴纸图标+文字直接悬浮在内容上方
//

import SwiftUI

/// 贴纸统计展示条
/// 横向显示当前分享收集到的贴纸统计信息
struct StickerSummaryBar: View {
    /// 贴纸统计项列表（已排序）
    let items: [StickerSummaryItem]

    /// 最大显示数量（超出显示 ...）
    var maxVisibleItems: Int = 4

    /// 点击时的回调
    var onTap: () -> Void = {}

    // MARK: - Computed Properties

    /// 实际显示的贴纸项
    private var visibleItems: [StickerSummaryItem] {
        Array(items.prefix(maxVisibleItems))
    }

    /// 是否有更多未显示的贴纸
    private var hasMore: Bool {
        items.count > maxVisibleItems
    }

    // MARK: - Body

    var body: some View {
        Group {
            if items.isEmpty {
                // 空状态：显示占位提示
                emptyStateView
            } else {
                // 有数据：横向排列贴纸统计
                contentView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Subviews

    /// 空状态视图
    private var emptyStateView: some View {
        Text("还没有贴纸，拖动下方贴纸来互动")
            .font(.caption)
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    /// 内容视图（有贴纸统计时显示）
    private var contentView: some View {
        HStack(spacing: 16) {
            ForEach(visibleItems) { item in
                stickerItemView(for: item)
            }

            if hasMore {
                Text("...")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// 单个贴纸统计项视图
    private func stickerItemView(for item: StickerSummaryItem) -> some View {
        HStack(spacing: 4) {
            // 贴纸缩略图
            StickerThumbnail(definition: item.definition, size: 20)

            // 名称
            Text(item.displayName)
                .font(.footnote)
                .foregroundColor(.white)

            // 数量
            Text("\(item.count)")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - StickerThumbnail

/// 贴纸缩略图视图
/// 根据 StickerDefinition.assetKind 渲染对应的图标
struct StickerThumbnail: View {
    let definition: StickerDefinition
    var size: CGFloat = 24

    /// 文字回退的背景颜色（根据贴纸类型变化）
    private var textFallbackBackgroundColor: Color {
        if definition.kind.isVoteType {
            return Color.orange.opacity(0.3)
        } else {
            return Color.blue.opacity(0.3)
        }
    }

    var body: some View {
        Group {
            switch definition.assetKind {
            case .image(let name):
                Image(name)
                    .resizable()
                    .scaledToFit()

            case .systemSymbol(let name):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.orange)

            case .textFallback(let characters):
                // 文字回退：显示前两个字符
                Text(characters.prefix(2))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(textFallbackBackgroundColor)
                    )

            case .svg(let name):
                // 未来支持 SVG
                Image(name)
                    .resizable()
                    .scaledToFit()

            case .threeD:
                // 未来支持 3D，暂时显示占位符
                Image(systemName: "cube.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - String Extension

extension String {
    /// 安全截取前 N 个字符（支持中文）
    /// 使用 Swift 的 prefix(_:) 方法，无需担心字符串下标问题
    func prefix(_ maxLength: Int) -> String {
        String(self.prefix(maxLength))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("有数据") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            StickerSummaryBar(
                items: [
                    StickerSummaryItem(kind: .like, count: 128),
                    StickerSummaryItem(kind: .neutral, count: 23)
                ],
                maxVisibleItems: 4,
                onTap: {
                    print("点击了贴纸统计条")
                }
            )

            Spacer()
        }
        .padding(.top, 100)
    }
}

#Preview("空状态") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            StickerSummaryBar(
                items: [],
                onTap: {}
            )

            Spacer()
        }
        .padding(.top, 100)
    }
}

#Preview("超出最大显示数量") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            StickerSummaryBar(
                items: [
                    StickerSummaryItem(kind: .like, count: 100),
                    StickerSummaryItem(kind: .neutral, count: 30),
                    StickerSummaryItem(kind: .mijing, count: 20),
                    StickerSummaryItem(kind: .zhenxiu, count: 15),
                    StickerSummaryItem(kind: .wanqu, count: 10)
                ],
                maxVisibleItems: 3,
                onTap: {}
            )

            Spacer()
        }
        .padding(.top, 100)
    }
}

#Preview("标签类贴纸") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            StickerSummaryBar(
                items: [
                    StickerSummaryItem(kind: .mijing, count: 50),
                    StickerSummaryItem(kind: .zhenxiu, count: 30),
                    StickerSummaryItem(kind: .caikeng, count: 20),
                    StickerSummaryItem(kind: .maomao, count: 10)
                ],
                maxVisibleItems: 4,
                onTap: {}
            )

            Spacer()
        }
        .padding(.top, 100)
    }
}
#endif
