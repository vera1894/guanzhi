//
//  NameView.swift
//  guanzhi
//
//  Created by Vera on 2024/4/7.
//

import SwiftUI

//名字
struct nameView: View {
    
    @State var input = ""
    @State var next =  false
    
    @ObservedObject var userlogin : UserLoginModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showNotice = false
    @State private var isLoading = false

    var body: some View {

        ZStack {  //用于在最底层增加点击收起键盘
            Color.clear // 最底层放置的收起键盘透明背景
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.endEditing()
                    print("点击底层")
                }
                .edgesIgnoringSafeArea(.all)
            
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
                    NicknameTextField(nickname: $userlogin.nickName, placeholder: "请输入名字")
                        .frame(height: 54)
                        .padding(.horizontal,Constants.spacingSpacingM)
                }
                .padding(.top,60)
                .shadow(color: Color("CardShadow"), radius: 30, x: 0, y: 15)

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
                                isLoading = true
                                userlogin.register()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if userlogin.namePassed{
                                    isLoading = false
                                    next = true
                                }else{
                                    showNotice = true
                                    isLoading = false
                                }
                            }
                                }) {
                                    Text("🔜 下一步")
                                }
                            .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: userlogin.nickName.count != 0))
                            .disabled(!(userlogin.nickName.count != 0))
                            .navigationDestination(isPresented: $next) {
                                SearchView(userlogin: UserLoginModel(), /*appState: AppStateModel(),*/ locationManager: LocationManager(), searchViewModel: SearchViewModel(/*appState: AppStateModel()*/))
                                    .environment(\.appState, AppStateModel())
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            
            if isLoading {
                ProcessingView()
            }
            
            }
        .background(Color("color-white"))
        }
    }


#Preview {
    nameView(userlogin: UserLoginModel())
        .preferredColorScheme(.dark) // 设置为夜间模式
}
