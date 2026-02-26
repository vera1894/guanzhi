---
name: sticker-gen
description: 为「观之」项目生成圆形贴纸（linocut 风格），处理 PNG → SVG 透明背景转换并部署到 Xcode Assets。触发关键词：「生成贴纸」「贴纸」「重新生成贴纸」「补充贴纸」「贴纸坏了」「贴纸换图」「贴纸 svg」「sticker」「贴纸风格」「linocut」「Imagen 贴纸」「icons/stickers」「贴纸图像」「圆形徽章」「badge sticker」。
---

# 贴纸生成工作流

## 目录结构

```
icons/stickers/
├── 贴纸参考/          # 风格参考图（勿修改）
└── generated/
    ├── gen_stickers.py        # 生成脚本（合并版，含 10 款精确提示词）
    ├── png_to_svg_v2.py       # SVG 转换脚本
    ├── ref-precise-like.png   # 风格参考图（必须，linocut 青蓝大拇指）
    ├── 可用/                   # 用户筛选的候选贴纸
    │   ├── *.png
    │   └── svg/               # 最终 SVG（透明背景）
    ├── stickers_upload/       # 上传服务器的正式 PNG（10 张）
    └── old/                   # 历史候选图 + 原始 batch 脚本存档
```

Xcode 目标：
```
guanzhi/Assets.xcassets/Stickers/stickers-{name}.imageset/
```

---

## 第一步：确认任务范围

- 若 `$ARGUMENTS` 指定了贴纸名（如 `like neutral`），仅处理这些
- 若无参数，询问用户需要新增还是重新生成哪些贴纸
- 每批次最多处理 2 款，生成后立即复查，再继续

**运行方式：**
```bash
cd icons/stickers/generated

# 生成全部 10 款
python gen_stickers.py

# 只生成指定款（推荐，避免浪费配额）
python gen_stickers.py like neutral

# 版本号自动递增（扫 generated/ + old/ 中最高 vN，+1 输出）
# 输出：v7-{name}-0~3.png
```

---

## 第二步：提示词构造规范

### API 参数（固定不变）

```python
model   = "imagen-3.0-capability-001"
project = "tajimoji-dev"
url     = "https://us-central1-aiplatform.googleapis.com/v1/projects/tajimoji-dev/locations/us-central1/publishers/google/models/imagen-3.0-capability-001:predict"
ref_img = "ref-precise-like.png"   # 风格参考图（必须）
sampleCount = 4
aspectRatio = "1:1"
```

### STYLE_DESC（固定文本）

```
linocut / screen-print circular badge sticker.
Solid flat color circle background.
One massive bold organic silhouette shape in contrasting solid color, filling 70-80% of the circle.
Slight grain/texture like hand-printed risograph.
2-3 tiny accent shapes scattered.
No outlines, no strokes, no gradients, no 3D.
```

### 提示词模板

```
A circular badge sticker in linocut print style.
{背景色名} circle background ({背景色HEX}).
ONE massive bold {主题描述} shape in {主体色名} ({主体色HEX}),
organically shaped, slightly rough edges like hand-carved, filling 75% of the circle.
{点缀元素描述：1-2句}
Slight print grain texture overall.
Only 3 colors: {背景色} background, {主体色} {主体形状}, cream {点缀}.
The {主体形状} is MASSIVE and BOLD — a graphic badge silhouette.
NO outlines, NO strokes, NO gradients, NO 3D shading.
Match the exact hand-printed linocut style of reference [1].
```

### 关键要求

- 主体剪影必须是**纯实心填充**（solid silhouette），不能是描线图
- 主体填充 **70–80%** 的圆形面积
- **严禁**餐具/具体文化符号（如亚洲建筑、筷子）→ 改用通用符号
- 如主题有歧义（如 chaosheng），改为跨文化通用意象（烛火 > 宝塔）

---

## 第三步：10 款贴纸颜色方案

| 贴纸 | 背景色 | 主体色 | 主题语义 |
|------|--------|--------|---------|
| like | `#007090` 青蓝 | `#002030` 深海军蓝 | 大拇指剪影 + 星形点缀 |
| neutral | `#3D6B8E` 石蓝 | `#E8C98A` 沙黄 | 圆脸剪影，平线嘴 + 半睁眼 |
| maomao | `#C03000` 橙红 | `#002030` 深海军蓝 | 猫脸剪影 + 鱼形点缀 |
| richu | `#2B3A6B` 深靛蓝 | `#D4695A` 珊瑚橙 | 半圆日出 + 放射线 |
| zhenxiu | `#8B2635` 酒红 | `#E8B84B` 金黄 | 圆碗剪影 + 蒸汽线（无餐具）|
| wanqu | `#5B3A8E` 紫 | `#F2A94B` 琥珀黄 | 五角星剪影 + 内嵌笑脸 |
| caikeng | `#B8862A` 琥珀赭 | `#1A2E50` 深蓝 | 感叹号 + 放射破线 |
| mijing | `#2D6A4F` 森林绿 | `#D4962C` 金赭 | 拱形入口 + 植物叶 |
| chaosheng | `#C47E6B` 赭玫 | `#1B5C5E` 深青 | 烛火剪影 + 放射光芒 |
| jishi | `#4A7B5E` 橄榄绿 | `#C46B3A` 赭红 | 遮阳篷 + 台面 + 货品圆点 |

