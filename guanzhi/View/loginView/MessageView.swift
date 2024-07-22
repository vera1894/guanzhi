//
//  MessageView.swift
//  guanzhi
//
//  Created by Vera on 2024/4/7.
//

//
//  MessageView.swift
//  OnettoO-iOS
//
//  Created by Vera on 2023/3/6.
//

import SwiftUI

//验证验证码，未注册需要注册
struct MessageView: View {
    
    @State private var next =  false
    @ObservedObject var userlogin : UserLoginModel
  //  @ObservedObject var vm : MessageinputViewModel
    
    @State private var timeRemaining = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showNotice = false
    
    @Environment(\.presentationMode) var presentationMode
    
    @State var codeString = ["","","",""]
    @State var input = "" //临时输入框方案
    
    //判断跳转路径
    func topage() -> some View{
        
        if userlogin.loginState == 1{
            return AnyView(nameView(userlogin: userlogin))
        }
        if userlogin.loginState == 0{
            //登陆成功
            return AnyView(SearchView())
        }else {
            return AnyView(EmptyView())
            
        }
        
    }
    
    //验证验证码
    func checkCode(phNumber:String,code:String){
        
        Task {
            guard let data = try? await OTONetwork.request(.checkCodeOrLogin(phoneNumber: phNumber, code: code)) else { return }
            
            print(data)
            do {
                let decoder = JSONDecoder()
                if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []) {
                    let response = try decoder.decode(OTOResponseModel.self, from: jsonData)
                    //已注册
                    if response.respCode == 0 {
                        print("验证码验证成功")
                        userlogin.loginState = 0
                        if let string = response.datas {
                            userlogin.header = "Bearer " + string
                            print("登录令牌：", userlogin.header)
                            
                            OTOLoginStatusManager.shared.login(token: userlogin.header)
                            //获取用户昵称
                            userlogin.getUserInfo()
                        }
                        next = true
                    }

                    //未注册
                    if response.respCode == -1 && response.respMsg == "1" {
                        print("需要注册")
                        userlogin.loginState = 1
                        next = true
                    }
                    //验证码错误
                    else {
                        print(response.respMsg)
                    }
        
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
    }
    var body: some View {
            VStack{
                Text("请输入短信验证码")
                    .fontWeight(.semibold)
                    .font(.system(size: 24))
                    .padding(.bottom,10)
                    .padding(.top,150)
                Text("输入\( userlogin.phone)收到的短信验证码")
                    .font(.system(size: 20))
                
                //OTPTextField(numberOfFields: 4, enterValue: $codeString)
               // inputView(vm: vm)
               // TextField("", text: $input).keyboardType(.numberPad) //临时结局方式
                PhoneNumberTextField(phoneNumber: $input,placeholder: "请输入验证码")
                    .frame(height: 54)
                    .padding(.horizontal,Constants.spacingSpacingM)
               
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
                
                ZStack{
                    
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        ZStack{
                            Circle()
                                .frame(height: 36)
                                .foregroundColor(Color("ButtonPressed"))
                               
                            Image(systemName: "chevron.left")
                                .foregroundColor(Color.white)
                        }
                    }.animation(.easeInOut(duration: 0.5))
                        .padding(.bottom,40)
                        .offset(x:-60)

                    //下一步按钮
                    Button {
                      //  checkCode(phNumber: userlogin.phone, code: codeString.joined())
                        
                        checkCode(phNumber: userlogin.phone, code: input)
                        
                    } label: {
                        Text("🔜 下一步")
                    }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: next))
                    .navigationDestination(isPresented: $next) {
                        topage()
                    }
                    .padding(20)
                        
                   
                }
                
                
                
            }
            .navigationBarBackButtonHidden(true)

            //提示 - 待调整
//            .hud(isPresented: $showNotice){
//                Text("\(userlogin.noticeText)")
//            }
            .onAppear{
                if userlogin.sendStatus == false{
                    showNotice = true
                    userlogin.time = 0
                }
            }
    }
}





#Preview {
    MessageView(userlogin: UserLoginModel())
}
