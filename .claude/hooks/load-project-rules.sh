#!/bin/bash

# 项目规则加载器 - 在 Claude Code 会话开始时自动运行
# 使用 $CLAUDE_PROJECT_DIR 实现路径参数化

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
DOC_DIR="projectBasicInfo"

echo "=== 观之项目 ==="
echo ""
echo "MEMORY.md 和 rules/ 已自动加载，包含关键经验和查找策略。"
echo "根据任务类型，按需查阅 CLAUDE.md 中的任务索引表定位文档。"
echo "禁止每次都阅读全部 $DOC_DIR/ 文档。"
echo ""

exit 0
