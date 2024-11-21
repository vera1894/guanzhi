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

    var body: some View {
        
        if let mediaItem = mediaItemWrapper.mediaItem {
            if let photo = mediaItem as? Photo {
                if photo.data.isEmpty {
                    // 数据为空，显示加载指示器
                    ProcessingView()
                } else if let uiImage = UIImage(data: photo.data) {
                    if photo.livePhotoMovieURL != nil {
                        // 动态照片
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .onTapGesture {
                                    isPlayingLivePhoto.toggle()
                                }
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
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            isPlayingLivePhoto = true
                        }
                    } else {
                        // 静态照片
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
//            }
        }
    }
}
