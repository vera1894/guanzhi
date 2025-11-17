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

    // Coordinator 用于追踪播放会话，防止重复播放
    final class Coordinator: NSObject, PHLivePhotoViewDelegate {
        weak var view: PHLivePhotoView?

        // —— 会话 & 状态 ——
        var wantPlay       = false                 // shouldPlay && isSelected
        var hasPlayedOnce  = false                 // 本次会话是否已播过 .full
        var isPlayingFull  = false

        // —— 预热控制（只响应"当前 livePhoto"的 hint）——
        weak var hintLivePhotoRef: PHLivePhoto?    // 最近一次 start .hint 时绑定的对象
        var isPreheating   = false
        var prepared       = false

        // 仅当"当前 livePhoto 的 hint 结束"才认为预热完成 → 触发 full 一次
        func livePhotoView(_ livePhotoView: PHLivePhotoView,
                           didEndPlaybackWith style: PHLivePhotoViewPlaybackStyle) {
            #if DEBUG
            print("⏹️ LivePhotoView Delegate - didEnd playback with style: \(style == .full ? "full" : "hint")")
            #endif

            if style == .hint {
                // 只接受当前 livePhoto 的 hint 回调；旧 hint（换素材前发起的）一律忽略
                guard let current = hintLivePhotoRef,
                      current === livePhotoView.livePhoto else {
                    #if DEBUG
                    print("⏭️ LivePhotoView - 忽略旧 livePhoto 的 hint 回调")
                    #endif
                    return
                }

                prepared = true
                isPreheating = false

                #if DEBUG
                print("✅ LivePhotoView - 预热完成，prepared = true, wantPlay = \(wantPlay), hasPlayedOnce = \(hasPlayedOnce)")
                #endif

                guard wantPlay, !hasPlayedOnce else {
                    #if DEBUG
                    print("⏭️ LivePhotoView - 预热完成但不播放（wantPlay=\(wantPlay), hasPlayedOnce=\(hasPlayedOnce)）")
                    #endif
                    return
                }

                livePhotoView.isMuted = false
                livePhotoView.startPlayback(with: .full)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isPlayingFull = true
                hasPlayedOnce = true

                #if DEBUG
                print("🎬 LivePhotoView - 预热后自动播放 .full（有声音+震动）")
                #endif
            } else if style == .full {
                isPlayingFull = false
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
        let wantPlay = (shouldPlay && isSelected)
        context.coordinator.wantPlay = wantPlay

        #if DEBUG
        let livePhotoAddr = livePhoto.map { Unmanaged.passUnretained($0).toOpaque() }
        print("🔄 LivePhotoView updateUIView - isSelected: \(isSelected), shouldPlay: \(shouldPlay), wantPlay: \(wantPlay), prepared: \(context.coordinator.prepared), hasPlayedOnce: \(context.coordinator.hasPlayedOnce), LivePhoto: \(livePhotoAddr?.debugDescription ?? "nil")")
        #endif

        // 重置视图状态，防止复用污染
        v.contentMode = .scaleAspectFit
        v.clipsToBounds = true
        v.transform = .identity
        v.layer.transform = CATransform3DIdentity

        // 2) livePhoto 变化：先停掉可能在跑的旧 hint/full，再绑定新素材
        if v.livePhoto !== livePhoto {
            v.stopPlayback() // 🔴 关键：取消旧 hint，避免旧回调再触发 full
            v.livePhoto = livePhoto

            // 重置预热状态；会话计数不在这里清（只在会话结束清）
            context.coordinator.prepared      = false
            context.coordinator.isPreheating  = false
            // ⚠️ 不在这里更新 hintLivePhotoRef，等开始 hint 时再更新

            #if DEBUG
            if let livePhoto = livePhoto {
                print("🔄 LivePhotoView - LivePhoto 对象变化: \(Unmanaged.passUnretained(livePhoto).toOpaque())，停止旧播放")
            } else {
                print("🔄 LivePhotoView - LivePhoto 对象变为 nil")
            }
            #endif
        }

        // 3) 需要播放且素材已到，但尚未预热 → 发起一次 .hint（静音）
        if livePhoto != nil,
           wantPlay,
           !context.coordinator.prepared,
           !context.coordinator.isPreheating,
           !context.coordinator.hasPlayedOnce {
            context.coordinator.isPreheating = true
            context.coordinator.hintLivePhotoRef = livePhoto  // ✅ 在开始 hint 时才更新
            v.isMuted = true
            DispatchQueue.main.async { [weak v] in
                v?.startPlayback(with: .hint)
                #if DEBUG
                print("🔇 LivePhotoView - 开始 .hint 预热（静音）")
                #endif
            }
        }

        // 4) 预热已完成且会话开始 → 立即播放（解决长按失效问题）
        if wantPlay,
           context.coordinator.prepared,
           !context.coordinator.hasPlayedOnce,
           !context.coordinator.isPlayingFull {
            v.isMuted = false
            v.startPlayback(with: .full)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            context.coordinator.isPlayingFull = true
            context.coordinator.hasPlayedOnce = true

            #if DEBUG
            print("🎬 LivePhotoView - 预热完成，立即播放 .full（有声音+震动）")
            #endif
        }

        // 5) 会话结束（手指松开/切走等导致不想播）：停止 full，清会话计数
        if !wantPlay {
            if context.coordinator.isPlayingFull {
                v.stopPlayback()
                #if DEBUG
                print("⏹️ LivePhotoView - 停止播放")
                #endif
            }
            context.coordinator.isPlayingFull = false
            context.coordinator.hasPlayedOnce = false
            // prepared 保留：再进入会更快，但不会自动 full，仍需 wantPlay 触发

            #if DEBUG
            print("🔚 LivePhotoView - 会话结束，重置 hasPlayedOnce")
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
