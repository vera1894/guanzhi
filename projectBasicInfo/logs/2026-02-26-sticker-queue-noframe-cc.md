# 贴纸队列去除白框

**日期**: 2026-02-26
**类型**: UI 优化
**状态**: 完成
**版本**: v3.7.6（与服务端资产化同批）

---

## 问题

观之详情页贴纸选择区域（SpriteKit 场景），贴纸队列中每个贴纸图标外围有一个大白色圆形背景框 + 灰色边框，视觉上突兀。

---

## 根因

`StickerTextureCache.createTexture` 的 `.image` case 调用了 `renderWithFrame(image:size:)`，该方法会在图片外围绘制：
- 白色圆形背景（带阴影）
- 灰色圆形边框
- 将图片裁剪缩放到内圈

而贴纸 PNG 本身已经是带透明圆形背景的设计，叠加白框后显示错误。

---

## 修复

**修改文件**：`guanzhi/View/Features/StickerKit/SpriteKit/StickerTextureCache.swift`

新增 `renderScaled(image:size:)` 方法，仅将图片缩放到目标尺寸，不添加任何背景/边框：

```swift
private func renderScaled(image: UIImage, size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
}
```

将 `.image` case 改为调用 `renderScaled`（本地磁盘 PNG 和 xcassets 两个路径均改）。

`renderWithFrame` 保留，供 `.systemSymbol` 和 `.svg` case 继续使用。

---

## 注意事项

- 仅 `.image` asset kind 受影响；systemSymbol 类贴纸仍保留白框（因为 SF Symbol 本身无背景）
- 无需重新部署后端
