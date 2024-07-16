//
//  detailView.swift
//  guanzhi
//
//  Created by Vera on 2024/3/10.
//

import SwiftUI

struct detailView: View {
    var body: some View {
        VStack{
            CarouselView()
            VStack(alignment: .leading, spacing: Constants.spacingSpacingXs) {
                Text("快来这里看看！快来这里看看！快来这里看看！快来这里看看！")
                  .font(Font.custom("PingFang SC", size: 16))
                  .kerning(0.22)
                  .foregroundColor(Color("color-black"))
                  .frame(maxWidth: .infinity, alignment: .leading)
                // tx/SecondaryInfo
                Text("#FB80765·2023.02.12 12:22")
                  .font(Font.custom("PingFang SC", size: 14))
                  .kerning(0.22)
                  .foregroundColor(Color("text-gray"))
            }
            .padding(.horizontal, Constants.spacingSpacingM)
            .padding(.vertical, Constants.spacingSpacingXs)
           // .frame(width: 430, alignment: .topLeading)
           
            // tx/Body

            //name
            HStack(alignment: .top, spacing: Constants.spacingSpacingXs) {
                HStack(alignment: .center, spacing: Constants.spacingSpacing0) { Image("icon-avatar")
                        .frame(width: Constants.iconSizeXl, height: Constants.iconSizeXl)
                    VStack{
                        // tx/OptionPageTitle
                        Text("一只鸡腿儿")
                            .font(
                                Font.custom("PingFang SC", size: 18)
                                    .weight(.semibold)
                            )
                            .kerning(0.22)
                            .foregroundColor(.black)
                        // tx/SecondaryInfo
                        HStack{
                            Text("☠️")
                                .font(Font.custom("PingFang SC", size: 14))
                                .kerning(0.22)
                                .foregroundColor(Color(red: 0.61, green: 0.61, blue: 0.61))
                            Text("Onettoooo")
                                .font(Font.custom("PingFang SC", size: 14))
                                .kerning(0.22)
                                .foregroundColor(Constants.textColorTxGery)
                        }
                        
                    }
                    
                }
                // .padding(Constants.spacingSpacingM)
              
                Spacer()
            }
            
            Spacer()
        }

        
        
    }
}

#Preview {
    detailView()
}
