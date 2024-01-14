//
//  TestView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/14.
//

import SwiftUI

struct TestView: View {
    @State private var dragOffset: CGSize = .zero
       
       var body: some View {
           VStack {
               Text("Draggable View")
                   .font(.title)
                   .foregroundColor(.white)
                   .padding()
                   .background(Color.blue)
               
               Rectangle()
                   .fill(Color.gray)
                   .frame(width: 100, height: 6)
                   .cornerRadius(3)
                   .offset(x: dragOffset.width, y: dragOffset.height)
                   .gesture(
                       DragGesture()
                           .onChanged { gesture in
                               dragOffset = gesture.translation
                           }
                           .onEnded { _ in
                               dragOffset = .zero
                           }
                   )
               
               Spacer()
           }
           .padding()
       }
}

#Preview {
    TestView()
}
