//
//  EditNameView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/2/20.
//

import SwiftUI

struct EditNameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var toastManager: ToastManager
    @State private var userNickName: String = ""
    @State private var placeholder: String = String(localized: "请输入")
    @State private var canUpdate = false
    @State private var currentCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack{
                    HStack {
                        Text("✏️ 编辑名字")
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
                text: $userNickName,
                onSubmit: {
                    
                },
                maxCharacters: 24,
                showsCharacterCount: true,
                characterCount: $currentCount
            )
            
            VStack(alignment: .leading) {
                Text("请设置 2-24个字符，不包括 @<>/等无效字符。")
                    .foregroundStyle(Color(.gray))
            }
            
            Spacer()
            
            Button(action: {
                    // 发布-胶囊按钮fill
                UIApplication.shared.endEditing()
                Task {await validateUsername()}
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
    private func validateUsername() async {
        // 定义非法字符集合（这里包括 @, <, >, /）
        let invalidSet = CharacterSet(charactersIn: "@<>/")
        if userNickName.rangeOfCharacter(from: invalidSet) != nil {
            toastManager.show(ToastMessages.nameInvalidChars)
            dismiss()
            return
        }
        // 检查字符数量是否在 2 到 24 之间
        if userNickName.count < 2 || userNickName.count > 24 {
            toastManager.show(ToastMessages.nameLengthInvalid)
            dismiss()
            return
        }
        // 进行下一步操作（例如调用 API 更新用户名）
        await performNextStep()
    }
    
    /// 合法时执行的下一步操作
    private func performNextStep() async {
        Task {
            do {
                let updatedProfile = try await userProfileManager.updateUserNickname(newNickname: userNickName)
                if let profile = updatedProfile {
                    print("更新成功，最新昵称: \(profile.nickname)")
                    dismiss()
                    toastManager.show(ToastMessages.editSuccess)
                } else {
                    print("更新成功，但获取资料失败：nil")
                }
            } catch {
                print("更新昵称失败：\(error)")
                toastManager.show(ToastMessages.editFailed)
            }
        }
        
    }
    
}

#Preview {
    EditNameView()
        .environmentObject(UserProfileManager())
        .environmentObject(ToastManager())
}
