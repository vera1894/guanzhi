//
//  MediaItemView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/11/19.
//


import SwiftUI
import PhotosUI
import AVKit

struct MediaItemView: View {
    @ObservedObject var mediaItemWrapper: MediaItemWrapper
    var thumbnailImage: UIImage?
    var currentIndex: Int? = nil  // 当前项的索引
    var selectedIndex: Int? = nil  // 当前选中的索引
    @State private var isPlayingLivePhoto: Bool = false // 控制 Live Photo 的播放
    @State private var isLongPressActive: Bool = false // 长按手势是否正在进行
    @State private var longPressWorkItem: DispatchWorkItem? = nil
    @State private var didTriggerLongPressPlayback: Bool = false

    // 判断当前项是否被选中
    private var isCurrentlySelected: Bool {
        guard let current = currentIndex, let selected = selectedIndex else {
            return false
        }
        return current == selected
    }

    var body: some View {
        #if DEBUG
        let _ = print("🔄 MediaItemView[\(currentIndex ?? -1)] body 重新渲染, isPlayingLivePhoto: \(isPlayingLivePhoto), isSelected: \(isCurrentlySelected)")
        #endif
        
        if let mediaItem = mediaItemWrapper.mediaItem {
            if let photo = mediaItem as? Photo {
                if photo.data.isEmpty {
                    // 数据为空，显示加载指示器
                    ProcessingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let uiImage = UIImage(data: photo.data) {
                    // 动态照片或静态照片（统一处理）
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .overlay(
                                VStack{
                                    HStack{
                                        // 只有 LivePhoto 才显示 badge
                                        if photo.livePhotoMovieURL != nil {
                                            LiveBadgeOnPhoto()
                                                .padding(.horizontal)
                                        }
                                        Spacer()
                                    }
                                    .padding(.top, 20)
                                    Spacer()
                                }
                            )
                            .onLongPressGesture(
                                minimumDuration: 0.8,
                                maximumDistance: 50,
                                pressing: { isPressing in
                                    guard photo.livePhotoMovieURL != nil else { return }

                                    if isPressing {
                                        // 已经在执行长按，避免重复调度
                                        guard !isLongPressActive else { return }
                                        isLongPressActive = true

                                        // 取消上一次的调度任务
                                        longPressWorkItem?.cancel()

                                        let workItem = DispatchWorkItem { [currentIndex] in
                                            guard isLongPressActive else { return }
                                            // ✅ 检查 LivePhoto 是否已准备好
                                            guard mediaItemWrapper.livePhoto != nil else {
                                                #if DEBUG
                                                print("⚠️ MediaItemView[\(currentIndex ?? -1)] - 长按触发但 LivePhoto 未准备好，取消播放")
                                                #endif
                                                return
                                            }
                                            #if DEBUG
                                            print("👆 MediaItemView[\(currentIndex ?? -1)] - 长按触发重新播放")
                                            #endif
                                            didTriggerLongPressPlayback = true
                                            mediaItemWrapper.currentPlayToken = UUID()
                                            isPlayingLivePhoto = true
                                        }

                                        longPressWorkItem = workItem
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
                                    } else {
                                        isLongPressActive = false
                                        longPressWorkItem?.cancel()
                                        longPressWorkItem = nil

                                        if didTriggerLongPressPlayback {
                                            // 松开手指后停止播放，下次可再次触发
                                            isPlayingLivePhoto = false
                                            mediaItemWrapper.currentPlayToken = nil
                                            mediaItemWrapper.handledPlayToken = nil
                                            didTriggerLongPressPlayback = false
                                        }
                                    }
                                },
                                perform: {}
                            )

                        // ✅ LivePhotoView 必须有稳定的 identity，避免在 TabView 中被复用或混淆
                        // 使用 mediaItemWrapper.id 作为唯一标识，确保每个 MediaItemView 有独立的 LivePhotoView 实例
                        LivePhotoView(
                            livePhoto: photo.livePhotoMovieURL != nil ? mediaItemWrapper.livePhoto : nil,
                            shouldPlay: isPlayingLivePhoto,
                            isSelected: isCurrentlySelected,
                            playToken: mediaItemWrapper.currentPlayToken,
                            handledPlayToken: mediaItemWrapper.handledPlayToken,
                            onPlaybackStarted: { token in
                                // ✅ 使用 Task 避免在视图更新期间修改 @Published 属性
                                Task { @MainActor in
                                    mediaItemWrapper.handledPlayToken = token
                                }
                            },
                            onPlaybackFinished: {
                                // ✅ 使用 Task 避免在视图更新期间修改 @Published 属性
                                Task { @MainActor in
                                    isPlayingLivePhoto = false
                                    mediaItemWrapper.currentPlayToken = nil
                                    mediaItemWrapper.handledPlayToken = nil
                                }
                            }
                        )
                        .id("LivePhotoView-\(mediaItemWrapper.id)")  // ✅ 关键修复：确保每个 MediaItemWrapper 有唯一的 LivePhotoView 实例
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isPlayingLivePhoto ? 1 : 0)
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        #if DEBUG
                        print("▶️ MediaItemView[\(currentIndex ?? -1)] - ZStack.onAppear, isSelected: \(isCurrentlySelected), hasAutoPlayed: \(mediaItemWrapper.hasAutoPlayedForSelection), livePhoto: \(mediaItemWrapper.livePhoto != nil ? "已准备" : "未准备")")
                        #endif
                        // 只有在 LivePhoto 已经准备好的情况下才播放，使用短延迟给 PHLivePhotoView 准备资源的时间
                        if isCurrentlySelected,
                           photo.livePhotoMovieURL != nil,
                           mediaItemWrapper.livePhoto != nil,  // ✅ 检查 LivePhoto 是否已准备好
                           mediaItemWrapper.hasAutoPlayedForSelection == false {
                            #if DEBUG
                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - LivePhoto 已准备，延迟 100ms 后自动播放（给视图时间准备资源）")
                            #endif
                            // ✅ 使用 100ms 短延迟，给 PHLivePhotoView 时间准备内部资源，但不会长到让 TabView 干扰
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak mediaItemWrapper] in
                                guard let mediaItemWrapper = mediaItemWrapper,
                                      !mediaItemWrapper.hasAutoPlayedForSelection else { return }
                                mediaItemWrapper.currentPlayToken = UUID()
                                isPlayingLivePhoto = true
                                mediaItemWrapper.hasAutoPlayedForSelection = true
                            }
                        } else if isCurrentlySelected,
                                  photo.livePhotoMovieURL != nil,
                                  mediaItemWrapper.livePhoto == nil {
                            #if DEBUG
                            print("⏳ MediaItemView[\(currentIndex ?? -1)] - LivePhoto 未准备好，等待生成完成")
                            #endif
                        }
                    }
                    .onChange(of: isCurrentlySelected) { oldValue, newValue in
                        #if DEBUG
                        print("🔀 MediaItemView[\(currentIndex ?? -1)] - isCurrentlySelected 变化: \(oldValue) -> \(newValue), livePhoto: \(mediaItemWrapper.livePhoto != nil ? "已准备" : "未准备")")
                        #endif
                        // 切换到当前照片：使用短延迟给 PHLivePhotoView 准备资源的时间
                        if newValue,
                           photo.livePhotoMovieURL != nil,
                           mediaItemWrapper.livePhoto != nil,  // ✅ 检查 LivePhoto 是否已准备好
                           mediaItemWrapper.hasAutoPlayedForSelection == false {
                            #if DEBUG
                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - 切换到当前照片，LivePhoto 已准备，延迟 100ms 后播放")
                            #endif
                            // ✅ 使用 100ms 短延迟
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak mediaItemWrapper] in
                                guard let mediaItemWrapper = mediaItemWrapper,
                                      !mediaItemWrapper.hasAutoPlayedForSelection else { return }
                                mediaItemWrapper.currentPlayToken = UUID()
                                isPlayingLivePhoto = true
                                mediaItemWrapper.hasAutoPlayedForSelection = true
                            }
                        } else if newValue,
                                  photo.livePhotoMovieURL != nil,
                                  mediaItemWrapper.livePhoto == nil {
                            #if DEBUG
                            print("⏳ MediaItemView[\(currentIndex ?? -1)] - 切换到当前照片，LivePhoto 未准备好，等待生成完成")
                            #endif
                        }

