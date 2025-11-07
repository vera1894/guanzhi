//
//  ZoomSliderView.swift
//  guanzhi
//
//  Created by 晨光 訾 on 2025/2/7.
//


import SwiftUI
import MapKit

struct ZoomSliderView: View {
    @Binding var position: MapCameraPosition
    @EnvironmentObject var searchViewModel: SearchViewModel
    
    // 0.0 对应最大放大（街区），1.0 对应最小放大（全球）
    @State private var zoomLevel: Double = 0.5
    
    // 你希望的最小/最大缩放范围（映射到全地球 ~ 超级放大）
    private let minDelta: CLLocationDegrees = 0.0001   // 街区级（值=0）
    private let maxDelta: CLLocationDegrees = 160.0   // 全球（值=1）
    
    // 标记：是否滑杆在更新地图（true），否则是地图在更新滑杆（false）
    @State private var isUpdatingFromSlider = false
    
    // 当地图在被用户手势操作(或自动定位)更新时，禁用滑杆交互
    @State private var sliderDisabled = false
    
    var body: some View {
        VStack {
            // 自定义竖直滑杆
            VerticalCustomSlider(
                value: $zoomLevel,
                trackWidth: 6,
                trackColor: Color.gray.opacity(0.4),
                fillColor: Color("color-primary"),
                thumbSize: 24,
                isDisabled: sliderDisabled
            )
            .frame(height: 180)
            .frame(maxWidth: 16)
            
            // 当滑杆数值变化 => 更新地图 (仅当 sliderDisabled==false 才会触发手势)
            .onChange(of: zoomLevel) { newVal, _ in
                guard !sliderDisabled else { return }
                isUpdatingFromSlider = true
                updateMapZoom(newVal)
                // 地图更新完后，下一帧再还原 isUpdatingFromSlider
                DispatchQueue.main.async {
                    isUpdatingFromSlider = false
                }
            }
            
            // 当地图region变化 => 更新滑杆位置，但不在“滑杆主动更新”期间
            .onChange(of: searchViewModel.region) { newRegion , _ in
                // 如果是滑杆触发的地图更新，就不改滑杆位置
                guard !isUpdatingFromSlider else { return }
                
                // 说明是用户双指缩放/移动地图 或 .automatic 定位 => 禁用滑杆交互
                sliderDisabled = true
                
                let newSliderVal = regionToSliderValue(newRegion)
                let diff = abs(newSliderVal - zoomLevel)
                
                if diff > 0.00001 {
                    // 用 spring 动画让滑块位置跟随地图
                    withAnimation(.spring) {
                        zoomLevel = newSliderVal
                    }
                }
                
                // 这里可以选择：在地图稳定后再恢复可交互
                // 简单做法：稍后再启用滑杆
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sliderDisabled = false
                }
            }
            
            // 首次显示时，根据 searchViewModel.region 设置滑杆
            .onAppear {
                zoomLevel = regionToSliderValue(searchViewModel.region)
            }
        }
        .background(Color.red.opacity(0.2))  // 仅示意背景
    }
    
    // MARK: - 当滑杆改变时
    private func updateMapZoom(_ sliderValue: Double) {
        let oldRegion = searchViewModel.region
        let center = oldRegion.center
        
        let newDelta = sliderValueToDelta(sliderValue)
        let newRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: newDelta, longitudeDelta: newDelta)
        )
        
        // 更新地图
        position = .region(newRegion)
        searchViewModel.region = newRegion
    }
    
    /// 非线性：region => sliderValue
    private func regionToSliderValue(_ region: MKCoordinateRegion) -> Double {
        let latDelta = region.span.latitudeDelta
        // clamp latDelta 到 [minDelta, maxDelta]，避免 log 溢出
        let clampedDelta = max(min(latDelta, maxDelta), minDelta)
        
        // log-scale: ratio = [ln(latDelta) - ln(minDelta)] / [ln(maxDelta)-ln(minDelta)]
        let logMin = log(minDelta)
        let logMax = log(maxDelta)
        let logCurrent = log(clampedDelta)
        let ratio = (logCurrent - logMin) / (logMax - logMin)
        
        // 再 clamp 到 [0,1] 以防浮点误差
        return max(min(ratio, 1), 0)
    }

    /// 非线性：sliderValue => latDelta
    private func sliderValueToDelta(_ value: Double) -> CLLocationDegrees {
        // value in [0..1], latDelta in [minDelta..maxDelta], log-scale
        let logMin = log(minDelta)
        let logMax = log(maxDelta)
        
        let logDelta = logMin + (logMax - logMin)*value
        let latDelta = exp(logDelta)
        
        // clamp 到 [minDelta, maxDelta]
        return max(min(latDelta, maxDelta), minDelta)
    }
}

// ------------------------------
// 自定义滑杆
// ------------------------------
struct VerticalCustomSlider: View {
    /// 进度 0...1，0 在底端，1 在顶端
    @Binding var value: Double
    
    let trackWidth: CGFloat
    let trackColor: Color
    let fillColor: Color
    let thumbSize: CGFloat
    
    // 是否禁用手势
    let isDisabled: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                
                // 背景轨道
                RoundedRectangle(cornerRadius: trackWidth / 2)
                    .fill(trackColor)
                    .frame(width: trackWidth, height: geo.size.height)
                
                // 填充
                RoundedRectangle(cornerRadius: trackWidth / 2)
                    .fill(fillColor)
                    .frame(width: trackWidth,
                           height: geo.size.height * CGFloat(value))
                
                // 滑块 (自定义按钮替代Circle)
                ButtonView_s()
                    // 微调offset让视觉对齐
                    .offset(y: 22)
                    .offset(y: -geo.size.height * CGFloat(value) - (thumbSize / 2))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // 手势：仅在未禁用时生效
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard !isDisabled else { return }
                        let localY = drag.location.y
                        // y=0 => value=1, y=max => value=0
                        let ratio = 1 - (localY / geo.size.height)
                        let newVal = min(max(ratio, 0), 1)
                        value = newVal
                    }
            )
        }
    }
}

#Preview {
    ZoomSliderView(
        position: .constant(
            .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        )
    )
    .environmentObject(SearchViewModel())
}

