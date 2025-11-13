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

    func makeUIView(context: Context) -> PHLivePhotoView {
        let livePhotoView = PHLivePhotoView()
        livePhotoView.contentMode = .scaleAspectFit  // 确保按比例显示
        livePhotoView.livePhoto = livePhoto
        livePhotoView.startPlayback(with: .full)
        print("LivePhotoView makeUIView: started playback")
        return livePhotoView
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        // 只在 livePhoto 实际改变时才更新和播放
        if uiView.livePhoto != livePhoto {
            uiView.livePhoto = livePhoto
            uiView.startPlayback(with: .full)
            print("LivePhotoView updateUIView: started playback")
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
