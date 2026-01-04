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
            setCameraProgrammatically(newCamera, mapView: mapView, animated: true)
            print("🗺️ [Coordinator] Centered on user: \(userLocation.coordinate)")
        } else {
            print("🗺️ [Coordinator] User location not available yet")
            // 用户位置还不可用，启用跟踪模式等待
            mapView.userTrackingMode = .follow
        }
    }

    // MARK: - MKMapViewDelegate

    /// region 变化完成时调用
    /// ⚠️ 关键：只有在非程序化变化时才更新 ViewModel
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // 如果是程序主动触发的变化，不回调（防止回环）
        guard !isProgrammaticChange else {
            print("🗺️ [Coordinator] regionDidChange ignored (programmatic)")
            return
        }
        print("🗺️ [Coordinator] regionDidChange (user interaction): \(mapView.region.center)")
        // 通过回调更新 ViewModel，而不是直接修改 @Binding
        parent.onRegionChange?(mapView.region)
    }

    /// 返回标注视图
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // 用户位置标注使用系统默认视图
        if annotation is MKUserLocation {
            return nil
        }

        // 自定义标注
        guard let customAnnotation = annotation as? CustomAnnotation else {
            return nil
        }

        let annotationView = mapView.dequeueReusableAnnotationView(
            withIdentifier: CustomMKAnnotationView.reuseIdentifier,
            for: annotation
        ) as? CustomMKAnnotationView

        annotationView?.configure(with: customAnnotation)

        // Stage 1: 暂不设置 clusteringIdentifier（Stage 2 再添加）
        // annotationView?.clusteringIdentifier = "share"

        return annotationView
    }

    /// 标注被选中时调用
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        guard let customAnnotation = annotation as? CustomAnnotation else {
            return
        }

        // 获取标注视图以获取缩略图
        let annotationView = mapView.view(for: annotation) as? CustomMKAnnotationView
        let thumbnailImage = annotationView?.thumbnailImage

        // 调用点击回调
        parent.onAnnotationTap?(customAnnotation, thumbnailImage)

        // 取消选中状态，允许再次点击
        mapView.deselectAnnotation(annotation, animated: false)
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
}
