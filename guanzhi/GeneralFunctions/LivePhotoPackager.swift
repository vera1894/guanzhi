/*
 LivePhotoPackager.swift
 
 用于在上传前为LivePhoto资源（JPG/HEIC + MOV）写入配对元数据
 使其成为真正的LivePhoto资源对，避免客户端播放时的预热延迟
 
 技术背景：
 - 真Live Photo需要共享同一个 assetIdentifier（UUID）
 - 图片侧：写入 MakerApple key 17
 - 视频侧：写入 QuickTime content.identifier 和 still-image-time
 */

import Foundation
import AVFoundation
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

enum LivePhotoPackagerError: Error {
    case invalidImageData
    case invalidVideoURL
    case videoExportFailed
    case imageWriteFailed
}

final class LivePhotoPackager {
    
    // MARK: - 生成配对标识
    
    /// 生成一个唯一的 assetIdentifier（UUID字符串）
    static func makeAssetIdentifier() -> String {
        return UUID().uuidString
    }
    
    // MARK: - 处理图片（写入配对标识）
    
    /// 为图片写入配对的 assetIdentifier
    /// - Parameters:
    ///   - originalImageData: 原始图片数据（HEIC或JPG）
    ///   - assetId: 配对标识（UUID字符串）
    ///   - outputURL: 输出文件路径
    /// - Throws: LivePhotoPackagerError
    static func writePairedImage(
        originalImageData: Data,
        assetId: String,
        outputURL: URL
    ) throws {
        // 创建图片源
        guard let imageSource = CGImageSourceCreateWithData(originalImageData as CFData, nil) else {
            throw LivePhotoPackagerError.invalidImageData
        }
        
        // 获取图片类型（HEIC或JPG）
        guard let imageType = CGImageSourceGetType(imageSource) else {
            throw LivePhotoPackagerError.invalidImageData
        }
        
        // 读取原始元数据
        var metadata = (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]) ?? [:]
        
        // 获取或创建 MakerApple 字典
        // 使用字符串常量而非kCGImagePropertyMakerAppleDictionary（该常量在某些iOS版本不可用）
        let makerAppleDictKey = "{MakerApple}"
        var makerApple = (metadata[makerAppleDictKey] as? [String: Any]) ?? [:]
        
        // 写入配对标识到 MakerApple key 17（这是行业标准做法）
        makerApple["17"] = assetId
        
        // 更新元数据
        metadata[makerAppleDictKey] = makerApple
        
        // 同时写入XMP作为冗余（可选，但更安全）
        let xmpDictKey = "{XMP}"
        var xmp = (metadata[xmpDictKey] as? [String: Any]) ?? [:]
        xmp["LivePhotoAssetID"] = assetId
        metadata[xmpDictKey] = xmp
        
        // 创建图片目标
        guard let imageDestination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            imageType,
            1,
            nil
        ) else {
            throw LivePhotoPackagerError.imageWriteFailed
        }
        
        // 写入图片和元数据
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, metadata as CFDictionary)
        
        guard CGImageDestinationFinalize(imageDestination) else {
            throw LivePhotoPackagerError.imageWriteFailed
        }
        
        #if DEBUG
        print("✅ LivePhotoPackager: 图片配对元数据写入成功")
        print("   输出路径: \(outputURL.path)")
        print("   AssetID: \(assetId)")
        #endif
    }
    
    // MARK: - 处理视频（写入配对标识和静态帧时间）
    
    /// 为视频写入配对的 assetIdentifier 和 still-image-time
    /// - Parameters:
    ///   - originalVideoURL: 原始视频URL
    ///   - assetId: 配对标识（UUID字符串）
    ///   - outputURL: 输出文件路径
    ///   - stillTime: 静态帧时间（秒），-1表示自动选择封面帧
    /// - Throws: LivePhotoPackagerError
    static func writePairedVideo(
        originalVideoURL: URL,
        assetId: String,
        outputURL: URL,
        stillTime: Double = -1
    ) async throws {
        // 验证输入文件
        guard FileManager.default.fileExists(atPath: originalVideoURL.path) else {
            throw LivePhotoPackagerError.invalidVideoURL
        }
        
        let asset = AVURLAsset(url: originalVideoURL)
        
        // 使用 Passthrough 预设（不重新编码，只重新封装）
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw LivePhotoPackagerError.videoExportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        // 创建配对标识元数据项
        let contentIdItem = AVMutableMetadataItem()
        contentIdItem.keySpace = .quickTimeMetadata
        contentIdItem.key = "com.apple.quicktime.content.identifier" as any NSCopying & NSObjectProtocol
        contentIdItem.value = assetId as any NSCopying & NSObjectProtocol
        
        // 创建静态帧时间元数据项
        let stillTimeItem = AVMutableMetadataItem()
        stillTimeItem.keySpace = .quickTimeMetadata
        stillTimeItem.key = "com.apple.quicktime.still-image-time" as any NSCopying & NSObjectProtocol
        stillTimeItem.value = NSNumber(value: stillTime)
        stillTimeItem.dataType = kCMMetadataBaseDataType_Float64 as String
        
        // 设置元数据
        exportSession.metadata = [contentIdItem, stillTimeItem]
        
        // 执行导出
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            let error = exportSession.error ?? NSError(
                domain: "LivePhotoPackager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Video export failed"]
            )
            throw error
        }
        
        #if DEBUG
        print("✅ LivePhotoPackager: 视频配对元数据写入成功")
        print("   输出路径: \(outputURL.path)")
        print("   AssetID: \(assetId)")
        print("   Still Time: \(stillTime)")
        #endif
    }
    
    // MARK: - 便捷方法：处理完整的LivePhoto
    
    /// 为一对LivePhoto资源（图片+视频）写入配对元数据
    /// - Parameters:
    ///   - imageData: 原始图片数据
    ///   - videoURL: 原始视频URL
    ///   - outputImageURL: 输出图片路径
    ///   - outputVideoURL: 输出视频路径
    /// - Returns: 生成的 assetIdentifier
    /// - Throws: LivePhotoPackagerError
    @discardableResult
    static func packageLivePhoto(
        imageData: Data,
        videoURL: URL,
        outputImageURL: URL,
        outputVideoURL: URL
    ) async throws -> String {
        // 生成配对标识
        let assetId = makeAssetIdentifier()
        
        #if DEBUG
        print("🎬 LivePhotoPackager: 开始处理LivePhoto配对")
        print("   AssetID: \(assetId)")
        #endif
        
        // 处理图片
        try writePairedImage(
            originalImageData: imageData,
            assetId: assetId,
            outputURL: outputImageURL
        )
        
        // 处理视频
        try await writePairedVideo(
            originalVideoURL: videoURL,
            assetId: assetId,
            outputURL: outputVideoURL,
            stillTime: -1
        )
        
        #if DEBUG
        print("✅ LivePhotoPackager: LivePhoto配对处理完成")
        #endif
        
        return assetId
    }
}

