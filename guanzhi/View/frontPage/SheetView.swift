//
//  SheetView.swift
//  guanzhi
//
//  Created by Vera on 2024/2/29.
//

import SwiftUI
import MapKit

struct SheetView: View {
    @State private var search: String = ""
    @State private var locationService = LocationService(completer: .init())
    @Binding var searchResults: [SearchResult]
    @State private var isShowingImagePicker = false
    @State private var image: UIImage?
    @State private var isShowPostView = false
    @Binding var cardName : String
    let placeholder = "🔍想瞧瞧哪里？"
    @Binding var currentDetent: PresentationDetent // 绑定sheetview高度
    @Binding var selectedLocation: SearchResult?
    @Binding var position: MapCameraPosition
    @Binding var isShowSearchView: Bool
    @Binding var isShowResultCard: Bool
    @Binding var isShowMarker: Bool
    @Binding var currentSearchTask: Task<Void, Never>?  // 添加任务管理
    
    var body: some View {
        
        VStack {
            // 1 搜索栏
            HStack(spacing: 8) {
                // Image(systemName: "magnifyingglass")
               
//                    Text(" 🔍")
//                    TextField("想瞧瞧哪里？", text: $search)
//                        .autocorrectionDisabled()
//                        .onSubmit {
//                            Task {
//                                searchResults = (try? await locationService.search(with: search)) ?? []
//                            }
//                        }
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                        .stroke(.black, lineWidth: 4)
                        .foregroundStyle(Color("color-white").opacity(1))
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            TextField(placeholder, text: $search)
                                .font(.system(size: 16, weight: .regular, design: .default))
                                .padding(.horizontal, 16)
                                .frame(height: 32)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0))
                                .cornerRadius(20)
                                .multilineTextAlignment(.leading)
                                .autocorrectionDisabled()
                                .onTapGesture {
                                    currentDetent = .large
                                    selectedLocation = nil
                                    searchResults.removeAll()
                                }
                                .onSubmit {
                                    currentSearchTask?.cancel() // 取消当前任务
                                    currentSearchTask = Task {
                                        searchResults = (try? await locationService.search(with: search)) ?? []
                                    }
                                }
                        }
                
                if currentDetent != .large { // 根据 BottomSheet 的状态隐藏或显示
                    Button(action: {
                        // 分享地点-胶囊按钮hug
                        isShowingImagePicker = true
                    }) {
                        Text("📷 分享地点")
                    }
                    .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: true))
                    
                } else {
                    Button{
                        //关闭按钮-圆形
                        search = ""
                        UIApplication.shared.endEditing()
                        currentDetent = .height(60)
                        selectedLocation = nil
                        searchResults.removeAll()
                        
                    }label: {
                        Image("icon-close")
                    }
                    .buttonStyle(ButtonStyle_m())
                }
                
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3), value: currentDetent)
            .padding(.top, 32)
            .padding(.horizontal)
            .padding(.bottom, 8)
//            .frame(width: .infinity, height: .infinity)
            .sheet(isPresented: $isShowingImagePicker) {
                NavigationStack{
                    CameraView(image: $image)
                    { image in
                        self.image = image
                        isShowPostView = true
                    }.navigationDestination(isPresented: $isShowPostView) {
                        PostUIView(image: self.image,cardName: $cardName)
                    }
                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .disabled(!isShowSearchView)
        .presentationCornerRadius(20)
        // 2 用户无法通过向下滑动来关闭工作表视图
        .interactiveDismissDisabled()//
        // 3 工作表视图有两种可能的尺寸：小尺寸（200 点高）和大尺寸（默认尺寸）
        .presentationDetents([.height(60), .large], selection: $currentDetent)
        // 4 模糊效果
        .presentationBackground(.regularMaterial)
        // 5 用户可以与其后面的地图视图进行交互
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }
    
    private func didTapOnCompletion(_ completion: SearchCompletions) {
        Task {
            // 取消当前任务
            currentSearchTask?.cancel()
                // 启动新任务
            currentSearchTask = Task {
                if let singleLocation = try? await locationService.search(with: "\(completion.title) \(completion.subTitle)").first {
                    searchResults = [singleLocation]
                    selectedLocation = singleLocation
                    print("Selected Location in SheetView: \(String(describing: selectedLocation))")
                    withAnimation(Animation.spring()) {
                        position = .region(MKCoordinateRegion(center: singleLocation.location, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
                        isShowMarker = true
                        isShowSearchView = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                        search = ""
                        currentDetent = .height(60)
                        isShowResultCard = true
                        print([SearchResult].self)  //测试
                    }
                }
            }
        }
    }
}

//#Preview {
//    SheetView()
//}
