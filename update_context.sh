#!/bin/bash
# 自动更新项目上下文信息

echo "# 项目当前上下文状态" > PROJECT_CONTEXT.md
echo "" >> PROJECT_CONTEXT.md
echo "## 基本信息" >> PROJECT_CONTEXT.md
echo "- 更新时间: $(date)" >> PROJECT_CONTEXT.md
echo "- 项目名称: guanzhi" >> PROJECT_CONTEXT.md
echo "- 当前分支: $(git branch --show-current)" >> PROJECT_CONTEXT.md
echo "" >> PROJECT_CONTEXT.md

echo "## 最近提交" >> PROJECT_CONTEXT.md
git log --oneline -5 >> PROJECT_CONTEXT.md
echo "" >> PROJECT_CONTEXT.md

echo "## 当前状态" >> PROJECT_CONTEXT.md
echo "请在此处手动添加当前开发状态信息" >> PROJECT_CONTEXT.md
echo "" >> PROJECT_CONTEXT.md

echo "## 待办事项" >> PROJECT_CONTEXT.md
echo "请在此处手动添加待解决的问题" >> PROJECT_CONTEXT.md

echo "上下文已更新"
