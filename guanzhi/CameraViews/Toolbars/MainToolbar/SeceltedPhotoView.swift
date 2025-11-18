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
    let needsPrewarm: Bool          // 是否需要预热（首次播放时）
    let playToken: UUID?            // 每次播放的唯一标识
    let handledPlayToken: UUID?     // 已处理的播放标识（持久化）
    let onPlaybackStarted: ((UUID) -> Void)?
    let onPlaybackFinished: (() -> Void)?

    init(livePhoto: PHLivePhoto?,
         shouldPlay: Bool,
         isSelected: Bool,
         needsPrewarm: Bool = false,
         playToken: UUID? = nil,
         handledPlayToken: UUID? = nil,
         onPlaybackStarted: ((UUID) -> Void)? = nil,
         onPlaybackFinished: (() -> Void)? = nil) {
        self.livePhoto = livePhoto
        self.shouldPlay = shouldPlay
        self.isSelected = isSelected
        self.needsPrewarm = needsPrewarm
        self.playToken = playToken
        self.handledPlayToken = handledPlayToken
        self.onPlaybackStarted = onPlaybackStarted
        self.onPlaybackFinished = onPlaybackFinished
    }

    // Coordinator 用于追踪播放会话，防止重复播放
    final class Coordinator: NSObject, PHLivePhotoViewDelegate {
        weak var view: PHLivePhotoView?

        var isPlayingFull = false
        var isPlayingHint = false
        var isPrewarmed = false  // 是否已完成预热
        var prewarmToken: UUID?  // 预热播放的 token
        var currentPlayToken: UUID?
        var onPlaybackStarted: ((UUID) -> Void)?
        var onPlaybackFinished: (() -> Void)?

        func livePhotoView(_ livePhotoView: PHLivePhotoView,
                           didEndPlaybackWith style: PHLivePhotoViewPlaybackStyle) {
            #if DEBUG
            print("⏹️ LivePhotoView Delegate - didEnd playback with style: \(style == .full ? "full" : "hint")")
            #endif

            if style == .hint {
                isPlayingHint = false
                isPrewarmed = true
                #if DEBUG
                print("✅ LivePhotoView - .hint 预热完成，准备播放 .full")
                #endif
                // ✅ 预热完成后立即播放 .full
                if let token = prewarmToken {
                    DispatchQueue.main.async { [weak self, weak livePhotoView] in
                        guard let self = self, let livePhotoView = livePhotoView else { return }
                        self.isPlayingFull = true
                        self.currentPlayToken = token
                        livePhotoView.isMuted = false
                        livePhotoView.alpha = 1
                        livePhotoView.startPlayback(with: .full)
                        #if DEBUG
                        print("🎬 LivePhotoView - 预热后开始播放 .full")
                        #endif
                        // 通知外部播放已开始
                        Task { @MainActor in
                            self.onPlaybackStarted?(token)
                        }
                    }
                }
            } else if style == .full {
                isPlayingFull = false
                livePhotoView.alpha = 0
                currentPlayToken = nil
                prewarmToken = nil
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
            print("🎬 LivePhotoView makeUIView - NEW VIEW CREATED - isSelected: \(isSelected), shouldPlay: \(shouldPlay), playToken: \(playToken?.uuidString ?? "nil"), LivePhoto: \(Unmanaged.passUnretained(livePhoto).toOpaque())")
        } else {
            print("🎬 LivePhotoView makeUIView - NEW VIEW CREATED - isSelected: \(isSelected), shouldPlay: \(shouldPlay), playToken: \(playToken?.uuidString ?? "nil"), LivePhoto: nil")
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
        print("🔄 LivePhotoView updateUIView - isSelected: \(isSelected), shouldPlay: \(shouldPlay), playToken: \(playToken?.uuidString ?? "nil"), handled: \(handledPlayToken?.uuidString ?? "nil"), LivePhoto: \(livePhotoAddr?.debugDescription ?? "nil"), isPlaying: \(context.coordinator.isPlayingFull)")
        #endif

        // ✅ 关键防护：如果当前正在播放且是另一个 cell 的更新（!isSelected），跳过所有操作防止干扰
        if context.coordinator.isPlayingFull && !isSelected && !shouldPlay {
            #if DEBUG
            print("⚠️ LivePhotoView updateUIView - 正在播放但非当前选中项，跳过更新防止干扰")
            #endif
            return
        }

        // 重置视图状态，防止复用污染
        v.contentMode = .scaleAspectFit
        v.clipsToBounds = true
        v.transform = .identity
        v.layer.transform = CATransform3DIdentity

        // 2) livePhoto 变化：先停掉可能在跑的播放，再绑定新素材
        if v.livePhoto !== livePhoto {
            // ✅ 只有在确实正在播放且当前被选中时才停止（防止 TabView 复用导致误停）
            if context.coordinator.isPlayingFull && isSelected {
                v.stopPlayback()
                #if DEBUG
                print("🔄 LivePhotoView - 停止旧的播放（isSelected=\(isSelected)）")
                #endif
            } else if context.coordinator.isPlayingFull && !isSelected {
                #if DEBUG
                print("⚠️ LivePhotoView - 检测到播放状态但未选中，可能是 TabView 复用，不停止播放")
                #endif
            }

            v.livePhoto = livePhoto
            context.coordinator.currentPlayToken = handledPlayToken
            context.coordinator.isPlayingFull = false

            #if DEBUG
            if let livePhoto = livePhoto {
                print("🔄 LivePhotoView - LivePhoto 对象变化: \(Unmanaged.passUnretained(livePhoto).toOpaque())")
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
           context.coordinator.currentPlayToken != token,
           context.coordinator.prewarmToken != token {

            #if DEBUG
            print("🎬 LivePhotoView - 准备播放，token: \(token), needsPrewarm: \(needsPrewarm), isPrewarmed: \(context.coordinator.isPrewarmed)")
            #endif

            // ✅ 震动反馈在 Task 中执行，避免阻塞
            Task {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            // ✅ 根据是否需要预热选择播放策略
            if needsPrewarm && !context.coordinator.isPrewarmed {
                // 首次自动播放：先用 .hint 预热，完成后自动播放 .full
                context.coordinator.prewarmToken = token
                context.coordinator.isPlayingHint = true
                v.isMuted = true  // 预热时静音
                v.alpha = 0       // 预热时不可见

                DispatchQueue.main.async { [weak v] in
                    guard let v = v, v.livePhoto != nil else {
                        #if DEBUG
                        print("⚠️ LivePhotoView - 预热取消（LivePhoto 不存在）")
                        #endif
                        return
                    }
                    v.startPlayback(with: .hint)
                    #if DEBUG
                    print("🔥 LivePhotoView - 开始预热播放 .hint（不可见）")
                    #endif
                }
            } else {
                // 非首次或已预热：直接播放 .full
                context.coordinator.currentPlayToken = token
                context.coordinator.isPlayingFull = true
                v.isMuted = false
                v.alpha = 1

                // 通知外部播放已开始
                Task { @MainActor in
                    context.coordinator.onPlaybackStarted?(token)
                }

                DispatchQueue.main.async { [weak v] in
                    guard let v = v, v.livePhoto != nil else {
                        #if DEBUG
                        print("⚠️ LivePhotoView - 播放取消（LivePhoto 不存在）")
                        #endif
                        return
                    }
                    v.startPlayback(with: .full)
                    #if DEBUG
                    print("🎬 LivePhotoView - 开始播放 .full（无需预热）")
                    #endif
                }
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
