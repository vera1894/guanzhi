//
//  ShareListView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/31.
//

import SwiftUI

struct ShareListView: View {
    @State private var selectedTab = 0
    @StateObject var timelineVM = UserTimelineViewModel()
    @Environment(\.appState) var appState
    @EnvironmentObject var searchViewModel: SearchViewModel
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator

    let userId: Int
    let lat: Double
    let lon: Double
    let radius: Double
        
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top,spacing: Constants.iconSizeS) {
                TabButton(title: "全部观之", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(title: "已褪色", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                Spacer()
            }
            .padding()
            Divider()
            if selectedTab == 0 {
                // 根据加载状态显示不同内容
                switch timelineVM.loadingState {
                case .idle, .loading:
                    VStack {
                        Spacer()
                        ProgressView("加载中...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                case .error:
                    RetryView(
                        message: "加载失败",
                        detail: "请检查网络连接",
                        onRetry: {
                            timelineVM.retry()
                        }
                    )
                    .frame(maxWidth: .infinity)

                case .loaded:
                    if timelineVM.userShares.filter({ $0.deleted == 0 }).isEmpty {
                        VStack {
                            Spacer()
                            Text("暂无分享")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List {
                            ForEach(timelineVM.userShares.filter { $0.deleted == 0 }, id: \.id) { shareItem in
                                ShareSingleView(share: shareItem)
                                    .listRowInsets(EdgeInsets())
                                    .environment(\.appState, appState)
                                    .environmentObject(searchViewModel)
                                    .environmentObject(navigationCoordinator)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            } else {
                // 已褪色 tab：显示褪色度达到100的分享
                switch timelineVM.loadingState {
                case .idle, .loading:
                    VStack {
                        Spacer()
                        ProgressView("加载中...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                case .error:
                    RetryView(
                        message: "加载失败",
                        detail: "请检查网络连接",
                        onRetry: {
                            timelineVM.retry()
                        }
                    )
                    .frame(maxWidth: .infinity)

                case .loaded:
                    let fadedShares = timelineVM.userShares.filter { $0.deleted == 0 && ($0.fadeScore ?? 0) >= 100 }
                    if fadedShares.isEmpty {
                        VStack {
                            Spacer()
                            Text("暂无已褪色的观之")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List {
                            ForEach(fadedShares, id: \.id) { shareItem in
                                ShareSingleView(share: shareItem)
                                    .listRowInsets(EdgeInsets())
                                    .environment(\.appState, appState)
                                    .environmentObject(searchViewModel)
                                    .environmentObject(navigationCoordinator)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }


        }
        .task {
            do {
                // 这里假设 lat/lon 你可以自行决定传什么
                // 目前 radius=10
                try await timelineVM.fetchUserShareList(
                    userId: userId,
                    lat: lat,
                    lon: lon,
                    radius: radius
                )
            } catch {
                print("加载用户分享列表出错：\(error)")
            }
        }
        
    }
    
    private func formattedDate(_ timeInterval: Int) -> String {
            // 这里假设 createDate = 秒级或毫秒级 => 需要看实际
            // 你可能要 /1000.0
            let date = Date(timeIntervalSince1970: TimeInterval(timeInterval / 1000))
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: date)
        }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.custom("PingFang SC", size: 14))
                .kerning(0.22)
                .foregroundColor(isSelected ? Color("text-black") : Color("text-gray"))
        }
    }
}

#Preview {
    ShareListView(userId: 11, lat: 39.976165771484375, lon: 116.34468640857655, radius: 10)
}
