//
//  CommentInputBar.swift
//  guanzhi
//
//  Created by Claude Code on 2024/12/23.
//  底部评论输入栏
//

import SwiftUI
import Combine

// MARK: - 键盘高度观察器
final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var keyboardAnimationDuration: Double = 0.25
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 监听键盘显示
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return
                }

                // 获取动画时长
                let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25

                // 计算键盘遮挡高度：键盘顶部到屏幕底部的距离
                let screenHeight = UIScreen.main.bounds.height
                let keyboardTop = keyboardFrame.origin.y
                let keyboardOverlap = max(0, screenHeight - keyboardTop)

                withAnimation(.easeOut(duration: duration)) {
                    self?.keyboardHeight = keyboardOverlap
                    self?.keyboardAnimationDuration = duration
                }
            }
            .store(in: &cancellables)

        // 监听键盘隐藏
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                withAnimation(.easeOut(duration: duration)) {
                    self?.keyboardHeight = 0
                }
            }
            .store(in: &cancellables)

        // 监听键盘尺寸变化（第三方键盘切换等）
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .sink { [weak self] notification in
                guard let userInfo = notification.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return
                }

                let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                let screenHeight = UIScreen.main.bounds.height
                let keyboardTop = keyboardFrame.origin.y
                let keyboardOverlap = max(0, screenHeight - keyboardTop)

                // 只有当键盘在屏幕内时才更新
                if keyboardTop < screenHeight {
                    withAnimation(.easeOut(duration: duration)) {
                        self?.keyboardHeight = keyboardOverlap
                    }
                }
            }
            .store(in: &cancellables)
    }
}

struct CommentInputBar: View {
    @ObservedObject var viewModel: CommentViewModel
    @FocusState.Binding var isFocused: Bool
    @StateObject private var keyboardObserver = KeyboardObserver()

    private let maxLength = 230

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                // 回复提示（回复模式时显示）
                if viewModel.isReplyMode, let user = viewModel.replyToUser {
                    HStack {
                        Text("回复 @\(user.nickname ?? "用户")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            viewModel.exitReplyMode()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    // 输入框
                    HStack {
                        TextField(
                            viewModel.isReplyMode ? "回复..." : "展开说说...",
                            text: $viewModel.inputText,
                            axis: .vertical
                        )
                        .focused($isFocused)
                        .font(.system(size: 15))
                        .lineLimit(1...4)
                        .onChange(of: viewModel.inputText) { _, newValue in
                            if newValue.count > maxLength {
                                viewModel.inputText = String(newValue.prefix(maxLength))
                            }
                        }

                        // 字数提示
                        if !viewModel.inputText.isEmpty {
                            Text("\(viewModel.inputText.count)/\(maxLength)")
                                .font(.system(size: 10))
                                .foregroundColor(
                                    viewModel.inputText.count >= maxLength ? .red : .secondary
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)

                    // 发送按钮
                    Button {
                        Task {
                            await viewModel.postComment()
                            isFocused = false
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(
                                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .gray : Color("color-primary")
                                )
                                .frame(width: 32, height: 32)
                        }
                    }
                    .disabled(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isSubmitting
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.regularMaterial)
        }
        // 键盘显示时添加底部 padding（使用键盘实际遮挡高度）
        .padding(.bottom, keyboardObserver.keyboardHeight)
    }
}

// MARK: - 不需要外部 FocusState 的简化版本
struct CommentInputBarSimple: View {
    @ObservedObject var viewModel: CommentViewModel
    @FocusState private var isFocused: Bool
    @StateObject private var keyboardObserver = KeyboardObserver()

    private let maxLength = 230

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 8) {
                // 回复提示（回复模式时显示）
                if viewModel.isReplyMode, let user = viewModel.replyToUser {
                    HStack {
                        Text("回复 @\(user.nickname ?? "用户")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button {
                            viewModel.exitReplyMode()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    // 输入框
                    HStack {
                        TextField(
                            viewModel.isReplyMode ? "回复..." : "展开说说...",
                            text: $viewModel.inputText,
                            axis: .vertical
                        )
                        .focused($isFocused)
                        .font(.system(size: 15))
                        .lineLimit(1...4)
                        .onChange(of: viewModel.inputText) { _, newValue in
                            if newValue.count > maxLength {
                                viewModel.inputText = String(newValue.prefix(maxLength))
                            }
                        }

                        // 字数提示
                        if !viewModel.inputText.isEmpty {
                            Text("\(viewModel.inputText.count)/\(maxLength)")
                                .font(.system(size: 10))
                                .foregroundColor(
                                    viewModel.inputText.count >= maxLength ? .red : .secondary
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)

                    // 发送按钮
                    Button {
                        Task {
                            await viewModel.postComment()
                            isFocused = false
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(
                                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? .gray : Color("color-primary")
                                )
                                .frame(width: 32, height: 32)
                        }
                    }
                    .disabled(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isSubmitting
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.regularMaterial)
        }
        // 键盘显示时添加底部 padding（使用键盘实际遮挡高度）
        .padding(.bottom, keyboardObserver.keyboardHeight)
    }
}
