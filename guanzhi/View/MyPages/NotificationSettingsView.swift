//
//  NotificationSettingsView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/30.
//

import SwiftUI

// MARK: - ViewModel

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var globalPushEnabled = true
    @Published var preferences: [NotificationEventPreference] = []
    @Published var errorMessage: String?
    @Published var showErrorAlert = false

    /// 按分组获取偏好 - 互动消息
    var interactionPreferences: [NotificationEventPreference] {
        preferences.filter { $0.eventGroup == "interaction" }
    }

    /// 按分组获取偏好 - 系统消息
    var systemPreferences: [NotificationEventPreference] {
        preferences.filter { $0.eventGroup == "system" }
    }

    /// 加载偏好设置
    func loadPreferences() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await NotificationService.shared.getPreferences()
            globalPushEnabled = data.globalPushEnabled
            preferences = data.preferences
            errorMessage = nil
            print("📬 NotificationSettingsViewModel: 加载成功 - globalPushEnabled=\(data.globalPushEnabled), 事件数=\(data.preferences.count)")
            for pref in data.preferences {
                print("   - \(pref.eventCode): group=\(pref.eventGroup), push=\(pref.pushEnabled)")
            }
        } catch {
            print("❌ NotificationSettingsViewModel: 加载偏好失败 - \(error)")
            errorMessage = "\(String(localized: "加载失败"))：\(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    /// 切换全局开关
    func toggleGlobalPush(_ enabled: Bool) async {
        let oldValue = globalPushEnabled
        globalPushEnabled = enabled  // 乐观更新
        print("📬 NotificationSettingsViewModel: 切换全局开关 \(oldValue) -> \(enabled)")

        do {
            try await NotificationService.shared.updateGlobalPushEnabled(enabled)
            errorMessage = nil
            print("✅ NotificationSettingsViewModel: 全局开关更新成功")
        } catch {
            globalPushEnabled = oldValue  // 回滚
            errorMessage = "\(String(localized: "保存失败"))：\(error.localizedDescription)"
            showErrorAlert = true
            print("❌ NotificationSettingsViewModel: 更新全局开关失败 - \(error)")
        }
    }

    /// 切换事件开关
    func toggleEventPush(eventCode: String, enabled: Bool) async {
        guard let index = preferences.firstIndex(where: { $0.eventCode == eventCode }) else { return }

        let oldValue = preferences[index].pushEnabled
        preferences[index].pushEnabled = enabled  // 乐观更新
        print("📬 NotificationSettingsViewModel: 切换事件 \(eventCode) 开关 \(oldValue) -> \(enabled)")

        do {
            try await NotificationService.shared.updateEventPreference(
                eventCode: eventCode,
                pushEnabled: enabled
            )
            errorMessage = nil
            print("✅ NotificationSettingsViewModel: 事件开关更新成功")
        } catch {
            preferences[index].pushEnabled = oldValue  // 回滚
            errorMessage = "\(String(localized: "保存失败"))：\(error.localizedDescription)"
            showErrorAlert = true
            print("❌ NotificationSettingsViewModel: 更新事件偏好失败 - \(error)")
        }
    }
}

// MARK: - View

struct NotificationSettingsView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        List {
            // 全局开关
            Section {
                Toggle("接收推送通知", isOn: Binding(
                    get: { viewModel.globalPushEnabled },
                    set: { newValue in
                        Task { await viewModel.toggleGlobalPush(newValue) }
                    }
                ))
            }

            // 互动消息
            if !viewModel.interactionPreferences.isEmpty {
                Section("互动消息") {
                    ForEach(viewModel.interactionPreferences) { pref in
                        eventToggleRow(pref)
                    }
                }
                .disabled(!viewModel.globalPushEnabled)
            }

            // 系统消息
            if !viewModel.systemPreferences.isEmpty {
                Section("系统消息") {
                    ForEach(viewModel.systemPreferences) { pref in
                        eventToggleRow(pref)
                    }
                }
                .disabled(!viewModel.globalPushEnabled)
            }

            // 说明
            Section {
                Text("关闭推送后，您仍可在消息页查看站内通知")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        navigationCoordinator.path.removeLast()
                    } label: {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        navigationCoordinator.path.removeLast()
                    } label: {
                        Image("icon-back")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .alert("提示", isPresented: $viewModel.showErrorAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .task {
            await viewModel.loadPreferences()
        }
    }

    @ViewBuilder
    private func eventToggleRow(_ pref: NotificationEventPreference) -> some View {
        Toggle(pref.localizedEventName, isOn: Binding(
            get: { pref.pushEnabled },
            set: { newValue in
                Task { await viewModel.toggleEventPush(eventCode: pref.eventCode, enabled: newValue) }
            }
        ))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(NavigationCoordinator())
    }
}
