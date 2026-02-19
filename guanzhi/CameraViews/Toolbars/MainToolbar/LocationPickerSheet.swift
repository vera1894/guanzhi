//
//  LocationPickerSheet.swift
//  guanzhi
//
//  Created by Claude Code on 2026/2/19.
//

import SwiftUI
import MapKit

struct LocationPickerSheet: View {
    var service: LocationPickerService
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedId: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 当前位置
                Section {
                    Button {
                        selectedId = "current"
                        service.selectCurrentLocation()
                        onDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("当前位置")
                                    .font(.headline)
                                Text(service.currentAddress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if selectedId == "current" || selectedId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text("当前位置")
                }

                // MARK: - 附近地点（搜索框为空时显示）
                if searchText.isEmpty {
                    Section {
                        if service.isLoadingNearby {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if service.nearbyPOIs.isEmpty {
                            Text("未找到附近地点")
                                .foregroundColor(.secondary)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(service.nearbyPOIs) { poi in
                                Button {
                                    selectedId = poi.id
                                    service.selectPOI(poi)
                                    onDismiss()
                                } label: {
                                    poiRow(poi)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    } header: {
                        Text("附近地点")
                    }
                }

                // MARK: - 搜索结果（搜索框有内容时显示）
                if !searchText.isEmpty {
                    Section {
                        if service.isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if service.searchResults.isEmpty {
                            Text("未找到结果")
                                .foregroundColor(.secondary)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(service.searchResults) { poi in
                                Button {
                                    selectedId = poi.id
                                    service.selectPOI(poi)
                                    onDismiss()
                                } label: {
                                    poiRow(poi)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    } header: {
                        Text("搜索结果")
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "搜索地点")
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            service.loadNearbyPOIs()
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            if newValue.isEmpty {
                service.searchResults = []
                return
            }
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await service.search(query: newValue)
            }
        }
    }

    // MARK: - POI 行视图（含距离）
    @ViewBuilder
    private func poiRow(_ poi: POIItem) -> some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(poi.name)
                    .font(.body)
                if !poi.subtitle.isEmpty {
                    Text(poi.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let distance = poi.distance {
                Text(service.formatDistance(distance))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if selectedId == poi.id {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
    }
}
