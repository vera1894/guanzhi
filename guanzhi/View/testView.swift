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
            VStack (alignment: .center, spacing: 0){
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
                Divider()
                if selectedTab == 0 {
                    List {
                        SwiftUIView().listRowInsets(EdgeInsets())
                        SwiftUIView().listRowInsets(EdgeInsets())
                        SwiftUIView().listRowInsets(EdgeInsets())
                              
                            }
                    
                    .listStyle(PlainListStyle())
                      
                } else {
                    List {
                        SwiftUIView().listRowInsets(EdgeInsets())
                        SwiftUIView().listRowInsets(EdgeInsets())
                        SwiftUIView().listRowInsets(EdgeInsets())
                              
                            }.listStyle(PlainListStyle())
                       
                }
                
                
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
