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
                
                VStack {
                    Button{
                        //喜欢按钮❤️
                        isLiked.toggle()
                    }label: {
                        Image(systemName: isLiked ?  "heart.circle.fill" : "heart.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(isLiked ? Color("color-primary") : Color(.white) ))
                    }
                    .buttonStyle(ButtonStyle_LikeControl())
                    
                    Text("123")
                        .font(Font.custom("PingFang SC", size: 14))
                        .kerning(0.22)
                        .foregroundColor(Color(.white))
                        .shadow(color: Color(.black), radius: 10, x: 2, y:4)
                }
                
                
            }
            .padding(.trailing)
            .padding(.bottom, 140)
        }
    }
}

#Preview {
    InteractionOverlayView()
}
