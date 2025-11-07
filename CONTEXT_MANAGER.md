# 项目上下文管理工具

## 概述
此工具用于维护和更新项目的状态信息，确保新的Claude Code实例能够快速了解项目的当前状态和上下文。

## 使用方法

### 更新项目状态
当项目有重要更新时，运行以下命令更新上下文：

```bash
# 更新项目上下文（需要手动编辑状态信息）
./update_context.sh

# 或者直接运行（会自动收集一些基本信息）
./update_context.sh auto
```

### 查看当前项目状态
```bash
# 查看当前项目上下文
cat PROJECT_CONTEXT.md
```

## 上下文信息包含内容

1. 项目基本信息（名称、版本、技术栈）
2. 最近的重要变更
3. 当前开发状态
4. 待解决的问题
5. 近期开发计划
6. 重要文件位置索引
7. 开发环境配置要求

## 自动化脚本

### update_context.sh
```bash
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
```

### initialize_context.sh
```bash
#!/bin/bash
# 初始化项目上下文

# 创建上下文文件
echo "# 项目上下文状态" > PROJECT_CONTEXT.md
echo "" >> PROJECT_CONTEXT.md
echo "## 基本信息" >> PROJECT_CONTEXT.md
echo "- 项目名称: guanzhi" >> PROJECT_CONTEXT.md
echo "- 平台: iOS" >> PROJECT_CONTEXT.md
echo "- 技术栈: SwiftUI, Swift, SwiftData" >> PROJECT_CONTEXT.md
echo "" >> PROJECT_CONTEXT.md

echo "## 当前状态" >> PROJECT_CONTEXT.md
echo "初始状态 - 请更新" >> PROJECT_CONTEXT.md
echo "" >> PROJECT_CONTEXT.md

# 创建更新脚本
cat > update_context.sh << 'EOF'
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
EOF

chmod +x update_context.sh

echo "项目上下文管理工具已初始化"