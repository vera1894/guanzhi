//
//  NetworkErrorBanner.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/2.
//  网络错误提示横幅
//

import SwiftUI

/// 网络错误提示横幅
/// 显示在页面顶部，包含错误信息和重试按钮
struct NetworkErrorBanner: View {
    let message: String
    var detail: String? = nil
    let onRetry: () -> Void

    @State private var isRetrying = false

    var body: some View {
        HStack(spacing: 12) {
            // 错误图标
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            // 错误信息
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 重试按钮
            Button(action: {
                isRetrying = true
                onRetry()
                // 延迟重置状态，给用户反馈
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isRetrying = false
                }
            }) {
                HStack(spacing: 4) {
                    if isRetrying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text("重试")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(16)
            }
            .disabled(isRetrying)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.9))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 60) // 避开状态栏和刘海
    }
}

/// 全屏重试视图（用于关键数据加载失败）
struct RetryView: View {
    let message: String
    var detail: String? = nil
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(message)
                .font(.headline)

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                Text("点击重试")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

#Preview {
    VStack {
        NetworkErrorBanner(
            message: "加载失败",
            detail: "网络连接超时",
            onRetry: { print("Retry tapped") }
        )

        Spacer()

        RetryView(
            message: "加载失败",
            detail: "请检查网络连接",
            onRetry: { print("Retry tapped") }
        )

        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
