//
//  ShareDetailView.swift
//  guanzhi
//
//  Created by Vera on 2024/3/10.
//

import SwiftUI


struct ShareDetailView: View {
    @Environment(\.appState) var appState
    @ObservedObject var searchViewModel: SearchViewModel
    var animationNamespace: Namespace.ID
    @State private var isShowShareDetailsCard: Bool = true // 控制卡片的显示与隐藏
    @State private var isFullScreen: Bool = false // 控制卡片的当前状态（部分或全屏）
    @State private var dragOffset: CGFloat = 0 // 记录拖动过程中的偏移量
    @State private var isAtTop: Bool = true
    @State private var isMoreOptionsShow: Bool = true
    @State private var isTieTieEnabled: Bool = false
    @State private var isShowCarousel: Bool = false
    @State private var image: UIImage?
    
    var body: some View {
        @Bindable var appState = appState

//            NavigationStack {
                ZStack {
                    // 显示 CarouselView，展示所有图片
//                        CarouselView(isShowCarousel: $isShowCarousel)
//                            .environmentObject(searchViewModel)
//                        SimpleCarouselView(mediaGroups: mediaGroups)
                    
                    
                    if let selectedAnnotation = searchViewModel.selectedAnnotation {
                                        MediaCarouselView(
                                            animationNamespace: animationNamespace,
                                            annotationId: selectedAnnotation.id
                                        )
                                        .environment(appState)
                                        .environmentObject(searchViewModel)
                                        .ignoresSafeArea(.all)
                                        
                                    }
                    
//                    MediaCarouselView(isShowCarousel: $isShowCarousel)
//                        .environment(appState)
//                        .environmentObject(searchViewModel)
//                        .onTapGesture {
//                            withAnimation(.easeInOut) {
//                                if isShowShareDetailsCard {
//                                    // 隐藏卡片
//                                    isShowShareDetailsCard = false
//                                    resetCardState()
//                                } else {
//                                    // 显示卡片，初始为部分显示
//                                    isShowShareDetailsCard = true
//                                    resetCardState()
//                                }
//                            }
//                        }
                    
//                    TabView {
//                        if let selectedAnnotation = searchViewModel.selectedAnnotation {
//                            if let imageUrl = selectedAnnotation.imageUrl,
//                               let cachedImage = ImageCache.shared.image(forKey: imageUrl.absoluteString) {
//                                SharedImageView(
//                                    image: cachedImage,
//                                    isExpanded: appState.isShareImageExpanded,
//                                    animationNamespace: animationNamespace,
//                                    id: selectedAnnotation.id
//                                )
//                                .environment(appState)
//                                .environmentObject(searchViewModel)
//                                .matchedGeometryEffect(id: "image-\(selectedAnnotation.id)", in: animationNamespace, isSource: false)
//                                .ignoresSafeArea(.all)
//                                .onAppear {
//                                    withAnimation(.spring(duration: 0.5)) {
//                                        appState.isShareImageExpanded = true
//                                    }
//                                }
////                                .opacity(isShowCarousel ? 0 : 1)
//                            }
//                        }
//                    }
//                    .ignoresSafeArea(.all)
//                    .frame(width: .infinity, height: .infinity)
//                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
//                    .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                    

                    // 当需要显示卡片时
//                    if isShowShareDetailsCard {
//                        // 弹出卡片视图
//                        ShareDetailsCardView(isFullScreen: isFullScreen, isAtTop: $isAtTop)
//                            .transition(.move(edge: .bottom)) // 从底部移动过渡
//                            .zIndex(1) // 确保卡片在最上层
//                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height) // 固定卡片尺寸为屏幕大小
//                            .edgesIgnoringSafeArea(.all)
//                            .offset(y: isFullScreen ? 0 + dragOffset : UIScreen.main.bounds.height * 4 / 5 + dragOffset) // 根据状态设置偏移量
//                            .gesture(
//                                DragGesture()
//                                    .onChanged { value in
//                                        let translation = value.translation.height
//                                        if isFullScreen && isAtTop {
//                                            // 全屏且在顶部，允许下拉
//                                            if translation > 0 {
//                                                dragOffset = translation
//                                            }
//                                        } else if !isFullScreen {
//                                            // 部分显示状态，允许上拉
//                                            if translation < 0 {
//                                                dragOffset = translation
//                                            }
//                                        }
//                                    }
//                                    .onEnded { value in
//                                        let translation = value.translation.height
//                                        withAnimation(.easeInOut) {
//                                            if isFullScreen && isAtTop {
//                                                if translation > 150 {
//                                                    // 下拉超过阈值，缩回部分显示
//                                                    isFullScreen = false
//                                                }
//                                            } else if !isFullScreen {
//                                                if translation < -150 {
//                                                    // 上拉超过阈值，展开全屏
//                                                    isFullScreen = true
//                                                }
//                                            }
//                                            // 重置拖动偏移量
//                                            dragOffset = 0
//                                        }
//                                    }
//                            )
//                        
//                        CommentContentView(isTieTieEnabled: $isTieTieEnabled)
//                            .zIndex(2)
//                            .edgesIgnoringSafeArea(.all)
//                    }
                    
                }
                .toolbar {
                    if isShowShareDetailsCard {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button{
                                //返回按钮-圆形
                                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.4)) {
                                    appState.isShareImageExpanded.toggle()
                                }
//                                appState.isShareImageExpanded = false
                                searchViewModel.selectedAnnotation = nil
                                searchViewModel.selectedAnnotationID = nil
                                appState.isShowingSearchView = true
                                appState.isShowingShowMarker = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    searchViewModel.cleandownloadMedia()
                                }
                            }label: {
                                Image("icon-back")
                            }
                            .buttonStyle(ButtonStyle_m())
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button{
                                //更多按钮-圆形
                            }label: {
                                Image("icon-more")
                            }
                            .buttonStyle(ButtonStyle_m())
                        }
                    }
                }
                .ignoresSafeArea(.all)
