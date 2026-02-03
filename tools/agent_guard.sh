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
# 版本：v0.2.0 (添加锁机制)
# 创建日期：2026-02-03
# 最后更新：2026-02-03
# 兼容性：bash 3.2+ (macOS 默认版本)

set -euo pipefail

# ==================== 配置区 ====================

# 仓库根目录（包含 .git/ 的目录）
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 锁目录
LOCK_DIR="$REPO_ROOT/.locks"

# 锁超时时间（秒）
LOCK_TIMEOUT_AUTOMATED=300    # automated 模式：5 分钟
LOCK_TIMEOUT_INTERACTIVE=1200  # interactive 模式：20 分钟

# Heartbeat 间隔（秒）
HEARTBEAT_INTERVAL_AUTOMATED=60        # automated 模式：60 秒
HEARTBEAT_INTERVAL_INTERACTIVE=600     # interactive 模式：10 分钟

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
  # 权限检查
  --check-write           检查写入权限
  --workspace=<name>      指定 Agent 所属 workspace (ios|backend|admin-web|meta)
  --files=<paths>         要检查的文件路径列表（逗号分隔，相对于仓库根）
  --actor=<agent_id>      Agent 标识符（如 cc, gpt, infrastructure 等）

  # 锁管理
  --acquire-lock          获取 workspace 锁
  --release-lock          释放 workspace 锁
  --check-lock            检查 workspace 锁状态
  --update-heartbeat      更新锁的 heartbeat（保持锁活跃）
  --task-id=<id>          任务 ID（用于锁标识）
  --lock-mode=<mode>      锁模式（automated|interactive，默认 automated）

  # 其他
  --help                  显示此帮助信息

示例:
  # 检查 iOS Agent 是否可以写入指定文件
  ./agent_guard.sh --check-write --workspace=ios \\
    --files="guanzhi/View/FrontPages/SearchView.swift" --actor=cc

  # 检查多个文件
  ./agent_guard.sh --check-write --workspace=ios \\
    --files="guanzhi/View/A.swift,guanzhi/View/B.swift" --actor=cc

  # 获取 iOS workspace 锁
  ./agent_guard.sh --acquire-lock --workspace=ios \\
    --actor=cc --task-id=task-123 --lock-mode=automated

  # 释放 iOS workspace 锁
  ./agent_guard.sh --release-lock --workspace=ios \\
    --actor=cc --task-id=task-123

  # 检查锁状态
  ./agent_guard.sh --check-lock --workspace=ios

  # 更新 heartbeat（保持锁活跃）
  ./agent_guard.sh --update-heartbeat --workspace=ios

退出码:
  0 - 检查通过/操作成功
  1 - 未授权操作（跨 workspace 写入）
  2 - 锁冲突（锁已被占用）
  3 - 参数错误或脚本内部错误
EOF
}

# ==================== 锁管理函数 ====================

# 获取当前时间戳（ISO 8601 格式）
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# 获取当前时间的 Unix 时间戳（UTC）
get_unix_timestamp() {
    date -u +%s
}

# 解析 ISO 8601 时间戳为 Unix 时间戳（UTC）
parse_timestamp() {
    local iso_timestamp="$1"
    # macOS 和 Linux 的 date 命令不同，兼容处理
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        date -u -d "$iso_timestamp" +%s 2>/dev/null || echo "0"
    else
        # BSD date (macOS) - 需要 -u 选项指定 UTC
        date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso_timestamp" +%s 2>/dev/null || \
        date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "$iso_timestamp" +%s 2>/dev/null || echo "0"
    fi
}

# 获取锁文件路径
get_lock_path() {
    local workspace="$1"
    echo "$LOCK_DIR/${workspace}.lock"
}

# 检查锁是否存在
# 返回: 0=存在, 1=不存在
check_lock_exists() {
    local workspace="$1"
    local lock_file
    lock_file=$(get_lock_path "$workspace")

    [[ -f "$lock_file" ]]
}

# 读取锁信息
# 参数: $1=workspace
# 输出: JSON 字符串（如果锁存在）
read_lock() {
    local workspace="$1"
    local lock_file
    lock_file=$(get_lock_path "$workspace")

    if [[ -f "$lock_file" ]]; then
        cat "$lock_file"
    else
        echo ""
    fi
}

