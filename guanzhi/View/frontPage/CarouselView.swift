//
//  CarouselView.swift
//  guanzhi
//  轮播图
//  Created by Vera on 2024/3/10.
//

//import SwiftUI
//import PhotosUI
//
//struct CarouselView: View {
//    @EnvironmentObject var searchViewModel: SearchViewModel
////    let mediaGroups: [MediaGroup]
//    @Binding var isShowCarousel: Bool
//    
//    var mediaGroups: [MediaGroup] {
//        if let selectedAnnotation = searchViewModel.selectedAnnotation,
//           let shareData = selectedAnnotation.annotationData {
//            return getSortedMediaGroups(from: shareData)
//        } else {
//            return []
//        }
//    }
//    
//    var body: some View {
//        GeometryReader { geometry in
//                    if !mediaGroups.isEmpty {
//                        TabView {
////                            ForEach(mediaGroups, id: \.id) { group in
////                                if let photo = group.photo {
////                                    if let video = group.video {
////                                        // 有对应的 .mov 文件，生成 Live Photo
////                                        LivePhotoContainerView(photoURL: photo.url, videoURL: video.url)
////                                            .frame(width: geometry.size.width, height: geometry.size.height)
////                                            .edgesIgnoringSafeArea(.all)
////                                    } else {
////                                        // 仅有图片
////                                        AsyncImage(url: photo.url) { phase in
////                                            switch phase {
////                                            case .empty:
////                                                ProgressView()
////                                                    .frame(width: geometry.size.width, height: geometry.size.height)
////                                                    .edgesIgnoringSafeArea(.all)
////                                                    .background(Color.black)
////                                            case .success(let image):
////                                                DispatchQueue.main.async {
////                                                    if !isShowCarousel {
////                                                        withAnimation {
////                                                            isShowCarousel = true
////                                                        }
////                                                    }
////                                                }
////                                                image
////                                                    .resizable()
////                                                    .scaledToFit()
////                                                    .frame(width: geometry.size.width, height: geometry.size.height)
////                                                    .edgesIgnoringSafeArea(.all)
////                                            case .failure:
////                                                Text("加载图片失败")
////                                            @unknown default:
////                                                EmptyView()
////                                            }
////                                        }
////                                    }
////                                }
////                                else if let video = group.video {
////                                    // 只有视频，没有对应的图片
////                                    // 根据需求处理
////                                }
////                            }
//                        }
//                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//                        .frame(width: geometry.size.width, height: geometry.size.height)
//                    } else {
//                        // 处理 mediaGroups 为空的情况
//                        Text("没有可显示的数据")
//                            .frame(width: geometry.size.width, height: geometry.size.height)
//                    }
//                }
//                .background(Color.black)
//                .edgesIgnoringSafeArea(.all)
//            }
//}
//
////struct LivePhotoContainerView: View {
////    let photoURL: URL
////    let videoURL: URL
////    @State private var livePhoto: PHLivePhoto?
////    @State private var isPlayingLivePhoto = true
////    @State private var hasPlayedLivePhoto = false
////
////    var body: some View {
////        Group {
////            if let livePhoto = livePhoto {
////                LivePhotoView(livePhoto: livePhoto)
////                    .onAppear {
////                        if !hasPlayedLivePhoto {
////                            hasPlayedLivePhoto = true
////                            // 在 LivePhotoView 中控制播放
////                        }
////                    }
////            } else {
////                // 显示静态图片
////                AsyncImage(url: photoURL) { image in
////                    image
////                        .resizable()
////                        .scaledToFit()
////                        .frame(maxWidth: .infinity, maxHeight: .infinity)
////                        .edgesIgnoringSafeArea(.all)
////                } placeholder: {
////                    ProgressView()
////                        .frame(maxWidth: .infinity, maxHeight: .infinity)
////                        .edgesIgnoringSafeArea(.all)
////                        .background(Color.black)
////                }
////                .onAppear {
////                    print("LivePhotoContainerView onAppear")
////                    generateLivePhoto(photoURL: photoURL, videoURL: videoURL) { generatedLivePhoto in
////                        if let generatedLivePhoto = generatedLivePhoto {
////                            self.livePhoto = generatedLivePhoto
////                            self.hasPlayedLivePhoto = false
////                            print("Live Photo is set")
////                        } else {
////                            print("Failed to generate Live Photo")
////                        }
////                    }
////                }
////            }
////        }
////    }
////
////    func generateLivePhoto(photoURL: URL, videoURL: URL, completion: @escaping (PHLivePhoto?) -> Void) {
////        print("generateLivePhoto called with photoURL: \(photoURL), videoURL: \(videoURL)")
////        downloadFiles(photoURL: photoURL, videoURL: videoURL) { localPhotoURL, localVideoURL in
////            guard let localPhotoURL = localPhotoURL, let localVideoURL = localVideoURL else {
////                print("Failed to download photo or video")
////                completion(nil)
////                return
////            }
////            print("Generating Live Photo with local files: \(localPhotoURL), \(localVideoURL)")
////            PHLivePhoto.request(withResourceFileURLs: [localPhotoURL, localVideoURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, info in
////                if let error = info[PHLivePhotoInfoErrorKey] as? NSError {
////                    print("Failed to generate Live Photo: \(error)")
////                } else {
////                    print("Live Photo generated successfully")
////                }
////                DispatchQueue.main.async {
////                    completion(livePhoto)
////                }
////            }
////        }
////    }
////    
////    func downloadFiles(photoURL: URL, videoURL: URL, completion: @escaping (URL?, URL?) -> Void) {
////        let dispatchGroup = DispatchGroup()
////        var localPhotoURL: URL?
////        var localVideoURL: URL?
////
////        dispatchGroup.enter()
////        downloadFile(from: photoURL) { url in
////            localPhotoURL = url
////            dispatchGroup.leave()
////        }
////
////        dispatchGroup.enter()
////        downloadFile(from: videoURL) { url in
////            localVideoURL = url
////            dispatchGroup.leave()
////        }
////
////        dispatchGroup.notify(queue: .main) {
////            completion(localPhotoURL, localVideoURL)
////        }
////    }
////
////    func downloadFile(from url: URL, completion: @escaping (URL?) -> Void) {
////        print("Downloading file from URL: \(url)")
////        let fileName = url.lastPathComponent
////        let tempDir = FileManager.default.temporaryDirectory
////        let localURL = tempDir.appendingPathComponent(fileName)
////
////        print("Downloading file from URL: \(url)")
////
////        // 如果文件已存在，直接返回
////        if FileManager.default.fileExists(atPath: localURL.path) {
////            print("File already exists at path: \(localURL.path)")
////            completion(localURL)
////            return
////        }
////
////        let task = URLSession.shared.downloadTask(with: url) { tempFileURL, response, error in
////            if let error = error {
////                print("Download error: \(error)")
////                completion(nil)
////                return
////            }
////            if let tempFileURL = tempFileURL {
////                do {
////                    try FileManager.default.copyItem(at: tempFileURL, to: localURL)
////                    print("File copied to: \(localURL.path)")
////                    completion(localURL)
////                } catch {
////                    print("Error copying file: \(error)")
////                    completion(nil)
////                }
////            } else {
////                print("Download failed, tempFileURL is nil")
////                completion(nil)
////            }
////        }
////        task.resume()
////    }
////    
////}
//
//
////#Preview {
////    CarouselView()
////}
//
//
////struct CarouselView: View {
////    let images = ["Rectangle 70","测试长图", "IMG-2", "IMG-1"] // 图片名称数组
////
////    var body: some View {
////        GeometryReader { geometry in
//////            Rectangle()
//////                .foregroundStyle(Color.red)
//////                .frame(width: geometry.size.width, height: geometry.size.height)
////
////                TabView {
////                    ForEach(images, id: \.self) { imageName in
////                        Image(imageName)
////                            .resizable()
////                            .scaledToFit() // 使用 scaledToFill 以确保图片填充屏幕
////                            .frame(width: geometry.size.width, height: geometry.size.height)
//////                                .clipped() // 裁剪超出屏幕的部分
////                            .edgesIgnoringSafeArea(.all)
////                    }
////                }
////                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//////                .ignoresSafeArea(.all) // 忽略所有安全区域
////                .frame(width: geometry.size.width, height: geometry.size.height)
////
////            }
////        .background(Color.black)
////        .edgesIgnoringSafeArea(.all)
////    }
////}
