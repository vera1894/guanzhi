/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
An object that writes photos and movies to the user's Photos library.
*/

import Foundation
import Photos
import UIKit

/// An object that writes photos and movies to the user's Photos library. `MediaLibrary` 是一个 actor，用于将照片和视频写入用户的照片库，同时生成媒体缩略图。
actor MediaLibrary {
    
    // Errors that media library can throw. 定义了一个错误类型，用于表示可能的错误情况。
    enum Error: Swift.Error {
        case unauthorized  //定义了一个错误类型，用于表示可能的错误情况。
        case saveFailed  // 保存媒体失败。
    }
    
    /// An asynchronous stream of thumbnail images the app generates after capturing media.  一个异步流，用于在捕获媒体后生成缩略图图像。
    let thumbnails: AsyncStream<CGImage?>
    private let continuation: AsyncStream<CGImage?>.Continuation?
    
    /// Creates a new media library object. 创建一个新的媒体库对象。初始化 `thumbnails` 流及其 `continuation`。
    init() {
        let (thumbnails, continuation) = AsyncStream.makeStream(of: CGImage?.self)
        self.thumbnails = thumbnails
        self.continuation = continuation
    }
    
    // MARK: - Authorization 授权
    /// 异步属性，检查用户是否已授权应用程序访问照片库。
    private var isAuthorized: Bool {
        get async {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            /// Determine whether the user has previously authorized `PHPhotoLibrary` access. 确定用户是否已授权 `PHPhotoLibrary` 访问。
            var isAuthorized = status == .authorized
            // If the system hasn't determined the user's authorization status,explicitly prompt them for approval. 如果系统尚未确定用户的授权状态，请明确请求他们的批准。
            if status == .notDetermined {
                // Request authorization to add media to the library. 请求授权将媒体添加到库中。
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                isAuthorized = status == .authorized
            }
            return isAuthorized
        }
    }

    // MARK: - Saving media 保存媒体
    
    /// Saves a photo to the Photos library. 将照片保存到照片库。
    func save(photo: Photo) async throws {
        
        let location = try await currentLocation
        try await performChange {
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // Save primary photo. 保存主照片。
            let options = PHAssetResourceCreationOptions()
            // Specify the appropriate resource type for the photo. 为照片指定适当的资源类型。
            creationRequest.addResource(with: photo.isProxy ? .photoProxy : .photo, data: photo.data, options: options)
            creationRequest.location = location
            
            // Save Live Photo data. 保存 Live Photo 数据。
            if let url = photo.livePhotoMovieURL {
                let livePhotoOptions = PHAssetResourceCreationOptions()
                livePhotoOptions.shouldMoveFile = false //******原始为true
                creationRequest.addResource(with: .pairedVideo, fileURL: url, options: livePhotoOptions)
            }
            
            return creationRequest.placeholderForCreatedAsset
        }
    }
    
    /// Saves a movie to the Photos library. 将视频保存到照片库。
    func save(movie: Movie) async throws {
        let location = try await currentLocation
        try await performChange {
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = true
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: movie.url, options: options)
            creationRequest.location = location
            return creationRequest.placeholderForCreatedAsset
        }
    }
    
    // A template method for writing a change to the user's photo library. 一个模板方法，用于将更改写入用户的照片库。
    private func performChange(_ change: @Sendable @escaping () -> PHObjectPlaceholder?) async throws {
        guard await isAuthorized else {
            throw Error.unauthorized
        }
        
        do {
            var placeholder: PHObjectPlaceholder?
            try await PHPhotoLibrary.shared().performChanges {
                // Execute the change closure. 执行更改闭包。
                placeholder = change()
            }
            
            if let placeholder {
                /// Retrieve the newly created `PHAsset` instance. 检索新创建的 `PHAsset` 实例。
                guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier],
                                                      options: nil).firstObject else { return }
                await createThumbnail(for: asset)
            }
        } catch {
            throw Error.saveFailed
        }
    }
    
    // MARK: - Thumbnail handling 缩略图处理
    /// 加载初始缩略图。
    private func loadInitialThumbnail() async {
        // Only load an initial thumbnail if the user has already authorized the app to write to the Photos library. 仅在用户已授权应用程序写入照片库时加载初始缩略图。
        // Deferring this call prevents the app from prompting for Photos authorization when the app starts. 延迟此调用可防止应用程序在启动时提示照片授权。
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return }
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        if let asset = PHAsset.fetchAssets(with: options).lastObject {
            await createThumbnail(for: asset)
        }
    }
    
    /// 为给定的资产创建缩略图。
    private func createThumbnail(for asset: PHAsset) async {
        // Request the generation of a 256x256 thumbnail image. 请求生成 256x256 的缩略图图像。
        PHImageManager.default().requestImage(for: asset,
                                              targetSize: .init(width: 256, height: 256),
                                              contentMode: .default,
                                              options: nil) { [weak self] image, _ in
            // Set the latest thumbnail image. 设置最新的缩略图图像。
            guard let self, let image = image else { return }
            continuation?.yield(image.cgImage)
        }
    }
    
    // MARK: - Location management 位置管理
    
    private let locationManager = CLLocationManager()
    
    /// 获取当前的位置。
    private var currentLocation: CLLocation? {
        get async throws {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            // Return the location for the first update. 返回第一个更新的位置。
            return try await CLLocationUpdate.liveUpdates().first(where: { _ in true })?.location
        }
    }
}