                        // 切换走：停止播放并重置标志
                        if !newValue {
                            isPlayingLivePhoto = false
                            mediaItemWrapper.hasAutoPlayedForSelection = false
                            mediaItemWrapper.currentPlayToken = nil
                            mediaItemWrapper.handledPlayToken = nil
                        }
                    }
                    .onChange(of: mediaItemWrapper.livePhoto) { oldValue, newValue in
                        #if DEBUG
                        print("📸 MediaItemView[\(currentIndex ?? -1)] - livePhoto 变化: \(oldValue != nil ? "有" : "无") -> \(newValue != nil ? "有" : "无"), isSelected: \(isCurrentlySelected), hasAutoPlayed: \(mediaItemWrapper.hasAutoPlayedForSelection)")
                        #endif

                        // ✅ 核心逻辑：当 LivePhoto 从 nil 变为非 nil，且满足自动播放条件时，延迟触发播放
                        if oldValue == nil,
                           newValue != nil,
                           isCurrentlySelected,
                           photo.livePhotoMovieURL != nil,
                           !mediaItemWrapper.hasAutoPlayedForSelection,
                           !didTriggerLongPressPlayback {  // 不干扰长按播放
                            #if DEBUG
                            print("✅ MediaItemView[\(currentIndex ?? -1)] - LivePhoto 准备完成，延迟 100ms 后触发自动播放")
                            #endif
                            // ✅ 使用 100ms 短延迟，给 PHLivePhotoView 时间准备内部资源
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak mediaItemWrapper] in
                                guard let mediaItemWrapper = mediaItemWrapper,
                                      !mediaItemWrapper.hasAutoPlayedForSelection,
                                      !didTriggerLongPressPlayback else { return }
                                mediaItemWrapper.currentPlayToken = UUID()
                                isPlayingLivePhoto = true
                                mediaItemWrapper.hasAutoPlayedForSelection = true
                            }
                        }
                    }
                    .onChange(of: isPlayingLivePhoto) { oldValue, newValue in
                        #if DEBUG
                        print("🔀 MediaItemView[\(currentIndex ?? -1)] - isPlayingLivePhoto 状态变化: \(oldValue) -> \(newValue)")
                        #endif
                    }
                } else {
                    Text("无法加载图片")
                }
            } else if let movie = mediaItem as? Movie {
                // 视频
                VideoPlayer(player: AVPlayer(url: movie.url))
                    .aspectRatio(contentMode: .fit)
            } else {
                Text("Unsupported media type")
            }
            
        } else {
            // 显示占位符或缩略图
//            if let thumbnailImage = thumbnailImage {
//                Image(uiImage: thumbnailImage)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    .overlay {
//                        ProcessingView()
//                    }
//            } else {
                ProcessingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
        }
    }
}
