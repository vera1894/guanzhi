//
//  ShareSingleView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/31.
//

import SwiftUI

struct ShareSingleView: View {
    let share: ResponsedShare
    // 环境对象
    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var image: UIImage?
    @State private var variableValue: Double = 0.0
    @State private var isPressed: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: Constants.spacingSpacingXs) {
            
            if let uiImage = image {
                Image(uiImage: uiImage)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 120, height: 120)
                  .clipped()
            } else {
                Rectangle()
                  .foregroundColor(Color("color-primary"))
                  .frame(width: 120, height: 120)
                  .overlay {
                      Image(systemName: "timelapse", variableValue: variableValue)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .onAppear {
                            loadImage()
                            withAnimation(Animation.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                                self.variableValue = 1.0
                            }
                        }
                  }
                
            }
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
                  .truncationMode(.tail) // 设置省略模式为尾部省略
                Spacer(minLength: 2)
                // Alternating Views and Spacers
                // tx/SecondaryInfo
                VStack(alignment: .leading, spacing: Constants.spacingSpacingXs) {
                    let dateString = dateStringFrom(share.createDate)
                    Text("#\(share.id) · \(dateString)")
                      .font(Font.custom("PingFang SC", size: 14))
                      .kerning(0.22)
                      .foregroundColor(Color("text-gray"))
                    Text("📌 \(share.address)") //需要调整
                        .font(Font.custom("PingFang SC", size: 14))
                        .kerning(0.22)
                        .foregroundColor(Color("color-black"))
                        .lineLimit(1) // 限制显示一行
                        .truncationMode(.tail) // 设置省略模式为尾部省略
                }
            }
            .padding(Constants.spacingSpacing0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Constants.spacingSpacingM)
        .padding(.vertical, Constants.spacingSpacingXs)
        .frame(maxWidth: .infinity, maxHeight: 133,alignment: .topLeading)
        .onTapGesture {
            // 点击 -> 进入分享详情
            showShareDetail()
        }
        
    }
    // MARK: - Helper
    private func dateStringFrom(_ createDate: Int) -> String {
        let ts = TimeInterval(createDate / 1000)
        let date = Date(timeIntervalSince1970: ts)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func loadImage() {
        if let url = ephemeralGetThumbnailOrPhotoURL(responsedShare: share) {
            ImageCache.shared.loadImage(from: url) { downloaded in
                DispatchQueue.main.async {
                    self.image = downloaded
                }
            }
        }
    }
    
    private func ephemeralGetThumbnailOrPhotoURL(responsedShare: ResponsedShare) -> URL? {
        let baseURL = "https://onettoo.com/"

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
        deleted: 0
    ))
}
