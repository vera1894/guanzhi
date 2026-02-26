# 贴纸视觉资产完成

**日期**: 2026-02-26
**类型**: 资产制作 + 工具链建设
**状态**: 完成

---

## 背景

贴纸系统（2025-12-22 上线）一直使用占位图标。本次完成所有 10 款贴纸的最终视觉资产，确立了 linocut / screen-print 圆形徽章风格，并固化了完整的生成 → SVG 转换 → 部署工作流。

---

## 目标

1. 为 10 款贴纸生成风格统一的视觉资产
2. 处理为带透明背景的 SVG，部署到 Xcode Assets
3. 将整个流程固化为可复用的 Claude 技能

---

## 方案确立过程

### 风格定位（核心决策）

经过多轮迭代，最终确立风格为 **linocut / screen-print 丝网印刷风**：
- 圆形徽章，实心剪影填充 70–80% 圆面
- 3 色方案：背景色 + 主体色 + 奶白点缀
- 轻微印刷颗粒质感，有机手刻边缘
- 无描线轮廓、无渐变、无 3D 阴影

参考图来源：Midjourney 生成的 linocut 贴纸图组（`icons/stickers/贴纸参考/`）。

### 技术选型

| 环节 | 最终方案 | 淘汰方案 & 原因 |
|------|---------|----------------|
| 图像生成 | Vertex AI Imagen 3 (`imagen-3.0-capability-001`) + 风格参考图 | `generate-002`（无参考图版）：风格不一致 |
| 风格参考图 | `ref-precise-like.png`（青蓝底大拇指 linocut） | cat/richu 参考图：主题污染 |
| SVG 转换 | PIL 4x 抗锯齿遮罩 + base64 PNG 嵌入 + `<clipPath>` | vtracer：锯齿路径 + 近白区域不透明 |

---

## 实施过程

### 生成脚本演进

| 版本 | 策略 | 问题 |
|------|------|------|
| v2 | cat 参考图 + 10 款并行 | cat 主题污染 like 等贴纸 |
| v3 | richu 参考图（非主题参考）| sun/waves 污染 neutral/chaosheng |
| v4 | 无参考图，generate-002 | 风格飘移，不像 linocut |
| **v5** | ref-precise-like.png + 精确 linocut 提示词 | **稳定，全套命中** |
| v6 | v5 基础上修订 3 款（通用化） | — |

### 提示词关键结论

- **主体描述必须强调**：`MASSIVE BOLD SOLID SILHOUETTE, filling 75%, organically shaped`
- **必须禁止**：`NO outlines, NO strokes, NO gradients, NO 3D`
- **参考图引导**：`Match the exact hand-printed linocut style of reference [1]`
- **文化通用性**：去掉筷子、宝塔等特定文化符号 → 改用碗、烛火、摊台货品

### 各贴纸调整记录

| 贴纸 | 调整说明 |
|------|---------|
| zhenxiu | 删除筷子/叉子，仅保留「碗 + 蒸汽线」 |
| chaosheng | 宝塔→烛火剪影（更通用的朝圣/虔诚意象） |
| jishi | 增加台面 + 货品陈列，去掉东方灯笼 |

---

## 最终资产

### 10 款贴纸颜色方案

| 贴纸 | 背景色 | 主体色 | 主题图形 |
|------|--------|--------|---------|
| like | `#007090` 青蓝 | `#002030` 深海军蓝 | 大拇指 + 星形点缀 |
| neutral | `#3D6B8E` 石蓝 | `#E8C98A` 沙黄 | 圆脸，平线嘴 + 半睁眼 |
| maomao | `#C03000` 橙红 | `#002030` 深海军蓝 | 猫脸 + 鱼形点缀 |
| richu | `#2B3A6B` 深靛蓝 | `#D4695A` 珊瑚橙 | 半圆日出 + 放射线 |
| zhenxiu | `#8B2635` 酒红 | `#E8B84B` 金黄 | 圆碗 + 蒸汽线 |
| wanqu | `#5B3A8E` 深紫 | `#F2A94B` 琥珀黄 | 五角星 + 内嵌笑脸 |
| caikeng | `#B8862A` 琥珀赭 | `#1A2E50` 深蓝 | 感叹号 + 放射破线 |
| mijing | `#2D6A4F` 森林绿 | `#D4962C` 金赭 | 拱形入口 + 植物叶 |
| chaosheng | `#C47E6B` 赭玫 | `#1B5C5E` 深青 | 烛火剪影 + 放射光芒 |
| jishi | `#4A7B5E` 橄榄绿 | `#C46B3A` 赭红 | 遮阳篷 + 台面 + 货品圆点 |

### 文件位置

```
# 源文件（PNG 候选 + SVG）
icons/stickers/generated/可用/           # 用户筛选的最终 PNG
icons/stickers/generated/可用/svg/       # 透明背景 SVG

# 部署目标
guanzhi/Assets.xcassets/Stickers/
├── stickers-like.imageset/stickers-like.svg
├── stickers-neutral.imageset/stickers-neutral.svg
├── stickers-maomao.imageset/stickers-maomao.svg
├── stickers-richu.imageset/stickers-richu.svg
├── stickers-zhenxiu.imageset/stickers-zhenxiu.svg
├── stickers-wanqu.imageset/stickers-wanqu.svg
├── stickers-caikeng.imageset/stickers-caikeng.svg
├── stickers-mijing.imageset/stickers-mijing.svg
├── stickers-chaosheng.imageset/stickers-chaosheng.svg
└── stickers-jishi.imageset/stickers-jishi.svg
```

---

## SVG 转换方案

**禁用 vtracer** 原因：多色复杂图像描线产生大量折线路径（锯齿），且近白区域被描为不透明路径。

**最终方案**（`png_to_svg_v2.py`）：
1. PIL 4x 超采样圆形遮罩 + LANCZOS 降采样（抗锯齿）
2. 应用为 alpha 通道（圆外透明）
3. base64 编码嵌入 SVG `<image>` 标签
4. SVG `<clipPath>` 圆形双重保险

---

## 工具链固化

**Claude 技能**：`~/.claude/skills/sticker-gen/`

- `SKILL.md`：完整流程文档（API参数、提示词模板、颜色方案、复查标准、SVG方案、部署规范、FAQ）
- `png_to_svg_v2.py`：SVG 转换脚本附件

**触发方式**：`/sticker-gen [贴纸名]` 或关键词「贴纸」「sticker」「linocut」等自动触发。

---

## 踩坑总结

1. **参考图污染**：参考图主题（cat/sun）会渗入所有贴纸。解决：使用主题中性的 like 贴纸作参考。
2. **vtracer 锯齿**：矢量描线不适合复杂多色图像，改用 PIL 嵌入方案完全规避。
3. **文化特异性**：宝塔/筷子等符号在国际化场景有误导性，统一改为通用意象。
4. **圆形检测阈值**：`detect_circle` 必须用 threshold=220（检测彩色外圈），不能用低阈值（会检测到内部深色图案）。
