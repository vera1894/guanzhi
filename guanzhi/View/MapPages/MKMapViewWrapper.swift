//
//  MKMapViewWrapper.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/3.
//
//  Stage 1: UIViewRepresentable 包装器
//  - 单向 region 绑定（SwiftUI → MKMapView）
//  - region 变化只记录，不回写触发 updateUIView
//  - 基础标注显示（暂不聚合）
//

import SwiftUI
import MapKit

struct MKMapViewWrapper: UIViewRepresentable {

    // MARK: - Bindings & Dependencies

    /// 地图区域（单向绑定：初始化时设置，之后由 delegate 更新 ViewModel）
    @Binding var region: MKCoordinateRegion

    /// 标注数据
    var annotations: [CustomAnnotation]

    /// 标注点击回调
    var onAnnotationTap: ((CustomAnnotation, UIImage?) -> Void)?

    /// 聚合点击回调（返回聚合内的所有 CustomAnnotation）
    var onClusterTap: (([CustomAnnotation]) -> Void)?

    /// region 变化回调（用于更新 ViewModel，不触发 updateUIView）
    var onRegionChange: ((MKCoordinateRegion) -> Void)?

    /// 是否显示用户位置
    var showsUserLocation: Bool = true

    /// 控制是否需要设置 region（用于防回环）
    @Binding var shouldSetRegion: Bool

    /// 是否应该定位到用户位置（点击定位按钮时设为 true）
    @Binding var shouldCenterOnUser: Bool

    /// 是否应该复位到正北（点击指南针按钮时设为 true）
    @Binding var shouldResetHeading: Bool

    /// 是否应该切换 3D 模式（点击 3D 按钮时设为 true）
    @Binding var shouldToggle3D: Bool

    /// 当前是否为 3D 模式（用于按钮状态显示）
    @Binding var is3DMode: Bool

    /// MKMapView 引用回调（用于创建 MKCompassButton）
    var onMapViewCreated: ((MKMapView) -> Void)?

    // MARK: - 默认区域（中国中心，确保地图永远有内容）
    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
        span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
    )

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        print("🗺️ [MKMapView] makeUIView called, region: \(region.center)")

        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = .standard

        // 启用交互
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true

        // 禁用默认指南针（我们在 SwiftUI overlay 中使用 MKCompassButton）
        mapView.showsCompass = false

        // ===== 单一初始化策略 =====
        // 1. 永远先设置一个有效的初始区域（优先用传入的，否则用默认）
        let initialRegion: MKCoordinateRegion
        let isValidRegion = region.center.latitude != 0 || region.center.longitude != 0
        if isValidRegion {
            initialRegion = region
            print("🗺️ [MKMapView] Using provided region: \(initialRegion.center)")
        } else {
            initialRegion = Self.defaultRegion
            print("🗺️ [MKMapView] Using default region: \(initialRegion.center)")
        }
        mapView.setRegion(initialRegion, animated: false)

        // 2. 不在这里设置 userTrackingMode，让 SearchView 的 onReceive 统一处理首次定位

        // 回调传出 mapView 引用（延迟到下一个 runloop，确保 mapView 已添加到视图层级）
        DispatchQueue.main.async {
            self.onMapViewCreated?(mapView)
        }

        // 注册标注视图
        mapView.register(
            CustomMKAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: CustomMKAnnotationView.reuseIdentifier
        )

        // Stage 2: 注册聚合视图
        mapView.register(
            ClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: ClusterAnnotationView.reuseIdentifier
        )

        // 添加初始标注
        mapView.addAnnotations(annotations)

        print("🗺️ [MKMapView] makeUIView completed")
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新 Coordinator 引用
        context.coordinator.parent = self

        // ===== 只在明确的触发信号下才操作 camera/region =====

        // 处理定位按钮：定位到用户位置
        if shouldCenterOnUser {
            print("🗺️ [MKMapView] shouldCenterOnUser triggered")
            context.coordinator.centerOnUser(mapView: mapView)
            DispatchQueue.main.async {
                self.shouldCenterOnUser = false
            }
            return
        }

        // 处理指南针按钮：复位到正北
        if shouldResetHeading {
            print("🗺️ [MKMapView] shouldResetHeading triggered")
            let camera = mapView.camera
            let newCamera = MKMapCamera(
                lookingAtCenter: camera.centerCoordinate,
                fromDistance: camera.centerCoordinateDistance,
                pitch: camera.pitch,
                heading: 0
            )
            context.coordinator.setCameraProgrammatically(newCamera, mapView: mapView, animated: true)
            DispatchQueue.main.async {
                self.shouldResetHeading = false
            }
            return
        }

        // 处理 3D 按钮：切换 2D/3D 视角
        if shouldToggle3D {
            print("🗺️ [MKMapView] shouldToggle3D triggered, current is3DMode: \(is3DMode)")
            let camera = mapView.camera
            let newPitch: CGFloat = is3DMode ? 0 : 45
            let newCamera = MKMapCamera(
                lookingAtCenter: camera.centerCoordinate,
                fromDistance: camera.centerCoordinateDistance,
                pitch: newPitch,
                heading: camera.heading
            )
            context.coordinator.setCameraProgrammatically(newCamera, mapView: mapView, animated: true)
            DispatchQueue.main.async {
                self.is3DMode = !self.is3DMode
                self.shouldToggle3D = false
            }
            return
        }

        // 处理搜索跳转等场景：仅在 shouldSetRegion 时设置
        if shouldSetRegion {
            let isValidRegion = region.center.latitude != 0 || region.center.longitude != 0
            if isValidRegion {
                print("🗺️ [MKMapView] shouldSetRegion triggered, setting region: \(region.center)")
                context.coordinator.setRegionProgrammatically(region, mapView: mapView, animated: true)
            }
            DispatchQueue.main.async {
                self.shouldSetRegion = false
            }
            return
        }

        // 更新标注（diff 算法，避免全量刷新）
        updateAnnotations(mapView: mapView)
    }

    func makeCoordinator() -> MKMapViewCoordinator {
        MKMapViewCoordinator(parent: self)
    }

    // MARK: - Private Methods

    /// 使用 diff 算法更新标注，避免全量删除/添加
    /// 关键：只有在真正有变化时才执行 remove/add，避免打断聚合状态
    private func updateAnnotations(mapView: MKMapView) {
        // 获取当前地图上的自定义标注（不包括聚合标注和用户位置）
        let currentAnnotations = Set(mapView.annotations.compactMap { $0 as? CustomAnnotation })
        let newAnnotations = Set(annotations)

        let toRemove = currentAnnotations.subtracting(newAnnotations)
        let toAdd = newAnnotations.subtracting(currentAnnotations)

        // 只有在真的有变化时才执行操作
        let hasChanges = !toRemove.isEmpty || !toAdd.isEmpty

        #if DEBUG
        if hasChanges {
            print("📍 [Annotations] 更新: 移除 \(toRemove.count), 添加 \(toAdd.count), 当前 \(currentAnnotations.count) -> 新 \(newAnnotations.count)")
        }
        #endif

        if !toRemove.isEmpty {
            mapView.removeAnnotations(Array(toRemove))
        }
        if !toAdd.isEmpty {
            mapView.addAnnotations(Array(toAdd))
        }
    }
}

