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
                //Spacer()
                TabButton(title: "我分享的", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
               // Spacer()
                TabButton(title: "我的消息", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                Spacer()
            }
            .padding()
            Divider()
            if selectedTab == 0 {
                List {
                    ForEach(timelineVM.userShares.filter { $0.deleted == 0 }, id: \.id) { shareItem in
                        ShareSingleView(share: shareItem)
                            .listRowInsets(EdgeInsets())
                            .environment(\.appState, appState)
                            .environmentObject(searchViewModel)                  //
                            .environmentObject(navigationCoordinator)
                    }
                }
                
                .listStyle(PlainListStyle())
                  
            } else {
                List {
//                    ShareSingleView().listRowInsets(EdgeInsets())
//                    ShareSingleView().listRowInsets(EdgeInsets())
//                    ShareSingleView().listRowInsets(EdgeInsets())
                          
                        }.listStyle(PlainListStyle())
                   
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
