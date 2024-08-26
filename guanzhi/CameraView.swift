/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main user interface for the sample app.
*/

import SwiftUI
import AVFoundation
import AVKit

// 定义一个 @MainActor 的结构体 CameraView，它泛型参数为 CameraModel，且遵循 PlatformView 协议
@MainActor
struct CameraView<CameraModel: Camera>: PlatformView {
    
    // 环境变量，用于获取设备的垂直、水平尺寸类别
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    
    // The direction a person swipes on the camera preview or mode selector. 状态变量，保存用户在相机预览或模式选择器上的滑动方向
    @State var swipeDirection = SwipeDirection.left
    @State private var isShowPhoto = false
    
    var body: some View {
        ZStack {
            // A container view that manages the placement of the preview. 一个容器视图，管理预览的布局
            VStack {
                PreviewContainer(camera: camera) {
                    CameraPreview(source: camera.previewSource)
                        .onTapGesture { location in
                            // Focus and expose at the tapped point. 在点击的点对焦和曝光
                            Task { await camera.focusAndExpose(at: location) }
                        }
//                        .simultaneousGesture(swipeGesture) //滑动切换拍摄模式手势
                        /// The value of `shouldFlashScreen` changes briefly to `true` when capture
                        /// starts, then immediately changes to `false`. Use this to
                        /// flash the screen to provide visual feedback.
                        /// `shouldFlashScreen` 的值在捕获开始时短暂变为 `true`，然后立即变为 `false`。使用此值来闪烁屏幕以提供视觉反馈。
                        .opacity(camera.shouldFlashScreen ? 0 : 1)
                    
                }
                Spacer()
            }
//            .ignoresSafeArea(.all)
            
            if camera.selectedMedia.firstIndex(of: true) != nil {
                SeceltedPhotoView(camera: camera)
            }
            
            // The main camera user interface. 主相机用户界面
            CameraUI(camera: camera, swipeDirection: $swipeDirection)
            
//            HStack {
//                
//                if (camera.capturedPhotos.first) != nil {
//                    Text("\(String(describing: camera.capturedPhotos.first?.data))")
//                }
//                
//                ForEach(camera.capturedMedia.indices, id: \.self) { index in
//                    let media = camera.capturedMedia[index]
//                    
//                    if let photo = media as? Photo {
//                        let data = photo.data
//                        if let uiImage = UIImage(data: data) {
//                            Image(uiImage: uiImage)
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                        }
//                    } else if let movie = media as? Movie {
//                        VideoPlayer(player: AVPlayer(url: movie.url))
//                            .frame(height: 300)
//                    } else {
//                        Image(systemName: "photo.on.rectangle")
//                    }
//                }
////                if let data = camera.capturedPhotos.first?.data, let uiImage = UIImage(data: data) {
////                            Image(uiImage: uiImage)
////                                .resizable()
////                                .aspectRatio(contentMode: .fit)
////                        } else {
////                    Image(systemName: "photo.on.rectangle")
////                }
////                
////                if let movie = camera.capturedMovies.last {
////                                VideoPlayer(player: AVPlayer(url: movie.url))
////                                    .frame(height: 300)
////                            } else {
////                                Text("No video captured")
////                            }
//                
//                if camera.capturedPhotos.count + camera.capturedMovies.count == 4 {
//                    Text("媒体总数到达4个")
//                }
//            }
            
        } // ZStack
        .background(Color.gray)
        
    }

    // 定义滑动手势
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded {
                // Capture swipe direction. 捕捉滑动方向
                swipeDirection = $0.translation.width < 0 ? .left : .right
            }
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel())
}

// 定义滑动方向的枚举
enum SwipeDirection {
    case left
    case right
    case up
    case down
}
