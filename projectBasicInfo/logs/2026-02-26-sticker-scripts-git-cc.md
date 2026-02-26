# 贴纸生成脚本整合 + 纳入 Git

**日期**: 2026-02-26
**类型**: 工程整理
**状态**: 完成

---

## 背景

贴纸生成脚本（`gen_v5_batch2~6.py`、`png_to_svg_v2.py`）原本散落在 `icons/stickers/generated/` 目录中，且该目录不在任何 git 仓库范围内，存在以下风险：

1. `icons/` 目录在 guanzhi 项目外，不受 git 保护
2. 多个 batch 脚本分散（batch2~6），难以维护
3. 脚本被误删（`rm`）后只能靠对话记录找回
4. 全局 skill（`~/.claude/skills/sticker-gen/`）只有 `png_to_svg_v2.py`，缺少生成脚本

---

## 操作

### 1. 脚本整合

将 `gen_v5_batch2~6.py` 合并为 `gen_stickers.py`（单文件，含 10 款精确提示词）：
- 提示词全部从对话记录和原始 batch 文件中精确提取（非重建）
- 版本号自动递增（同时扫 `generated/` + `old/`，避免重叠）
- 支持命令行指定款式：`python gen_stickers.py like neutral`
- 错误处理：JSON 解析异常、post_process 失败均有 fallback

原始 batch 脚本保留在 `old/`（已从对话记录恢复）。

### 2. 目录整理

`icons/stickers/generated/` 清理为：
```
generated/
├── gen_stickers.py      # 生成脚本（合并版）
├── png_to_svg_v2.py     # SVG 转换脚本
├── ref-precise-like.png # 风格参考图（必须）
├── 可用/                # 最终选定图 + svg/
├── stickers_upload/     # 上传服务器的正式 PNG（10 张）
└── old/                 # 历史候选图 + 原始 batch 脚本
```

### 3. 纳入 Git

将 `icons/` 目录从 `DarkForce/Seee/icons/` 移动到 `guanzhi/icons/`，纳入项目 git 覆盖范围。

`.gitignore` 追加：
```
icons/stickers/generated/old/   # 历史候选图（大量 PNG，无需版本控制）
```

### 4. 三层备份

| 位置 | 内容 |
|------|------|
| `icons/stickers/generated/` | 工作目录（git 追踪） |
| `.claude/skills/sticker-gen/` | 项目内备份（git 追踪） |
| `~/.claude/skills/sticker-gen/` | 全局 skill 备份 |

---

## 经验

- `rm` 在 iCloud Drive 上**不走回收站**，直接永久删除
- 从 JSONL 对话记录可以恢复脚本内容（`grep -l "关键词" *.jsonl`）
- 重要的生成脚本应同时存入 skill 目录作备份
