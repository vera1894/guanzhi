//
//  NameView.swift
//  guanzhi
//
//  Created by Vera on 2024/4/7.
//

import SwiftUI

//名字
struct nameView:View{
    @State var input = ""
    @State var next =  false
    
    @ObservedObject var userlogin : UserLoginModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showNotice = false
    

    var body: some View {

        VStack{
            Text("起个名字")
                .fontWeight(.semibold)
                .font(.system(size: 24))
                .padding(.bottom,10)
                .padding(.top,150)
            Text("为自己起个酷酷的名字")
                .font(.system(size: 20))

            ZStack(alignment: .center){
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color("LightBlue")).frame(height: 48)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color("DarkBlue"), lineWidth: 1)
                    .frame(height: 48)
                PhoneNumberTextField(phoneNumber: $userlogin.nickName,placeholder: "请输入名字")
                    .frame(height: 54)
                    .padding(.horizontal,Constants.spacingSpacingM)
//                TextField("", text: $userlogin.nickName)
//                    .font(.body.weight(.semibold))
//                    .accentColor(Color("DarkBlue"))//光标颜色
//                    .multilineTextAlignment(.center)
//                  //  .keyboardType(.numberPad)
//                    .padding(.horizontal,12)

            }
            .padding(.top,60)
            .shadow(color: Color("CardShadow"), radius: 30, x: 0, y: 15)

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
                
                NavigationLink(destination: SearchView(), isActive: $next) {
                    Button {
                        userlogin.register()
                        if userlogin.namePassed{
                            next = true
                        }else{
                            showNotice = true
                        }
                              
                    } label: {
                        Text("✅ 完成")
                    }
                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: userlogin.nickName.count != 0))
                        .animation(.easeInOut(duration: 0.5))
                        .padding(.bottom,40)
                }
            }



        }
        //待调整
//        .hud(isPresented: $showNotice){
//            Text("\(userlogin.noticeText)")
//        }
    }
}

#Preview {
    nameView(userlogin: UserLoginModel())
}
