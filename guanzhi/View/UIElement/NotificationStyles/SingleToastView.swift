//
//  SingleToastView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/12/31.
//


import SwiftUI
import Combine

/// 展示单个ToastItem的视图
struct SingleToastView: View {
    let item: ToastItem
    @EnvironmentObject var toastManager: ToastManager
    
    // 计时器
    @State private var timerCancellable: Cancellable?
    @State private var startTime: Date = Date()
    @State private var elapsedTime: CGFloat = 0
    
    var body: some View {
        // 根据 item.style 不同，显示不同UI
        switch item.style {
        case .notificationOnly(
            let title,
            let symbol,
            let tint,
            let isUserInteractionEnabled,
            let timing,
            let isAutoClose
        ):
            NotificationOnlyView(
                title: title,
                symbol: symbol,
                tint: tint,
                isUserInteractionEnabled: isUserInteractionEnabled,
                timing: timing,
                isAutoClose: isAutoClose,
                elapsedTime: $elapsedTime
            ) {
                removeThisToast()
            }
            .onAppear {
                startTimerIfNeeded(timing: timing, isAutoClose: isAutoClose)
            }
            
        case .notificationOfWelcome(
            let title,
            let symbol,
            let tint,
            let isUserInteractionEnabled,
            let timing,
            let isAutoClose
        ):
            NotificationOfWelcomeView(
                title: title,
                symbol: symbol,
                tint: tint,
                isUserInteractionEnabled: isUserInteractionEnabled,
                timing: timing,
                isAutoClose: isAutoClose,
                elapsedTime: $elapsedTime
            ) {
                removeThisToast()
            }
            .onAppear {
                startTimerIfNeeded(timing: timing, isAutoClose: isAutoClose)
            }
            
        case .notificationWithButton(
            let title,
            let symbol,
            let tint,
            let isUserInteractionEnabled,
            let timing,
            let isAutoClose,
            let buttonText,
            let isButtonAction
        ):
            NotificationWithButtonView(
                title: title,
                symbol: symbol,
                tint: tint,
                isUserInteractionEnabled: isUserInteractionEnabled,
                timing: timing,
                isAutoClose: isAutoClose,
                buttonText: buttonText,
                isButtonAction: isButtonAction,
                elapsedTime: $elapsedTime
            ) {
                removeThisToast()
            }
            .onAppear {
                startTimerIfNeeded(timing: timing, isAutoClose: isAutoClose)
            }
        }
    }
    
    /// 启动自动关闭计时
    private func startTimerIfNeeded(timing: ToastTime, isAutoClose: Bool) {
        guard isAutoClose else { return }
        startTime = Date()
        timerCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let diff = CGFloat(Date().timeIntervalSince(startTime))
                if diff < timing.rawValue {
                    elapsedTime = diff
                } else {
                    elapsedTime = timing.rawValue
                    removeThisToast() // 时间到了 => 移除
                }
            }
    }
    
    /// 移除自己
    private func removeThisToast() {
        timerCancellable?.cancel()
        toastManager.remove(item)
    }
}