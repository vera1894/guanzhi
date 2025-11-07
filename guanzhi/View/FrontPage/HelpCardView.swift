//
//  HelpCardView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/7/17.
//

import SwiftUI

struct HelpCardView: View {
    @Binding var name : String
    
    
    var body: some View {
        VStack{
            HStack(content: {
                Text("\(name)")
                    .font(
                    Font.custom("SF Pro Display", size: 24)
                    .weight(.semibold)
                    )
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Color(red: 0.03, green: 0.03, blue: 0.03))
                Spacer()
                Button{
                    //关闭按钮-圆形
                }label: {
                    Image("icon-close")
                }
                .buttonStyle(ButtonStyle_m())
            })
           
            HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                Image("icon-avatar")
                  .frame(width: Constants.iconSizeL, height: Constants.iconSizeL)
                VStack(alignment: .leading, spacing: Constants.spacingSpacingXxs) {
                    // tx/UserNameBlue
                    Text("三只鸡腿儿")
                      .font(
                        Font.custom("PingFang SC", size: 16)
                          .weight(.semibold)
                      )
                      .kerning(0.22)
                      .foregroundColor(Color("text-black"))
                    // tx/SecondaryInfo
                    Text("2023.02.23 12:23")
                      .font(Font.custom("PingFang SC", size: 14))
                      .kerning(0.22)
                      .foregroundColor(Color("text-gray"))
                }
                .padding(0)
                Spacer()
                 
            }
            .padding(Constants.spacingSpacing0)
            
            // tx/Body
            Text("找到了！滑雪场现在人多吗？谁来给我发个照片啊啊啊啊！感谢感谢🙏")
              .font(Font.custom("PingFang SC", size: 16))
              .kerning(0.22)
              .foregroundColor(Color("text-deepgray"))
              .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
            // tx/SecondaryInfo
            Text("你所帮助的人将会收到通知！我们将会记录你的善举！")
              .font(Font.custom("PingFang SC", size: 14))
              .kerning(0.22)
              .foregroundColor(Color("text-gray"))
            Button(action: {
                        // 帮他（紫色）-胶囊按钮fill
                    }) {
                        Text("📷 帮助ta了解这里的情况")
                    }
                .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
        }
        .padding()
        // iOS 26 适配：使用 Constants.sheetExpandedFraction 替代 .large 确保填满屏幕
        .presentationDetents([.height(400), .fraction(Constants.sheetExpandedFraction)])
        .presentationCornerRadius(Constants.sheetCornerRadius)
    }
}

#Preview {
    HelpCardView(name: .constant("地点名称"))
}
