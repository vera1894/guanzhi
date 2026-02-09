#!/bin/bash

# 项目规则加载器 - 在 Claude Code 会话开始时自动运行
# 使用 $CLAUDE_PROJECT_DIR 实现路径参数化

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
DOC_DIR="projectBasicInfo"

echo "=== 项目规则提醒 ==="
echo ""
echo "请在开始工作前阅读 $PROJECT_DIR/$DOC_DIR/ 下的文档："
echo ""
echo "1. $DOC_DIR/00_AGENT_RULES.md - Agent 使用规则（必读）"
echo "2. $DOC_DIR/01_PROJECT_OVERVIEW.md - 项目结构与端侧入口"
echo "3. $DOC_DIR/04_TERMINOLOGY.md - 术语规范（必读）"
echo "4. $DOC_DIR/logs/ - 近期操作日志（了解上下文）"
echo ""
echo "日志命名格式：YYYY-MM-DD-英文主题-角色.md"
echo ""
echo "=== 请确认已阅读项目规则后再开始工作 ==="
echo ""

exit 0