# 检查锁是否为僵尸锁
# 参数: $1=workspace
# 返回: 0=是僵尸锁, 1=不是僵尸锁
is_zombie_lock() {
    local workspace="$1"
    local lock_content
    lock_content=$(read_lock "$workspace")

    if [[ -z "$lock_content" ]]; then
        return 1  # 锁不存在，不是僵尸锁
    fi

    # 提取锁信息（简单的 JSON 解析，兼容 bash 3.x）
    local lock_mode heartbeat_at
    lock_mode=$(echo "$lock_content" | grep -o '"lock_mode": *"[^"]*"' | sed 's/.*": *"\([^"]*\)".*/\1/')
    heartbeat_at=$(echo "$lock_content" | grep -o '"heartbeat_at": *"[^"]*"' | sed 's/.*": *"\([^"]*\)".*/\1/')

    if [[ -z "$heartbeat_at" ]]; then
        warn "锁文件格式错误（缺少 heartbeat_at），视为僵尸锁"
        return 0
    fi

    # 计算超时时间
    local timeout
    if [[ "$lock_mode" == "interactive" ]]; then
        timeout=$LOCK_TIMEOUT_INTERACTIVE
    else
        timeout=$LOCK_TIMEOUT_AUTOMATED
    fi

    # 计算心跳时间差
    local heartbeat_unix current_unix time_diff
    heartbeat_unix=$(parse_timestamp "$heartbeat_at")
    current_unix=$(get_unix_timestamp)
    time_diff=$((current_unix - heartbeat_unix))

    if [[ "$time_diff" -gt "$timeout" ]]; then
        return 0  # 是僵尸锁
    else
        return 1  # 不是僵尸锁
    fi
}

# 获取锁持有者信息
# 参数: $1=workspace
# 输出: "actor (task_id)"
get_lock_holder() {
    local workspace="$1"
    local lock_content
    lock_content=$(read_lock "$workspace")

    if [[ -z "$lock_content" ]]; then
        echo "无"
        return
    fi

    local actor task_id
    actor=$(echo "$lock_content" | grep -o '"actor": *"[^"]*"' | sed 's/.*": *"\([^"]*\)".*/\1/')
    task_id=$(echo "$lock_content" | grep -o '"task_id": *"[^"]*"' | sed 's/.*": *"\([^"]*\)".*/\1/')

    echo "${actor:-unknown} (${task_id:-unknown})"
}

# 获取锁模式
# 参数: $1=workspace
# 输出: "automated" 或 "interactive"
get_lock_mode() {
    local workspace="$1"
    local lock_content
    lock_content=$(read_lock "$workspace")

    if [[ -z "$lock_content" ]]; then
        echo ""
        return
    fi

    echo "$lock_content" | grep -o '"lock_mode": *"[^"]*"' | sed 's/.*": *"\([^"]*\)".*/\1/'
}

# 获取锁（原子操作）
# 参数: $1=workspace, $2=actor, $3=task_id, $4=lock_mode
# 返回: 0=成功, 1=失败（已被占用）
acquire_lock() {
    local workspace="$1"
    local actor="$2"
    local task_id="$3"
    local lock_mode="${4:-automated}"

    # 确保锁目录存在
    mkdir -p "$LOCK_DIR"

    local lock_file
    lock_file=$(get_lock_path "$workspace")

    # 检查锁是否已存在
    if check_lock_exists "$workspace"; then
        # 检查是否为僵尸锁
        if is_zombie_lock "$workspace"; then
            local holder
            holder=$(get_lock_holder "$workspace")
            local old_mode
            old_mode=$(get_lock_mode "$workspace")

            # interactive 锁需要显式确认才能抢占
            if [[ "$old_mode" == "interactive" ]]; then
                warn "检测到 interactive 模式的僵尸锁"
                warn "锁持有者: $holder"
                warn "interactive 锁需要人工确认才能抢占"
                return 1
            fi

            info "检测到 automated 模式的僵尸锁，抢占中..."
            info "原持有者: $holder"

            # 删除僵尸锁
            rm -f "$lock_file"
        else
            # 锁仍然有效
            return 1
        fi
    fi

    # 生成锁内容
    local timestamp
    timestamp=$(get_timestamp)
    local hostname
    hostname=$(hostname)

    local lock_content
    lock_content=$(cat <<EOF
{
  "task_id": "$task_id",
  "actor": "$actor",
  "lock_mode": "$lock_mode",
  "holder_pid": $$,
  "host": "$hostname",
  "started_at": "$timestamp",
  "heartbeat_at": "$timestamp",
  "workspace": "$workspace"
}
EOF
)

    # 原子获取锁（使用 mv -n）
    local temp_file="$LOCK_DIR/.tmp.lock.$$"
    echo "$lock_content" > "$temp_file"

    if mv -n "$temp_file" "$lock_file" 2>/dev/null; then
        # 获取成功
        return 0
    else
        # 获取失败（被其他进程抢占）
        rm -f "$temp_file"
        return 1
    fi
}

