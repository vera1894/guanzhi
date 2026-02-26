#!/usr/bin/env python3
"""
观之贴纸生成脚本 — 最终版
使用 Vertex AI Imagen 3 + linocut/screen-print 风格
合并自 gen_v5_batch2~6

用法：
  python gen_stickers.py                # 生成全部 10 款
  python gen_stickers.py like neutral   # 只生成指定款

输出：v{N}-{name}-{0..3}.png（v 号自动递增）
"""

import json, base64, subprocess, time, sys, os
from PIL import Image
import numpy as np

BASE    = os.path.dirname(os.path.abspath(__file__))
REF_IMG = os.path.join(BASE, "ref-precise-like.png")   # 风格参考图（必须）
MODEL   = "imagen-3.0-capability-001"
PROJECT = "tajimoji-dev"
URL     = (f"https://us-central1-aiplatform.googleapis.com/v1/projects/{PROJECT}"
           f"/locations/us-central1/publishers/google/models/{MODEL}:predict")

# ── 风格描述（固定不变） ───────────────────────────────────────────────
STYLE_DESC = (
    "linocut / screen-print circular badge sticker. "
    "Solid flat color circle background. "
    "One massive bold organic silhouette shape in contrasting solid color, filling 70-80% of the circle. "
    "Slight grain/texture like hand-printed risograph. "
    "2-3 tiny accent shapes scattered. "
    "No outlines, no strokes, no gradients, no 3D."
)

