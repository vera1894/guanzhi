//
//  AutoNotificationBanner.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/7.
//  测试用

import SwiftUI

struct AutoNotificationBanner: View {
    @EnvironmentObject var toastManager: ToastManager
    @State private var infoText: String = "🌍世界虽大 吾可观之👀"
    
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let startTime: Date = Date()
    private let endTime: Double = 4
    @State private var elapsedTime: Double = 0.0
    
    
    var body: some View {
        ZStack{
            VStack{
                ZStack {
                    VStack{
                        Spacer()
                        
                        HStack {
                            Label(
                                title: {
                                    Text(infoText)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color("text-black"))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                },
                                icon: {}
                            )
                            .padding(.bottom,64)
                        }
                        
                    }
                        .frame(height: 160, alignment: .center)
                        .frame(maxWidth: .infinity)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                                .foregroundColor(Color("color-primary"))
                        )
                        .overlay(
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                                .stroke(Color.black, lineWidth: 4)
                        )
                        .compositingGroup()
                    .shadow(color: Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
                    
                    
                    HStack {
                        Spacer()
                        
                        VStack{
                                Circle()
                                .foregroundColor(.clear)
                                .overlay{
                                    Button(action: {
                                                //
                                            }) {
                                                Image("icon-X")
                                                    .frame(width: 14, height: 14)
                                            }
                                }
                                .overlay {
                                    Circle()
                                        .trim(from: (elapsedTime/endTime), to: 1)
                                        .stroke(Color.black, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .round))
                                        .rotationEffect(Angle(degrees: 270))
                                        .animation(.linear(duration: 0.2), value: elapsedTime)
                                }
                                .frame(width: 32, height: 32)
                                
                                }
                                .onReceive(timer) { _ in
                                    let elapsedTime = Date().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
                                    if elapsedTime < endTime {
                                        self.elapsedTime = elapsedTime
                                    } else  {
                                        self.elapsedTime = endTime
                                    }
                                }
                                .onDisappear {
                                    timer.upstream.connect().cancel()
                                }
                                .padding(.vertical,68)
                                .padding(.horizontal,16)
                        
                    }
                    .frame(height: 160, alignment: .bottomTrailing)
                    .frame(maxWidth: .infinity)
                    
                    
                    VStack{
                        Spacer()
                        
                        Button(action: {
                                    // 求助（紫色）-胶囊按钮fill
                                }) {
                                    Text("🥺 求一下这里最新的照片或视频")
                                }
                            .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                            .padding(.vertical,20)
                            .padding(.horizontal,16)
                    }
                    .frame(height: 160, alignment: .bottomTrailing)
                    .frame(maxWidth: .infinity)
                    
                    
                }
                .ignoresSafeArea(.all)
                
                ZStack {
                    VStack{
                        Spacer()
                        
                        HStack {
                            Label(
                                title: {
                                    Text(infoText)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color("text-black"))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                },
                                icon: {}
                            )
                            .padding(.bottom,4)
                            
                            
                        }
                        
                    }
                        .frame(height: 110, alignment: .center)
                        .frame(maxWidth: .infinity)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                                .foregroundColor(Color("color-primary"))
                        )
                        .overlay(
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                                .stroke(Color.black, lineWidth: 4)
                        )
                        .compositingGroup()
                    .shadow(color: Color("color-primary").opacity(1), radius: 0, x: 2, y: 4)
                    
                    
                    HStack {
                        Spacer()
                        
                        VStack{
                                Circle()
                                .foregroundColor(.clear)
                                .overlay{
                                    Button(action: {
                                                //
                                            }) {
                                                Image("icon-X")
                                                    .frame(width: 14, height: 14)
                                            }
                                }
                                .overlay {
                                    Circle()
                                        .trim(from: (elapsedTime/endTime), to: 1)
                                        .stroke(Color.black, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .round))
                                        .rotationEffect(Angle(degrees: 270))
                                        .animation(.linear(duration: 0.2), value: elapsedTime)
                                }
                                .frame(width: 32, height: 32)
                                
                                }
                                .onReceive(timer) { _ in
                                    let elapsedTime = Date().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
                                    if elapsedTime < endTime {
                                        self.elapsedTime = elapsedTime
                                    } else  {
                                        self.elapsedTime = endTime
                                    }
                                }
                                .onDisappear {
                                    timer.upstream.connect().cancel()
                                }
                                .padding(.vertical,8)
                                .padding(.horizontal,16)
                    }
                    .frame(height: 110, alignment: .bottomTrailing)
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea(.all)
                
                
                Spacer()
                
                VStack {
                    Button("进入主页的通知-自动关闭") {
                        let newItem = ToastItem(style: .notificationOfWelcome(
                            title: "🌍世界虽大 吾可观之👀",
                            symbol: "",
                            tint: Color("color-primary"),
                            isUserInteractionEnabled: true,
                            timing: .medium,
                            isAutoClose: true
                        ))
                        toastManager.show(newItem)
                    }
                    
                    Button("系统通知-自动关闭") {
                        let newItem = ToastItem(style: .notificationOnly(
                            title: "⛔验证码错误请重试",
                            symbol: "",
                            tint: Color("color-primary"),
                            isUserInteractionEnabled: true,
                            timing: .short,
                            isAutoClose: true
                        ))
                        toastManager.show(newItem)
                    }
                    
                    Button("带按钮的通知-自动关闭") {
                        let newItem = ToastItem(style: .notificationWithButton(
                            title: "🔉你所在的地点有人在求助！",
                            symbol: "",
                            tint: Color("color-primary"),
                            isUserInteractionEnabled: true,
                            timing: .long,
                            isAutoClose: true,
                            buttonText: "查看求助信息",
                            isButtonAction: true
                        ))
                        toastManager.show(newItem)
                    }
                }
            }
            
            
            GlobalToastContainerView()
        }
        
    }
    
}

#Preview {
    AutoNotificationBanner()
        .environmentObject(ToastManager())
}
