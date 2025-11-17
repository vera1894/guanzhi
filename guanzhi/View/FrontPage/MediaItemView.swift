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

                        // ✅ LivePhotoView 始终存在于视图树中，避免节点重建导致 Coordinator 重置
                        // 通过 livePhoto 参数控制：livePhotoMovieURL 为 nil 时传入 nil，LivePhotoView 不会播放
                        // 不使用 .id() - 让 SwiftUI 使用默认 identity，避免因 id 变化导致重建
                        LivePhotoView(
                            livePhoto: photo.livePhotoMovieURL != nil ? mediaItemWrapper.livePhoto : nil,
                            shouldPlay: isPlayingLivePhoto,
                            isSelected: isCurrentlySelected,
                            playToken: mediaItemWrapper.currentPlayToken,
                            handledPlayToken: mediaItemWrapper.handledPlayToken,
                            onPlaybackStarted: { token in
                                mediaItemWrapper.handledPlayToken = token
                            },
                            onPlaybackFinished: {
                                isPlayingLivePhoto = false
                                mediaItemWrapper.currentPlayToken = nil
                                mediaItemWrapper.handledPlayToken = nil
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isPlayingLivePhoto ? 1 : 0)
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        #if DEBUG
                        print("▶️ MediaItemView[\(currentIndex ?? -1)] - ZStack.onAppear, isSelected: \(isCurrentlySelected), hasAutoPlayed: \(mediaItemWrapper.hasAutoPlayedForSelection)")
                        #endif
                        if isCurrentlySelected,
                           photo.livePhotoMovieURL != nil,
                           mediaItemWrapper.hasAutoPlayedForSelection == false {
                            #if DEBUG
                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - 设置 isPlayingLivePhoto = true（首次自动播放）")
                            #endif
                            mediaItemWrapper.currentPlayToken = UUID()
                            isPlayingLivePhoto = true
                            mediaItemWrapper.hasAutoPlayedForSelection = true
                        }
                    }
                    .onChange(of: isCurrentlySelected) { oldValue, newValue in
                        #if DEBUG
                        print("🔀 MediaItemView[\(currentIndex ?? -1)] - isCurrentlySelected 变化: \(oldValue) -> \(newValue)")
                        #endif
                        if newValue,
                           photo.livePhotoMovieURL != nil,
                           mediaItemWrapper.hasAutoPlayedForSelection == false {
                            mediaItemWrapper.currentPlayToken = UUID()
                            isPlayingLivePhoto = true
                            mediaItemWrapper.hasAutoPlayedForSelection = true
                        }

                        if !newValue {
                            isPlayingLivePhoto = false
                            mediaItemWrapper.hasAutoPlayedForSelection = false
                            mediaItemWrapper.currentPlayToken = nil
                            mediaItemWrapper.handledPlayToken = nil
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
