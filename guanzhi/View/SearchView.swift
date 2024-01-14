//
//  SearchView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI

struct SearchView: View {
    @State private var isPresented = false
       
       var body: some View {
           VStack {
               Button("打开全屏视图") {
                   isPresented = true
               }
               .padding()
               
               // 通过 fullScreenCover 修饰符呈现全屏视图
               .fullScreenCover(isPresented: $isPresented, content: FullScreenView.init)
           }
       }
}

struct FullScreenView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                TextFieldView()
                
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .foregroundColor(.black)
                
                Spacer()
            }
        }
    }
}

#Preview {
    SearchView()
}
