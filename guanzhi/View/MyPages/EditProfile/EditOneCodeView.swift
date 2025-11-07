//
//  EditOneCodeView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/2/21.
//

import SwiftUI

struct EditOneCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var toastManager: ToastManager
    @State private var userOneCode: String = ""
    @State private var placeholder: String = "请输入"
    @State private var canUpdate = false
    @State private var currentCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack{
                    HStack {
                        Text("✏️ 编辑OneCode")
                            .font(.title3)
                            .bold()
                        Spacer()
                    }
                    
                    HStack {
                        Spacer()
                        Button{
                            //关闭按钮-圆形
                            dismiss()
                        }label: {
                            Image("icon-close")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                    .frame(maxWidth: .infinity)
                }
                
            }
            
            CapsuleTextField(
                placeholder: placeholder,
                text: $userOneCode,
                onSubmit: {
                    
                },
                maxCharacters: 16,
                showsCharacterCount: true,
                characterCount: $currentCount
            )
            
            VStack(alignment: .leading) {
                Text("请设置6-16个字符，仅可使用英文(必须)、数字、下划线。OneCode是账号的唯一凭证，不能和其他人重复。")
                    .foregroundStyle(Color(.gray))
            }
            
            Spacer()
            
            Button(action: {
                    // 发布-胶囊按钮fill
                UIApplication.shared.endEditing()
                Task {await validateUserOnecode()}
                }) {
                    Text("✅ 确认")
                }
            .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: canUpdate))
            
        }
        .padding()
        .onChange(of: currentCount) { oldValue, newValue in
            if newValue >= 2 {
                canUpdate = true
            } else {
                canUpdate = false
            }
        }
        
    }
    
    /// 检查用户名是否合法
    private func validateUserOnecode() async {
        // 定义允许的字符集合：仅允许英文（大小写）、数字和下划线
        let allowedSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        
        // 检查输入中是否包含非法字符（即不在允许集合中的字符）
        if userOneCode.rangeOfCharacter(from: allowedSet.inverted) != nil {
            showNotification(message: "❌ 仅可使用英文、数字、下划线")
            dismiss()
            return
        }
        
        // 检查字符数量是否在 6 到 16 之间
        if userOneCode.count < 6 || userOneCode.count > 16 {
            showNotification(message: "❌ OneCode长度须为6-16个字符")
            dismiss()
            return
        }
        
        // 输入合法，继续下一步操作
        await performNextStep()
    }
    
    /// 合法时执行的下一步操作
    private func performNextStep() async {
        Task {
            do {
                let updatedProfile = try await userProfileManager.updateUserName(newName: userOneCode)
                if let profile = updatedProfile {
                    print("更新成功，最新OneCode: \(profile.name)")
                    dismiss()
                    showNotification(message: "✅ 修改成功")
                } else {
                    print("更新成功，但获取资料失败：nil")
                }
            } catch {
                print("更新OneCode失败：\(error)")
                showNotification(message: "❌ 修改失败")
            }
        }
        
    }
    
    private func showNotification(message: String) {
        let newItem = ToastItem(style: .notificationOnly(
            title: message,
            symbol: "",
            tint: Color("color-primary"),
            isUserInteractionEnabled: true,
            timing: .short,
            isAutoClose: true
        ))
        toastManager.show(newItem)
    }
}

#Preview {
    EditOneCodeView()
        .environmentObject(UserProfileManager())
        .environmentObject(ToastManager())
}
