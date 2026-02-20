//
//  LogInView.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import SwiftUI

struct LogInView: View {
    
    @Environment(\.dismiss) var logInDismiss
    @State var sendStatus = false //手机号发送是否成功
    @State var nextPage = false //是否支持跳转
    @ObservedObject var userlogin : UserLoginModel
   // @ObservedObject var vm : MessageinputViewModel
    @State private var showNotice = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    #if APPSTORE_REVIEW
    // 审核专用：特殊账号登录（无需短信验证码）
    private let reviewPhone = "13263258926"
    #endif
    @Namespace private var fallbackNamespace
    
    var body: some View {
        
        //前台手机号验证
        let isChecked = ValidateEnum.phoneNum(userlogin.phone).isRight && (userlogin.time == 0 )
//        let isChecked = true
        
        NavigationStack{
            
            ZStack {  //用于在最底层增加点击收起键盘
                Color.clear // 最底层放置的收起键盘透明背景
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.endEditing()
                    }
                    .edgesIgnoringSafeArea(.all)
                
                VStack{
                    Text("请输入你的手机号")
                        .fontWeight(.semibold)
                        .font(.system(size: 24))
                        .padding(.bottom,10)
                        .padding(.top,150)
                    Text("我们将发送验证码到你的手机上")
                        .font(.system(size: 20))
                        .padding(.bottom,60)
                    
                    PhoneNumberTextField(phoneNumber: $userlogin.phone, placeholder: "请输入手机号")
                        .frame(height: 54)
                        .padding(.horizontal,Constants.spacingSpacingM)
                    
                    
                    Spacer()
                    
                    //剩余秒数文字提示
                    if userlogin.firstSendMessage{
                        Button {
                            
                        } label: {
                            if userlogin.time != 0 {
                                Text("\(userlogin.time)秒后可重新发送")
                                
                            }
                        }.disabled(userlogin.time != 0)
                    }
                    
                    
                    Button {
                        #if APPSTORE_REVIEW
                        // 审核特殊账号：调用 sendCode API（后端不发短信），然后跳转验证码页面
                        if userlogin.phone == reviewPhone {
                            nextPage = true
                            userlogin.sendCode(phNumber: userlogin.phone)
                        } else if isChecked {
                            nextPage = true
                            userlogin.firstSendMessage = true
                            userlogin.time = 60
                            userlogin.sendCode(phNumber:userlogin.phone)
                        } else if !ValidateEnum.phoneNum(userlogin.phone).isRight {
                            showNotice = true
                            userlogin.noticeText = "请输入正确的手机号"
                        }
                        #else
                        // 正式版本逻辑
                        if isChecked {
                            nextPage = true
                            userlogin.firstSendMessage = true
                            userlogin.time = 60
                            userlogin.sendCode(phNumber:userlogin.phone)
                        } else if !ValidateEnum.phoneNum(userlogin.phone).isRight {
                            showNotice = true
                            userlogin.noticeText = "请输入正确的手机号"
                        }
                        #endif
                    } label: {
                        Text("🔜 下一步")
                            .animation(.easeInOut(duration: 0.3))
                    }
                    #if APPSTORE_REVIEW
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: userlogin.phone == reviewPhone || isChecked))
                    .disabled(userlogin.phone != reviewPhone && !isChecked)
                    #else
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: isChecked))
                    .disabled(!isChecked)
                    #endif
                    .navigationDestination(isPresented: $nextPage) {
                        MessageView(userlogin: userlogin)
                    }
                    .padding(.horizontal,Constants.spacingSpacingM)
                    .padding(.bottom)
                    
                    
                }.onReceive(timer) { time in
                    guard userlogin.time > 0 else {return}
                    userlogin.time -= 1
                }
            }
            .background(Color("color-white"))
        }
    }
}

#Preview {
    LogInView(userlogin: UserLoginModel())
        .preferredColorScheme(.dark) // 设置为夜间模式
}
