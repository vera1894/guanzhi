//
//  MessageView.swift
//  guanzhi
//
//  Created by Vera on 2024/4/7.
//

import SwiftUI

//验证验证码，未注册需要注册
struct MessageView: View {

    @State private var next =  false
    @ObservedObject var userlogin : UserLoginModel
    @Namespace private var fallbackNamespace

    @State private var timeRemaining = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showNotice = false

    @Environment(\.presentationMode) var presentationMode

    // ✅ 监听登录状态，登录成功后自动 dismiss
    @ObservedObject var loginManager = OTOLoginStatusManager.shared
    
//    @State var codeString = ["","","",""]
    @State private var enterSMSCode = ""
    @State private var isComplete = false
    @State private var isLoading = false
    
    //判断跳转路径
    func topage() -> some View{
        if userlogin.loginState == 1{
            // 新用户，跳转到设置昵称页面
            return AnyView(nameView(userlogin: userlogin))
        }
        // ✅ loginState == 0（老用户登录成功）或其他情况
        // 不返回 SearchView，登录状态已更新，guanzhiApp 中的 SearchView 会自动响应
        return AnyView(EmptyView())
    }
    
    //验证验证码
    func checkCode(phNumber: String, code: String) {
        Task {
            do {
                let data = try await OTONetwork.request(.checkCodeOrLogin(phoneNumber: phNumber, code: code))
                let decoder = JSONDecoder()
                let response = try decoder.decode(OTOResponseModel<String>.self, from: data)

                if response.respCode == 0 {
                    // ✅ 老用户登录成功
                    userlogin.loginState = 0
                    if let tokenString = response.datas {
                        userlogin.header = "Bearer " + tokenString
                        OTOLoginStatusManager.shared.login(token: userlogin.header)
                        userlogin.getUserInfo()
                    }
                    // ✅ 不设置 next = true
                    // OTOLoginStatusManager.shared.login() 会触发 @Published isLoggedIn 变化
                    // guanzhiApp 中的 SearchView 会自动从 LogInView 切换到主内容
                    isLoading = false
                } else if response.respCode == -1 && response.respMsg == "1" {
                    // 新用户，需要设置昵称
                    userlogin.loginState = 1
                    next = true  // ✅ 这个保留，跳转到 NameView
                    isLoading = false
                } else {
                    isLoading = false
                }
            } catch {
                // 错误已在 NetworkService 层处理
            }
        }
    }
    
    var body: some View {
        ZStack {  //用于在最底层增加点击收起键盘
            Color.clear // 最底层放置的收起键盘透明背景
                .contentShape(Rectangle())
                .onTapGesture {
//                    fieldFocus = nil
                    UIApplication.shared.endEditing()
                    print("点击底层")
                }
                .edgesIgnoringSafeArea(.all)
            
            VStack{
                    Text("请输入短信验证码")
                        .fontWeight(.semibold)
                        .font(.system(size: 24))
                        .padding(.bottom,10)
                        .padding(.top,150)
                    Text("输入\( userlogin.phone)收到的短信验证码")
                        .font(.system(size: 20))
                        .padding(.bottom,60)
                
                    
                OTPTextField(numberOfFields: 4, enterSMSCode: $enterSMSCode, isComplete: $isComplete)
                    .frame(height: 54)
                   
                    Button {
                        userlogin.sendCode(phNumber:userlogin.phone)
                        if userlogin.sendStatus{
                            userlogin.time = Constants.MessageTime
                        }
                        
                        if userlogin.noticeText.count != 0{
                            showNotice = true
                        }
                    } label: {
                        if userlogin.time == 0 || !userlogin.sendStatus {
                            Text("重新发送验证码").underline().font(.system(size: 16))
                          
                        }else{
                            Text("\(userlogin.time)秒后可重新发送")
                        }
                       
                    }.padding(20)
                    .disabled(userlogin.time != 0 && userlogin.sendStatus )
                    .onReceive(timer) { time in
                        if userlogin.firstSendMessage && userlogin.time > 0 {
                            userlogin.time -= 1
                        }
                    }

                    Spacer()
                    
                    HStack{
                        Button(action: {
                                    // 返回（白色）-胶囊按钮hug
                            withAnimation(.easeInOut(duration: 0.5)) {
                                presentationMode.wrappedValue.dismiss()
                            }
                                }) {
                                    Text("🔙️ 返回")
                                }
                            .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                        
                        Button(action: {
                                    // 下一步（禁用）-胶囊按钮fill
//                              checkCode(phNumber: userlogin.phone, code: codeString.joined())
                            checkCode(phNumber: userlogin.phone, code: enterSMSCode)
                            isLoading = true
                                }) {
                                    Text("🔜 下一步")
                                }
                            .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: isComplete))
                            .disabled(!isComplete)
                            .navigationDestination(isPresented: $next) {
                                topage()
                            }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    
                }
                .navigationBarBackButtonHidden(true)

                //提示 - 待调整
    //            .hud(isPresented: $showNotice){
    //                Text("\(userlogin.noticeText)")
    //            }
                .onAppear{
                    if userlogin.sendStatus == false{
                        showNotice = true
//                        userlogin.time = 0
                        print(userlogin.time)
                    }
            }
            
            if isLoading {
                ProcessingView()
            }
            
        }
        .background(Color("color-white"))
        // ✅ 监听登录状态变化，登录成功后自动 dismiss 整个登录流程
        .onChange(of: loginManager.isLoggedIn) { oldValue, newValue in
            if newValue {
                // 登录成功，dismiss 当前页面（返回到 LogInView）
                // LogInView 会被 SearchView 的条件分支自动移除
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

#Preview {
    MessageView(userlogin: UserLoginModel())
        .preferredColorScheme(.dark) // 设置为夜间模式
}
