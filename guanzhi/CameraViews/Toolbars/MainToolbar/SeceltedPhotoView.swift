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
                                                    LivePhotoView(
                                                        livePhoto: livePhoto,
                                                        shouldPlay: appState.isPlayingLivePhoto,
                                                        isSelected: true
                                                    )
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
    let livePhoto: PHLivePhoto?     // 可为 nil
    let shouldPlay: Bool            // 由父层控制（如 isPlayingLivePhoto）
    let isSelected: Bool            // 当前 cell 是否选中（防"传染式播放"）
    let playToken: UUID?            // 每次播放的唯一标识
    let handledPlayToken: UUID?     // 已处理的播放标识（持久化）
    let onPlaybackStarted: ((UUID) -> Void)?
    let onPlaybackFinished: (() -> Void)?

    init(livePhoto: PHLivePhoto?,
         shouldPlay: Bool,
         isSelected: Bool,
         playToken: UUID? = nil,
         handledPlayToken: UUID? = nil,
         onPlaybackStarted: ((UUID) -> Void)? = nil,
         onPlaybackFinished: (() -> Void)? = nil) {
        self.livePhoto = livePhoto
        self.shouldPlay = shouldPlay
        self.isSelected = isSelected
        self.playToken = playToken
        self.handledPlayToken = handledPlayToken
        self.onPlaybackStarted = onPlaybackStarted
        self.onPlaybackFinished = onPlaybackFinished
    }

    // Coordinator 用于追踪播放会话，防止重复播放
    final class Coordinator: NSObject, PHLivePhotoViewDelegate {
        weak var view: PHLivePhotoView?

        var isPlayingFull  = false
        var currentPlayToken: UUID?
        var onPlaybackStarted: ((UUID) -> Void)?
        var onPlaybackFinished: (() -> Void)?

        func livePhotoView(_ livePhotoView: PHLivePhotoView,
                           didEndPlaybackWith style: PHLivePhotoViewPlaybackStyle) {
            #if DEBUG
            print("⏹️ LivePhotoView Delegate - didEnd playback with style: \(style == .full ? "full" : "hint")")
            #endif

            if style == .full {
                isPlayingFull = false
                livePhotoView.alpha = 0
                currentPlayToken = nil
                onPlaybackFinished?()
                #if DEBUG
                print("✅ LivePhotoView - .full 播放完成")
                #endif
            }
        }

        func livePhotoView(_ livePhotoView: PHLivePhotoView,
                           willBeginPlaybackWith style: PHLivePhotoViewPlaybackStyle) {
            #if DEBUG
            print("🎬 LivePhotoView Delegate - willBegin playback with style: \(style == .full ? "full" : "hint")")
            #endif

            if style == .full {
                livePhotoView.alpha = 1
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let v = PHLivePhotoView()
        v.delegate = context.coordinator
        context.coordinator.view = v
        v.clipsToBounds = true
        v.contentMode = .scaleAspectFit
        v.alpha = 0

        #if DEBUG
        if let livePhoto = livePhoto {
            print("🎬 LivePhotoView makeUIView - isSelected: \(isSelected), shouldPlay: \(shouldPlay), LivePhoto: \(Unmanaged.passUnretained(livePhoto).toOpaque())")
        } else {
            print("🎬 LivePhotoView makeUIView - isSelected: \(isSelected), shouldPlay: \(shouldPlay), LivePhoto: nil")
        }
        #endif

        return v
    }

    func updateUIView(_ v: PHLivePhotoView, context: Context) {
        // 1) 更新"是否允许播放"的会话门
        context.coordinator.onPlaybackStarted = onPlaybackStarted
        context.coordinator.onPlaybackFinished = onPlaybackFinished
        if context.coordinator.currentPlayToken == nil,
           let handledPlayToken = handledPlayToken {
            context.coordinator.currentPlayToken = handledPlayToken
        }

        #if DEBUG
        let livePhotoAddr = livePhoto.map { Unmanaged.passUnretained($0).toOpaque() }
        print("🔄 LivePhotoView updateUIView - isSelected: \(isSelected), shouldPlay: \(shouldPlay), playToken: \(playToken?.uuidString ?? "nil"), handled: \(handledPlayToken?.uuidString ?? "nil"), LivePhoto: \(livePhotoAddr?.debugDescription ?? "nil")")
        #endif

        // 重置视图状态，防止复用污染
        v.contentMode = .scaleAspectFit
        v.clipsToBounds = true
        v.transform = .identity
        v.layer.transform = CATransform3DIdentity

        // 2) livePhoto 变化：先停掉可能在跑的播放，再绑定新素材
        if v.livePhoto !== livePhoto {
            v.stopPlayback()
            v.livePhoto = livePhoto
            context.coordinator.currentPlayToken = handledPlayToken
            context.coordinator.isPlayingFull = false

            #if DEBUG
            if let livePhoto = livePhoto {
                print("🔄 LivePhotoView - LivePhoto 对象变化: \(Unmanaged.passUnretained(livePhoto).toOpaque())，停止旧播放")
            } else {
                print("🔄 LivePhotoView - LivePhoto 对象变为 nil")
            }
            #endif
        }

        // 3) 需要播放且已有素材 → 根据 playToken 判断是否为新的播放请求
        if let token = playToken,
           livePhoto != nil,
           shouldPlay,
           isSelected,
           context.coordinator.currentPlayToken != token {
            context.coordinator.currentPlayToken = token
            context.coordinator.isPlayingFull = true
            v.isMuted = false
            v.alpha = 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            context.coordinator.onPlaybackStarted?(token)

            DispatchQueue.main.async { [weak v] in
                v?.startPlayback(with: .full)
                #if DEBUG
                print("🎬 LivePhotoView - 直接播放 .full（无预热）")
                #endif
            }
        }

        // 4) 会话结束（手指松开/切走等导致不想播）：停止 full，清会话计数
        if (!shouldPlay || !isSelected), context.coordinator.isPlayingFull {
            v.stopPlayback()
            context.coordinator.isPlayingFull = false
            context.coordinator.currentPlayToken = nil
            v.alpha = 0
            context.coordinator.onPlaybackFinished?()

            #if DEBUG
            print("🔚 LivePhotoView - 会话结束，停止播放并清空 token")
            #endif
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
