//
//  PassthroughSpriteView.swift
//  guanzhi
//
//  Created by Claude Code on 2025/12/11.
//
//  带触摸穿透功能的 SpriteView 包装器
//

import SwiftUI
import SpriteKit

// MARK: - PassthroughSpriteView

/// 带触摸穿透功能的 SpriteView
/// 只有在指定的触摸区域内才会响应触摸事件
struct PassthroughSpriteView: UIViewRepresentable {

    let scene: SKScene

    /// 触摸激活区域（在视图坐标系中）
    /// 如果为 nil，则整个视图都响应触摸
    var touchActiveRegion: CGRect?

    func makeUIView(context: Context) -> PassthroughSKView {
        let view = PassthroughSKView()
        view.presentScene(scene)
        view.allowsTransparency = true
        view.backgroundColor = .clear
        view.ignoresSiblingOrder = true
        // 确保不会阻止用户交互穿透
        view.isUserInteractionEnabled = true
        return view
    }

    func updateUIView(_ uiView: PassthroughSKView, context: Context) {
        uiView.touchActiveRegion = touchActiveRegion
        if uiView.scene !== scene {
            uiView.presentScene(scene)
        }
    }
}

// MARK: - PassthroughSKView

/// 自定义 SKView，支持触摸穿透
final class PassthroughSKView: SKView {

    /// 触摸激活区域（在视图坐标系中）
    var touchActiveRegion: CGRect?

    /// 当前是否正在追踪触摸（拖拽中）
    private var isTrackingTouch = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 如果正在追踪触摸（拖拽中），始终返回 self 以继续接收触摸事件
        if isTrackingTouch {
            return self
        }

        // 如果设置了触摸激活区域，检查点击点是否在该区域内
        if let region = touchActiveRegion {
            if !region.contains(point) {
                // 点击点不在激活区域内，返回 nil 让事件穿透
                return nil
            }
        }

        // 默认行为
        return super.hitTest(point, with: event)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTrackingTouch = true
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        isTrackingTouch = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isTrackingTouch = false
    }
}
