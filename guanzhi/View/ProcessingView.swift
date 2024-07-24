//
//  ProcessingView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/7/24.
//

import SwiftUI



struct ProcessingView: View {
    
    @State private var loading = false
    @State private var completed = false
    @State private var isNextOK = true
    
    private func startProcessing() {
        self.loading = true
        print("1")

        // 使用DispatchQueue.main.asyncAfter 來模擬操作
        // 在真實世界的專案中，你將在這裡執行一個任務
        // 當任務完成之後，你將完成狀態設定為true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.completed = true
        }
    }
    
    var body: some View {
            ZStack{
                Rectangle()
                    .foregroundStyle(.thinMaterial.opacity(0.9))
//                    .presentationBackground(.regularMaterial)
                
                RoundedRectangle(cornerRadius: 20)
                    .frame(width: 120, height: 120)
                    .foregroundColor(Color("color-primary"))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 4)
                            .frame(width: 120, height: 120)
                    }
//                Circle()
//                .stroke(Color(.systemGray5), lineWidth: 14)
//                                .frame(width: 100, height: 100)
                
//                Circle()
//                .trim(from: 0, to: 0.5)
//                .stroke(Color("color-black"), lineWidth: 5)
//                .frame(width: 50, height: 50)
//                .rotationEffect(Angle(degrees:loading ? 360 : 0))
//                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: loading)
                HStack {
                        ForEach(0...1, id: \.self) { index in
                            Circle()
                                .stroke(Color.black, lineWidth: 4)
                                .frame(width: 30, height: 30)
                                .foregroundColor(Color("color-black"))
                                .scaleEffect(self.loading ? 0.2 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3).repeatForever().delay(0.2 * Double(index)), value: loading)
                        }
                    }
                .onAppear() {
                    loading = true
            }
//                Button(action: {
//                            // 下一步（禁用）-胶囊按钮fill
//                    startProcessing()
//                    
//                        }) {
//                            Text("🔜 下一步")
//                        }
//                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: isNextOK))
                
            }
            .ignoresSafeArea(.all)
            
            
        
    }
    
}

#Preview {
    ProcessingView()
}
