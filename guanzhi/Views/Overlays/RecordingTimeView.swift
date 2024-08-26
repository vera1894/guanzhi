/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that displays the current recording time.
*/

import SwiftUI

/// A view that displays the current recording time. 一个视图，用于显示当前的录制时间。
struct RecordingTimeView: PlatformView {

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    // 录制的时间，以秒为单位
    let time: TimeInterval
    
    var body: some View {
        Text(time.formatted)
            .padding([.leading, .trailing], 12)
            .padding([.top, .bottom], isRegularSize ? 8 : 0)
            .background(Color(white: 0.0, opacity: 0.5))
            .foregroundColor(.white)
            .font(.title2.weight(.semibold))
            .clipShape(.capsule)
    }
}

// 扩展 TimeInterval 类型，添加格式化方法
extension TimeInterval {
    // 将时间间隔格式化为时:分:秒的字符串
    var formatted: String {
        let time = Int(self) // 将时间间隔转换为整数
        let seconds = time % 60 // 计算秒数
        let minutes = (time / 60) % 60 // 计算分钟数
        let hours = (time / 3600) // 计算小时数
        let formatString = "%0.2d:%0.2d:%0.2d" // 格式化字符串
        return String(format: formatString, hours, minutes, seconds) // 返回格式化后的字符串
    }
}

#Preview {
    RecordingTimeView(time: TimeInterval(floatLiteral: 500))
        .background(Image("video_mode"))
}