# 释放锁
# 参数: $1=workspace, $2=actor, $3=task_id
# 返回: 0=成功, 1=失败（锁不属于当前进程）
release_lock() {
    local workspace="$1"
    local actor="$2"
    local task_id="$3"

    local lock_file
    lock_file=$(get_lock_path "$workspace")

    if [[ ! -f "$lock_file" ]]; then
        warn "锁文件不存在: $workspace"
        return 0  # 锁已不存在，视为成功
    fi

    # 读取锁信息
    local lock_content
    lock_content=$(read_lock "$workspace")

    # 验证锁持有者
    local lock_actor lock_pid lock_host
    lock_actor=$(echo "$lock_content" | grep -o '"actor": *"[^"]*"' | sed 's/.*": *"\([^"]*\)".*/\1/')
    lock_pid=$(echo "$lock_content" | grep -o '"holder_pid": *[0-9]*' | sed 's/.*: *\([0-9]*\).*/\1/')
    lock_host=$(echo "$lock_content" | grep -o '"host": *"[^"]*"' | sed 's/.*": *"\([^"]*\)".*/\1/')

    local current_host
    current_host=$(hostname)

    # 检查是否有权释放锁
    if [[ "$lock_actor" != "$actor" ]] || \
       [[ "$lock_pid" != "$$" ]] || \
       [[ "$lock_host" != "$current_host" ]]; then
        error "无权释放锁: $workspace"
        error "锁持有者: $lock_actor (PID $lock_pid @ $lock_host)"
        error "当前进程: $actor (PID $$ @ $current_host)"
        return 1
    fi

    # 删除锁文件
    rm -f "$lock_file"
    info "锁已释放: $workspace"
    return 0
}

# 更新锁的 heartbeat
# 参数: $1=workspace
# 返回: 0=成功, 1=失败
update_lock_heartbeat() {
    local workspace="$1"

    local lock_file
    lock_file=$(get_lock_path "$workspace")

    if [[ ! -f "$lock_file" ]]; then
        warn "锁文件不存在: $workspace"
        return 1
    fi

    # 读取现有锁内容
    local lock_content
    lock_content=$(read_lock "$workspace")

    # 更新 heartbeat_at 字段
    local timestamp
    timestamp=$(get_timestamp)

    local updated_content
    updated_content=$(echo "$lock_content" | sed "s/\"heartbeat_at\": *\"[^\"]*\"/\"heartbeat_at\": \"$timestamp\"/")

    # 写入更新后的内容
    echo "$updated_content" > "$lock_file"
    return 0
}

