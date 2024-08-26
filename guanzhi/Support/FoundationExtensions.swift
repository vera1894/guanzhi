/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Extensions on Foundation types.
*/

import Foundation

extension URL {
    /// A unique output location to write a movie. 一个用于写入电影文件的唯一输出位置。
    /// 这个计算属性生成一个新的临时文件 URL 来存储电影文件。它使用 UUID 创建一个唯一的文件名，并附加 `.mov` 文件扩展名。
    static var movieFileURL: URL {
        // 获取系统的临时目录。
        // 使用新的 UUID 字符串将一个唯一组件附加到目录路径中。
        // 将 QuickTime 电影文件扩展名附加到唯一的文件名中。
        URL.temporaryDirectory.appending(component: UUID().uuidString).appendingPathExtension(for: .quickTimeMovie)
    }
}