// MARK: - Preview

#Preview {
    MKMapViewWrapper(
        region: .constant(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )),
        annotations: [],
        shouldSetRegion: .constant(false),
        shouldCenterOnUser: .constant(false),
        shouldResetHeading: .constant(false),
        shouldToggle3D: .constant(false),
        is3DMode: .constant(false)
    )
}

// MARK: - MKCompassButton SwiftUI Wrapper

/// SwiftUI 包装器，用于在 overlay 中显示 MKCompassButton
/// 使用圆形纯色背景（浅色模式白色，深色模式深色）
struct MKCompassButtonWrapper: UIViewRepresentable {
    /// 关联的 MKMapView（用于创建指南针按钮）
    var mapView: MKMapView?

    /// 按钮尺寸
    var size: CGFloat = 36

    func makeUIView(context: Context) -> UIView {
        // 使用圆形纯色背景（自动适应深色/浅色模式）
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = size / 2
        container.clipsToBounds = true
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新圆角和背景色（以防 size 变化或主题切换）
        uiView.layer.cornerRadius = size / 2
        uiView.backgroundColor = .systemBackground

        // 移除旧的子视图
        uiView.subviews.forEach { $0.removeFromSuperview() }

        guard let mapView = mapView else { return }

        // 创建 MKCompassButton
        let compassButton = MKCompassButton(mapView: mapView)
        compassButton.compassVisibility = .visible
        compassButton.translatesAutoresizingMaskIntoConstraints = false

        uiView.addSubview(compassButton)

        NSLayoutConstraint.activate([
            compassButton.centerXAnchor.constraint(equalTo: uiView.centerXAnchor),
            compassButton.centerYAnchor.constraint(equalTo: uiView.centerYAnchor),
            compassButton.widthAnchor.constraint(equalToConstant: size),
            compassButton.heightAnchor.constraint(equalToConstant: size)
        ])
    }
}

// MARK: - MKUserTrackingButton SwiftUI Wrapper

/// SwiftUI 包装器，用于在 overlay 中显示 MKUserTrackingButton（官方定位按钮）
/// 使用圆形纯色背景（浅色模式白色，深色模式深色），与 MKCompassButton 样式统一
struct MKUserTrackingButtonWrapper: UIViewRepresentable {
    /// 关联的 MKMapView
    var mapView: MKMapView?

    /// 按钮尺寸
    var size: CGFloat = 36

    func makeUIView(context: Context) -> UIView {
        // 使用圆形纯色背景（自动适应深色/浅色模式）
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = size / 2
        container.clipsToBounds = true
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新圆角和背景色（以防 size 变化或主题切换）
        uiView.layer.cornerRadius = size / 2
        uiView.backgroundColor = .systemBackground

        // 移除旧的子视图
        uiView.subviews.forEach { $0.removeFromSuperview() }

        guard let mapView = mapView else { return }

        // 创建 MKUserTrackingButton
        let trackingButton = MKUserTrackingButton(mapView: mapView)
        trackingButton.translatesAutoresizingMaskIntoConstraints = false
        // 隐藏按钮自带的背景，只显示图标
        trackingButton.backgroundColor = .clear
        trackingButton.tintColor = .label  // 使用自适应颜色（浅色模式黑色，深色模式白色）

        uiView.addSubview(trackingButton)

        NSLayoutConstraint.activate([
            trackingButton.centerXAnchor.constraint(equalTo: uiView.centerXAnchor),
            trackingButton.centerYAnchor.constraint(equalTo: uiView.centerYAnchor),
            trackingButton.widthAnchor.constraint(equalToConstant: size),
            trackingButton.heightAnchor.constraint(equalToConstant: size)
        ])
    }
}
