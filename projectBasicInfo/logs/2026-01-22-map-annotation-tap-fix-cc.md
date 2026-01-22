# 地图标注点击响应修复

**日期**: 2026-01-22
**作者**: Claude Code
**状态**: ✅ 已完成

---

## 问题描述

在主页点击地图上单独的观之标注时，经常出现点一下不触发跳转到观之详情页面的情况，需要多点几次才成功。

**现象**：
- 点击标注时有按下动画（视觉反馈正常）
- 但页面不跳转（didSelect 未触发）
- 多点几次后某一次才成功

---

## 根本原因

### 背景

`CustomMKAnnotationView` 为了减少聚合敏感度，将 `frame`（碰撞盒）缩小到了 12×17pt，而视觉尺寸约为 84×101pt。代码假设可以通过重写 `point(inside:with:)` 来解耦点击区域和碰撞盒。

### 问题

MKMapView 有**双重判断机制**：

| 机制 | 判定依据 | 用途 |
|------|---------|------|
| UIView touch 事件 | `point(inside:with:)` | 决定触摸事件传递给哪个视图 |
| MKMapView didSelect | `frame`（独立判断） | 决定是否触发标注选中 |

重写 `point(inside:with:)` 只影响了第一层（所以有按下动画），但 **MKMapView 的 didSelect 选择机制有独立的第二层判断**，直接使用 `frame` 来判断，无法通过重写方法来影响。

### 验证数据

| 点击坐标 | 在 point(inside:) 区域内 | 在 frame 内 | didSelect 触发 |
|---------|-------------------------|------------|----------------|
| (38.3, 17.7) | ✓ | ✗ | ✗ |
| (32.0, 23.0) | ✓ | ✗ | ✗ |
| (8.7, 3.0) | ✓ | ✓ | ✓ |

---

## 修复方案

绕过 MKMapView 的 didSelect 机制，改用 `touchesEnded` 直接触发点击回调。

### 修改文件

**1. CustomMKAnnotationView.swift**

添加 `onTap` 回调属性：
```swift
/// 点击回调（绕过 MKMapView 的 didSelect 机制）
var onTap: ((CustomAnnotation, UIImage?) -> Void)?
```

在 `touchesEnded` 中触发回调：
```swift
override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    // ... 动画代码 ...

    // 直接通过 touchesEnded 触发点击回调
    if let customAnnotation = annotation as? CustomAnnotation {
        onTap?(customAnnotation, thumbnailImage)
    }
}
```

**2. MKMapViewCoordinator.swift**

在 `viewFor` 中设置回调：
```swift
annotationView?.onTap = { [weak self] annotation, thumbnailImage in
    self?.parent.onAnnotationTap?(annotation, thumbnailImage)
}
```

在 `didSelect` 中移除单个标注处理（避免重复触发）：
```swift
func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
    // 聚合标注：仍通过 didSelect 处理
    if let clusterAnnotation = annotation as? MKClusterAnnotation {
        // ... 聚合处理逻辑 ...
    }

    // 单个标注：不在这里处理，由 touchesEnded 触发
    if annotation is CustomAnnotation {
        mapView.deselectAnnotation(annotation, animated: false)
        return
    }
}
```

---

## 修复后的行为

| 标注类型 | 点击触发方式 | 点击区域 |
|---------|-------------|---------|
| 单个标注 | `touchesEnded` → `onTap` | `point(inside:)` 定义的完整视觉区域 |
| 聚合标注 | `didSelect`（不变） | frame（本身就是完整尺寸） |

---

## 技术要点

1. **MKMapView 的 didSelect 无法通过重写 `point(inside:with:)` 来自定义点击区域**
2. **UIView 的 touch 事件和 MKMapView 的 didSelect 是两套独立机制**
3. **聚合标注（ClusterAnnotationView）不需要此修复**，因为其 frame 本身就是完整视觉尺寸
