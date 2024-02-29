//
//  SheetView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/29.
//

import SwiftUI

struct SheetView: View {
    @State private var search: String = ""
    @State private var locationService = LocationService(completer: .init())
    @Binding var searchResults: [SearchResult]
    @State private var isShowingImagePicker = false
    @State private var image: UIImage?
    
    var body: some View {
        VStack {
            // 1 搜索栏
            HStack {
                // Image(systemName: "magnifyingglass")
                HStack{
                    Text(" 🔍")
                    TextField("想瞧瞧哪里？", text: $search)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task {
                                searchResults = (try? await locationService.search(with: search)) ?? []
                            }
                        }
                }.modifier(TextFieldGrayBackgroundColor())
                
                //相机按钮
                Button{
                    isShowingImagePicker = true
                }label: {
                    Image("icon-camera")
                        .frame(width: 40, height: 40)
                        .padding(.trailing,Constants.spacingSpacingM)
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                CameraView(image: $image)
            }
            
            
            Spacer()
            
            // 2
            List {
                ForEach(locationService.completions) { completion in
                    Button(action: {didTapOnCompletion(completion) }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(completion.title)
                                .font(.headline)
                                .fontDesign(.rounded)
                            Text(completion.subTitle)
                            // Show the URL if it's present
                            if let url = completion.url {
                                Link(url.absoluteString, destination: url)
                                    .lineLimit(1)
                            }
                        }
                    }
                    // 3
                    .listRowBackground(Color.clear)
                }
            }
            // 4
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        // 5
        .onChange(of: search) {
            locationService.update(queryFragment: search)
        }
        
        
        .padding()
        // 2 用户无法通过向下滑动来关闭工作表视图
        .interactiveDismissDisabled()//
        // 3 工作表视图有两种可能的尺寸：小尺寸（200 点高）和大尺寸（默认尺寸）
        .presentationDetents([.height(120), .large])
        // 4 模糊效果
        .presentationBackground(.regularMaterial)
        // 5 用户可以与其后面的地图视图进行交互
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
    
    private func didTapOnCompletion(_ completion: SearchCompletions) {
        Task {
            if let singleLocation = try? await locationService.search(with: "\(completion.title) \(completion.subTitle)").first {
                searchResults = [singleLocation]
            }
        }
    }
}

//#Preview {
//    SheetView()
//}
