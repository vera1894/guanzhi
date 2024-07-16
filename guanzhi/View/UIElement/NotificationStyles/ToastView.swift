//
//  ToastView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/3/12.
//

import SwiftUI

/// Root View for Creating Overlay Window
struct ToastRootView<Content: View>: View {
    @ViewBuilder var content: Content
    /// View Properties
    @State private var overlayWindow: UIWindow?
    var body: some View {
        content
            .onAppear {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, overlayWindow == nil {
                    let window = PassthroughWindow(windowScene: windowScene)
                    window.backgroundColor = .clear
                    /// View Controller
                    let rootController = UIHostingController(rootView: ToastGroup())
                    rootController.view.frame = windowScene.keyWindow?.frame ?? .zero
                    rootController.view.backgroundColor = .clear
                    window.rootViewController = rootController
                    window.isHidden = false
                    window.isUserInteractionEnabled = true
                    window.tag = 1009
                    
                    overlayWindow = window
                }
            }
    }
}

/// 自定义窗口类，用于处理点击事件的穿透
fileprivate class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let view = super.hitTest(point, with: event) else { return nil }
        
        return rootViewController?.view == view ? nil : view
    }
}

@Observable
class Toast {
    static let shared = Toast()
    fileprivate var toasts: [ToastItem] = []
    
    func present(style: ToastStyle) {
        
        withAnimation(.snappy) {
            toasts.append(ToastItem(style: style))
        }
    }
}

fileprivate struct ToastItem: Identifiable {
    let id: UUID = .init()
    /// Custom Properties
    var style: ToastStyle
//    var title: String
//    var symbol: String?
//    var tint: Color
//    var isUserInteractionEnabled: Bool
//    /// Timing
//    var timing: ToastTime = .medium
//    var isAutoClose: Bool
}

enum ToastStyle {
    case notificationOnly(title: String, symbol: String?, tint: Color, isUserInteractionEnabled: Bool, timing: ToastTime, isAutoClose: Bool)
    case notificationOfWelcome(title: String, symbol: String?, tint: Color, isUserInteractionEnabled: Bool, timing: ToastTime, isAutoClose: Bool)
    case notificationWithButton(title: String, symbol: String?, tint: Color, isUserInteractionEnabled: Bool, timing: ToastTime, isAutoClose: Bool, buttonText: String, isButtonAction: Bool)
}

enum ToastTime: CGFloat {
    case short = 3.0
    case medium = 5.0
    case long = 60.0
}

//enum ToastStyle {
//    case notificationOnly
//    case notificationWithButton
//}

fileprivate struct ToastGroup: View {
    var model = Toast.shared
    var body: some View {
        GeometryReader {
            let size = $0.size
            
            ZStack {
                ForEach(model.toasts) { toast in
                    ToastView(size: size, item: toast)
                        .scaleEffect(scale(toast))
                        .offset(y: offsetY(toast))
                        .zIndex(Double(model.toasts.firstIndex(where: { $0.id == toast.id }) ?? 0))
                }
            }
            .ignoresSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    func offsetY(_ item: ToastItem) -> CGFloat {
        let index = CGFloat(model.toasts.firstIndex(where: { $0.id == item.id }) ?? 0)
        let totalCount = CGFloat(model.toasts.count) - 1
        return (totalCount - index) >= 2 ? -20 : ((totalCount - index) * -10)
    }
    
    func scale(_ item: ToastItem) -> CGFloat {
        let index = CGFloat(model.toasts.firstIndex(where: { $0.id == item.id }) ?? 0)
        let totalCount = CGFloat(model.toasts.count) - 1
        return 1.0 - ((totalCount - index) >= 2 ? 0.2 : ((totalCount - index) * 0.1))
    }
}

fileprivate struct ToastView: View {
    var size: CGSize
    var item: ToastItem
    
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let startTime: Date = Date()
    @State private var elapsedTime: Double = 0.0
    /// View Properties
    @State private var delayTask: DispatchWorkItem?
    
    @ViewBuilder
    var body: some View {
        
        switch item.style {
        case .notificationOnly(let title, let symbol, let tint, let isUserInteractionEnabled, let timing, let isAutoClose):
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
                                Button(action: {
                                    removeToast()// 点击按钮隐藏通知
                                        }) {
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
                            .onReceive(timer) { _ in
                                let elapsedTime = Date().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
                                if elapsedTime < timing.rawValue {
                                    self.elapsedTime = elapsedTime
                                } else  {
                                    self.elapsedTime = timing.rawValue
                                }
                            }
                            .onDisappear {
                                timer.upstream.connect().cancel()
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
                            removeToast()
                        }
                    })
            )
            .onAppear {
                guard delayTask == nil else { return }
                delayTask = .init(block: {
                    removeToast()
                })
                
                if let delayTask {
                    DispatchQueue.main.asyncAfter(deadline: .now() + timing.rawValue, execute: delayTask)
                }
            }
            .transition(.offset(y: -150))
            
            

        case .notificationOfWelcome(let title, let symbol, let tint, let isUserInteractionEnabled, let timing, let isAutoClose): ZStack {
            
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
                            Button(action: {
                                removeToast()// 点击按钮隐藏通知
                                    }) {
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
                        .onReceive(timer) { _ in
                            let elapsedTime = Date().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
                            if elapsedTime < timing.rawValue {
                                self.elapsedTime = elapsedTime
                            } else  {
                                self.elapsedTime = timing.rawValue
                            }
                        }
                        .onDisappear {
                            timer.upstream.connect().cancel()
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
                        removeToast()
                    }
                })
        )
        .onAppear {
            guard delayTask == nil else { return }
            delayTask = .init(block: {
                removeToast()
            })
            
            if let delayTask {
                DispatchQueue.main.asyncAfter(deadline: .now() + timing.rawValue, execute: delayTask)
            }
        }
        .transition(.offset(y: -150))
            
            
        case .notificationWithButton(let title, let symbol, let tint, let isUserInteractionEnabled, let timing, let isAutoClose, let buttonText, let isButtonAction):
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
                                Button(action: {
                                    removeToast()// 点击按钮隐藏通知
                                        }) {
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
                            .onReceive(timer) { _ in
                                let elapsedTime = Date().timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
                                if elapsedTime < timing.rawValue {
                                    self.elapsedTime = elapsedTime
                                } else  {
                                    self.elapsedTime = timing.rawValue
                                }
                            }
                            .onDisappear {
                                timer.upstream.connect().cancel()
                            }
                            .padding(.vertical,68)
                            .padding(.horizontal,16)
                }
                
                VStack{
                    Spacer()
                    
                    Button(action: {
                        if isButtonAction{
                            
                        }
                            }) {
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
                            removeToast()
                        }
                    })
            )
            .onAppear {
                guard delayTask == nil else { return }
                delayTask = .init(block: {
                    removeToast()
                })
                
                if let delayTask {
                    DispatchQueue.main.asyncAfter(deadline: .now() + timing.rawValue, execute: delayTask)
                }
            }
            .transition(.offset(y: -200))
            
            
            
                }
    }
    
    func removeToast() {
        if let delayTask {
            delayTask.cancel()
        }
        withAnimation(.snappy) {
            Toast.shared.toasts.removeAll(where: { $0.id == item.id })
        }
    }
    
    
}

#Preview {
    ToastRootView {
        AutoNotificationBanner()
    }
}
