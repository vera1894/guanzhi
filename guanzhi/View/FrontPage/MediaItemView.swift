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
    @State private var longPressStarted: Bool = false // 添加状态跟踪
    @State private var didAutoStart: Bool = false  // 防止 onAppear 重复触发

    // 判断当前项是否被选中
    private var isCurrentlySelected: Bool {
        guard let current = currentIndex, let selected = selectedIndex else {
            return true  // 如果没有提供索引信息，默认为选中状态（向后兼容）
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
                                minimumDuration: 0.8,  // 设置最小长按时间为0.8秒
                                maximumDistance: 50,   // 允许的最大移动距离
                                pressing: { isPressing in
                                    // 只有 LivePhoto 才响应长按
                                    guard photo.livePhotoMovieURL != nil else { return }

                                    // 这个闭包在按下和松开时都会调用
                                    if isPressing && !longPressStarted {
                                        // 开始长按
                                        longPressStarted = true
                                        // 延迟0.8秒后执行动作
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                            if longPressStarted {
                                                #if DEBUG
                                                print("👆 MediaItemView[\(currentIndex ?? -1)] - 长按手势触发 toggle")
                                                #endif
                                                isPlayingLivePhoto.toggle()
                                            }
                                        }
                                    } else if !isPressing {
                                        // 松开手指
                                        longPressStarted = false
                                    }
                                },
                                perform: {
                                    // 这个闭包在长按成功时调用（可以留空或添加额外逻辑）
                                }
                            )

                        // ✅ LivePhotoView 始终存在于视图树中，避免节点重建导致 Coordinator 重置
                        // 通过 livePhoto 参数控制：livePhotoMovieURL 为 nil 时传入 nil，LivePhotoView 不会播放
                        // 不使用 .id() - 让 SwiftUI 使用默认 identity，避免因 id 变化导致重建
                        LivePhotoView(
                            livePhoto: photo.livePhotoMovieURL != nil ? mediaItemWrapper.livePhoto : nil,
                            shouldPlay: isPlayingLivePhoto,
                            isSelected: isCurrentlySelected
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isPlayingLivePhoto ? 1 : 0)
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        #if DEBUG
                        print("▶️ MediaItemView[\(currentIndex ?? -1)] - ZStack.onAppear, isSelected: \(isCurrentlySelected), didAutoStart: \(didAutoStart)")
                        #endif
                        // 只有当前选中的页面且是 LivePhoto 才自动播放，且只自动开始一次
                        if isCurrentlySelected && !didAutoStart && photo.livePhotoMovieURL != nil {
                            #if DEBUG
                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - 设置 isPlayingLivePhoto = true（首次自动播放）")
                            #endif
                            isPlayingLivePhoto = true
                            didAutoStart = true
                        }
                    }
                    .onChange(of: isCurrentlySelected) { oldValue, newValue in
                        #if DEBUG
                        print("🔀 MediaItemView[\(currentIndex ?? -1)] - isCurrentlySelected 变化: \(oldValue) -> \(newValue)")
                        #endif
                        // 当页面从未选中变为选中时，且是 LivePhoto，自动播放
                        if newValue && !oldValue && photo.livePhotoMovieURL != nil {
                            isPlayingLivePhoto = true
                        }

                        // 当页面取消选中时，重置自动开始标志，允许下次选中时再次自动播放
                        if !newValue {
                            didAutoStart = false
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
