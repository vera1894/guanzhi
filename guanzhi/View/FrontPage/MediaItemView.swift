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
                    if photo.livePhotoMovieURL != nil {
                        // 动态照片
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .overlay(
                                    VStack{
                                        HStack{
                                            LiveBadgeOnPhoto()
                                                .padding(.horizontal)
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
                            // ✅ LivePhotoView 永远存在于视图树中，避免节点重建导致 Coordinator 重置
                            // livePhoto 可为 nil（异步加载），shouldPlay 控制播放，isSelected 确保只有选中项才播放
                            // 只有当 livePhotoMovieURL 存在时才渲染，条件稳定不会导致重建
                            if photo.livePhotoMovieURL != nil {
                                LivePhotoView(
                                    livePhoto: mediaItemWrapper.livePhoto,
                                    imageSize: uiImage.size,
                                    shouldPlay: isPlayingLivePhoto,
                                    isSelected: isCurrentlySelected
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(isPlayingLivePhoto ? 1 : 0)
                                .allowsHitTesting(false)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            #if DEBUG
                            print("▶️ MediaItemView[\(currentIndex ?? -1)] - ZStack.onAppear, isSelected: \(isCurrentlySelected), didAutoStart: \(didAutoStart)")
                            #endif
                            // 只有当前选中的页面才自动播放，且只自动开始一次
                            if isCurrentlySelected && !didAutoStart {
                                #if DEBUG
                                print("▶️ MediaItemView[\(currentIndex ?? -1)] - 设置 isPlayingLivePhoto = true（首次自动播放）")
                                #endif
                                isPlayingLivePhoto = true
                                didAutoStart = true

                                // 1.5秒后自动停止
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if isPlayingLivePhoto {
                                        #if DEBUG
                                        print("⏹️ MediaItemView[\(currentIndex ?? -1)] - 自动停止播放")
                                        #endif
                                        isPlayingLivePhoto = false
                                    }
                                }
                            }
                        }
                        .onChange(of: isCurrentlySelected) { oldValue, newValue in
                            #if DEBUG
                            print("🔀 MediaItemView[\(currentIndex ?? -1)] - isCurrentlySelected 变化: \(oldValue) -> \(newValue)")
                            #endif
                            // 当页面从未选中变为选中时，自动播放 LivePhoto
                            if newValue && !oldValue {
                                isPlayingLivePhoto = true

                                // 1.5秒后自动停止
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if isPlayingLivePhoto {
                                        #if DEBUG
                                        print("⏹️ MediaItemView[\(currentIndex ?? -1)] - 切换后自动停止播放")
                                        #endif
                                        isPlayingLivePhoto = false
                                    }
                                }
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
                        // 静态照片
//                        Image("测试长图")
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
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
