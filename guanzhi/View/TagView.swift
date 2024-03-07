//  通用设计元素
//  UIView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/13.
//

import SwiftUI

struct TagView: View {
    let tagText:String
    
    var body: some View {
        HStack(alignment: .center, spacing: Constants.spacingSpacingXs) { // tx/Tag
            Text(tagText)
              .font(
                Font.custom("PingFang SC", size: 14)
                  .weight(.medium)
              )
              .kerning(0.22)
              .foregroundColor(Constants.textColorTxBlack) }
        .padding(.horizontal, Constants.spacingSpacingS)
        .padding(.vertical, Constants.spacingSpacingXxs)
        .background(Color.red)
        .cornerRadius(12)
        .shadow(color: Color(red: 1, green: 0.77, blue: 0.18), radius: 0, x: 2, y: 4)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .inset(by: 1)
            .stroke(Constants.strokeStrokeBlack, lineWidth: 2)
        )
    }
}

struct UIView_Previews: PreviewProvider {
    static var previews: some View {
        TagView(tagText: "🎨 大师")
    }
}
