/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Extensions and supporting SwiftUI types.
*/

import SwiftUI
import UIKit

// 定义了大按钮和小按钮的尺寸。
let largeButtonSize = CGSize(width: 64, height: 64)
let smallButtonSize = CGSize(width: 32, height: 32)

@MainActor
// 定义了一个协议 PlatformView，它继承了 View 协议。
protocol PlatformView: View {
    // 提供当前界面的垂直和水平尺寸类别。
    var verticalSizeClass: UserInterfaceSizeClass? { get }
    var horizontalSizeClass: UserInterfaceSizeClass? { get }
    var isRegularSize: Bool { get } // 检查当前界面是否为常规尺寸。
    var isCompactSize: Bool { get } // 检查当前界面是否为紧凑尺寸。
}

// 为 PlatformView 协议提供了默认实现。
extension PlatformView {
    var isRegularSize: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }
    var isCompactSize: Bool { horizontalSizeClass == .compact || verticalSizeClass == .compact }
}

/// A container view for the app's toolbars that lays the items out horizontally on iPhone and vertically on iPad and Mac Catalyst. 一个适应性工具栏容器视图，根据设备尺寸类别水平或垂直排列项目。
struct AdaptiveToolbar<Content: View>: PlatformView {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // 设置水平和垂直间距。
    private let horizontalSpacing: CGFloat
    private let verticalSpacing: CGFloat
    private let content: Content
    
    init(horizontalSpacing: CGFloat = 0.0, verticalSpacing: CGFloat = 0.0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
    
    var body: some View {
        // 如果是常规尺寸，垂直排列内容，否则水平排列内容。
        if isRegularSize {
            VStack(spacing: verticalSpacing) { content }
        } else {
            HStack(spacing: horizontalSpacing) { content }
        }
    }
}

// 定义了一个默认按钮样式。
struct DefaultButtonStyle: ButtonStyle {
    
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum Size: CGFloat {
        case small = 22
        case large = 24
    }
    
    private let size: Size
    
    init(size: Size) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
        // 根据按钮是否启用设置前景色。
            .foregroundColor(isEnabled ? .primary : Color(white: 0.4))
            .font(.system(size: size.rawValue))
            // Pad buttons on devices that use the `regular` size class, and also when explicitly requesting large buttons. 在使用常规尺寸类别的设备上以及显式请求大按钮时添加填充。
            .padding(isRegularSize || size == .large ? 10.0 : 0)
//            .background(.black.opacity(0.4))
            .clipShape(size == .small ? AnyShape(Rectangle()) : AnyShape(Circle()))
    }
    
    var isRegularSize: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
}

// 扩展 View，以添加调试边框的方法。
extension View {
    func debugBorder(color: Color = .red) -> some View {
        self
            .border(color)
    }
}

// 扩展 Image，以使用 CGImage 初始化。
extension Image {
    init(_ image: CGImage) {
        self.init(uiImage: UIImage(cgImage: image))
    }
}
