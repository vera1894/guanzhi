//
//  AccountManagementView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/3/9.
//

import SwiftUI

struct AccountManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var toastManager: ToastManager
    @Environment(\.appState) var appState
    @State private var showPhoneAlert = false
    @State private var showChangePhoneSheet = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteConfirmAlert = false
    @State private var deleteConfirmText = ""
    @State private var isDeletingAccount = false

    var body: some View {
        let localUser = userProfileManager.localUserProfile
        let items: [(label: String, value: String)] = [
            ("手机号", localUser?.phone ?? "")
        ]

            List {
                ForEach(items, id: \.label) { item in
                    HStack {
                        // 左侧固定文字
                        Text(LocalizedStringKey(item.label))
                        Spacer()

                        // 中间：本机用户资料
                    Text(formatPhoneNumberForDisplay(item.value))

                        // 右侧 chevron 按钮
                        Button {
                            handleAction(label: item.label)
                        } label: {
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 注销账号
                Section {
                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Text("注销账号")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(isDeletingAccount)
                }
            }
            .navigationTitle("账号与绑定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            navigationCoordinator.path.removeLast()
                        }) {
                            Image("icon-back")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            navigationCoordinator.path.removeLast()
                        }) {
                            Image("icon-back")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
        .alert("更换绑定的手机号？", isPresented: $showPhoneAlert) {
            Button("取消", role: .cancel) { }

            Button("更换") {
                toastManager.show(ToastMessages.phoneChangeNotReady)
            }
        } message: {
            Text("当前绑定的手机号码为\n\(formatPhoneNumberForDisplay(localUser?.phone ?? ""))")
        }
        // 第一步：注销警告
        .alert("确定要注销账号吗？", isPresented: $showDeleteAccountAlert) {
            Button("取消", role: .cancel) { }
            Button("继续注销", role: .destructive) {
                deleteConfirmText = ""
                showDeleteConfirmAlert = true
            }
        } message: {
            Text("注销后账号将无法恢复，您发布的观之仍会保留。")
        }
        // 第二步：输入确认
        .alert("请输入「注销」以确认", isPresented: $showDeleteConfirmAlert) {
            TextField("", text: $deleteConfirmText)
            Button("取消", role: .cancel) { }
            Button("注销", role: .destructive) {
                performDeleteAccount()
            }
            .disabled(!isDeleteConfirmValid)
        }
    }

    private var isDeleteConfirmValid: Bool {
        let lang = Locale.current.language.languageCode?.identifier ?? "zh"
        if lang == "en" {
            return deleteConfirmText.lowercased() == "delete"
        }
        return deleteConfirmText == "注销"
    }

    private func performDeleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                let data = try await OTONetwork.request(.deleteAccount)
                let decoder = JSONDecoder()
                let response = try decoder.decode(OTOResponseModel<String>.self, from: data)

                guard response.respCode == 0 else {
                    toastManager.show(ToastMessages.accountDeleteFailed)
                    isDeletingAccount = false
                    return
                }

                // 注销成功：清理本地数据 + 退出登录
                await DeviceService.shared.logoutDevice()
                try? userProfileManager.clearAllUserProfiles()
                appState.isShowingSearchView = true
                OTOLoginStatusManager.shared.logout()
                navigationCoordinator.path = NavigationPath()
                toastManager.show(ToastMessages.accountDeleted)
            } catch {
                toastManager.show(ToastMessages.accountDeleteFailed)
                isDeletingAccount = false
            }
        }
    }
    
    // 根据不同的列表项执行操作
    private func handleAction(label: String) {
        switch label {
        case "手机号":
            showPhoneAlert = true
        default:
            break
        }
    }
    
    // 格式化手机号，保留前三位和后四位，中间用星号代替
    private func formatPhoneNumberForDisplay(_ phone: String) -> String {
        if phone.isEmpty { return "" }
        
        // 处理不带国家代码的情况
        if phone.count > 7 {
            let prefix = String(phone.prefix(3))
            let suffix = String(phone.suffix(4))
            return "+86 \(prefix)****\(suffix)"
        }
        
        return "+86 \(phone)" // 如果格式不符合预期，返回带默认国家代码的原始号码
    }
    
}

