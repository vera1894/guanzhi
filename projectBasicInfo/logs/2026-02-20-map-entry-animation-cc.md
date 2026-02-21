# 地图入场动画 + 标注实时刷新

**日期**: 2026-02-20
**角色**: Claude Code
**类型**: 功能开发 + 体验优化

---

## 背景

地球仪模式完成后，用户希望 App 启动时有一个从地球仪旋转俯冲到用户位置的入场动画，类似苹果地图的启动体验。同时要求动画过程中能看到地图上的观之标注。

## 实施过程

### 阶段 1：基础入场动画

**问题**：`UIView.animate` 无法驱动 MKMapView 的 camera 变化（camera 属性不参与 Core Animation 事务）。

**方案**：CADisplayLink 逐帧插值动画引擎。

- `animateCamera()` 创建 CADisplayLink，每帧在 `animationTick()` 中插值经纬度、高度、俯仰角、方位角
- `easeInOut()` 二次缓动函数
- `interpolateLongitude()` 处理跨日期变更线的经度插值

**入场流程**：
1. `makeUIView` 预加载：在设 delegate **之前**设 camera 到地球仪高度，瓦片静默加载
2. `mapViewDidFinishLoadingMap` 或超时 → `playEntryAnimation`
3. `startEntryAnimation`：在遮罩遮挡下跳到起点 → 通知 UI 淡出遮罩 → `performEntryAnimation`
4. CADisplayLink 驱动旋转 + 俯冲 → `finishEntryAnimation`

### 阶段 2：动画体验迭代

**用户反馈 1**：动画感觉两段式，不连续。
- **修复**：合并为单一连续动画，位置用标准 ease-in-out，高度用 `pow(easeInOut(t), 3.0)` 独立缓动
- 效果：前期在高空旋转（高度几乎不变），后期快速俯冲

**用户反馈 2**：有可见的瞬移（从默认位置跳到动画起点）。
- **修复**：将起点跳转移到 `startEntryAnimation` 中、`onEntryAnimationReady` 回调**之前**执行，此时遮罩仍覆盖地图

**用户反馈 3**：180° 旋转太快，标注不明显。
- **修复**：偏移量从 180° 调整为 60°，增加 `Bool.random()` 随机正负方向

### 阶段 3：标注实时刷新

**问题**：动画和手动操作过程中标注不更新，只有操作停下后才刷新。

**排查过程**：
1. 尝试预设目标 region → 无效（动画期间可见区域不断变化）
2. 尝试混合动画（CADisplayLink + 原生 setCamera）→ 动画被分割为两段，且标注仍不显示
3. 尝试 `scheduleAnnotationUpdate` 改为节流 + `animationTick` 中周期性调用 `onRegionChange` → 无效

**根因发现**：
- `regionDidChangeAnimated` 只在手势/动画**结束**时触发一次
- `mapViewDidChangeVisibleRegion` 在手势/动画**进行中**持续触发

**最终方案**：
```swift
func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
    let now = CACurrentMediaTime()
    guard now - lastContinuousRegionUpdateTime >= 0.5 else { return }
    lastContinuousRegionUpdateTime = now
    updateGlobeConfigurationIfNeeded(mapView: mapView)
    parent.onRegionChange?(mapView.region)
}
```

- `onRegionChange` → `searchViewModel.region` 更新 + `scheduleAnnotationUpdate()` → `getAnnotations()`（纯本地 SwiftData 查询，无网络请求）
- 移除了 `animationTick` 中的周期性刷新代码（`mapViewDidChangeVisibleRegion` 已覆盖）

## 修改文件清单

| 文件 | 改动类型 |
|------|---------|
| `View/MapPages/MKMapViewCoordinator.swift` | 新增 `EntryAnimationConfig`、CADisplayLink 动画引擎、入场动画流程、`mapViewDidChangeVisibleRegion` |
| `View/MapPages/MKMapViewWrapper.swift` | 新增 `onEntryAnimationReady` 回调、瓦片预加载（camera 设置在 delegate 之前） |
| `View/FrontPages/SearchView.swift` | 新增 `isMapReady` 状态、splash overlay、`onEntryAnimationReady` 回调 |
| `ModelsForMap/SearchViewModel.swift` | `scheduleAnnotationUpdate()` 改为节流模式（首次立即执行 + 0.3s 间隔） |

## 最终动画参数

```swift
enum EntryAnimationConfig {
    static let globeAltitude: Double = 35_000_000   // 地球仪高度
    static let longitudeOffset: Double = -60        // ±60° 随机偏移
    static let totalDuration: Double = 2.8          // 动画时长
    static let altitudeEasingPower: Double = 3.0    // 高度缓动指数
    static let finalAltitude: Double = 5000         // 最终高度
    static let splashFadeDuration: Double = 0.5     // 遮罩淡出
    static let annotationRefreshInterval: Double = 0.5  // 标注刷新节流
}
```

## 关键经验

1. **`UIView.animate` 不能驱动 MKMapView camera**：MKMapView 的 `camera` setter 不参与 Core Animation，必须用 CADisplayLink 逐帧插值
2. **`regionDidChangeAnimated` vs `mapViewDidChangeVisibleRegion`**：前者只在手势结束时触发，后者持续触发。操作中刷新标注必须用后者
3. **遮罩时序是关键**：先在遮罩下完成起点跳转，再淡出遮罩，用户看到的第一帧就是正确的起点
4. **瓦片预加载**：在设 delegate 之前设置 camera，瓦片加载不会触发任何回调
5. **`getAnnotations()` 是纯本地查询**：查 SwiftData 数据库创建标注，无网络请求，频繁调用安全
