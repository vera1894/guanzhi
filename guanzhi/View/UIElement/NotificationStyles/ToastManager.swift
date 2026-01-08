//
//  ToastManager.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/12/31.
//


import SwiftUI

/// 全局的 ToastManager: 管理所有在屏幕顶层显示的 Toast 列表
class ToastManager: ObservableObject {
    @Published var toasts: [ToastItem] = []
    
    /// 显示新的 Toast
    func show(_ item: ToastItem) {
        withAnimation(.spring()) {
            toasts.append(item)
        }
        // 如果需要自动隐藏，可以在这里设置 DispatchQueue 循环
        // 不过本例中，每个 ToastItem 自己带 timing/isAutoClose，所以在视图里处理
    }

    /// 显示新的 Toast（防重复：相同 title 的 toast 存在时不重复添加）
    func showIfNotPresent(_ item: ToastItem) {
        let newTitle = item.style.title
        // 检查是否已有相同 title 的 toast
        let alreadyExists = toasts.contains { $0.style.title == newTitle }
        if !alreadyExists {
            withAnimation(.spring()) {
                toasts.append(item)
            }
        }
    }
    
    /// 移除指定 Toast
    func remove(_ item: ToastItem) {
        withAnimation(.spring()) {
            toasts.removeAll { $0.id == item.id }
        }
    }
}

/// 你的 ToastItem 结构
struct ToastItem: Identifiable {
    let id = UUID()
    var style: ToastStyle
}

/// 你已有的枚举
enum ToastStyle {
    case notificationOnly(
        title: String,
        symbol: String?,
        tint: Color,
        isUserInteractionEnabled: Bool,
        timing: ToastTime,
        isAutoClose: Bool
    )
    case notificationOfWelcome(
        title: String,
        symbol: String?,
        tint: Color,
        isUserInteractionEnabled: Bool,
        timing: ToastTime,
        isAutoClose: Bool
    )
    case notificationWithButton(
        title: String,
        symbol: String?,
        tint: Color,
        isUserInteractionEnabled: Bool,
        timing: ToastTime,
        isAutoClose: Bool,
        buttonText: String,
        isButtonAction: Bool
    )
}

/// 显示时长
enum ToastTime: CGFloat {
    case short = 3.0
    case medium = 5.0
    case long = 60.0
}

// MARK: - ToastStyle 扩展

extension ToastStyle {
    /// 获取 toast 的 title（用于防重复判断）
    var title: String {
        switch self {
        case .notificationOnly(let title, _, _, _, _, _):
            return title
        case .notificationOfWelcome(let title, _, _, _, _, _):
            return title
        case .notificationWithButton(let title, _, _, _, _, _, _, _):
            return title
        }
    }
}