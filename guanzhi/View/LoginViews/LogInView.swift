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
    
    // 添加测试通道相关状态
    @State private var tapCount: Int = 0
    @State private var isTestMode: Bool = false
    @State private var testToken = "Bearer eyJhbGciOiJIUzUxMiJ9.eyJqdGkiOiIyYTEzZjA0OThlZDI0ZmFlOWU3OTY2N2FhMzhlOTY1OSIsInVzZXIiOjExLCJuYW1lIjoiMTU4MTAzNDk3NjYiLCJuaWNrbmFtZSI6IjQ0NDQiLCJwaG9uZSI6IjE1ODEwMzQ5NzY2Iiwic3ViIjoiMTEifQ.ovN9drdZwUfGMRes7loS4Nwo_NURVYeQY1Uw1TuAhF_d8PfVNeFo8JN2z2juqc1MowgSr6hfynOR7dA-bP0wpQ"
    @State private var testPhone = "15810349766"
    @State private var directLogin = false
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
                        print("点击底层")
                    }
                    .edgesIgnoringSafeArea(.all)
                
                VStack{
                    Text(isTestMode ? "Input Secret Code" : "请输入你的手机号")
                        .fontWeight(.semibold)
                        .font(.system(size: 24))
                        .padding(.bottom,10)
                        .padding(.top,150)
                        .onTapGesture {
                            // 增加点击计数
                            tapCount += 1
                            if tapCount >= 10 {
                                isTestMode = true
                                print("测试模式已激活")
                            }
                        }
                    Text("我们将发送验证码到你的手机上")
                        .font(.system(size: 20))
                        .padding(.bottom,60)
                    
                    PhoneNumberTextField(phoneNumber: $userlogin.phone, placeholder: isTestMode ? "请输入测试密码" : "请输入手机号")
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
                        // 测试模式逻辑
                        if isTestMode && userlogin.phone == testPhone {
                            // 直接登录
                            userlogin.header = testToken
                            userlogin.loginState = 0
                            OTOLoginStatusManager.shared.login(token: testToken)
                            OTOLoginStatusManager.shared.setUserID(11) // 设置用户ID为11
                            directLogin = true
                        } else if isChecked {
                            nextPage = true
                            userlogin.firstSendMessage = true
                            userlogin.time = 60
                            
                            // TODO: - 待解除注释，发验证码
                            
                            userlogin.sendCode(phNumber:userlogin.phone)
                         
                        }
                        else if !ValidateEnum.phoneNum(userlogin.phone).isRight{
                            showNotice = true
                            userlogin.noticeText = "请输入正确的手机号"
                        }
                        print("input是否为空",userlogin.phone.isEmpty)
                        
                    } label: {
                        Text("🔜 下一步")
                            .animation(.easeInOut(duration: 0.3))
                    }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: isTestMode || isChecked))
                    .disabled(!isTestMode && !isChecked)
                    .navigationDestination(isPresented: $nextPage) {
                        MessageView(userlogin: userlogin)
                    }
                    .navigationDestination(isPresented: $directLogin) {
                        SearchView(animationNamespace: fallbackNamespace, userlogin: UserLoginModel())
                            .environment(\.appState, AppStateModel())
                            .environmentObject(LocationManager())
                            .environmentObject(SearchViewModel())
                            .environmentObject(ToastManager())
                            .environmentObject(UserProfileManager())
                            .environmentObject(NavigationCoordinator())
                    }
                    .padding(.horizontal,Constants.spacingSpacingM)
                    .padding(.bottom)
                    
                    
                }.onReceive(timer) { time in
                    guard userlogin.time > 0 else {return}
                    userlogin.time -= 1
                }.onAppear{
                    print("loginstate:",userlogin.loginState)
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