---

## 第四步：生成脚本

使用 `gen_stickers.py`（已包含 10 款精确提示词，直接运行即可）。

**关键实现要点：**
- `next_version_prefix()`：扫 `generated/` + `old/` 两个目录，取最高 vN +1，避免版本号冲突
- `generate()`：curl POST → JSON 解析（含异常处理） → `post_process` 裁圆（失败时保留原图）→ 保存 `v{N}-{name}-{i}.png`
- 主循环：每批 2 款，批次间 sleep 12s；429 限速时指数退避重试（最多 3 次）

**新增贴纸时**，在 `gen_stickers.py` 的 `STICKERS` 字典末尾追加：
```python
"newname": (
    "A circular badge sticker in linocut print style. "
    "{背景色名} circle background ({HEX}). "
    "ONE massive bold {主体形状} in {主体色} ({HEX}), "
    "organically shaped, slightly rough edges like hand-carved, filling 75% of the circle. "
    "{点缀描述}. "
    "Slight print grain texture overall. "
    "Only 3 colors: {背景色} background, {主体色} {形状}, cream accents. "
    "NO outlines, NO strokes, NO gradients, NO 3D shading. "
    "Match the exact hand-printed linocut style of reference [1]."
),
```

---

## 第五步：复查标准

每批生成后用 Read 工具逐一查看候选图：

| 项目 | 合格 | 不合格 |
|------|------|--------|
| 风格 | linocut/screen-print 手版印刷感 | 3D 渲染、照片写实、扁平图标 |
| 主体 | 实心剪影，填满 70-80% | 描线图、空心图、主体过小 |
| 颜色 | 背景+主体+奶白 3 色 | 渐变、过多颜色 |
| 背景 | 圆外纯白，无阴影 | 圆外有阴影/灰度边缘 |
| 语义 | 图形通用、无特定文化指向 | 含筷子/亚洲建筑等具体符号 |

不合格 → 调整提示词（强化「MASSIVE BOLD SOLID SILHOUETTE」「NO outlines」）→ 重新生成。

---

## 第六步：PNG → SVG（透明背景）

使用 `png_to_svg_v2.py`，核心逻辑：

```python
# 1. 4x 超采样抗锯齿圆形遮罩
scale = 4
mask_big = Image.new("L", (w*scale, h*scale), 0)
ImageDraw.Draw(mask_big).ellipse([...], fill=255)
mask = mask_big.resize((w, h), Image.LANCZOS)
img.putalpha(mask)

# 2. base64 嵌入 SVG + clipPath 双重圆形裁剪
svg = f"""<svg ...>
  <defs><clipPath id="c"><circle cx="{cx}" cy="{cy}" r="{r}"/></clipPath></defs>
  <image ... href="data:image/png;base64,{img_b64}" clip-path="url(#c)"/>
</svg>"""
```

**禁用 vtracer**：多色复杂图像描线会产生锯齿路径，且近白区域变成不透明路径。

---

## 第七步：部署到 Xcode

```bash
# 命名规范
stickers-{name}.svg  →  guanzhi/Assets.xcassets/Stickers/stickers-{name}.imageset/

# Contents.json 结构（如文件名变更需同步更新）
{
  "images": [{"filename":"stickers-{name}.svg","idiom":"universal","scale":"1x"}, ...],
  "info": {"author":"xcode","version":1}
}
```

---

## 常见问题速查

| 问题 | 原因 | 解决 |
|------|------|------|
| 生成结果有波浪/海浪 | 提示词含 horizon / waves，或参考图污染 | 在 prompt 显式禁止：`NO waves, NO horizon line` |
| 主体太小 | 模型未理解"填满 75%" | 加强：`MASSIVE AND BOLD — fills 75% of the circle, NOT small` |
| 背景出现太阳/宝塔 | 参考图含这些元素（如用了 richu 作参考） | 必须用 `ref-precise-like.png` 作参考，不可换 |
| SVG 有锯齿/背景不透 | 使用了 vtracer | 改用 `png_to_svg_v2.py`（PIL 抗锯齿遮罩嵌入方案）|
| 429 限速 | API 频率超限 | 已内置指数退避；批次间 sleep 12s |
| gcloud token 过期 | 运行时间超过 1 小时 | 重新执行 `gcloud auth print-access-token` |
