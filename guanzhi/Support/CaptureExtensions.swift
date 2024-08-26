/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Extensions on AVFoundation capture and related types.
*/

import AVFoundation
// 这段代码的主要作用是扩展 AVFoundation 框架中的一些类型，以便更方便地处理和比较视频格式和尺寸。这些扩展用于在捕获视频时选择合适的格式和参数。
// 扩展 CMVideoDimensions 结构体，使其符合 Equatable 和 Comparable 协议。
extension CMVideoDimensions: Equatable, Comparable {
    
    // 定义一个静态常量 zero 表示零尺寸的 CMVideoDimensions。
    static let zero = CMVideoDimensions()
    
    // 实现 Equatable 协议中的 == 运算符，用于比较两个 CMVideoDimensions 是否相等。
    public static func == (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }
    
    // 实现 Comparable 协议中的 < 运算符，用于比较两个 CMVideoDimensions 的大小。
    public static func < (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        lhs.width < rhs.width && lhs.height < rhs.height
    }
}

// 扩展 AVCaptureDevice 类，添加一个计算属性 activeFormat10BitVariant。
extension AVCaptureDevice {
    // 返回与当前 activeFormat 具有相同帧率和分辨率的第一个 10 位格式。
    var activeFormat10BitVariant: AVCaptureDevice.Format? {
        formats.filter {
            // 筛选出帧率和分辨率与 activeFormat 相同的格式。
            $0.maxFrameRate == activeFormat.maxFrameRate &&
            $0.formatDescription.dimensions == activeFormat.formatDescription.dimensions
        }
        .first(where: { $0.isTenBitFormat }) // 返回第一个 10 位格式。
    }
}

// 扩展 AVCaptureDevice.Format 类，添加一些计算属性和方法。
extension AVCaptureDevice.Format {
    // 返回格式描述符的 mediaSubType 是否为 10 位格式。
    var isTenBitFormat: Bool {
        formatDescription.mediaSubType.rawValue == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
    }
    // 返回支持的最大帧率。
    var maxFrameRate: Double {
        videoSupportedFrameRateRanges.last?.maxFrameRate ?? 0
    }
}

