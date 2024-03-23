//
//  LogInView.swift
//  guanzhi
//
//  Created by Vera on 2024/3/20.
//

import SwiftUI

struct LogInView: View {
    @State var sendStatus = false //手机号发送是否成功
    
    @State var nextPage = false //是否支持跳转
    
    @ObservedObject var userlogin : UserLoginModel
    
    @ObservedObject var vm : MessageinputViewModel

    @State private var showNotice = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        
        //前台手机号验证
        let isChecked = ValidateEnum.phoneNum(userlogin.phone).isRight && (userlogin.time == 0 )
        
        NavigationView{
            VStack{
                Text("请输入你的手机号")
                    .fontWeight(.semibold)
                    .font(.system(size: 24))
                    .padding(.bottom,10)
                    .padding(.top,150)
                Text("我们将发送验证码到你的手机上")
                    .font(.system(size: 20))
                    
                ZStack(alignment: .center){
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color("LightBlue")).frame(height: 48)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                       .stroke(Color("DarkBlue"), lineWidth: 1)
                        .frame(height: 48)
                    TextField("", text: $userlogin.phone)
                       
                        .font(.body.weight(.semibold))
                        .accentColor(Color("DarkBlue"))//光标颜色
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding(.horizontal,12)
                         
                }
                .padding(.top,60)
                .padding(.horizontal,44)
                .shadow(color: Color("CardShadow"), radius: 30, x: 0, y: 15)
                
                
                
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
                

                
                NavigationLink(destination: 
                                detailView()
                               // MessageView(userlogin: userlogin,vm:vm)
                               , isActive: $nextPage) {
                    Button {
                        if isChecked {
                            nextPage = true
                            userlogin.firstSendMessage = true
                            userlogin.time = 60
                            
                            // TODO: - 待解除注释，发验证码

                            userlogin.sendCode(phNumber:userlogin.phone)
                            vm.text = ""
                        }
                        else if !ValidateEnum.phoneNum(userlogin.phone).isRight{
                            showNotice = true
                            userlogin.noticeText = "请输入正确的手机号"
                        }
                        print("input是否为空",userlogin.phone.isEmpty)
                       
                    } label: {
                        
                        ZStack{
                            Circle()
                                .frame(height: 44)
                                .foregroundColor(Color(isChecked ? "ButtonPressed":"ButtonDefault"))
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.white)
                        }
                        
                        .animation(.easeInOut(duration: 0.3))
  
                    }
                    
                        .padding(.bottom,40)
                        
                }
            }.onReceive(timer) { time in
                guard userlogin.time > 0 else {return}
                    userlogin.time -= 1
            }.onAppear{
                print("loginstate:",userlogin.loginState)
            }
        }.navigationViewStyle(.stack)

    }
}

#Preview {
    LogInView(userlogin: UserLoginModel(),vm:MessageinputViewModel())
}