//            } //NavStack
//            .background(Color.black)
            .ignoresSafeArea(.all)
            .statusBar(hidden: isFullScreen)
            .onAppear {
                withAnimation(.spring()) {
                    appState.isShareImageExpanded = true
                }
            }
    }

    // 重置卡片状态到初始部分显示
    func resetCardState() {
        isFullScreen = false
        dragOffset = 0
        isAtTop = true
    }
}




struct ShareDetailView_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @Namespace var animationNamespace

        var body: some View {
            ShareDetailView(
                searchViewModel: SearchViewModel(),
                animationNamespace: animationNamespace
            )
            .environment(\.appState, AppStateModel())
        }
    }

    static var previews: some View {
        PreviewContainer()
    }
}


struct CommentContentView: View {
    @State private var commentContent: String = ""
    @State private var placeholder: String = "发表一个贴贴"
    @Binding var isTieTieEnabled: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 8) {
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(.shadow(.inner(color: Color("color-primary").opacity(1), radius: 0, x: 4, y: 6)))
                    .stroke(.black, lineWidth: 4)
                    .foregroundStyle(Color("color-white").opacity(1))
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        TextField(placeholder, text: $commentContent)
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0))
                            .cornerRadius(20)
                            .multilineTextAlignment(.leading)
                            .autocorrectionDisabled()
                            .onTapGesture {
                                
                            }
                            .onSubmit {
                                
                            }
                    }
                
                Button(action: {
                    // 贴贴--胶囊按钮hug
                }) {
                    Text("🫂 贴贴")
                }
                .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: isTieTieEnabled))
                
                
            }
            .padding(.top, 16)
            .padding(.horizontal)
            .padding(.bottom, 48)
            .background(BlurView(style: .systemMaterialLight)/*Color.white.opacity(0.9)*/)
        }
    }
}


