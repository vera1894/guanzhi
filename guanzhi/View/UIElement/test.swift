//
//  test.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/1/31.
//

import SwiftUI

struct test: View {
    
    @State private var grayscale: Double = 0
    let animationDuration: Double = 1
    
    @State private var isLocated: Bool = true
    
    var body: some View {
                
        Text("")
        
        Button{
            //定位
        }label: { }
    .buttonStyle(IconStylePosition(isAnimating: $isLocated))
        
        
        
        
    }
}







#Preview {
    test()
}
