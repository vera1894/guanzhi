//  我的
//  MyView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI

struct MyView: View {
    var body: some View {
        VStack{
            //name
            HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                HStack(alignment: .center, spacing: Constants.iconSizeS) { Image("icon-avatar")
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
                .padding(Constants.spacingSpacing0)}
            .padding(.horizontal, Constants.spacingSpacingM)
            .padding(.vertical, Constants.spacingSpacingXs)
            .frame(width: 430, alignment: .leading)
            //tags
            HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {  }
            .padding(.horizontal, Constants.spacingSpacingM)
            .padding(.top, Constants.spacingSpacingXs)
            .padding(.bottom, Constants.spacingSpacingM)
            .frame(width: 430, alignment: .leading)
        }
        
    }
}

struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
    }
}
