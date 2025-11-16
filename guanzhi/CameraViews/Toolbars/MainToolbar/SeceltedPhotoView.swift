//
//  SeceltedPhotoView.swift
//  AVCam
//
//  Created by 晨光 訾 on 2024/8/20.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI
import PhotosUI
import AVFoundation
import AVKit

struct SeceltedPhotoView<CameraModel: Camera, AppStateModel: AppState>: PlatformView {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    @State var appState: AppStateModel
//    @State private var appState.isPlayingLivePhoto = false
    @State private var livePhoto: PHLivePhoto? = nil // 添加这个状态变量来保存生成的 Live Photo
    var cameraMainHeight: CGFloat = 240
    
    private func generateThumbnail(from movie: Movie) -> UIImage? {
        let asset = AVAsset(url: movie.url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: imageRef)
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
    
    func generateLivePhoto(photoURL: URL, videoURL: URL, completion: @escaping (PHLivePhoto?) -> Void) {
        PHLivePhoto.request(withResourceFileURLs: [photoURL, videoURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, info in
            completion(livePhoto)
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                if let selectedIndex = camera.selectedMedia.firstIndex(of: true) {
                        let media = camera.capturedMedia[selectedIndex]
                    
                    if let photo = media as? Photo {
                        if let uiImage = UIImage(data: photo.data) {
                            Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .onTapGesture {
                                        appState.isPlayingLivePhoto.toggle()
                                    }
                                    .overlay {
                                        if  camera.livePhotoGroup[selectedIndex] != nil {
                                            if appState.isPlayingLivePhoto, let livePhoto = camera.livePhotoGroup[selectedIndex] {
                                                    LivePhotoView(livePhoto: livePhoto)
                                                    .onAppear {
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                            appState.isPlayingLivePhoto = false // 自动恢复到静态图片
                                                        }
                                                    }
                                            }
                                        }
                                    }
                            }
                        }
                    
                    else if let movie = media as? Movie, let thumbnailImage = generateThumbnail(from: movie) {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } 
                    else {
                            Text("No media available")
                        }
                    }
                
            }
        }
    }
    
    // 根据设备尺寸类别确定工具栏的宽度。
    var width: CGFloat? { isRegularSize ? 250 : nil }
    // 设置工具栏的固定高度。
    var height: CGFloat? { 80 }
}

struct LivePhotoView: UIViewRepresentable {
    var livePhoto: PHLivePhoto
    var imageSize: CGSize? = nil

    func makeUIView(context: Context) -> PHLivePhotoView {
        let livePhotoView = PHLivePhotoView()
        configureView(livePhotoView)
        livePhotoView.livePhoto = livePhoto
        livePhotoView.startPlayback(with: .full)
        return livePhotoView
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        // 彻底重置视图状态，防止视图复用时的状态污染
        configureView(uiView)

        // 只在 livePhoto 实际改变时才更新和播放
        if uiView.livePhoto != livePhoto {
            uiView.livePhoto = livePhoto
            uiView.startPlayback(with: .full)
        }
    }

    private func configureView(_ view: PHLivePhotoView) {
        // 调试日志：检查视图状态是否异常
        #if DEBUG
        let transformScale = sqrt(view.transform.a * view.transform.a + view.transform.c * view.transform.c)
        if transformScale != 1.0 {
            print("⚠️ LivePhotoView 检测到异常 transform scale: \(transformScale)")
        }
        #endif

        // 重置所有可能影响布局的属性
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true

        // 重置 transform，防止缩放状态被保留
        view.transform = .identity
        view.layer.transform = CATransform3DIdentity

        // 如果有图片尺寸信息，设置内部约束
        if let size = imageSize {
            // 移除所有现有约束
            view.constraints.forEach { view.removeConstraint($0) }
        }
    }
}

#if DEBUG
#Preview {
    Group {
        SeceltedPhotoView(camera: PreviewCameraModel(), appState: AppStateModel())
    }
}
#endif
