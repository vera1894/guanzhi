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
    @State private var isPlayingLivePhoto: Bool = false // 控制 Live Photo 的播放
    @State private var longPressStarted: Bool = false // 添加状态跟踪

    var body: some View {
        
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
                            if let livePhoto = mediaItemWrapper.livePhoto, isPlayingLivePhoto {
                                LivePhotoView(livePhoto: livePhoto)
//                                    .aspectRatio(contentMode: .fit)
                                    .aspectRatio((mediaItemWrapper.imageSize?.width ?? 1) / (mediaItemWrapper.imageSize?.height ?? 1), contentMode: .fit)
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            isPlayingLivePhoto = false // 自动停止播放
                                        }
                                    }
                            }
                            VStack{
                                HStack{
                                    LiveBadgeOnPhoto()
                                        .padding(.horizontal)
                                    Spacer()
                                }
                                .padding(.top, 60)
                                Spacer()
                            }
                            
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            isPlayingLivePhoto = true
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
