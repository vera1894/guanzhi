//
//  ShareDetailsCardView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2024/9/26.
//

import SwiftUI
import CoreLocation

struct ShareDetailsCardView: View {
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Binding var isFullScreen: Bool
    @Binding var isAtTop: Bool
    @Binding var dragOffset: CGFloat
    @State private var scrollPosition: CGPoint = .zero
    @Binding var cardDragIsActive: Bool
    
    @State private var isLoadingUser: Bool = false
    @State private var loadUserError: String?
    @State private var topPadding: Double = 0.01
    @State private var showDragIndicator: Bool = false  // 拖动指示条延迟显示
    
    private var localUser: LocalUserProfile {
        return userProfileManager.localUserProfile!
    }

    var body: some View {
        if let share = searchViewModel.selectedShare {
            ZStack {
                VStack {

                    // 拖动指示条（仅展开状态显示，带延迟以配合展开动画）
                    if showDragIndicator {
                        Rectangle()
                            .foregroundStyle(Color("color-white"))
                            .frame(width: 36, height: 6)
                            .cornerRadius(3, corners: .allCorners)
                            .padding(.top, 8)
                            .transition(.opacity)
                    } else {
                        // 收起状态：占位符保持布局一致
                        Color.clear
                            .frame(width: 36, height: 6)
                            .padding(.top, 8)
                    }
                    
                    ScrollView {
                        VStack {
                            
                            // 用户信息区域
//                            if isAuthorMyself(share.userId) {
//                                // 显示本机用户
//                                if let local = userProfileManager.localUserProfile {
//                                    userProfileSectionForMine(localUser: local)
//                                        .onTapGesture {
//                                            navigationCoordinator.path.append(Route.myView)
//                                        }
//                                } else {
//                                    Text("本机用户信息尚未加载")
//                                }
//                            } else {
//                                // 显示他人用户
//                                if isLoadingUser {
//                                    Text("加载中...")
//                                } else if let error = loadUserError {
//                                    Text("加载失败：\(error)")
//                                        .foregroundColor(.red)
//                                } else if let otherUserInfo = userProfileManager.otherUserProfile,
//                                          otherUserInfo.id == share.userId  {
//                                    userProfileSectionForOthers(otherInfo: otherUserInfo)
//                                        .onTapGesture {
//                                            navigationCoordinator.path.append(Route.othersView(userId: Int(share.userId)))
//                                        }
//                                } else {
//                                    Text("加载中或无数据")
//                                }
//                            }
                            
                            
                            VStack(alignment: .leading, spacing: Constants.spacingSpacingXs) {
                                //分享内容
                                if isFullScreen {
                                    // 全屏状态：显示完整内容
                                    Text(share.data)
                                        .font(Font.custom("PingFang SC", size: 16))
                                        .kerning(0.22)
                                        .foregroundColor(Color("color-black"))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    // 收起状态：最多2行 + "·查看更多"
                                    collapsedContentView(text: share.data)
                                }
                                
                                // 次级信息
//                                HStack {
//    //                                Text("#FB80765·2023.02.12 12:22")
//                                    Text("#\(share.id) · \(searchViewModel.formattedDate(from: share.createDate))")
//                                        .font(Font.custom("PingFang SC", size: 14))
//                                        .kerning(0.22)
//                                        .foregroundColor(Color("text-deepgray"))
//                                    Spacer()
//                                }
                                
                                // 位置信息
                                if isFullScreen {
                                    HStack{
                                        Text("📌 \(share.address)") //需要调整
                                            .font(Font.custom("PingFang SC", size: 14))
                                            .kerning(0.22)
                                            .foregroundColor(isFullScreen ? Color("color-black") : Color.white)
                                            .lineLimit(1) // 限制显示一行
                                            .truncationMode(.tail) // 设置省略模式为尾部省略
                                        Spacer()
                                        Button(action: {
                                            // 查看路线-胶囊按钮s
                                            openNavigationApp(destination: CLLocationCoordinate2D(latitude: share.latitude, longitude: share.longitude))
                                        }) {
                                            Text("🧭 查看路线")
                                        }
                                        .buttonStyle(ButtonStyle_capsuleHugPrimary_s(isEnabled: true))
                                    }
                                }
                                
                                
                            } //主题内容
                            .padding(.horizontal, Constants.spacingSpacingM)
                            .padding(.bottom, Constants.spacingSpacingXs)
                            
                            
                            
//                            //评论区
//                            ForEach(0..<20, id: \.self) { i in
//                                Text("评论内容 \(i)")
//                                    .font(.system(size: 20))
//                                    .foregroundColor(.black)
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//                                    .id(i)
//                            }
//                            .padding()
//                            
//                            Spacer()
                        }
                        .background(GeometryReader { geometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
                        })
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            self.scrollPosition = value
                        }
                        .padding(.top, isFullScreen ? UIScreen.main.bounds.height * topPadding : 0)
                    }  // 卡片中的内容与顶部距离
                    .coordinateSpace(name: "scroll")
                    .onAppear(perform: {
                        isAtTop = true
                    })
                    .onChange(of: scrollPosition) { _ , _ in
                        if scrollPosition.y >= (UIScreen.main.bounds.height * topPadding - 5) { // 卡片中的内容与顶部距离
                            isAtTop = true
                        } else {
                            isAtTop = false
                        }
                    }
                    
                }
                .background(
                    Group {
                        if isFullScreen {
                            // 展开状态：模糊背景
                            BlurView(style: .systemMaterial)
                        } else {
                            // 收起状态：完全透明背景
                            Color.clear
                        }
                    }
                    .cornerRadius(isFullScreen ? 0 : Constants.cornerRCornerRM)
                )
                .frame(maxWidth: .infinity)
                .scrollDisabled(!isFullScreen || !cardDragIsActive)
                
                HStack {
                    Color.clear
                        .frame(width: 25)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let dragDistance = value.translation.width
                                    if dragDistance > 0 {
                                        dragOffset = dragDistance
                                    }
                                }
                                .onEnded { value in
                                    let dragDistance = value.translation.width
                                    let threshold: CGFloat = 120
                                    if dragDistance > threshold {
                                        withAnimation(.spring) {
                                            isFullScreen = false
                                        }
                                    }
                                    withAnimation(.spring) {
                                        dragOffset = 0
                                    }
                                    
                                }
                        )
                    Spacer()
                } // 左边缘滑动退出区域
                .ignoresSafeArea(.all)
            }
            .onAppear {
                if !isAuthorMyself(share.userId) {
                    Task {
                        do {
                            isLoadingUser = true
                            try await userProfileManager.fetchUserFullInfo(userId: Int(share.userId))
                            isLoadingUser = false
                        } catch {
                            isLoadingUser = false
                            loadUserError = "\(error)"
                        }
                    }
                }
            }
            // 监听展开/收起状态，控制拖动指示条的延迟显示
            .onChange(of: isFullScreen) { _, newValue in
                if newValue {
                    // 展开时：延迟 0.3 秒显示指示条（等待展开动画完成）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showDragIndicator = true
                        }
                    }
                } else {
                    // 收起时：立即隐藏指示条
                    withAnimation(.easeInOut(duration: 0.1)) {
                        showDragIndicator = false
                    }
                }
            }
        }
        
    }
    
    func openNavigationApp(destination: CLLocationCoordinate2D) {
        // 先设置状态，让遮罩出现（使用 withAnimation 统一动画节拍）
        withAnimation {
            searchViewModel.showNavigationSheet = true
        }

        // 创建坐标转换器
        let converter = CoordinateConverter.shared

        // 获取正确的坐标
        // 首先判断是否在中国境内
        let isInChina = !converter.isOutOfChina(destination)

        // 导入的坐标可能是WGS-84，需要转换为适合各个地图的格式
        let wgs84Coordinate = destination // 假设传入的是WGS-84坐标
        let gcj02Coordinate: CLLocationCoordinate2D

        if isInChina {
            // 在中国境内需要转换
            gcj02Coordinate = converter.wgs84ToGcj02(wgs84Coordinate) // 转为火星坐标系
        } else {
            // 国外坐标不需要转换
            gcj02Coordinate = wgs84Coordinate
        }

        let alert = UIAlertController(title: "选择导航应用", message: nil, preferredStyle: .actionSheet)

        // 高德地图选项 - 使用GCJ-02坐标系
        if UIApplication.shared.canOpenURL(URL(string: "iosamap://")!) {
            alert.addAction(UIAlertAction(title: "高德地图", style: .default) { [weak searchViewModel] _ in
                let urlString = "iosamap://path?sourceApplication=观之&dlat=\(gcj02Coordinate.latitude)&dlon=\(gcj02Coordinate.longitude)&dev=0&t=0"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
                withAnimation {
                    searchViewModel?.showNavigationSheet = false
                }
            })
        }

        // 百度地图选项 - 由于没有直接转换为BD-09的方法，我们使用GCJ-02坐标
        // 百度地图会自动处理GCJ-02到BD-09的转换
        if UIApplication.shared.canOpenURL(URL(string: "baidumap://")!) {
            alert.addAction(UIAlertAction(title: "百度地图", style: .default) { [weak searchViewModel] _ in
                let urlString = "baidumap://map/direction?destination=latlng:\(gcj02Coordinate.latitude),\(gcj02Coordinate.longitude)|name:观之位置&mode=driving&src=观之"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
                withAnimation {
                    searchViewModel?.showNavigationSheet = false
                }
            })
        }

        // Google Maps 选项 - 使用WGS-84坐标系
        if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
            alert.addAction(UIAlertAction(title: "Google Maps", style: .default) { [weak searchViewModel] _ in
                let urlString = "comgooglemaps://?daddr=\(wgs84Coordinate.latitude),\(wgs84Coordinate.longitude)&directionsmode=driving"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
                withAnimation {
                    searchViewModel?.showNavigationSheet = false
                }
            })
        }

        // Apple Maps 选项 - 使用WGS-84坐标系
        alert.addAction(UIAlertAction(title: "Apple 地图", style: .default) { [weak searchViewModel] _ in
            let urlString = "http://maps.apple.com/?daddr=\(wgs84Coordinate.latitude),\(wgs84Coordinate.longitude)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
            withAnimation {
                searchViewModel?.showNavigationSheet = false
            }
        })

        // 取消按钮
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak searchViewModel] _ in
            withAnimation {
                searchViewModel?.showNavigationSheet = false
            }
        })

        // 让一轮 runloop，避免与遮罩动画抢占
        DispatchQueue.main.async {
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func isAuthorMyself(_ userId: Int64) -> Bool {
        #if DEBUG
            return OTOLoginStatusManager.shared.__effectiveUserIdForPreview() == userId
        #else
            return OTOLoginStatusManager.shared.getUserID() == userId
        #endif
        }
    
    // MARK: - 视图拆分

    /// 收起状态的内容视图（最多2行 + "... ·查看更多"）
    @ViewBuilder
    private func collapsedContentView(text: String) -> some View {
        TruncatedTextWithViewMore(
            text: text,
            maxLines: 2,
            font: UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16),
            textColor: .white,
            viewMoreText: " ·查看更多",
            viewMoreColor: UIColor(named: "color-primary") ?? .systemBlue
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

        @ViewBuilder
        private func userProfileSectionForMine(localUser: LocalUserProfile) -> some View {
            // 获取本机用户头像
            let avatarImage: Image = {
                if let uiImage = userProfileManager.avatarImage {
                    return Image(uiImage: uiImage)
                } else {
                    return Image("例子")
                }
            }()

            HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                // 头像（使用真实头像）
                AvatarView_m(
                    isEnabled: true,
                    profileImage: avatarImage,
                    borderThickness: 4
                )

                // 只显示用户名，不显示 OneCode
                Text(localUser.nickname)
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
        }

        @ViewBuilder
        private func userProfileSectionForOthers(otherInfo: UserFullInfoModel) -> some View {
            HStack(alignment: .center, spacing: Constants.spacingSpacingXs) {
                // 头像（从网络加载或使用默认）
                if let photoPath = otherInfo.photo,
                   let photoURL = URL(string: photoPath) {
                    // 使用 AsyncImage 加载他人头像
                    AsyncImage(url: photoURL) { phase in
                        switch phase {
                        case .success(let image):
                            AvatarView_m(
                                isEnabled: true,
                                profileImage: image,
                                borderThickness: 4
                            )
                        case .failure, .empty:
                            AvatarView_m(
                                isEnabled: true,
                                profileImage: Image("例子"),
                                borderThickness: 4
                            )
                        @unknown default:
                            AvatarView_m(
                                isEnabled: true,
                                profileImage: Image("例子"),
                                borderThickness: 4
                            )
                        }
                    }
                } else {
                    // 无头像 URL，使用默认头像
                    AvatarView_m(
                        isEnabled: true,
                        profileImage: Image("例子"),
                        borderThickness: 4
                    )
                }

                // 只显示用户名，不显示 OneCode
                Text(otherInfo.nickname ?? "陌生人")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
        }
    
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

#Preview {
    ShareDetailsCardView(isFullScreen: .constant(false), isAtTop: .constant(true), dragOffset: .constant(0), cardDragIsActive: .constant(true))
        .environmentObject(SearchViewModel())
        .environmentObject(UserProfileManager())
        .environmentObject(NavigationCoordinator())
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

// MARK: - TruncatedTextWithViewMore

/// 支持截断后显示 "... ·查看更多" 的文本组件
/// 使用 UILabel 实现精确的截断控制
struct TruncatedTextWithViewMore: View {
    let text: String
    let maxLines: Int
    let font: UIFont
    let textColor: UIColor
    let viewMoreText: String
    let viewMoreColor: UIColor

    @State private var intrinsicHeight: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            TruncatedLabelRepresentable(
                text: text,
                maxLines: maxLines,
                font: font,
                textColor: textColor,
                viewMoreText: viewMoreText,
                viewMoreColor: viewMoreColor,
                availableWidth: geometry.size.width,
                onHeightChange: { height in
                    DispatchQueue.main.async {
                        intrinsicHeight = height
                    }
                }
            )
        }
        .frame(height: intrinsicHeight)
    }
}

/// UILabel 包装器
private struct TruncatedLabelRepresentable: UIViewRepresentable {
    let text: String
    let maxLines: Int
    let font: UIFont
    let textColor: UIColor
    let viewMoreText: String
    let viewMoreColor: UIColor
    let availableWidth: CGFloat
    let onHeightChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = maxLines
        label.lineBreakMode = .byWordWrapping
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let maxWidth = availableWidth > 0 ? availableWidth : UIScreen.main.bounds.width - 32

        // 设置 preferredMaxLayoutWidth 确保换行正确
        label.preferredMaxLayoutWidth = maxWidth

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .kern: 0.22,
            .paragraphStyle: paragraphStyle
        ]

        let viewMoreAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: viewMoreColor,
            .kern: 0.22
        ]

        // 测量完整文本需要多少行
        let fullAttributedText = NSAttributedString(string: text, attributes: textAttributes)
        let textSize = fullAttributedText.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let lineHeight = font.lineHeight
        let estimatedLines = Int(ceil(textSize.height / lineHeight))

        if estimatedLines <= maxLines {
            // 不需要截断，直接显示完整文本 + "·查看更多"
            let combined = NSMutableAttributedString(string: text, attributes: textAttributes)
            combined.append(NSAttributedString(string: viewMoreText, attributes: viewMoreAttributes))
            label.attributedText = combined
        } else {
            // 需要截断，计算能显示多少字符
            let suffix = "..." + viewMoreText
            let truncatedText = calculateTruncatedText(
                text: text,
                maxWidth: maxWidth,
                maxLines: maxLines,
                font: font,
                suffix: suffix,
                textAttributes: textAttributes
            )

            let combined = NSMutableAttributedString(string: truncatedText + "...", attributes: textAttributes)
            combined.append(NSAttributedString(string: viewMoreText, attributes: viewMoreAttributes))
            label.attributedText = combined
        }

        // 计算实际高度并回调
        label.sizeToFit()
        let actualHeight = label.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude)).height
        onHeightChange(actualHeight)
    }

    /// 计算截断后能显示的最大文本
    private func calculateTruncatedText(
        text: String,
        maxWidth: CGFloat,
        maxLines: Int,
        font: UIFont,
        suffix: String,
        textAttributes: [NSAttributedString.Key: Any]
    ) -> String {
        // 计算每行大约能容纳的字符数
        let avgCharWidth = ("测" as NSString).size(withAttributes: [.font: font]).width
        let charsPerLine = Int(maxWidth / avgCharWidth)
        let maxChars = charsPerLine * maxLines

        // 从估算的最大字符数开始，逐步减少直到能放下
        var endIndex = min(text.count, maxChars)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        while endIndex > 0 {
            let substring = String(text.prefix(endIndex))
            let testString = substring + suffix

            let testSize = (testString as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .kern: 0.22, .paragraphStyle: paragraphStyle],
                context: nil
            )

            let lineHeight = font.lineHeight
            let lines = Int(ceil(testSize.height / lineHeight))

            if lines <= maxLines {
                return substring
            }

            endIndex -= 1
        }

        return String(text.prefix(10)) // 兜底返回前10个字符
    }
}
