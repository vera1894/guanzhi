//
//  PhotosPreview.swift
//  AVCam
//
//  Created by 晨光 訾 on 2024/8/8.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct PhotosPreview<CameraModel: Camera, AppStateModel: AppState>: PlatformView {
    var verticalSizeClass: UserInterfaceSizeClass?
    var horizontalSizeClass: UserInterfaceSizeClass?
    
    @State var camera: CameraModel
    @State var appState: AppStateModel
//    @Environment(AppStateModel.self) var appState
    
//    @State private var mediasGroup: [MediaItemProtocol] = []
    
//    @State private var selectedIndex: Int? = nil
//    @State private var showingFullPreview = false
    
//    @State private var selectedPhoto: String? = nil
//    @State private var isSelected = [false, false, false, false] // 初始状态，所有按钮均未选中
//    let photoNames = ["例子", "例子", "例子", ""] // 示例照片名称，空字符串表示没有照片
//    @State private var buttonColors: [Color] = []
//    init() {
//        _buttonColors = State(initialValue: PhotoButton.availableColors.shuffled().prefix(4).map { $0 })
//    }

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
    
    var body: some View {
                    
        ZStack {
            HStack {
                ForEach(0..<4, id: \.self) { index in
                    Button(action: {
                        camera.selectedMedia = camera.selectedMedia.indices.map { $0 == index }
                        appState.isPlayingLivePhoto = true
                        print(camera.selectedMedia)
                    }, label: {
                        if index < camera.capturedMedia.count {
                            let media = camera.capturedMedia[index]
                            if let photo = media as? Photo {
                                if let uiImage = UIImage(data: photo.data) {
                                Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                }
                            } else if let movie = media as? Movie, let thumbnailImage = generateThumbnail(from: movie) {
                                Image(uiImage: thumbnailImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                        }
                    })
                    .buttonStyle(CapturedThumbnailButton(isSelected: camera.selectedMedia[index], index: index))
                    .disabled(index >= camera.capturedMedia.count || appState.isReadyToPost) // 禁用没有媒体的按钮
                }
                
                
                
    //            Button("删除") {
    //                // 删除选中的媒体
    //                if let selectedIndex = camera.selectedMedia.firstIndex(of: true) {
    //                    camera.capturedMedia.remove(at: selectedIndex)
    //                    camera.selectedMedia[selectedIndex] = false
    //                    
    //                    // 如果有剩余的媒体，将其向前移动
    //                    if selectedIndex < camera.capturedMedia.count {
    //                        camera.selectedMedia[selectedIndex] = true
    //                    }
    //                    
    //                    if selectedIndex > 0 {
    //                        if selectedIndex == camera.capturedMedia.count {
    //                            camera.selectedMedia[selectedIndex-1] = true
    //                        }
    //                    }
    //                    
    //                }
    //            }
                
            }
            .padding()
            
            HStack {
                Spacer()
                
                if appState.isReadyToPost == false {
                    if camera.selectedMedia.firstIndex(of: true) != nil {
    //                    Button("清除") {
    //                        // 清除所有选中状态
    //                        for i in camera.selectedMedia.indices {
    //                            camera.selectedMedia[i] = false
    //                        }
    //                    }
                        Button{
                            //返回按钮-圆形
                            for i in camera.selectedMedia.indices {
                                camera.selectedMedia[i] = false
                            }
                        }label: {
                            Image("icon-back")
                        }
                        .buttonStyle(ButtonStyle_m())
                        
                    } else {
                        Button{
                            //关闭按钮-圆形
                            print("关闭摄像页面")
                            appState.isShowingCameraView = false
                            appState.isShowingSearchView = true
                        }label: {
                            Image("icon-close")
                        }
                        .buttonStyle(ButtonStyle_m())
                    }
                }
                
                
                
            }
            .padding()
            
        }
          
    }
}

struct CapturedThumbnailButton: ButtonStyle {
//    var ThumbnailImage: Image
    var isSelected: Bool
    var index: Int
    private let buttonColors = availableColors.shuffled().prefix(4).map { $0 } // 随机选择颜色
    // 定义一组可选颜色
    static let availableColors: [Color] = [.red, .green, .blue, .orange, .pink, .purple, .yellow]
    @State private var gradientColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
    @State private var captureboxIsLoading = false
    
    func makeBody(configuration: Self.Configuration) -> some View {
        ZStack {
            configuration.label
        }
        .frame(width: 42, height: isSelected ? 42 : 32)
//        .background(Color(buttonColors[index])) //if camera.captureboxIsLoading?
        .background(
            captureboxIsLoading ?
            LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: true), value: captureboxIsLoading) as! Color
                    : Color(buttonColors[index])
                )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: isSelected ? StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 10]) : StrokeStyle(lineWidth: 4))
                .foregroundColor(isSelected ? Color.white : Color.black) // 边框颜色
        )
    }
}


#Preview {
    PhotosPreview(camera: PreviewCameraModel(), appState: AppStateModel())
}