//struct ShareDetailView: View {
//    @Environment(\.appState) var appState
//    @ObservedObject var searchViewModel: SearchViewModel
//    var animationNamespace: Namespace.ID
//    @State private var isShowShareDetailsCard: Bool = true // 控制卡片的显示与隐藏
//    @State private var isFullScreen: Bool = false // 控制卡片的当前状态（部分或全屏）
//    @State private var dragOffset: CGFloat = 0 // 记录拖动过程中的偏移量
//    @State private var isAtTop: Bool = true
//    @State private var isMoreOptionsShow: Bool = true
//    @State private var isTieTieEnabled: Bool = false
//    @State private var isShowCarousel: Bool = false
//
//    var body: some View {
//        @Bindable var appState = appState
//
//        NavigationView {
//            ZStack(alignment: .bottom) { // 设置对齐方式为底部
//                // 主轮播视图
//                CarouselView()
//                    .environmentObject(searchViewModel)
//                    .ignoresSafeArea(.all)
//                    .onTapGesture {
//                        withAnimation(.easeInOut) {
//                            if isShowShareDetailsCard {
//                                // 隐藏卡片
//                                isShowShareDetailsCard = false
//                                resetCardState()
//                            } else {
//                                // 显示卡片，初始为部分显示
//                                isShowShareDetailsCard = true
//                                resetCardState()
//                            }
//                        }
//                    }
//
//                // 当需要显示卡片时
//                if isShowShareDetailsCard {
//
//                    // 弹出卡片视图
//                    ShareDetailsCardView(isFullScreen: isFullScreen, isAtTop: $isAtTop)
//                        .transition(.move(edge: .bottom)) // 从底部移动过渡
//                        .zIndex(1) // 确保卡片在最上层
//                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height) // 固定卡片尺寸为屏幕大小
//                        .offset(y: isFullScreen ? 0 + dragOffset : UIScreen.main.bounds.height * 4 / 5 + dragOffset) // 根据状态设置偏移量
//                        .gesture(
//                            DragGesture()
//                                .onChanged { value in
//                                    let translation = value.translation.height
//                                    if isFullScreen && isAtTop {
//                                        // 全屏且在顶部，允许下拉
//                                        if translation > 0 {
//                                            dragOffset = translation
//                                        }
//                                    } else if !isFullScreen {
//                                        // 部分显示状态，允许上拉
//                                        if translation < 0 {
//                                            dragOffset = translation
//                                        }
//                                    }
//                                }
//                                .onEnded { value in
//                                    let translation = value.translation.height
//                                    withAnimation(.easeInOut) {
//                                        if isFullScreen && isAtTop {
//                                            if translation > 150 {
//                                                // 下拉超过阈值，缩回部分显示
//                                                isFullScreen = false
//                                            }
//                                        } else if !isFullScreen {
//                                            if translation < -150 {
//                                                // 上拉超过阈值，展开全屏
//                                                isFullScreen = true
//                                            }
//                                        }
//                                        // 重置拖动偏移量
//                                        dragOffset = 0
//                                    }
//                                }
//                        )
//
//                    CommentContentView(isTieTieEnabled: $isTieTieEnabled)
//                        .zIndex(2)
//                }
//
//
//
//            }
//            .ignoresSafeArea(.all)
//            .statusBar(hidden: isFullScreen)
//            .toolbar {
//                if isShowShareDetailsCard {
//                    ToolbarItem(placement: .navigationBarLeading) {
//                        Button{
//                            //返回按钮-圆形
//                            searchViewModel.selectedAnnotation = nil
//                            appState.isShowingSearchView = true
//                            appState.isShowingShowMarker = true
//                        }label: {
//                            Image("icon-back")
//                        }
//                        .buttonStyle(ButtonStyle_m())
//                    }
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        Button{
//                            //更多按钮-圆形
//                        }label: {
//                            Image("icon-more")
//                        }
//                        .buttonStyle(ButtonStyle_m())
//                    }
//                }
//            }
//
//        }
//    }
//
//    // 重置卡片状态到初始部分显示
//    func resetCardState() {
//        isFullScreen = false
//        dragOffset = 0
//        isAtTop = true
//    }
//}
