# 小型 UI 修复

**日期**: 2026-01-22
**作者**: Claude Code
**状态**: ✅ 已完成

---

## 修复内容

### 1. 禁用用户位置标注点击

**问题**：点击地图上自己的定位点会弹出系统默认的空白标注

**修复**：`MKMapViewCoordinator.swift` 的 `didSelect` 方法中，检测到 `MKUserLocation` 时直接取消选中

```swift
if annotation is MKUserLocation {
    mapView.deselectAnnotation(annotation, animated: false)
    return
}
```

### 2. 贴纸看板空状态文案

**修改**：`StickerSummaryBar.swift:109`

| 修改前 | 修改后 |
|--------|--------|
| 还没有贴纸，拖动下方贴纸来互动 | 还没人使用贴纸，快来贴一张 |
