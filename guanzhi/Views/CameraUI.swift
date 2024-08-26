/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that presents the main camera user interface.
*/

import SwiftUI
import AVFoundation

/// A view that presents the main camera user interface. 展示主要相机用户界面的视图。
struct CameraUI<CameraModel: Camera>: PlatformView {

    @State var camera: CameraModel
    @Binding var swipeDirection: SwipeDirection
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            // 根据设备尺寸类别选择合适的UI布局。
            if isRegularSize {
                regularUI
            } else {
                compactUI
            }
        }
        .overlay(alignment: .top) {
            // 根据捕获模式显示相应的叠加视图。
            switch camera.captureMode {
            case .photo:
                LiveBadge()
                    .opacity(camera.captureActivity.isLivePhoto ? 1.0 : 0.0)
            case .video:
                RecordingTimeView(time: camera.captureActivity.currentTime)
                    .offset(y: isRegularSize ? 20 : 0)
            }
        }
        .overlay {
            // 显示相机状态的叠加视图。
            StatusOverlayView(status: camera.status)
        }
    }
    
    /// This view arranges UI elements vertically. 在紧凑设备上垂直排列UI元素的视图。
    @ViewBuilder
    var compactUI: some View {
        VStack(spacing: 0) {
            FeaturesToolbar(camera: camera)
            Spacer()
//            CaptureModeView(camera: camera, direction: $swipeDirection) //暂时禁用拍摄模式切换
            MainToolbar(camera: camera)
//                .background(Color.red)
//                .padding(.bottom, bottomPadding)
        }
    }
    
    /// This view arranges UI elements in a layered stack. 在常规大小设备上分层排列UI元素的视图。
    @ViewBuilder
    var regularUI: some View {
        VStack {
            Spacer()
            ZStack {
                
//                CaptureModeView(camera: camera, direction: $swipeDirection)  //暂时禁用拍摄模式切换
//                    .offset(x: -250) // The vertical offset from center.
                MainToolbar(camera: camera)
                FeaturesToolbar(camera: camera)
                    .frame(width: 250)
                    .offset(x: 250) // The vertical offset from center.
            }
            .frame(width: 740)
            .background(.ultraThinMaterial.opacity(0.8))
            .cornerRadius(12)
            .padding(.bottom, 32)
        }
    }
    
    /// 处理滑动手势以切换捕获模式。
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded {
                // Capture the swipe direction. 捕获滑动方向。
                swipeDirection = $0.translation.width < 0 ? .left : .right
            }
    }
    
    var bottomPadding: CGFloat {
        // Dynamically calculate the offset for the bottom toolbar in iOS. 动态计算底部工具栏在 iOS 中的偏移量。
        let bounds = UIScreen.main.bounds
        let rect = AVMakeRect(aspectRatio: movieAspectRatio, insideRect: bounds)
        return (rect.minY.rounded() / 2) + 12
    }
}

#Preview {
    CameraUI(camera: PreviewCameraModel(), swipeDirection: .constant(.left))
}