# ── 10 款贴纸提示词 ───────────────────────────────────────────────────
# like / maomao：来自 29b16a9b.jsonl 对话记录（精确，生成 test-v5-like/maomao 所用）
# neutral / richu：来自 gen_v5_batch2.py（精确）
# zhenxiu / wanqu：来自 gen_v5_batch3.py（wanqu 精确；zhenxiu 使用 batch6 修订版，无餐具）
# caikeng / mijing：来自 gen_v5_batch4.py（精确）
# chaosheng / jishi：来自 gen_v5_batch6.py（精确，修订版）
STICKERS = {
    "like": (
        # 原始精确版（生成 test-v5-like-3.png 所用）
        "A circular badge sticker in linocut print style. "
        "Cerulean teal blue circle background (#007090). "
        "ONE massive bold thumbs-up hand silhouette in very dark navy (#002030), "
        "organically shaped, slightly rough edges like hand-carved, filling 75% of the circle. "
        "A thin cream/off-white gap separates the dark hand from the blue background. "
        "ONE tiny cream/white star accent shape in upper corner. "
        "Slight print grain texture overall. "
        "Only 3 colors: teal blue background, dark navy hand, cream star. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "neutral": (
        # batch2 精确版
        "A circular badge sticker in linocut print style. "
        "Slate blue circle background (#3D6B8E). "
        "ONE massive bold round face shape in warm sand yellow (#E8C98A), "
        "organically shaped, filling 70% of the circle. "
        "Inside the face: two simple half-closed heavy-lidded oval eye shapes in dark navy, "
        "and ONE short thick flat horizontal bar for the mouth — "
        "completely blank expressionless face, zero emotion. "
        "TWO tiny cream/off-white dot accents near the eyes. "
        "Slight print grain texture overall. "
        "Only 3 colors: slate blue background, sand yellow face, dark navy/cream face details. "
        "The face shape is MASSIVE and BOLD — a graphic badge silhouette. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "maomao": (
        # 原始精确版（生成 test-v5-maomao-2.png 所用）
        "A circular badge sticker in linocut print style. "
        "Vivid orange-red circle background (#C03000). "
        "ONE massive bold cat head silhouette in very dark navy (#002030), "
        "filling 70% of the circle — simple bold organic shape: rounded head, two triangular ears, "
        "no internal features except a simple cream crescent smile. "
        "2 tiny cream/white fish silhouette shapes as accent. "
        "Slight print grain texture. "
        "Only 3 colors: orange-red background, dark navy cat, cream accents. "
        "NO outlines, NO strokes, NO gradients, NO 3D. "
        "Match the bold flat linocut print style of reference [1]."
    ),
    "richu": (
        # batch2 精确版
        "A circular badge sticker in linocut print style. "
        "Deep indigo dark blue circle background (#2B3A6B). "
        "ONE massive bold half-circle sun shape in warm coral orange (#D4695A), "
        "sitting at the bottom center of the circle — like a sun just cresting the horizon. "
        "Above the half-circle: 7 thick short straight radiating lines in coral orange, "
        "fanning upward like bold sun rays. "
        "A thin straight horizontal line in coral orange divides the lower portion. "
        "ONE tiny cream/off-white star or sparkle accent shape near a ray tip. "
        "Slight print grain texture overall. "
        "Only 3 colors: dark indigo background, coral orange sun and rays, cream accent. "
        "The sun shape is MASSIVE and BOLD — a graphic badge silhouette, NOT a landscape scene. "
        "NO outlines, NO strokes around shapes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "zhenxiu": (
        # batch6 修订版（无餐具）
        "A circular badge sticker in linocut print style. "
        "Deep burgundy red circle background (#8B2635). "
        "ONE massive bold round bowl shape in warm golden yellow (#E8B84B), "
        "centered in the lower half, organically shaped with slightly rough edges like hand-carved, "
        "filling about 55% of the circle. "
        "NO chopsticks, NO fork, NO spoon, NO utensils of any kind. "
        "THREE bold curved steam line shapes in cream/off-white rising upward from inside the bowl — "
        "organic wavy shapes, like visible steam clouds. "
        "Slight print grain texture overall. "
        "Only 3 colors: burgundy red background, golden yellow bowl, cream steam shapes. "
        "The bowl is MASSIVE and BOLD — a pure graphic silhouette, no utensils. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "wanqu": (
        # batch3 精确版
        "A circular badge sticker in linocut print style. "
        "Deep violet purple circle background (#5B3A8E). "
        "ONE massive bold five-pointed star polygon shape in warm amber yellow (#F2A94B), "
        "perfectly centered, filling 75% of the circle, "
        "organically shaped with slightly rough edges like hand-carved. "
        "Inside the star: TWO small dot eyes and ONE small arc smile drawn in dark navy — "
        "a simple cute face. "
        "THREE tiny cream/off-white dot accents at the star tips. "
        "Slight print grain texture overall. "
        "Only 3 colors: violet purple background, amber yellow star, dark navy face details and cream dots. "
        "The star shape is MASSIVE and BOLD — fills most of the circle. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "caikeng": (
        # batch4 精确版
        "A circular badge sticker in linocut print style. "
        "Dark amber ochre circle background (#B8862A). "
        "ONE massive bold exclamation mark shape in deep navy (#1A2E50), "
        "perfectly centered — a tall thick rectangle body at the top and a circular dot below, "
        "filling most of the circle height, organically shaped with slightly rough edges. "
        "SIX short thick straight dash lines in cream/off-white radiating outward around the exclamation mark, "
        "evenly spaced like a warning burst. "
        "Slight print grain texture overall. "
        "Only 3 colors: amber ochre background, dark navy exclamation mark, cream radiating dashes. "
        "The exclamation mark is MASSIVE and BOLD — a graphic badge silhouette. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "mijing": (
        # batch4 精确版
        "A circular badge sticker in linocut print style. "
        "Forest green circle background (#2D6A4F). "
        "ONE large bold arch/tunnel entrance shape in golden ochre (#D4962C), "
        "centered — like a tall rounded arch or cave mouth, filling the upper 60% of the circle. "
        "Inside the arch: ONE small bright golden glow dot/shape in cream/off-white. "
        "On each side of the arch outside: TWO or THREE bold simple leaf shapes in golden ochre. "
        "Slight print grain texture overall. "
        "Only 3 colors: forest green background, golden ochre arch and leaves, cream glow dot. "
        "The arch shape is MASSIVE and BOLD — a graphic badge silhouette. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "chaosheng": (
        # batch6 修订版（烛火，非宝塔）
        "A circular badge sticker in linocut print style. "
        "Dusty terracotta rose circle background (#C47E6B). "
        "ONE massive bold candle flame shape in deep teal (#1B5C5E), "
        "centered — a large organic teardrop/flame silhouette sitting on top of a short thick candle body, "
        "filling 65% of the circle height. "
        "The flame shape is organic and alive, slightly irregular edges. "
        "EIGHT short thick straight radiating lines in cream/off-white fanning outward around the flame, "
        "like a radiant glow or holy light. "
        "ONE or TWO tiny cream dot accents. "
        "Slight print grain texture overall. "
        "Only 3 colors: terracotta rose background, deep teal flame and candle, cream radiating lines. "
        "Universal symbol of devotion and pilgrimage — NOT a pagoda, NOT any specific building. "
        "The flame is a MASSIVE BOLD SOLID SILHOUETTE. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
    "jishi": (
        # batch6 修订版（摊台+桌面+货品，非灯笼）
        "A circular badge sticker in linocut print style. "
        "Sage olive green circle background (#4A7B5E). "
        "ONE bold triangular awning/canopy shape in warm terracotta (#C46B3A) at the top, "
        "like a simple triangular roof or market tent top. "
        "Below the canopy: ONE horizontal flat rectangular counter/table surface in terracotta. "
        "On top of the table surface: THREE or FOUR small rounded shapes (like produce or goods) "
        "in cream/off-white, sitting on the counter. "
        "The whole stall (canopy + table + goods) fills 70% of the circle. "
        "TWO or THREE tiny cream dot accents scattered around. "
        "Slight print grain texture overall. "
        "Only 3 colors: olive green background, terracotta canopy and table, cream goods and dots. "
        "Universal market stall concept — NOT specifically Asian, just a simple stall with counter. "
        "All shapes are BOLD SOLID SILHOUETTES. "
        "NO outlines, NO strokes, NO gradients, NO 3D shading. "
        "Match the exact hand-printed linocut style of reference [1]."
    ),
}

# ── 工具函数 ──────────────────────────────────────────────────────────

def detect_circle(arr):
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


def post_process(src, dst):
    """裁掉圆外白边，保留圆形区域"""
    img = Image.open(src).convert("RGB")
    arr = np.array(img)
    h, w = arr.shape[:2]
    cx, cy, r = detect_circle(arr)
    Y, X = np.ogrid[:h, :w]
    arr[np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) > r] = [255, 255, 255]
    Image.fromarray(arr.astype(np.uint8)).save(dst)


