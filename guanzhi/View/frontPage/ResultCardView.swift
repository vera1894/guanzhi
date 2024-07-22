//
//  CardView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/29.
//

import SwiftUI
import MapKit

struct ResultCardView: View {
    @Binding var name : String
    @Binding var isShowResultCard: Bool
    @Binding var isShowSearchView: Bool
    @Binding var sesrchViewHight: PresentationDetent
    @State private var isInputMessage: Bool = false
    @State private var resultCardDetents: Set<PresentationDetent> = [.height(140), .large]
    @State private var resultCardCurrentDetent: PresentationDetent = .height(140)
    @Binding var searchResults: [SearchResult]
    @Binding var selectedLocation: SearchResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15, content: {
            HStack(spacing: 8) {
                Text("\(name)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(Color("text-black"))
                
                Spacer()
                
                Button{
                    //关闭按钮-圆形
                    //点击后关闭地点信息栏，显示搜索底栏
                    isShowSearchView = true
                    isShowResultCard = false
                    isInputMessage = false
                    sesrchViewHight = .height(60)
                    searchResults.removeAll()
                }label: {
                    Image("icon-close")
                }
                .buttonStyle(ButtonStyle_m())
            }
            .padding(.bottom, 8)
            .frame(width: .infinity, height: .infinity)
           
            if isInputMessage == false {
                VStack(alignment: .leading) {
                    Text("没有瞧到有用的信息？去试试求助👇")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                      .foregroundColor(Color("text-gray"))
                    Button(action: {
                                // 帮他（紫色）-胶囊按钮fill
                        isInputMessage = true
                        resultCardCurrentDetent = .large
                        
                            }) {
                                Text("🥺 求一下这里最新的照片或视频")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                }
            } else {
                VStack(spacing: 16) {
                    RoundedRectangleTextField()
                    Button(action: {
                                // 求助（紫色）-胶囊按钮fill
                        isShowSearchView = true
                        isShowResultCard = false
                        isInputMessage = false
                        sesrchViewHight = .height(60)
                        searchResults.removeAll()
                            }) {
                                Text("发布求助")
                            }
                        .buttonStyle(ButtonStyle_capsuleFillSecondary(isEnabled: true))
                }
                .padding(.bottom, 16)
            }
            
        })
        .padding(.top, 20)
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents(resultCardDetents, selection: $resultCardCurrentDetent) // 绑定 BottomSheet 的状态
        .presentationCornerRadius(20)
        .presentationBackground(.regularMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(140)))  //用于对下层的可操控
        .interactiveDismissDisabled()  //用于限制无法下滑关闭
        
    }
}

#Preview {
    ResultCardView(name: .constant("地点名称"), isShowResultCard: .constant(false), isShowSearchView: .constant(true), sesrchViewHight: .constant(.height(60)), searchResults: .constant( [SearchResult]()), selectedLocation: .constant(nil))
}
