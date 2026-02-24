//
//  WeChatShareHelper.swift
//  guanzhi
//
//  Created by Claude on 2026/2/24.
//

import UIKit
import WechatOpenSDK

/// 微信分享封装工具
/// 提供小程序卡片分享、网页链接分享等功能
struct WeChatShareHelper {

    // MARK: - 微信安装检查

    /// 检查设备是否安装了微信
    static func isWeChatInstalled() -> Bool {
        return WXApi.isWXAppInstalled()
    }

    // MARK: - 小程序卡片分享（发送给微信好友）

    /// 分享为微信小程序卡片
    /// - Parameters:
    ///   - shareId: 分享 ID
    ///   - title: 分享标题
    ///   - description: 分享描述（可选）
    ///   - coverImage: 封面图（可选，会压缩到 128KB 以内）
    ///   - completion: 完成回调（是否成功）
    static func shareToWechatAsMiniProgram(
        shareId: Int64,
        title: String,
        description: String?,
        coverImage: UIImage?,
        completion: ((Bool) -> Void)? = nil
    ) {
        let message = WXMediaMessage()
        message.title = title
        message.description = description ?? ""

        // 缩略图压缩到 128KB 以内
        if let image = coverImage {
            message.thumbData = compressImage(image, maxBytes: 128 * 1024)
        }

        // 小程序对象
        let miniProgramObject = WXMiniProgramObject()
        miniProgramObject.webpageUrl = "https://onettoo.com/s/\(shareId)"
        miniProgramObject.userName = "gh_a9e6e7b3aaf4"
        miniProgramObject.path = "/pages/detail/detail?id=\(shareId)"
        miniProgramObject.miniProgramType = .release

        message.mediaObject = miniProgramObject

        // 发送请求
        let req = SendMessageToWXReq()
        req.bText = false
        req.message = message
        req.scene = Int32(WXSceneSession.rawValue)

        // 监听分享结果
        if let completion = completion {
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .wechatShareResult,
                object: nil,
                queue: .main
            ) { notification in
                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                let success = notification.userInfo?["success"] as? Bool ?? false
                completion(success)
            }
        }

        WXApi.send(req)
    }

    // MARK: - 网页链接分享（朋友圈等场景）

    /// 分享为网页链接
    /// - Parameters:
    ///   - shareId: 分享 ID
    ///   - title: 分享标题
    ///   - description: 分享描述（可选）
    ///   - coverImage: 封面图（可选）
    static func shareToWechatAsWebpage(
        shareId: Int64,
        title: String,
        description: String?,
        coverImage: UIImage?
    ) {
        let message = WXMediaMessage()
        message.title = title
        message.description = description ?? ""

        if let image = coverImage {
            message.thumbData = compressImage(image, maxBytes: 128 * 1024)
        }

        let webpageObject = WXWebpageObject()
        webpageObject.webpageUrl = "https://onettoo.com/s/\(shareId)"

        message.mediaObject = webpageObject

        let req = SendMessageToWXReq()
        req.bText = false
        req.message = message
        req.scene = Int32(WXSceneTimeline.rawValue)

        WXApi.send(req)
    }

    // MARK: - 图片压缩

    /// 递减 JPEG quality 压缩图片到指定大小以内
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxBytes: 最大字节数
    /// - Returns: 压缩后的图片数据
    static func compressImage(_ image: UIImage, maxBytes: Int) -> Data {
        var quality: CGFloat = 0.9
        var data = image.jpegData(compressionQuality: quality) ?? Data()

        while data.count > maxBytes && quality > 0.1 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality) ?? Data()
        }

        // 如果仍然超过限制，缩小图片尺寸
        if data.count > maxBytes {
            let scale = sqrt(CGFloat(maxBytes) / CGFloat(data.count))
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            data = resizedImage.jpegData(compressionQuality: 0.7) ?? Data()
        }

        return data
    }
}
