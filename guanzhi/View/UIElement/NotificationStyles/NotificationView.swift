//
//  NotificationView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/12/31.
//
import SwiftUI

/// ========== NotificationOnlyView
struct NotificationOnlyView: View {
    let title: String
    let symbol: String?
    let tint: Color
    let isUserInteractionEnabled: Bool
    let timing: ToastTime
    let isAutoClose: Bool
    
    @Binding var elapsedTime: CGFloat
    var onClose: ()->Void
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Label(
                    title: {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color("text-black"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    },
                    icon: {
                        if let symbol = symbol {
                            Image(systemName: symbol)
                                .font(.title3)
                        }
                    }
                )
                .padding(.bottom,4)
            }

            HStack {
                Spacer()
                VStack{
                    Spacer()
                        Circle()
                        .foregroundColor(.clear)
                        .overlay{
                            Button(action: { onClose() }) {
                                Image("icon-X")
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .overlay {
                            Circle()
                                .trim(from: isAutoClose ?  (elapsedTime/timing.rawValue) : 0, to: 1)
                                .stroke(Color.black, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .round))
                                .rotationEffect(Angle(degrees: 270))
                                .animation(.linear(duration: 0.2), value: elapsedTime)
                        }
                        .frame(width: 32, height: 32)
                }
                .padding(.vertical,8)
                .padding(.horizontal,16)
            }

        }
        .ignoresSafeArea(.all)
        .frame(height: 110, alignment: .center)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                .foregroundColor(tint)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                .stroke(Color.black, lineWidth: 4)
        )
        .compositingGroup()
        .shadow(color: tint.opacity(1), radius: 0, x: 2, y: 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded({ value in
                    guard isUserInteractionEnabled else { return }
                    let endY = value.translation.height
                    let velocityY = value.velocity.height

                    if (endY + velocityY) < -100 {
                        onClose()
                    }
                })
        )
        .transition(.offset(y: -150))
    }
}

/// ========== NotificationOfWelcomeView
struct NotificationOfWelcomeView: View {
    let title: String
    let symbol: String?
    let tint: Color
    let isUserInteractionEnabled: Bool
    let timing: ToastTime
    let isAutoClose: Bool
    
    @Binding var elapsedTime: CGFloat
    var onClose: ()->Void
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Label(
                    title: {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color("text-black"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    },
                    icon: {
                        if let symbol = symbol {
                            Image(systemName: symbol)
                                .font(.title3)
                        }
                    }
                )
                .padding(.bottom,4)
            }

            HStack {
                Spacer()
                VStack{
                    Spacer()
                    Circle()
                    .foregroundColor(.clear)
                    .overlay{
                        Button(action: { onClose() }) {
                            Image("icon-X")
                                .frame(width: 14, height: 14)
                        }
                    }
                    .overlay {
                        Circle()
                            .trim(from: isAutoClose ?  (elapsedTime/timing.rawValue) : 0, to: 1)
                            .stroke(Color.black, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .round))
                            .rotationEffect(Angle(degrees: 270))
                            .animation(.linear(duration: 0.2), value: elapsedTime)
                    }
                    .frame(width: 32, height: 32)
                }
                .padding(.vertical,8)
                .padding(.horizontal,16)
            }
        }
        .ignoresSafeArea(.all)
        .frame(height: 110, alignment: .center)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                .foregroundColor(tint)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                .stroke(Color.black, lineWidth: 4)
        )
        .compositingGroup()
        .shadow(color: tint.opacity(1), radius: 0, x: 2, y: 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded({ value in
                    guard isUserInteractionEnabled else { return }
                    let endY = value.translation.height
                    let velocityY = value.velocity.height

                    if (endY + velocityY) < -100 {
                        onClose()
                    }
                })
        )
        .transition(.offset(y: -150))
    }
}

/// ========== NotificationWithButtonView
struct NotificationWithButtonView: View {
    let title: String
    let symbol: String?
    let tint: Color
    let isUserInteractionEnabled: Bool
    let timing: ToastTime
    let isAutoClose: Bool
    let buttonText: String
    let isButtonAction: Bool
    
    @Binding var elapsedTime: CGFloat
    var onClose: ()->Void
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Label(
                    title: {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color("text-black"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    },
                    icon: {
                        if let symbol = symbol {
                            Image(systemName: symbol)
                                .font(.title3)
                        }
                    }
                )
                .padding(.bottom,64)
            }

            HStack {
                Spacer()

                VStack{
                    Spacer()
                        Circle()
                        .foregroundColor(.clear)
                        .overlay{
                            Button(action: { onClose() }) {
                                        Image("icon-X")
                                            .frame(width: 14, height: 14)
                                    }
                        }
                        .overlay {
                            Circle()
                                .trim(from: isAutoClose ?  (elapsedTime/timing.rawValue) : 0, to: 1)
                                .stroke(Color.black, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, lineJoin: .round))
                                .rotationEffect(Angle(degrees: 270))
                                .animation(.linear(duration: 0.2), value: elapsedTime)
                        }
                        .frame(width: 32, height: 32)
                }
                .padding(.vertical,68)
                .padding(.horizontal,16)
            }

            VStack{
                Spacer()
                Button(action: {
                    if isButtonAction{

                    }}
                ) {
                    Text(buttonText)
                }
                .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                .padding(.vertical,24)
                .padding(.horizontal,16)
            }
        }
        .ignoresSafeArea(.all)
        .frame(height: 160, alignment: .center)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                .foregroundColor(tint)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 20.0, bottomTrailing: 20.0, topTrailing: 0), style: .continuous)
                .stroke(Color.black, lineWidth: 4)
        )
        .compositingGroup()
        .shadow(color: tint.opacity(1), radius: 0, x: 2, y: 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded({ value in
                    guard isUserInteractionEnabled else { return }
                    let endY = value.translation.height
                    let velocityY = value.velocity.height

                    if (endY + velocityY) < -100 {
                        onClose()
                    }
                })
        )
        .transition(.offset(y: -200))
    }
}

