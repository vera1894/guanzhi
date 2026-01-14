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
echo ""
echo "【任务专用文档】"
echo ""
echo "后端开发（写 Java 代码）："
echo "  → Server/onettoo/重要项目信息/项目结构说明.md"
echo ""
echo "后端部署（部署 JAR 到服务器）："
echo "  → projectBasicInfo/05_DEPLOYMENT_SSOT.md（部署操作 SSOT）"
echo "  → projectBasicInfo/02_CONNECTIONS.private.md（连接信息）"
echo ""
echo "服务器操作（Nginx/MySQL/排查问题）："
echo "  → projectBasicInfo/99_SERVER_OPERATIONS_RULES.md"
echo ""

exit 0
