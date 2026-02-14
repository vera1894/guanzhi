/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that the app presents to indicate that Live Photo capture is active.
*/

import SwiftUI

/// A view that the app presents to indicate that Live Photo capture is active. 一个视图，用于指示 Live Photo 捕获功能处于活动状态。
struct LiveBadge: View {
    var body: some View {
        Group {
            Text("LIVE")
                .padding(6)
                .foregroundColor(.white)
                .font(.subheadline.bold())
        }
        .background(Color.accentColor.opacity(0.9))
        .clipShape(.buttonBorder)
    }
}

struct LiveBadgeOnPhoto: View {
    var body: some View {
        Group {
            HStack{
                Image(systemName: "livephoto")
                Text("实况 ")
            }
            .padding(3)
            .foregroundColor(Color("text-deepgray").opacity(0.8))
            .font(.subheadline.bold())
        }
        .background(Color(.systemBackground))
        .clipShape(.buttonBorder)
    }
}

/// 带下载进度的 LivePhoto 标签，进度显示在图标本身（进度环 + 中心点）
struct LiveBadgeOnPhotoLoading: View {
    var progress: Double // 0.0 ~ 1.0

    var body: some View {
        Group {
            HStack(spacing: 4) {
                // 实况图标：进度环 + 中心点（模拟 livephoto 图标的进度状态）
                ZStack {
                    // 底圈轨道
                    Circle()
                        .stroke(lineWidth: 1.5)
                        .opacity(0.2)
                    // 进度环
                    Circle()
                        .trim(from: 0, to: max(0.05, progress))
                        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    // 中心点
                    Circle()
                        .fill()
                        .frame(width: 3, height: 3)
                }
                .frame(width: 16, height: 16)
                Text("实况")
            }
            .padding(3)
            .foregroundColor(Color("text-deepgray").opacity(0.8))
            .font(.subheadline.bold())
        }
        .background(Color(.systemBackground))
        .clipShape(.buttonBorder)
    }
}

#Preview {
    LiveBadge()
        .padding()
        .background(.black)
}

#Preview {
    LiveBadgeOnPhoto()
        .padding()
        .background(.black)
}

#Preview("Loading 0%") {
    LiveBadgeOnPhotoLoading(progress: 0)
        .padding()
        .background(.gray)
}

#Preview("Loading 50%") {
    LiveBadgeOnPhotoLoading(progress: 0.5)
        .padding()
        .background(.gray)
}

#Preview("Loading 100%") {
    LiveBadgeOnPhotoLoading(progress: 1.0)
        .padding()
        .background(.gray)
}
