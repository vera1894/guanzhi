# 地图地球仪模式实现 + 旧 SwiftUI Map 清理

**日期**: 2026-02-20
**角色**: Claude Code
**类型**: 功能开发 + 代码清理

---

## 背景

地图原先使用 `mapView.mapType = .standard`（旧 API），不支持地球仪效果。用户希望在极度缩小时看到地球仪（类似苹果地图 App），同时保留标准街道地图的日常体验。此外，代码中仍保留着旧 SwiftUI Map 的回退分支（`useMKMapView` 开关），已无实际用途，需要清理。

## 实施过程

### 阶段 1：可切换地球仪模式

按照设计方案，在 4 个文件中实现了带 `@AppStorage("globeModeEnabled")` 开关的地球仪模式：

- `MKMapViewWrapper.swift` — 新增 `globeModeEnabled` 参数，开启时用 `preferredConfiguration` API
- `MKMapViewCoordinator.swift` — 新增 `updateGlobeConfigurationIfNeeded()`，在 `regionDidChangeAnimated` 中动态切换 Standard ↔ HybridFlyover
- `MapOverlayView.swift` — 新增地球仪切换按钮（`globe.americas` / `map` 图标）
- `SearchView.swift` — 新增 `@AppStorage("globeModeEnabled")` 并透传

### 阶段 2：Bug 修复

用户反馈两个问题：

**Bug 1：App 重启后总显示卫星图**
- **根因**：`updateGlobeConfigurationIfNeeded()` 放在 `guard !isProgrammaticChange` 之后。App 启动时初始 region（中国中心，很远）触发 HybridFlyover 切换，随后 `centerOnUser`（程序化）缩放到用户位置，但因 `isProgrammaticChange = true` 跳过了 globe 检查，无法切回 Standard。
- **修复**：将 `updateGlobeConfigurationIfNeeded()` 移到 guard 之前，确保所有 region 变化（含程序化）都执行 globe 检查。

**Bug 2：放大缩小过渡不流畅**
- **根因**：进入和退出使用同一阈值（5,000km），在边界附近反复切换。
- **修复**：引入磁滞区间 — 进入地球仪 5,000km，退出地球仪 3,500km。

### 阶段 3：清理旧代码 + 默认启用

用户决定移除地球仪开关按钮，同时清理所有旧 SwiftUI Map 回退代码，让 MKMapView + 地球仪成为唯一模式。

**移除的代码/状态**：

| 文件 | 移除内容 |
|------|---------|
| `SearchView.swift` | `useMKMapView`、`@Namespace var mapScope`、`@State var position`、`didPrime3D`、`lastCamera`、`@AppStorage("globeModeEnabled")`、`prime3DButton()`、SwiftUI Map 分支（~70 行）、`.mapScope()` 修饰符 |
| `MapOverlayView.swift` | `mapScope`、`position`、`useMKMapView`、`globeModeEnabled` 参数、地球仪按钮、SwiftUI Map 控件分支（`MapUserLocationButton`、`MapCompass`、`MapPitchToggle`） |
| `MKMapViewWrapper.swift` | `globeModeEnabled` 参数、`makeUIView` 中的条件分支 |
| `MKMapViewCoordinator.swift` | `guard parent.globeModeEnabled` 条件 |

**简化后的初始化**：
```swift
// MKMapViewWrapper.makeUIView — 始终使用新 API
mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
```

**简化后的 globe 检查**：
```swift
// MKMapViewCoordinator.regionDidChangeAnimated — 无条件执行
func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    updateGlobeConfigurationIfNeeded(mapView: mapView)  // 所有变化都检查
    guard !isProgrammaticChange else { return }
    parent.onRegionChange?(mapView.region)
}
```

## 修改文件清单

| 文件 | 改动类型 |
|------|---------|
| `View/MapPages/MKMapViewWrapper.swift` | 改用 `preferredConfiguration` API，移除 `globeModeEnabled` 参数 |
| `View/MapPages/MKMapViewCoordinator.swift` | 新增 `updateGlobeConfigurationIfNeeded()` 带磁滞，调整调用位置 |
| `View/FrontPages/MapOverlayView.swift` | 移除旧参数和 SwiftUI Map 控件分支 |
| `View/FrontPages/SearchView.swift` | 移除旧状态变量和 SwiftUI Map 分支 |

## 关键经验

1. **`preferredConfiguration` vs `mapType`**：新 API 支持 `elevationStyle: .realistic`（3D 地形），旧 `mapType` 不支持地球仪
2. **Globe 检查位置至关重要**：必须在 `isProgrammaticChange` guard 之前执行，否则程序化定位后无法正确切回 Standard
3. **磁滞防抖**：单一阈值会在边界频繁切换，需要进入/退出使用不同阈值
4. **`MKHybridMapConfiguration` 的地球仪**：只有 Hybrid/Flyover 类型在极度缩小时才显示真正的地球仪，Standard 只显示平面世界地图

## 文档同步

- `memory/architecture.md` — 新增「地图模式：MKMapView + 内置地球仪」决策记录
- `memory/ios-dev.md` — 新增「地图系统」章节
- `projectBasicInfo/01_PROJECT_OVERVIEW.md` — 更新「4. 地图标注组件」，版本升至 v4.5
- `memory/MEMORY.md` — 更新主题文件索引