# ==================== Workspace 权限检查函数 ====================

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
    local task_id=""
    local lock_mode="automated"

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check-write)
                mode="check-write"
                shift
                ;;
            --acquire-lock)
                mode="acquire-lock"
                shift
                ;;
            --release-lock)
                mode="release-lock"
                shift
                ;;
            --check-lock)
                mode="check-lock"
                shift
                ;;
            --update-heartbeat)
                mode="update-heartbeat"
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
            --task-id=*)
                task_id="${1#*=}"
                shift
                ;;
            --lock-mode=*)
                lock_mode="${1#*=}"
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
    if [[ -z "$mode" ]]; then
        error "必须指定操作模式（--check-write, --acquire-lock, --release-lock, --check-lock, --update-heartbeat）"
        usage
        exit 3
    fi

    # 验证 workspace 参数（所有模式都需要）
    if [[ -z "$workspace" ]]; then
        error "必须指定 --workspace 参数"
        usage
        exit 3
    fi

    # 验证 workspace 是否有效
    if ! get_workspace_patterns "$workspace" > /dev/null 2>&1; then
        error "无效的 workspace: $workspace"
        error "有效的 workspace: $(get_valid_workspaces)"
        exit 3
    fi

    # 根据模式执行不同的操作
    case "$mode" in
        check-write)
            # 验证 check-write 模式的必需参数
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

            # 执行权限检查
            info "检查 Agent [$actor] 对以下文件的写入权限 (workspace: $workspace):"

            if check_cross_workspace_write "$workspace" "$files"; then
                info "✅ 权限检查通过"
                exit 0
            else
                error "❌ 检测到跨 workspace 写入，操作被拒绝"
                exit 1
            fi
            ;;

        acquire-lock)
            # 验证 acquire-lock 模式的必需参数
            if [[ -z "$actor" ]]; then
                error "必须指定 --actor 参数"
                usage
                exit 3
            fi

            if [[ -z "$task_id" ]]; then
                error "必须指定 --task-id 参数"
                usage
                exit 3
            fi

            # 验证 lock_mode
            if [[ "$lock_mode" != "automated" ]] && [[ "$lock_mode" != "interactive" ]]; then
                error "无效的 lock_mode: $lock_mode （必须是 automated 或 interactive）"
                exit 3
            fi

            # 尝试获取锁
            info "尝试获取 $workspace workspace 锁 (actor: $actor, task: $task_id, mode: $lock_mode)"

            if acquire_lock "$workspace" "$actor" "$task_id" "$lock_mode"; then
                info "✅ 锁获取成功: $workspace"
                exit 0
            else
                local holder
                holder=$(get_lock_holder "$workspace")
                error "❌ 锁冲突：$workspace workspace 已被占用"
                error "当前持有者: $holder"
                exit 2
            fi
            ;;

        release-lock)
            # 验证 release-lock 模式的必需参数
            if [[ -z "$actor" ]]; then
                error "必须指定 --actor 参数"
                usage
                exit 3
            fi

            if [[ -z "$task_id" ]]; then
                error "必须指定 --task-id 参数"
                usage
                exit 3
            fi

            # 尝试释放锁
            info "尝试释放 $workspace workspace 锁 (actor: $actor, task: $task_id)"

            if release_lock "$workspace" "$actor" "$task_id"; then
                info "✅ 锁释放成功: $workspace"
                exit 0
            else
                error "❌ 锁释放失败"
                exit 3
            fi
            ;;

        check-lock)
            # 检查锁状态
            info "检查 $workspace workspace 锁状态:"

            if check_lock_exists "$workspace"; then
                local holder mode_info
                holder=$(get_lock_holder "$workspace")
                mode_info=$(get_lock_mode "$workspace")

                if is_zombie_lock "$workspace"; then
                    warn "⚠️  锁存在但已过期（僵尸锁）"
                    warn "持有者: $holder"
                    warn "模式: $mode_info"
                    exit 2
                else
                    info "🔒 锁已被占用"
                    info "持有者: $holder"
                    info "模式: $mode_info"
                    exit 2
                fi
            else
                info "✅ 锁空闲"
                exit 0
            fi
            ;;

        update-heartbeat)
            # 更新锁的 heartbeat
            info "更新 $workspace workspace 锁的 heartbeat"

            if ! check_lock_exists "$workspace"; then
                error "锁不存在: $workspace"
                exit 3
            fi

            if update_lock_heartbeat "$workspace"; then
                info "✅ Heartbeat 更新成功"
                exit 0
            else
                error "❌ Heartbeat 更新失败"
                exit 3
            fi
            ;;

        *)
            error "未知模式: $mode"
            usage
            exit 3
            ;;
    esac
}

# 执行主函数
main "$@"
