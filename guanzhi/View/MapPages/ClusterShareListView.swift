//
//  ClusterShareListView.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/4.
//
//  Stage 2: 聚合分享列表
//  - 使用系统 sheet 呈现，与主页搜索结果卡片风格一致
//  - 复用 ShareSingleView 显示列表
//  - 点击列表项可跳转分享详情
//

import SwiftUI

struct ClusterShareListView: View {

    /// 聚合内的标注列表
    let annotations: [CustomAnnotation]

    /// 关闭回调
    var onDismiss: () -> Void

    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("附近的观之")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("text-black"))
                    .padding(.top, 8)

                Spacer()

                Text("\(annotations.count) 条")
                    .font(.system(size: 14))
                    .foregroundColor(Color("text-gray"))

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color("text-gray"))
                }
            }
            .padding(.horizontal, Constants.spacingSpacingM)
            .padding(.top, Constants.spacingSpacingS)
            .padding(.bottom, Constants.spacingSpacingS)

            Divider()

            // 分享列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(convertToResponsedShares(), id: \.id) { share in
                        ShareSingleView(share: share)
                            .environment(appState)
                            .environmentObject(searchViewModel)
                            .environmentObject(navigationCoordinator)

                        Divider()
                            .padding(.leading, 120 + Constants.spacingSpacingM)
                    }
                }
            }
        }
    }

    // MARK: - Helper

    /// 将 CustomAnnotation 转换为 ResponsedShare（ShareSingleView 需要）
    private func convertToResponsedShares() -> [ResponsedShare] {
        return annotations.compactMap { annotation -> ResponsedShare? in
            guard let share = annotation.annotationData else { return nil }

            // 分离变量以简化表达式，避免编译器超时
            let shareId = Int(share.id)
            let createDateTs = Int(share.createDate.timeIntervalSince1970) * 1000
            let userId = Int(share.userId)
            let dataText = share.data
            let lon = share.longitude
            let lat = share.latitude
            let addr = share.address
            let imgPath = share.imagePathsString ?? ""
            let titleText = share.title
            let agree = share.agreeCount
            let neutral = share.neutralCount
            let checkin = share.checkinCount
            let comment = share.commentCount

            return ResponsedShare(
                id: shareId,
                createDate: createDateTs,
                userId: userId,
                data: dataText,
                longitude: lon,
                latitude: lat,
                provinceCode: nil,
                cityCode: nil,
                districtCode: nil,
                address: addr,
                imagePath: imgPath,
                title: titleText,
                deleted: 0,
                agreeCount: agree,
                neutralCount: neutral,
                checkinCount: checkin,
                commentCount: comment,
                currentUserVoteType: nil,
                fadeScore: 0
            )
        }
    }
}

#Preview {
    ClusterShareListView(
        annotations: [],
        onDismiss: {}
    )
    .environment(\.appState, AppStateModel())
    .environmentObject(SearchViewModel())
    .environmentObject(NavigationCoordinator())
}
