//
//  InteractionOverlayView.swift
//  guanzhi
//
//  Created by Zaptain Zi on 2025/11/27.
//

import SwiftUI

struct InteractionOverlayView: View {
    
    @State private var isLiked: Bool = false //是否喜欢？
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack{
                Spacer()
                
                Button{
                    //喜欢按钮❤️
                    isLiked.toggle()
                }label: {
                    Image(systemName: isLiked ?  "heart.circle.fill" : "heart.circle")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(isLiked ? Color("color-primary") : Color("color-deep") ))
                }
                .buttonStyle(ButtonStyle_LikeControl())
            }
            .padding(.trailing)
            .padding(.bottom, 80)
        }
    }
}

#Preview {
    InteractionOverlayView()
}
