//
//  CardView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/29.
//

import SwiftUI

struct CardView: View {
    var body: some View {
        VStack{
            Text("北京渔阳国际滑雪场")
            Text("北京渔阳国际滑雪场")
            Button(action: {
                        // 帮他（紫色）-胶囊按钮fill
                    }) {
                        Text("📷 帮助ta了解这里的情况")
                    }
                .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
        }
        .padding()
        // 3 工作表视图有两种可能的尺寸：小尺寸（200 点高）和大尺寸（默认尺寸）
        .presentationDetents([.height(400), .large])
        
    }
}

#Preview {
    CardView()
}
