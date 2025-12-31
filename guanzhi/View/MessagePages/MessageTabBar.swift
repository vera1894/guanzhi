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

    var body: some View {
        HStack(spacing: 24) {
            ForEach(MessageCategory.allCases, id: \.self) { category in
                MessageTabItem(
                    category: category,
                    isSelected: selectedCategory == category,
                    unreadCount: unreadCounts?.count(for: category) ?? 0
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
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))

                Text(category.title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))

                // 未读数
                if unreadCount > 0 {
                    Text("(\(formatCount(unreadCount)))")
                        .font(.system(size: 14))
                        .foregroundColor(Color("color-primary"))
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

    private func formatCount(_ count: Int) -> String {
        if count > 999 {
            return "999+"
        }
        return "\(count)"
    }
}

// MARK: - Preview

#Preview {
    VStack {
        MessageTabBar(
            selectedCategory: .constant(.interaction),
            unreadCounts: UnreadCount(interaction: 12, system: 2, total: 14)
        )

        MessageTabBar(
            selectedCategory: .constant(.system),
            unreadCounts: UnreadCount(interaction: 0, system: 1000, total: 1000)
        )

        MessageTabBar(
            selectedCategory: .constant(.interaction),
            unreadCounts: nil
        )
    }
    .padding()
}
