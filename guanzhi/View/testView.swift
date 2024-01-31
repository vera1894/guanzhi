//
//  testView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/31.
//

import SwiftUI

struct testView: View {
    @State private var selectedTab = 0
        
        var body: some View {
            VStack {
                HStack(alignment: .top,spacing: Constants.iconSizeS) {
                    //Spacer()
                    TabButton(title: "我分享的", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                   // Spacer()
                    TabButton(title: "我的消息", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    Spacer()
                }
                .padding()
                
                if selectedTab == 0 {
                    Text("第一个选项卡")
                } else {
                    Text("第二个选项卡")
                }
                
                Spacer()
            }
        }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.custom("PingFang SC", size: 14))
                .kerning(0.22)
                .foregroundColor(isSelected ? Color("text-black") : Color("text-gray"))
        }
    }
}
#Preview {
    testView()
}