def next_version_prefix():
    """自动检测目录（含 old/）中已有的最高版本号，返回下一个（如 v7）"""
    nums = []
    for search_dir in [BASE, os.path.join(BASE, "old")]:
        if not os.path.isdir(search_dir):
            continue
        for f in os.listdir(search_dir):
            if f.startswith("v") and "-" in f:
                try:
                    nums.append(int(f[1:f.index("-")]))
                except ValueError:
                    pass
    return f"v{max(nums, default=6) + 1}"


def generate(name, prompt, version, token, ref_b64, attempt=0):
    payload = {
        "instances": [{
            "prompt": prompt,
            "referenceImages": [{
                "referenceType": "REFERENCE_TYPE_STYLE",
                "referenceId": 1,
                "referenceImage": {"bytesBase64Encoded": ref_b64},
                "styleImageConfig": {"styleDescription": STYLE_DESC}
            }]
        }],
        "parameters": {"sampleCount": 4, "aspectRatio": "1:1"}
    }

    cmd = [
        "curl", "-s", "-X", "POST", URL,
        "-H", f"Authorization: Bearer {token}",
        "-H", "Content-Type: application/json",
        "-d", json.dumps(payload)
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        print(f"    JSON 解析失败: {result.stdout[:200]}")
        return []

    if "error" in data:
        code = data["error"].get("code", 0)
        msg = data["error"].get("message", "")[:150]
        print(f"    ERROR {code}: {msg}")
        if code == 429 and attempt < 3:
            wait = 30 * (attempt + 1)
            print(f"    429 限速，等待 {wait}s …")
            time.sleep(wait)
            return generate(name, prompt, version, token, ref_b64, attempt + 1)
        return []

    saved = []
    for i, pred in enumerate(data.get("predictions", [])):
        raw_path = os.path.join(BASE, f"{version}-{name}-{i}-raw.png")
        out_path = os.path.join(BASE, f"{version}-{name}-{i}.png")
        img_bytes = base64.b64decode(pred["bytesBase64Encoded"])
        with open(raw_path, "wb") as f:
            f.write(img_bytes)
        try:
            post_process(raw_path, out_path)
            os.remove(raw_path)
        except Exception as e:
            print(f"    后处理失败({e})，保留原图")
            os.rename(raw_path, out_path)
        saved.append(out_path)
        print(f"    ✓ {os.path.basename(out_path)}")
    return saved


# ── 主流程 ────────────────────────────────────────────────────────────

def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else list(STICKERS.keys())
    unknown = [t for t in targets if t not in STICKERS]
    if unknown:
        print(f"未知贴纸名: {unknown}。可用: {list(STICKERS.keys())}")
        sys.exit(1)

    version = next_version_prefix()
    print(f"版本前缀: {version}，待生成: {targets}\n")

    # 获取 gcloud token
    token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()

    # 读取参考图
    with open(REF_IMG, "rb") as f:
        ref_b64 = base64.b64encode(f.read()).decode()

    # 每批 2 款，批次间 sleep 12s
    for i in range(0, len(targets), 2):
        batch = targets[i:i + 2]
        for name in batch:
            print(f"生成 {name} …")
            generate(name, STICKERS[name], version, token, ref_b64)
        if i + 2 < len(targets):
            print("  批次间等待 12s …\n")
            time.sleep(12)

    print(f"\n完成！生成文件：{version}-*.png")
    print("筛选后将选中文件移入 可用/，再运行 png_to_svg_v2.py 转换 SVG。")


if __name__ == "__main__":
    main()
