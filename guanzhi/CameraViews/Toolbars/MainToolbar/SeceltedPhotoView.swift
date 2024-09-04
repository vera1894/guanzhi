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

struct SeceltedPhotoView<CameraModel: Camera>: PlatformView {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
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
    
    var body: some View {
        ZStack {
//            Rectangle()
//                .foregroundColor(.gray)
//                .frame(maxHeight: .infinity)
            
            
            
//            if camera.selectedMedia != [false, false, false, false] {
                VStack {
                    if let selectedIndex = camera.selectedMedia.firstIndex(of: true) {
                            let media = camera.capturedMedia[selectedIndex]
                            
                        if let photo = media as? Photo {
                            if let uiImage = UIImage(data: photo.data) {
                            Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        } else if let movie = media as? Movie, let thumbnailImage = generateThumbnail(from: movie) {
                            Image(uiImage: thumbnailImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                                Text("No media available")
                            }
                        }
                    
//                    Spacer()
                }
//            }
              
        }
    }
    
    // 根据设备尺寸类别确定工具栏的宽度。
    var width: CGFloat? { isRegularSize ? 250 : nil }
    // 设置工具栏的固定高度。
    var height: CGFloat? { 80 }
}

#Preview {
    Group {
        SeceltedPhotoView(camera: PreviewCameraModel())
    }
}
