//
//  ShareSingleView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/31.
//

import SwiftUI

/// 列表项图片加载状态
private enum ListImageLoadState {
    case loading
    case loaded(UIImage)
    case failed
}

struct ShareSingleView: View {
    let share: ResponsedShare
    /// 是否显示「最新」徽章（仅聚合列表中 48h 内发布的观之显示）
    var showNewBadge: Bool = false
    /// 可选的点击回调，如果提供则使用它，否则使用内部的 showShareDetail()
    var onTap: (() -> Void)? = nil

    // 环境对象
    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @ObservedObject private var addressLocalizer = AddressLocalizer.shared

    @State private var loadState: ListImageLoadState = .loading
    @State private var isPressed: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: Constants.spacingSpacingXs) {

            ZStack(alignment: .topLeading) {
                switch loadState {
                case .loaded(let uiImage):
                    Image(uiImage: uiImage)
                      .resizable()
                      .aspectRatio(contentMode: .fill)
                      .frame(width: 120, height: 120)
                      .clipped()

                case .loading:
                    ImagePlaceholderView(state: .loading, size: 120)
                        .onAppear {
                            loadImage()
                        }

                case .failed:
                    ImagePlaceholderView(state: .failed, size: 120)
                }

                if showNewBadge {
                    Text("最新")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            .frame(width: 120, height: 120)
//            Rectangle()
//              .foregroundColor(.clear)
//              .frame(width: 120, height: 120)
//              .background(
//                Image("WechatIMG21 1")
//                  .resizable()
//                  .aspectRatio(contentMode: .fill)
//                  .frame(width: 120, height: 120)
//                  .clipped()
//              )
            
            VStack(alignment: .leading) {
                // Space Between
                // tx/Body
                Text(share.data)
                  .font(Font.custom("PingFang SC", size: 16))
                  .kerning(0.22)
                  .foregroundColor(Color("text-black"))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .lineLimit(2) // 限制显示两行
                  .truncationMode(.tail) // 设置省略模式为尾部省略
                Spacer(minLength: 2)
                // Alternating Views and Spacers
                // tx/SecondaryInfo
                VStack(alignment: .leading, spacing: 2) {
                    // 褪色度标签
                    let fadePercent = share.fadeScore ?? 0
                    Text("褪色度：\(fadePercent)%")
                        .font(Font.custom("PingFang SC", size: 14))
                        .kerning(0.22)
                        .foregroundColor(fadePercent >= 90 ? .red : Color("text-gray"))

                    let dateString = dateStringFrom(share.createDate)
                    Text("#\(share.id) · \(dateString)")
                      .font(Font.custom("PingFang SC", size: 14))
                      .kerning(0.22)
                      .foregroundColor(Color("text-gray"))
                    Text("📌 \(addressLocalizer.localizedAddress(for: Int64(share.id)) ?? share.address)")
                        .font(Font.custom("PingFang SC", size: 14))
                        .kerning(0.22)
                        .foregroundColor(Color("color-black"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .task {
                            await addressLocalizer.resolveAddress(
                                shareId: Int64(share.id),
                                latitude: share.latitude,
                                longitude: share.longitude
                            )
                        }
                }
            }
            .padding(Constants.spacingSpacing0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Constants.spacingSpacingM)
        .padding(.vertical, Constants.spacingSpacingXs)
        .frame(maxWidth: .infinity, maxHeight: 133,alignment: .topLeading)
        .contentShape(Rectangle())  // 扩大点击区域到整个 frame（包括空白处）
        .onTapGesture {
            if let onTap = onTap {
                // 有回调时：只执行回调，由调用方负责导航
                // （避免重复导航导致详情页出现两层）
                onTap()
            } else {
                // 无回调时：使用默认导航
                showShareDetail()
            }
        }
        
    }
    // MARK: - Helper
    @MainActor
    private func dateStringFrom(_ createDate: Int) -> String {
        // 使用 TimeKit 统一处理时间（后端已统一 UTC）
        let date = ServerTime.parse(milliseconds: createDate)
        return TimeDisplay.shared.absoluteTime(from: date, style: .fixedFormat("yyyy.MM.dd HH:mm"))
    }
    
    private func loadImage() {
        guard let url = ephemeralGetThumbnailOrPhotoURL(responsedShare: share) else {
            loadState = .failed
            return
        }

        let fadeScore = share.fadeScore ?? 0
        // 使用统一 API，传入 fadeScore 以支持白化效果
        ImageCache.shared.loadImage(
            from: url,
            variant: .fadeVeil(fadeScore: fadeScore)
        ) { downloaded in
            // 回调已统一在主线程，无需再 DispatchQueue.main.async
            if let image = downloaded {
                self.loadState = .loaded(image)
            } else {
                self.loadState = .failed
            }
        }
    }
    
    private func ephemeralGetThumbnailOrPhotoURL(responsedShare: ResponsedShare) -> URL? {
        let baseURL = Constants.MEDIA_CDN_HOST + "/"

        // 1. 拆分路径
        let pathList = responsedShare.imagePath.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if pathList.isEmpty { return nil }

        // 2. 仿照 parseMediaFile: 先尝试找 "thumbnail", 没有就找 "photo", 再没有就选第一个
        //   (这里你可以参考 parseMediaFile 的逻辑来判断类型)
        //   但因为你没 SwiftData, 不需要 actually create a MediaFile, 只要找到最合适的 path

        // 2.1. 优先 thumbnail
        if let thumbPath = pathList.first(where: { $0.lowercased().contains("thumbnail") }) {
            return URL(string: baseURL + thumbPath)
        }

        // 2.2. 不然看看第一个 photo
        if let photoPath = pathList.first(where: { $0.lowercased().contains("photo") }) {
            return URL(string: baseURL + photoPath)
        }

        // 2.3. 不然看看第一个 video
        if let videoPath = pathList.first(where: { $0.lowercased().contains("video") }) {
            return URL(string: baseURL + videoPath)
        }

        // 2.4. 其他情况就用第一个
        let firstPath = pathList[0]
        return URL(string: baseURL + firstPath)
    }
    
    private func showShareDetail() {
            // 1. 拿到 shareId
            let shareIdString = "\(share.id)"
            
            // 2. 根据你想要的方式决定
            if appState.useOverlayMode {
                // overlay模式
                //   a) 告诉 SearchViewModel 选中哪条分享
                searchViewModel.selectedAnnotationID = shareIdString
                searchViewModel.loadShareDetail(for: Int64(share.id))
                //   b) 显示 overlay
                /*appState.isShareImageExpanded*/searchViewModel.isShareDetailOverlayShown = true
                // 如果有需要，把 .isShowingSearchView = false
                // appState.isShowingSearchView = false
            } else {
                // navigation模式
                navigationCoordinator.path.append(Route.shareDetailView(annotationID: shareIdString))
            }
        }

        
}

#Preview {
    ShareSingleView(share: ResponsedShare(
        id: 123,
        createDate: 1721174400000, // mock
        userId: 456,
        data: "这是 mock 的分享内容",
        longitude: 116.32,
        latitude: 39.90,
        provinceCode: nil,
        cityCode: nil,
        districtCode: nil,
        address: "北京市海淀区某处",
        imagePath: "image-20240904080557516.jpg",
        title: "MockTitle",
        deleted: 0,
        agreeCount: 10,
        neutralCount: 2,
        checkinCount: 5,
        commentCount: 3,
        currentUserVoteType: nil,
        fadeScore: 25
    ))
}
