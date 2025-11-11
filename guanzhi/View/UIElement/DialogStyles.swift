//
//  DialogStyles.swift
//  guanzhi
//
//  Created by Claude Code
//  全局弹窗样式配置文件
//

import SwiftUI

// MARK: - 全局弹窗遮罩配置
/// 统一管理整个 App 所有弹窗的遮罩样式
/// 修改这里的配置会影响所有使用了 DialogOverlay 的弹窗
public struct DialogOverlayConfig {
    /// 遮罩颜色
    public static let overlayColor: Color = .black
    /// 遮罩透明度 (0.0 - 1.0)
    /// 建议值：0.3-0.5 之间
    public static let overlayOpacity: Double = 0.4
    /// 动画时长（秒）
    public static let animationDuration: Double = 0.25
}

// MARK: - 弹窗遮罩视图组件
/// 为 confirmationDialog、alert、sheet 等弹窗添加统一的变暗背景
public struct DialogOverlay: View {
    public let isPresented: Bool

    public init(isPresented: Bool) {
        self.isPresented = isPresented
    }

    public var body: some View {
        Group {
            if isPresented {
                DialogOverlayConfig.overlayColor
                    .opacity(DialogOverlayConfig.overlayOpacity)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: DialogOverlayConfig.animationDuration), value: isPresented)
            }
        }
    }
}

// MARK: - 使用示例和说明
/*

 ## 基本使用方法

 在任何需要弹窗遮罩的View中：

 ```swift
 struct MyView: View {
     @State private var showAlert = false
     @State private var showDialog = false

     var body: some View {
         VStack {
             Button("显示弹窗") {
                 showAlert = true
             }
         }
         // 在 View 最外层添加遮罩（一次性监听所有弹窗状态）
         .overlay(DialogOverlay(isPresented: showAlert || showDialog))
         .alert("标题", isPresented: $showAlert) {
             Button("确定") { }
         }
         .confirmationDialog("选项", isPresented: $showDialog) {
             Button("选项1") { }
             Button("取消", role: .cancel) { }
         }
     }
 }
 ```

 ## 调整全局样式

 修改 `DialogOverlayConfig` 中的参数：

 - `overlayColor`: 修改遮罩颜色（如 .black, .gray, .white）
 - `overlayOpacity`: 修改透明度（0.0-1.0，0.4 = 40% 不透明度）
 - `animationDuration`: 修改动画时长（秒）

 */
