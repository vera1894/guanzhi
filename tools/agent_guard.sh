#!/bin/bash
#
# Agent Guard - Agent 协作权限守护脚本
#
# 功能：
# 1. 检测跨 workspace 写入操作
# 2. 验证 Agent 是否有权限操作目标文件
# 3. 检查锁冲突
#
# 退出码：
#   0 - 检查通过
#   1 - 未授权操作（跨 workspace 写入）
#   2 - 锁冲突
#   3 - 参数错误或脚本内部错误
#
# 版本：v0.1.0 (骨架版本)
# 创建日期：2026-02-03
# 兼容性：bash 3.2+ (macOS 默认版本)

set -euo pipefail

# ==================== 配置区 ====================

# 仓库根目录（包含 .git/ 的目录）
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Workspace 定义（使用函数代替关联数组以兼容 bash 3.x）
get_workspace_patterns() {
    local workspace="$1"
    case "$workspace" in
        ios)
            echo "guanzhi/|Podfile|.xcodeproj|.xcworkspace|Pods/|Assets.xcassets"
            ;;
        backend)
            echo "Server/onettoo/"
            ;;
        admin-web)
            echo "admin-web/"
            ;;
        meta)
            echo "projectBasicInfo/|.claude/|重要项目信息/|tools/|.githooks/"
            ;;
        *)
            return 1
            ;;
    esac
}

# 获取所有有效的 workspace 名称
get_valid_workspaces() {
    echo "ios backend admin-web meta"
}

# 权限例外目录（所有 Agent 可写）
EXCEPTION_DIRS=(
    "projectBasicInfo/logs/"
    ".locks/"
)

# ==================== 工具函数 ====================

# 打印错误信息到 stderr
error() {
    echo "❌ [agent_guard] $*" >&2
}

# 打印警告信息到 stderr
warn() {
    echo "⚠️  [agent_guard] $*" >&2
}

# 打印信息到 stderr
info() {
    echo "ℹ️  [agent_guard] $*" >&2
}

# 显示使用说明
usage() {
    cat <<EOF
用法: agent_guard.sh [选项]

选项:
  --check-write           检查写入权限
  --workspace=<name>      指定 Agent 所属 workspace (ios|backend|admin-web|meta)
  --files=<paths>         要检查的文件路径列表（逗号分隔，相对于仓库根）
  --actor=<agent_id>      Agent 标识符（如 cc, gpt, infrastructure 等）
  --help                  显示此帮助信息

示例:
  # 检查 iOS Agent 是否可以写入指定文件
  ./agent_guard.sh --check-write --workspace=ios \\
    --files="guanzhi/View/FrontPages/SearchView.swift" --actor=cc

  # 检查多个文件
  ./agent_guard.sh --check-write --workspace=ios \\
    --files="guanzhi/View/A.swift,guanzhi/View/B.swift" --actor=cc

退出码:
  0 - 检查通过
  1 - 未授权操作（跨 workspace 写入）
  2 - 锁冲突
  3 - 参数错误或脚本内部错误
EOF
}

# 检查文件是否属于指定 workspace
# 参数: $1=文件路径(相对仓库根), $2=workspace名称
file_belongs_to_workspace() {
    local file_path="$1"
    local workspace="$2"

    # 获取 workspace 的路径模式
    local patterns
    patterns=$(get_workspace_patterns "$workspace") || return 1

    # 将模式字符串拆分为数组（以 | 分隔）
    local IFS='|'
    local pattern_array=($patterns)

    # 检查文件是否匹配任一模式
    for pattern in "${pattern_array[@]}"; do
        # 简单的前缀匹配和模糊匹配
        pattern="${pattern%/}"  # 移除末尾的 /

        # 如果模式以 . 开头（如 .xcodeproj），匹配包含该扩展名的路径
        if [[ "$pattern" == .* ]]; then
            if [[ "$file_path" == *"$pattern"* ]]; then
                return 0  # 属于
            fi
        # 否则使用前缀匹配
        elif [[ "$file_path" == "$pattern"* ]]; then
            return 0  # 属于
        fi
    done

    return 1  # 不属于
}

# 检查文件是否在权限例外目录中
# 参数: $1=文件路径(相对仓库根)
is_exception_path() {
    local file_path="$1"

    for exception_dir in "${EXCEPTION_DIRS[@]}"; do
        exception_dir="${exception_dir%/}"  # 移除末尾的 /
        if [[ "$file_path" == "$exception_dir"* ]]; then
            return 0  # 是例外路径
        fi
    done

    return 1  # 不是例外路径
}

# 检查跨 workspace 写入
# 参数: $1=Agent workspace, $2=文件路径列表（逗号分隔）
check_cross_workspace_write() {
    local agent_workspace="$1"
    local files="$2"
    local has_violation=0

    # 分割文件路径列表
    IFS=',' read -ra file_array <<< "$files"

    for file_path in "${file_array[@]}"; do
        # 去除前后空格
        file_path="${file_path## }"
        file_path="${file_path%% }"

        # 跳过空路径
        [[ -z "$file_path" ]] && continue

        # 检查是否为例外路径
        if is_exception_path "$file_path"; then
            info "✓ $file_path (例外目录，允许所有 Agent 写入)"
            continue
        fi

        # 检查是否属于 Agent 的 workspace
        if file_belongs_to_workspace "$file_path" "$agent_workspace"; then
            info "✓ $file_path (属于 $agent_workspace workspace)"
        else
            # 跨 workspace 写入
            error "✗ $file_path (不属于 $agent_workspace workspace)"
            has_violation=1
        fi
    done

    return $has_violation
}

# ==================== 主逻辑 ====================

main() {
    local mode=""
    local workspace=""
    local files=""
    local actor=""

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check-write)
                mode="check-write"
                shift
                ;;
            --workspace=*)
                workspace="${1#*=}"
                shift
                ;;
            --files=*)
                files="${1#*=}"
                shift
                ;;
            --actor=*)
                actor="${1#*=}"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error "未知参数: $1"
                usage
                exit 3
                ;;
        esac
    done

    # 验证必需参数
    if [[ "$mode" != "check-write" ]]; then
        error "必须指定 --check-write 模式"
        usage
        exit 3
    fi

    if [[ -z "$workspace" ]]; then
        error "必须指定 --workspace 参数"
        usage
        exit 3
    fi

    if [[ -z "$files" ]]; then
        error "必须指定 --files 参数"
        usage
        exit 3
    fi

    if [[ -z "$actor" ]]; then
        error "必须指定 --actor 参数"
        usage
        exit 3
    fi

    # 验证 workspace 是否有效
    if ! get_workspace_patterns "$workspace" > /dev/null 2>&1; then
        error "无效的 workspace: $workspace"
        error "有效的 workspace: $(get_valid_workspaces)"
        exit 3
    fi

    # 执行检查
    info "检查 Agent [$actor] 对以下文件的写入权限 (workspace: $workspace):"

    if check_cross_workspace_write "$workspace" "$files"; then
        info "✅ 权限检查通过"
        exit 0
    else
        error "❌ 检测到跨 workspace 写入，操作被拒绝"
        exit 1
    fi
}

# 执行主函数
main "$@"
