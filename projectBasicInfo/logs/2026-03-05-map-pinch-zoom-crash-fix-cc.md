# 地图双指缩放闪退修复

**日期**：2026-03-05
**类型**：Bug 修复

## 背景

用户反馈在地图页面双指捏合缩放时频繁闪退，尤其是快速缩放时必现。

## 根因分析

通过日志分析发现，每次闪退都遵循同一模式：

```
🔷 [Cluster] 创建聚合视图...  ← MKMapView 正在创建聚合视图
🌍 [Globe] 切换到 HybridFlyover  ← 同步切换 preferredConfiguration
→ crash
```

**主要根因**：`updateGlobeConfigurationIfNeeded()` 在 delegate 回调（`mapViewDidChangeVisibleRegion` / `regionDidChangeAnimated`）中**同步**修改 `mapView.preferredConfiguration`。当 MKMapView 正在创建聚合视图时，同步切换配置导致内部状态冲突闪退。

**次要根因**：`removeAnnotations`/`addAnnotations` 在 `updateUIView` 中同步执行，快速缩放时可能与 MKMapView 内部聚合计算竞态。

## 修复方案

### 1. Globe 配置切换异步化（主要修复）

`updateGlobeConfigurationIfNeeded()` 中 `preferredConfiguration` 的赋值改为 `DispatchQueue.main.async`，延迟到下一个 run loop 执行。`isInGlobeConfiguration` 标志仍同步更新防止重复触发。加 DispatchWorkItem coalescing 防止快速来回缩放多次切换。

### 2. Annotation 操作异步化 + 最小间隔

- 逻辑从 `MKMapViewWrapper.updateAnnotations`（struct 私有方法）移到 `MKMapViewCoordinator.scheduleAnnotationUpdate`
- `removeAnnotations`/`addAnnotations` 通过 `DispatchQueue.main.async` 延迟执行
- DispatchWorkItem coalescing：快速连续调用只执行最后一次
- 两次操作间强制最小间隔 200ms（`minAnnotationInterval`）

### 3. finishEntryAnimation 异步化

入场动画结束时的强制标注重渲染（remove all + add all）也改为异步执行。

## 修改的文件

- `guanzhi/View/MapPages/MKMapViewCoordinator.swift` — 新增 coalescing annotation 更新机制、globe 配置切换异步化、finishEntryAnimation 异步化
- `guanzhi/View/MapPages/MKMapViewWrapper.swift` — `updateUIView` 改用 coordinator 的安全方法，删除旧 `updateAnnotations` 私有方法

## 保留的行为

- `mapViewDidChangeVisibleRegion` 中的实时标注刷新不受影响
- 入场动画期间标注动态显示不受影响
- Globe 模式切换体验不变（延迟仅一个 run loop，人眼不可感知）
