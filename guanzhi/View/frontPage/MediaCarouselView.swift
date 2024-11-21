//
//  MediaCarouselView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/10/28.
//


import SwiftUI
import PhotosUI
import AVKit

struct MediaCarouselView: View {
    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
//    @Binding var isShowCarousel: Bool
    @State private var isPlayingLivePhoto = false  // 控制 Live Photo 播放状态
    @State private var livePhoto: PHLivePhoto? = nil
    @State private var isLoading = true
    
    var animationNamespace: Namespace.ID
    let annotationId: String
    @State private var showTabView = false
    
    var body: some View {
        ZStack {
//            if showTabView {
//                TabView {
//                    ForEach(Array(zip(searchViewModel.downloadMedia.indices, searchViewModel.downloadMedia)), id: \.0) { index, mediaItem in
//                        if let photo = mediaItem as? Photo {
//                            PhotoView(
//                                photo: photo,
//                                animationNamespace: animationNamespace,
//                                annotationId: annotationId,
//                                isFirstImage: index == 0 // 其他图片不应用 matchedGeometryEffect
//                            )
//                        } else if let movie = mediaItem as? Movie {
//                            VideoView(movie: movie)
//                        } else {
//                            EmptyView()
//                        }
//                    }
//                }
//                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//                .onAppear {
//                    isLoading = searchViewModel.downloadMedia.isEmpty
//                }
//            } else {
                // 仅显示第一张图片，用于动画过渡
                if let firstMediaItem = searchViewModel.downloadMedia.first,
                   let photo = firstMediaItem as? Photo {
                    PhotoView(
                        photo: photo,
                        animationNamespace: animationNamespace,
                        annotationId: annotationId,
                        isFirstImage: true // 仅第一张图片应用 matchedGeometryEffect
                    )
                }
//            }
        }
        .ignoresSafeArea(.all)
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
        .onAppear {
                    // 在动画结束后，显示 TabView
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showTabView = true
                        }
                    }
                }
//        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//        .onAppear {
////            searchViewModel.loadSelectedAnnotationMedia()
//            isLoading = searchViewModel.downloadMedia.isEmpty
//        }
//        .onReceive(searchViewModel.$downloadMedia) { downloadMedia in
//                if !downloadMedia.isEmpty {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                        isShowCarousel = true  // 当下载的媒体不为空时，显示 Carousel
//                    }
//                }
//            }
    }
}

// 照片视图：判断是否带有Live Photo并相应播放
struct PhotoView: View {
    @Environment(\.appState) var appState
    let photo: Photo
    @State private var isPlayingLivePhoto = false
    @State private var livePhoto: PHLivePhoto? = nil

    var animationNamespace: Namespace.ID
    let annotationId: String
    
    let isFirstImage: Bool
    
    var body: some View {
        ZStack {
            if let uiImage = UIImage(data: photo.data) {
                
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: appState.isShareImageExpanded ? .fit : .fill)
                    .clipShape(appState.isShareImageExpanded ? AnyShape(Rectangle()) : AnyShape(Circle()))
                    .ignoresSafeArea(.all)
                    .frame(width: appState.isShareImageExpanded ? UIScreen.main.bounds.width : 64,
                           height: appState.isShareImageExpanded ? UIScreen.main.bounds.height : 64)
                    .overlay(
                        Circle().stroke(Color.black.opacity(appState.isShareImageExpanded ? 0 : 1), lineWidth: appState.isShareImageExpanded ? 0 : 4)
                    )
                    .if(isFirstImage) { view in
                        view.matchedGeometryEffect(id: "image-\(annotationId)", in: animationNamespace, isSource: false)
                    }
                    .onAppear {
                        if let livePhotoURL = photo.livePhotoMovieURL {
                            generateLivePhoto(photoURL: livePhotoURL)
                        }
                    }
                    .onTapGesture {
                        if livePhoto != nil {
                            isPlayingLivePhoto.toggle()
                        }
                    }
                    .overlay {
                        if let livePhoto = livePhoto, isPlayingLivePhoto {
                            LivePhotoView(livePhoto: livePhoto)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        isPlayingLivePhoto = false
                                    }
                                }
                        }
                    }
                    
            }
        }
    }

    private func generateLivePhoto(photoURL: URL) {
        // 根据 .jpg 和 .mov 文件生成 PHLivePhoto 对象
        PHLivePhoto.request(withResourceFileURLs: [photoURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, _ in
            self.livePhoto = livePhoto
        }
    }
}

// 视频视图：展示视频文件
struct VideoView: View {
    let movie: Movie

    var body: some View {
        VideoPlayer(player: AVPlayer(url: movie.url))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, @ViewBuilder transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


//#Preview {
//    let exampleMediaItems: [MediaItemProtocol] = [
//        Photo(data: Data(), isProxy: false, livePhotoMovieURL: URL(string: "path/to/livephoto.mov")),  // Live Photo
//        Movie(url: URL(string: "path/to/video.mov")!),  // 视频
//        Photo(data: Data(), isProxy: false, livePhotoMovieURL: nil)  // 静态照片
//    ]
//    
//    MediaCarouselView(mediaItems: exampleMediaItems)
//}


//struct MediaCarouselView: View {
//    @Environment(\.appState) var appState
//    @State var camera: CameraModel
//    @EnvironmentObject var searchViewModel: SearchViewModel
//    @State private var isLoading = true
//
//    var body: some View {
//        ZStack {
//            if isLoading {
//                ProgressView("Loading Media...")
//            } else {
//                TabView {
//                    ForEach(0..<searchViewModel.downloadMedia.count, id: \.self) { index in
//                        let mediaItem = searchViewModel.downloadMedia[index]
//                        if let photo = mediaItem as? Photo {
//                            SeceltedPhotoView(camera: camera, appState: appState)
//                        } else if let movie = mediaItem as? Movie {
//                            VideoPlayerView(url: movie.url)
//                        }
//                    }
//                }
//                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//            }
//        }
//        .onAppear {
//            searchViewModel.loadSelectedAnnotationMedia()
//            isLoading = searchViewModel.downloadMedia.isEmpty
//        }
//    }
//}

// 简单的 VideoPlayerView 用于展示非 LivePhoto 的视频文件
//struct VideoPlayerView: View {
//    let url: URL
//
//    var body: some View {
//        VideoPlayer(player: AVPlayer(url: url))
//            .aspectRatio(contentMode: .fit)
//            .onAppear {
//                AVPlayer(url: url).play()
//            }
//    }
//}
