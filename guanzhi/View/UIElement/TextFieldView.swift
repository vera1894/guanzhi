//
//  TextField.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI

struct TextFieldView: View {
    
    @State private var text: String = ""
    var body: some View {
        ZStack{
            HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {  }
            .padding(.horizontal, Constants.spacingSpacingM)
            .padding(.vertical, 0)
            .frame(maxWidth: .infinity, minHeight: Constants.heightHeightM, maxHeight: Constants.heightHeightM, alignment: .center)
            .background(Constants.mainPrimaryWhite)
            .cornerRadius(Constants.cornerRCornerRM)
            .overlay(
              RoundedRectangle(cornerRadius: Constants.cornerRCornerRM)
                .inset(by: 2)
                .stroke(Constants.strokeStrokeBlack, lineWidth: 4)
            )
            TextField("   🔍想瞧瞧哪里？", text: $text)
        }
        
    }
}

#Preview {
    TextFieldView()
}
