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

// MARK: - 入场动画可调参数

/// 地图入场动画配置（所有参数集中管理，方便调整效果）
enum EntryAnimationConfig {
    // ── 起点设置 ──
    static let globeAltitude: Double = 35_000_000    // 地球仪视角高度（米），足够看到完整地球旋转
    static let startLatitude: Double = 0              // 起始纬度（0 = 赤道）
    static let longitudeOffset: Double = -60           // 经度偏移（相对用户位置，-60 = 稍偏西侧）
    static let startPitch: CGFloat = 0                // 起始俯仰角
    static let startHeading: Double = 0               // 起始方位角

    // ── 启动遮罩 ──
    static let splashFadeDuration: Double = 0.5       // 遮罩淡出时长（秒）
    static let maxWaitForTiles: Double = 3.0          // 等待瓦片加载的最大时间（秒），超时则强制开始

    // ── 动画（单一连续动画，旋转 + 下降融为一体）──
    static let initialDelay: Double = 0.3             // 起点停留时间（秒），让用户看到地球仪
    static let totalDuration: Double = 2.8            // 总动画时长（秒）
    static let altitudeEasingPower: Double = 3.0      // 高度下降缓动指数（越大 = 前期在高空旋转越久，后期俯冲越快）
    static let finalAltitude: Double = 5000           // 最终高度（米）
    static let finalPitch: CGFloat = 0                // 最终俯仰角
    static let finalHeading: Double = 0               // 最终方位角