// 新增的手机号更换视图
struct ChangePhoneNumberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newPhone = ""
    @State private var verificationCode = ""
    @State private var isCodeSent = false
    @State private var timeRemaining = 0
    @State private var isVerifying = false
    @State private var isComplete = false
    
    var onSuccess: (String) -> Void
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("绑定新手机号")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("新手机号")
                        .font(.headline)
                    
                    PhoneNumberTextField(phoneNumber: $newPhone, placeholder: "请输入新手机号")
                        .frame(height: 54)
                }
                .padding(.horizontal)
                
                if isCodeSent {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("验证码")
                            .font(.headline)
                        
                        OTPTextField(numberOfFields: 4, enterSMSCode: $verificationCode, isComplete: $isComplete)
                            .frame(height: 54)
                    }
                    .padding(.horizontal)
                    
                    Button {
                        if timeRemaining == 0 {
                            sendVerificationCode()
                        }
                    } label: {
                        Text(timeRemaining > 0 ? "\(timeRemaining)秒后可重新发送" : "重新发送验证码")
                            .font(.system(size: 16))
                            .underline(timeRemaining == 0)
                    }
                    .disabled(timeRemaining > 0)
                    .padding(.top, 8)
                }
                
                Spacer()
                
                if !isCodeSent {
                    Button("获取验证码") {
                        sendVerificationCode()
                    }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: ValidateEnum.phoneNum(newPhone).isRight))
                    .disabled(!ValidateEnum.phoneNum(newPhone).isRight)
                    .padding(.horizontal)
                } else {
                    Button("确认更换") {
                        verifyCodeAndChangePhone()
                    }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: isComplete && !isVerifying))
                    .disabled(!isComplete || isVerifying)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
            }
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
        }
    }
    
    private func sendVerificationCode() {
        // 发送验证码逻辑
        timeRemaining = 60
        isCodeSent = true
        
        // 调用发送验证码的API
        Task {
            do {
                let data = try await OTONetwork.request(.SendVerifiedCode(phoneNumber: newPhone))
                let decoder = JSONDecoder()
                let response = try decoder.decode(OTOResponseModel<String>.self, from: data)
                
                if response.respCode == 0 {
                    print("验证码发送成功")
                } else {
                    print("验证码发送失败: \(response.respMsg ?? "未知错误")")
                }
            } catch {
                print("发送验证码出错: \(error)")
            }
        }
    }
    
    private func verifyCodeAndChangePhone() {
        isVerifying = true
        
        // 这里添加验证码验证和手机号更换的逻辑
        // 调用验证码验证API并更新手机号
        
        // 示例:
        Task {
            do {
                // 模拟API调用延迟
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                
                // 成功后调用回调并关闭
                await MainActor.run {
                    onSuccess(newPhone)
                    dismiss()
                    isVerifying = false
                }
            } catch {
                print("验证失败: \(error)")
                isVerifying = false
            }
        }
    }
}

#Preview {
    // 模拟一个 UserProfileManager
    let manager = UserProfileManager()
    // 构造一个 mock 的 LocalUserProfile
    let mockLocalUser = LocalUserProfile(
        id: 999,
        name: "MockOneCode",
        nickname: "MockNickname",
        phone: "1234567890",
        photo: nil,
        code: nil,
        createDate: nil,
        jpushId: nil,
        titleDOS: nil
    )
    manager.localUserProfile = mockLocalUser
    
    return NavigationView {
        AccountManagementView()
            .environment(AppStateModel())
            .environmentObject(NavigationCoordinator())
            .environmentObject(manager)
    }
}
