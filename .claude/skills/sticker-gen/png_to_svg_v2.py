#!/usr/bin/env python3
"""
PNG → SVG（透明背景）— v2
方案：抗锯齿圆形遮罩 + SVG <image> 嵌入 + <clipPath> 双重圆形保险
- 无 vtracer 描线，不产生锯齿路径
- 圆形边缘 4x 超采样 + LANCZOS 降采样，平滑无锯齿
- 圆外完全透明，兼容所有 SVG 查看器
"""

import os, io, base64
import numpy as np
from PIL import Image, ImageDraw

BASE = os.path.dirname(os.path.abspath(__file__))
INPUT_DIR = os.path.join(BASE, "可用")
OUTPUT_DIR = os.path.join(INPUT_DIR, "svg")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def detect_circle(arr: np.ndarray):
    h, w = arr.shape[:2]
    cy = h // 2
    gray = np.mean(arr[:, :, :3], axis=2)
    for thresh in [220, 200, 180, 150]:
        non_white = np.where(gray[cy, :] < thresh)[0]
        if len(non_white) >= 10:
            r = (non_white[-1] - non_white[0]) // 2
            cx = (non_white[0] + non_white[-1]) // 2
            if r > 50:
                return cx, cy, r
    return w // 2, h // 2, min(w, h) // 2 - 10


def make_circle_svg(src_path: str, dst_path: str):
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    arr = np.array(img)

    cx, cy, r = detect_circle(arr)

    # ── 抗锯齿圆形遮罩（4x 超采样） ──────────────────────────────
    scale = 4
    mask_big = Image.new("L", (w * scale, h * scale), 0)
    draw = ImageDraw.Draw(mask_big)
    draw.ellipse(
        [
            (cx * scale - r * scale, cy * scale - r * scale),
            (cx * scale + r * scale, cy * scale + r * scale),
        ],
        fill=255,
    )
    mask = mask_big.resize((w, h), Image.LANCZOS)

    # 应用遮罩为 alpha 通道
    img.putalpha(mask)

    # ── 编码为 base64 PNG ─────────────────────────────────────────
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=False)
    img_b64 = base64.b64encode(buf.getvalue()).decode()

    # ── 输出 SVG（<image> + <clipPath> 双重裁剪） ─────────────────
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs>
    <clipPath id="c">
      <circle cx="{cx}" cy="{cy}" r="{r}"/>
    </clipPath>
  </defs>
  <image width="{w}" height="{h}"
         href="data:image/png;base64,{img_b64}"
         clip-path="url(#c)"/>
</svg>"""

    with open(dst_path, "w", encoding="utf-8") as f:
        f.write(svg)

    kb = os.path.getsize(dst_path) / 1024
    print(f"    ✓ {kb:.0f} KB  (圆心 {cx},{cy}  半径 {r}px)")


# ── 主流程 ────────────────────────────────────────────────────────

png_files = sorted(f for f in os.listdir(INPUT_DIR) if f.endswith(".png"))
print(f"找到 {len(png_files)} 个 PNG，开始转换...\n")

for fname in png_files:
    src = os.path.join(INPUT_DIR, fname)
    stem = os.path.splitext(fname)[0]
    dst = os.path.join(OUTPUT_DIR, f"{stem}.svg")
    print(f"  {fname}")
    make_circle_svg(src, dst)

print(f"\n完成！→ {OUTPUT_DIR}")
