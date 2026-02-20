//
//  MKMapViewCoordinator.swift
//  guanzhi
//
//  Created by Claude Code on 2026/1/3.
//
//  Stage 1: MKMapViewDelegate 实现
//  - region 变化只记录到 ViewModel，不触发 updateUIView 回设 region
//  - 标注视图创建（暂不聚合）
//  - 标注点击处理
//

import MapKit
import UIKit

class MKMapViewCoordinator: NSObject, MKMapViewDelegate {

    // MARK: - Properties

    var parent: MKMapViewWrapper

    /// 防回环标志：当程序主动设置 region/camera 时为 true，避免 delegate 回调触发循环
    private var isProgrammaticChange = false

    /// 延迟定位标志：当 centerOnUser 被调用但用户位置尚未可用时为 true
    /// 位置更新后会自动执行定位并重置此标志
    private var isPendingCenterOnUser = false

    /// 跟踪当前是否处于 Flyover 地球仪配置（globeMode 动态切换用）
    var isInGlobeConfiguration = false

    init(parent: MKMapViewWrapper) {
        self.parent = parent
    }

    // MARK: - Programmatic Camera/Region Control (防回环)

    /// 程序化设置 region（带防回环）
    func setRegionProgrammatically(_ region: MKCoordinateRegion, mapView: MKMapView, animated: Bool) {
        print("🗺️ [Coordinator] setRegionProgrammatically: \(region.center)")
        isProgrammaticChange = true
        mapView.setRegion(region, animated: animated)
        // 延迟重置标志，确保 regionDidChange 回调时标志仍为 true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProgrammaticChange = false
        }
    }

    /// 程序化设置 camera（带防回环）
    func setCameraProgrammatically(_ camera: MKMapCamera, mapView: MKMapView, animated: Bool) {
        print("🗺️ [Coordinator] setCameraProgrammatically")
        isProgrammaticChange = true
        mapView.setCamera(camera, animated: animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProgrammaticChange = false
        }
    }

    /// 定位到用户位置
    func centerOnUser(mapView: MKMapView) {
        print("🗺️ [Coordinator] centerOnUser called")
        if let userLocation = mapView.userLocation.location {
            let currentCamera = mapView.camera
            let newCamera = MKMapCamera(
                lookingAtCenter: userLocation.coordinate,
                fromDistance: min(currentCamera.centerCoordinateDistance, 5000), // 限制最大距离 5km
                pitch: currentCamera.pitch,
                heading: currentCamera.heading
            )
            // 确保关闭跟踪模式，避免地图被锁定
            if mapView.userTrackingMode != .none {
                mapView.userTrackingMode = .none
            }
            isPendingCenterOnUser = false
            setCameraProgrammatically(newCamera, mapView: mapView, animated: true)
            print("🗺️ [Coordinator] Centered on user: \(userLocation.coordinate)")

            // 延迟触发 region 更新回调，确保地图动画完成后标注能正确显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                self.parent.onRegionChange?(mapView.region)
                print("🗺️ [Coordinator] Manually triggered onRegionChange after centerOnUser")
            }
        } else {
            print("🗺️ [Coordinator] User location not available yet, will center when location updates")
            // 设置延迟定位标志，等待 didUpdate userLocation 回调时执行定位
            isPendingCenterOnUser = true
        }
    }

    // MARK: - MKMapViewDelegate

    /// region 变化完成时调用
    /// ⚠️ 关键：只有在非程序化变化时才更新 ViewModel
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Globe 模式配置检查：无论程序化还是用户操作都要执行
        // 这样程序化定位（如 centerOnUser）后也能正确切回 Standard
        updateGlobeConfigurationIfNeeded(mapView: mapView)

        // 如果是程序主动触发的变化，不回调 ViewModel（防止回环）
        guard !isProgrammaticChange else {
            print("🗺️ [Coordinator] regionDidChange ignored (programmatic)")
            return
        }

        print("🗺️ [Coordinator] regionDidChange (user interaction): \(mapView.region.center)")
        // 通过回调更新 ViewModel，而不是直接修改 @Binding
        parent.onRegionChange?(mapView.region)
    }

    // MARK: - Globe Mode

    /// 根据 camera distance 动态切换 Standard ↔ HybridFlyover
    /// 使用磁滞区间避免边界附近频繁切换：进入地球仪 5M，退出地球仪 3.5M
    private func updateGlobeConfigurationIfNeeded(mapView: MKMapView) {
        let distance = mapView.camera.centerCoordinateDistance
        let enterThreshold: Double = 5_000_000   // 进入地球仪：5000 公里
        let exitThreshold: Double = 3_500_000    // 退出地球仪：3500 公里（磁滞）

        if distance >= enterThreshold && !isInGlobeConfiguration {
            mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
            isInGlobeConfiguration = true
            print("🌍 [Globe] 切换到 HybridFlyover，distance=\(Int(distance))")
        } else if distance < exitThreshold && isInGlobeConfiguration {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
            isInGlobeConfiguration = false
            print("🗺️ [Globe] 切回 Standard，distance=\(Int(distance))")
        }
    }

    /// 返回标注视图
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // 用户位置标注使用系统默认视图
        if annotation is MKUserLocation {
            return nil
        }

        // Stage 2: 聚合标注
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            #if DEBUG
            print("🔷 [Cluster] 创建聚合视图, 成员数: \(clusterAnnotation.memberAnnotations.count)")
            #endif

            let clusterView = mapView.dequeueReusableAnnotationView(
                withIdentifier: ClusterAnnotationView.reuseIdentifier,
                for: annotation
            ) as? ClusterAnnotationView

            clusterView?.configure(with: clusterAnnotation)
            return clusterView
        }

        // 自定义标注
        guard let customAnnotation = annotation as? CustomAnnotation else {
            #if DEBUG
            print("⚠️ [viewFor] 未知标注类型: \(type(of: annotation))")
            #endif
            return nil
        }

        let annotationView = mapView.dequeueReusableAnnotationView(
            withIdentifier: CustomMKAnnotationView.reuseIdentifier,
            for: annotation
        ) as? CustomMKAnnotationView

        annotationView?.configure(with: customAnnotation)

        // 设置点击回调（绕过 MKMapView 的 didSelect 机制）
        // 由于 frame 被缩小用于聚合抵抗，didSelect 在点击边缘时不会触发
        // 所以通过 touchesEnded 直接触发回调，实现点击区域与碰撞盒的真正解耦
        annotationView?.onTap = { [weak self] annotation, thumbnailImage in
            self?.parent.onAnnotationTap?(annotation, thumbnailImage)
        }

        #if DEBUG
        // 验证 clusteringIdentifier 是否正确设置
        if annotationView?.clusteringIdentifier != "share" {
            print("⚠️ [viewFor] clusteringIdentifier 未设置!")
        }
        #endif

        return annotationView
    }

    /// 标注被选中时调用
    /// 注意：单个标注的点击已改为通过 touchesEnded 触发（见 CustomMKAnnotationView.onTap）
    /// 这里只处理聚合标注的点击，以实现点击区域与碰撞盒的解耦
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {

        // 用户位置标注：禁用点击，不弹出默认的空白标注
        if annotation is MKUserLocation {
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }

        // 聚合标注点击：仍通过 didSelect 处理（ClusterAnnotationView 的 frame 是完整尺寸）
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            let members = clusterAnnotation.memberAnnotations.compactMap { $0 as? CustomAnnotation }
            parent.onClusterTap?(members)
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }

        // 单个标注：不在这里处理，由 CustomMKAnnotationView.touchesEnded 触发 onTap 回调
        // 这样点击区域由 point(inside:) 决定（完整视觉区域），而不是 frame（缩小的碰撞盒）
        if annotation is CustomAnnotation {
            // 只取消选中状态，不触发回调（回调已由 touchesEnded 触发）
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }
    }

    /// 标注视图添加到地图时调用（可用于动画）
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        // 可选：添加入场动画
        for view in views {
            if view.annotation is CustomAnnotation {
                view.alpha = 0
                UIView.animate(withDuration: 0.3) {
                    view.alpha = 1
                }
            }
        }
    }

    /// 用户位置更新时调用
    /// 用于处理延迟定位：当 centerOnUser 被调用时位置尚未可用，在这里补偿执行
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        // 如果有待处理的定位请求，执行定位
        guard isPendingCenterOnUser else { return }

        guard let location = userLocation.location else { return }

        print("🗺️ [Coordinator] didUpdate userLocation, executing pending centerOnUser")

        let currentCamera = mapView.camera
        let newCamera = MKMapCamera(
            lookingAtCenter: location.coordinate,
            fromDistance: min(currentCamera.centerCoordinateDistance, 5000),
            pitch: currentCamera.pitch,
            heading: currentCamera.heading
        )

        // 确保关闭跟踪模式
        if mapView.userTrackingMode != .none {
            mapView.userTrackingMode = .none
        }

        isPendingCenterOnUser = false
        setCameraProgrammatically(newCamera, mapView: mapView, animated: true)
        print("🗺️ [Coordinator] Pending centerOnUser completed: \(location.coordinate)")

        // 延迟触发 region 更新回调，确保地图动画完成后标注能正确显示
        // 因为 setCameraProgrammatically 设置了 isProgrammaticChange = true，
        // regionDidChangeAnimated 不会触发 onRegionChange，需要手动触发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            self.parent.onRegionChange?(mapView.region)
            print("🗺️ [Coordinator] Manually triggered onRegionChange after pending centerOnUser")
        }
    }
}