    // ── 动画期间标注刷新 ──
    static let annotationRefreshInterval: Double = 0.5 // 动画期间触发标注刷新的间隔（秒）
}

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

    /// 入场动画标志：每次 Coordinator 创建时为 true，首次定位时播放入场动画
    private var shouldPlayEntryAnimation = true

    /// 入场动画进行中标志：防止动画期间被其他操作打断
    private var isEntryAnimating = false

    /// 瓦片加载完成标志（mapViewDidFinishLoadingMap 触发）
    private var isMapTilesReady = false

    /// 延迟入场动画：瓦片未加载完时暂存目标坐标
    private var pendingEntryDestination: CLLocationCoordinate2D?

    // CADisplayLink 动画引擎状态
    private var animDisplayLink: CADisplayLink?
    private var animStartTime: CFTimeInterval = 0
    private var animDuration: Double = 0
    private var animFrom: MKMapCamera?
    private var animTo: MKMapCamera?
    private var animCompletion: ((Bool) -> Void)?
    private weak var animMapView: MKMapView?
    private var animAltitudeEasingPower: Double = 1.0  // 高度独立缓动指数（1.0 = 与位置同步）
    private var lastContinuousRegionUpdateTime: CFTimeInterval = 0  // mapViewDidChangeVisibleRegion 节流

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

        // 入场动画优先：拦截首次 centerOnUser，由入场动画代替定位
        if shouldPlayEntryAnimation {
            print("🗺️ [Coordinator] centerOnUser deferred to entry animation")
            if let userLocation = mapView.userLocation.location {
                playEntryAnimation(mapView: mapView, destination: userLocation.coordinate)
            } else {
                // 位置还没拿到，设 pending 标志，等 didUpdate 时触发
                isPendingCenterOnUser = true
            }
            return
        }

        // 入场动画进行中，忽略 centerOnUser
        if isEntryAnimating {
            print("🗺️ [Coordinator] centerOnUser ignored (entry animation in progress)")
            return
        }

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

    /// region 变化完成时调用（手势结束 / 动画结束时触发一次）
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
        // 最终确认性更新：确保手势结束后标注状态与最终区域一致
        parent.onRegionChange?(mapView.region)
    }

    /// region 持续变化时调用（手势进行中 / 动画进行中持续触发）
    /// 用于操作过程中实时刷新标注（本地数据，无网络请求）
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        // 节流：限制调用频率，避免每帧都触发 SwiftUI 更新
        let now = CACurrentMediaTime()
        guard now - lastContinuousRegionUpdateTime >= EntryAnimationConfig.annotationRefreshInterval else { return }
        lastContinuousRegionUpdateTime = now

        // Globe 模式动态切换（缩放过程中也能切换，不用等手势结束）
        updateGlobeConfigurationIfNeeded(mapView: mapView)

        // 更新 region + 触发本地标注刷新
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

    /// 地图瓦片加载完成时调用
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        guard !isMapTilesReady else { return }
        isMapTilesReady = true
        print("🌍 [EntryAnim] 瓦片加载完成")

        // 如果入场动画在等待瓦片，现在启动
        if let destination = pendingEntryDestination {
            pendingEntryDestination = nil
            startEntryAnimation(mapView: mapView, destination: destination)
        }
    }

    /// 用户位置更新时调用
    /// 用于处理延迟定位：当 centerOnUser 被调用时位置尚未可用，在这里补偿执行
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        // 如果有待处理的定位请求，执行定位
        guard isPendingCenterOnUser else { return }

        guard let location = userLocation.location else { return }

        // 入场动画优先：位置到达后播放入场动画
        if shouldPlayEntryAnimation {
            print("🌍 [EntryAnim] didUpdate userLocation, starting entry animation")
            isPendingCenterOnUser = false
            playEntryAnimation(mapView: mapView, destination: location.coordinate)
            return
        }

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

    // MARK: - Entry Animation

    /// 入场动画入口：检查瓦片就绪状态，决定立即启动还是等待
    private func playEntryAnimation(mapView: MKMapView, destination: CLLocationCoordinate2D) {
        shouldPlayEntryAnimation = false

        if isMapTilesReady {
            // 瓦片已就绪，立即启动
            startEntryAnimation(mapView: mapView, destination: destination)
        } else {
            // 瓦片未就绪，暂存目标，等 mapViewDidFinishLoadingMap 触发
            pendingEntryDestination = destination
            print("🌍 [EntryAnim] 等待瓦片加载...")

            // 超时保护：最多等 maxWaitForTiles 秒
            DispatchQueue.main.asyncAfter(deadline: .now() + EntryAnimationConfig.maxWaitForTiles) { [weak self] in
                guard let self = self, let dest = self.pendingEntryDestination else { return }
                print("🌍 [EntryAnim] 瓦片加载超时，强制启动")
                self.pendingEntryDestination = nil
                self.startEntryAnimation(mapView: mapView, destination: dest)
            }
        }
    }

    /// 启动入场动画：先通知 UI 淡出遮罩，再开始动画
    private func startEntryAnimation(mapView: MKMapView, destination: CLLocationCoordinate2D) {
        isEntryAnimating = true
        isProgrammaticChange = true
        mapView.isUserInteractionEnabled = false

        if mapView.userTrackingMode != .none {
            mapView.userTrackingMode = .none
        }

        // ── 在遮罩遮挡下跳到动画起点（用户看不到这次跳转）──
        // 随机正负方向：每次打开 App 旋转方向不同，增加趣味性
        let direction: Double = Bool.random() ? 1.0 : -1.0
        var startLon = destination.longitude + EntryAnimationConfig.longitudeOffset * direction
        if startLon < -180 { startLon += 360 }
        if startLon > 180 { startLon -= 360 }

        let startCamera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: EntryAnimationConfig.startLatitude, longitude: startLon),
            fromDistance: EntryAnimationConfig.globeAltitude,
            pitch: EntryAnimationConfig.startPitch,
            heading: EntryAnimationConfig.startHeading
        )
        mapView.camera = startCamera
        updateGlobeConfigurationIfNeeded(mapView: mapView)

        print("🌍 [EntryAnim] 起点就绪: lon=\(startLon), alt=\(Int(EntryAnimationConfig.globeAltitude))")

        // 提前用目标区域更新 ViewModel 的 region，
        // 这样 API 返回数据后 getAnnotations() 能在正确区域找到分享，动画过程中即可看到标注
        let destinationRegion = MKCoordinateRegion(
            center: destination,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        parent.onRegionChange?(destinationRegion)

        // 起点就绪后，通知 UI 淡出遮罩（用户看到的第一帧就是正确的起点）
        parent.onEntryAnimationReady?()

        // 遮罩淡出后开始动画
        DispatchQueue.main.asyncAfter(deadline: .now() + EntryAnimationConfig.splashFadeDuration) { [weak self] in
            self?.performEntryAnimation(mapView: mapView, destination: destination)
        }
    }

    /// 执行入场动画：从当前位置（已在起点）开始连续动画
    private func performEntryAnimation(mapView: MKMapView, destination: CLLocationCoordinate2D) {
        let finalCamera = MKMapCamera(
            lookingAtCenter: destination,
            fromDistance: EntryAnimationConfig.finalAltitude,
            pitch: EntryAnimationConfig.finalPitch,
            heading: EntryAnimationConfig.finalHeading
        )

        print("🌍 [EntryAnim] 开始连续动画: duration=\(EntryAnimationConfig.totalDuration)s, altPower=\(EntryAnimationConfig.altitudeEasingPower)")

        // initialDelay: 遮罩刚淡出，让用户看一眼地球仪起点，再开始旋转
        DispatchQueue.main.asyncAfter(deadline: .now() + EntryAnimationConfig.initialDelay) { [weak self] in
            guard let self = self else { return }

            self.animateCamera(
                mapView: mapView,
                to: finalCamera,
                duration: EntryAnimationConfig.totalDuration,
                altitudeEasingPower: EntryAnimationConfig.altitudeEasingPower
            ) { _ in
                print("🌍 [EntryAnim] 入场动画完成")
                self.finishEntryAnimation(mapView: mapView)
            }
        }
    }

    /// 入场动画结束（正常完成或被打断）
    private func finishEntryAnimation(mapView: MKMapView) {
        animDisplayLink?.invalidate()
        animDisplayLink = nil
        isEntryAnimating = false
        isProgrammaticChange = false
        mapView.isUserInteractionEnabled = true

        // 强制标注重新渲染（CADisplayLink 期间 MKMapView 可能延迟了聚合/布局）
        let customAnnotations = mapView.annotations.compactMap { $0 as? CustomAnnotation }
        if !customAnnotations.isEmpty {
            mapView.removeAnnotations(customAnnotations)
            mapView.addAnnotations(customAnnotations)
        }

        parent.onRegionChange?(mapView.region)
    }

    // MARK: - CADisplayLink 动画引擎

    /// 通用 camera 动画：逐帧插值，支持精确时长控制
    /// - altitudeEasingPower: 高度独立缓动指数（1.0 = 与位置同步，>1 = 前期慢降后期快降）
    private func animateCamera(mapView: MKMapView, to target: MKMapCamera, duration: Double, altitudeEasingPower: Double = 1.0, completion: @escaping (Bool) -> Void) {
        animDisplayLink?.invalidate()

        animMapView = mapView
        animFrom = mapView.camera.copy() as? MKMapCamera
        animTo = target
        animDuration = duration
        animAltitudeEasingPower = altitudeEasingPower
        animCompletion = completion
        animStartTime = CACurrentMediaTime()

        animDisplayLink = CADisplayLink(target: self, selector: #selector(animationTick))
        animDisplayLink?.add(to: .main, forMode: .common)
    }

    @objc private func animationTick() {
        guard let mapView = animMapView,
              let from = animFrom,
              let to = animTo else {
            stopDisplayLink(finished: false)
            return
        }

        let elapsed = CACurrentMediaTime() - animStartTime
        let rawProgress = min(elapsed / animDuration, 1.0)

        // 位置（经纬度）：标准 ease-in-out 缓动
        let t = easeInOut(rawProgress)

        // 高度：独立缓动曲线（pow 指数越大，前期越平缓、后期越陡峭）
        // altitudeEasingPower = 3.0 时：前 40% 时间仅下降 6%，最后 30% 时间下降 66%
        let altT = pow(easeInOut(rawProgress), animAltitudeEasingPower)

        let lat = from.centerCoordinate.latitude + (to.centerCoordinate.latitude - from.centerCoordinate.latitude) * t
        let lon = interpolateLongitude(
            from: from.centerCoordinate.longitude,
            to: to.centerCoordinate.longitude,
            progress: t
        )
        let alt = from.centerCoordinateDistance + (to.centerCoordinateDistance - from.centerCoordinateDistance) * altT
        let pitch = from.pitch + (to.pitch - from.pitch) * CGFloat(t)
        let heading = from.heading + (to.heading - from.heading) * t

        let camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            fromDistance: alt,
            pitch: pitch,
            heading: heading
        )
        mapView.camera = camera

        // 高度变化时动态切换 globe 配置（Hybrid → Standard）
        // 注意：标注刷新由 mapViewDidChangeVisibleRegion 统一处理（含节流），
        // 这里不需要单独刷新
        updateGlobeConfigurationIfNeeded(mapView: mapView)

        if rawProgress >= 1.0 {
            stopDisplayLink(finished: true)
        }
    }

    private func stopDisplayLink(finished: Bool) {
        animDisplayLink?.invalidate()
        animDisplayLink = nil
        let completion = animCompletion
        animCompletion = nil
        completion?(finished)
    }

    /// 二次缓动函数（加速 → 减速）
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }

    /// 经度插值（自动选择最短路径，处理跨日期变更线）
    private func interpolateLongitude(from start: Double, to end: Double, progress: Double) -> Double {
        var delta = end - start
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var result = start + delta * progress
        if result > 180 { result -= 360 }
        if result < -180 { result += 360 }
        return result
    }
}
