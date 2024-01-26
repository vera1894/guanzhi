//
//  ButtonStyles.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/25.
//

import SwiftUI

struct ButtonStyles: View {
    var body: some View {
        HStack {
            Button{
                //返回按钮
            }label: {
                Image("icon-back")
            }
        .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-close")
            }
        .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-location")
            }
        .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-more")
            }
        .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-setting")
            }
        .buttonStyle(ButtonStyle_s())
            
            Button{
                //返回按钮
            }label: {
                Image("icon-notification")
            }
        .buttonStyle(ButtonStyle_s())
            
        }
    }
}

struct ButtonStyle_s: ButtonStyle {

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .shadow(color: Color("color-primary") ,radius: 0, x: 2, y:4)
            
    }
}



#Preview {
    ButtonStyles()
}
