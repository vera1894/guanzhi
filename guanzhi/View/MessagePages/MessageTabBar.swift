//
//  MessageTabBar.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import SwiftUI

struct MessageTabBar: View {
    @Binding var selectedCategory: MessageCategory
    let unreadCounts: UnreadCount?
    /// 各分类是否有未读消息（从消息列表计算）
    var hasUnreadByCategory: [MessageCategory: Bool] = [:]

    var body: some View {
        HStack(spacing: 24) {
            ForEach(MessageCategory.allCases, id: \.self) { category in
                // 优先使用 API 返回的分类未读数，否则使用从消息列表计算的结果
                let apiCount = unreadCounts?.count(for: category) ?? 0
                let hasUnread = apiCount > 0 || (hasUnreadByCategory[category] ?? false)
                MessageTabItem(
                    category: category,
                    isSelected: selectedCategory == category,
                    hasUnread: hasUnread
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Tab Item

struct MessageTabItem: View {
    let category: MessageCategory
    let isSelected: Bool
    let hasUnread: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))

                Text(category.title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))

                // 未读红点（有未读时始终显示）
                if hasUnread {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .foregroundColor(isSelected ? Color("color-black") : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color("color-primary").opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        MessageTabBar(
            selectedCategory: .constant(.interaction),
            unreadCounts: UnreadCount(interaction: 12, system: 2, total: 14),
            hasUnreadByCategory: [.interaction: true, .system: true]
        )

        MessageTabBar(
            selectedCategory: .constant(.system),
            unreadCounts: nil,
            hasUnreadByCategory: [.interaction: true, .system: false]
        )

        MessageTabBar(
            selectedCategory: .constant(.interaction),
            unreadCounts: nil,
            hasUnreadByCategory: [:]
        )
    }
    .padding()
}
