//
//  SwiftUIView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/31.
//

import SwiftUI

struct postView: View {
    var body: some View {
        HStack(alignment: .top, spacing: Constants.spacingSpacingXs) {
            Rectangle()
              .foregroundColor(.clear)
              .frame(width: 120, height: 120)
              .background(
                Image("WechatIMG21 1")
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 120, height: 120)
                  .clipped()
              )
            
            VStack(alignment: .leading) {
              // Space Between
                // tx/Body
                Text("快来这里看看！快来这里看看！快来这里看看！快来这里看看！")
                  .font(Font.custom("PingFang SC", size: 16))
                  .kerning(0.22)
                  .foregroundColor(Color("text-black"))
                  .frame(maxWidth: .infinity, alignment: .leading)
              Spacer()
              // Alternating Views and Spacers
                // tx/SecondaryInfo
                Text("#FB80765·2023.02.12 12:22")
                  .font(Font.custom("PingFang SC", size: 14))
                  .kerning(0.22)
                  .foregroundColor(Color("text-gray"))
                Spacer()
                HStack{
                    // tx/Tag
                    Text("👀")+Text("108")
                      .font(
                        Font.custom("PingFang SC", size: 14)
                          .weight(.medium)
                      )
                      .kerning(0.22)
                    // tx/Tag
                    Text("📌")+Text("金海湖环湖路23号号号号号...")
                      .font(
                        Font.custom("PingFang SC", size: 14)
                          .weight(.medium)
                      )
                      .kerning(0.22)
                      
                }
            }
            .padding(Constants.spacingSpacing0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Constants.spacingSpacingM)
        .padding(.vertical, Constants.spacingSpacingXs)
        .frame(maxWidth: .infinity, maxHeight: 133,alignment: .topLeading)
       // .background(Color.red)
        
        
    }
}

#Preview {
    postView()
}
