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
