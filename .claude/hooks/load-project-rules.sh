#!/bin/bash

# 项目规则加载器 - 在 Claude Code 会话开始时自动运行
# 确保 Agent 在开始工作前阅读项目规则

echo "=== 项目规则提醒 ==="
echo ""
echo "请在开始工作前阅读以下项目规则文档："
echo ""
echo "1. projectBasicInfo/00_AGENT_RULES.md - Agent 使用规则（必读）"
echo "2. projectBasicInfo/04_TERMINOLOGY.md - 术语规范（必读）"
echo "3. projectBasicInfo/logs/ - 近期操作日志（了解上下文）"
echo ""
echo "重要提醒："
echo "- 所有计划/日志文件应存放在 projectBasicInfo/logs/ 目录"
echo "- 日志命名格式：YYYY-MM-DD-英文主题-角色.md"
echo "- UI 文案使用「观之」，代码使用 Share"
echo ""
echo "=== 请确认已阅读项目规则后再开始工作 ==="

exit 0
