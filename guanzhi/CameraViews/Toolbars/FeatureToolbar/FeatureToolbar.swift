/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view that presents controls to enable capture features.
*/

import SwiftUI

/// A view that presents controls to enable capture features. 一个视图，显示用于启用捕获功能的控件。
struct FeaturesToolbar<CameraModel: Camera>: PlatformView {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    
    var body: some View {
        // 将相机的 photoFeatures 绑定到本地变量 features
        @Bindable var features = camera.photoFeatures
        
        HStack {
            Spacer()
            VStack(spacing: 16) {
                switch camera.captureMode {
                case .photo:
                    // 如果相机处于照片捕获模式，根据设备大小调整控件布局
                    if isCompactSize {
                        Spacer()
                        livePhotoButton // 显示 Live Photo 按钮
                        SwitchCameraButtonSmall(camera: camera)
    //                    prioritizePicker // 显示优先级选择器
                    } else {
                        Spacer()
                        livePhotoButton
                        prioritizePicker
                    }
                    
                case .video:
                    // 如果相机处于视频捕获模式，根据是否支持 HDR 视频来显示 HDR 按钮
                    Spacer()
                    if camera.isHDRVideoSupported {
                        hdrButton
                    }
                }
            }
            .buttonStyle(DefaultButtonStyle(size: isRegularSize ? .large : .small))
            .padding([.leading, .trailing])
            .padding(.bottom, 32)
        }
        
    }
    
    //  A button to toggle the enabled state of Live Photo capture. 用于切换 Live Photo 捕获功能的按钮
    var livePhotoButton: some View {
        Button {
            camera.photoFeatures.isLivePhotoEnabled.toggle()
        } label: {
            VStack {
                Image(systemName: "livephoto")
                    .foregroundColor(camera.photoFeatures.isLivePhotoEnabled ? .accentColor : .primary) // 根据是否启用 Live Photo 更改图标颜色
            }
        }
        .frame(width: smallButtonSize.width, height: smallButtonSize.height)
    }
    

    
    
    // 用于选择照片质量优先级的选择器
    @ViewBuilder
    var prioritizePicker: some View {
        @Bindable var features = camera.photoFeatures
        Picker("Quality Prioritization", selection: $features.qualityPrioritization) {
            ForEach(QualityPrioritization.allCases) {
                Text($0.description)
                    .font(.body.weight(.bold))
            }
        }
        .frame(width: 120)
        .pickerStyle(.menu)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }

    // 用于切换 HDR 视频功能的按钮
    @ViewBuilder
    var hdrButton: some View {
        if isCompactSize {
            hdrToggleButton
        } else {
            hdrToggleButton
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
    
    // HDR 切换按钮
    var hdrToggleButton: some View {
        Button {
            camera.isHDRVideoEnabled.toggle()
        } label: {
            Text("HDR \(camera.isHDRVideoEnabled ? "On" : "Off")")
                .font(.body.weight(.semibold))
                .foregroundStyle(camera.isHDRVideoEnabled ? Color("color-primary") : .secondary)
        }
        .disabled(camera.captureActivity.isRecording) // 如果相机正在录制，则禁用按钮
    }
    
    // 用于在紧凑尺寸设备上添加间距的视图
    @ViewBuilder
    var compactSpacer: some View {
        if !isRegularSize {
            Spacer()
        }
    }
}
