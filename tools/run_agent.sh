#!/bin/bash
#
# Agent 启动器
#
# 功能：管理 Agent 任务的生命周期（准备、执行、完成）
# 版本：v0.1.0
# 创建日期：2026-02-03

set -euo pipefail

# ==================== 配置 ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GUARD_SCRIPT="$SCRIPT_DIR/agent_guard.sh"
SCHEMA_DIR="$REPO_ROOT/projectBasicInfo/agent-schema"
CONTEXT_DIR="$REPO_ROOT/.task-contexts"

# 确保上下文目录存在
mkdir -p "$CONTEXT_DIR"

# ==================== 工具函数 ====================

info() {
    echo "ℹ️  $*"
}

success() {
    echo "✅ $*"
}

warn() {
    echo "⚠️  $*"
}

error() {
    echo "❌ $*" >&2
}

# 检查依赖
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it first:"
        error "  macOS: brew install jq"
        error "  Linux: sudo apt-get install jq"
        exit 3
    fi

    if [[ ! -x "$GUARD_SCRIPT" ]]; then
        error "agent_guard.sh not found or not executable: $GUARD_SCRIPT"
        exit 3
    fi
}

# 解析 task-input JSON
parse_task_input() {
    local input_file="$1"

    if [[ ! -f "$input_file" ]]; then
        error "Task input file not found: $input_file"
        exit 2
    fi

    # 验证 JSON 格式
    if ! jq empty "$input_file" 2>/dev/null; then
        error "Invalid JSON format: $input_file"
        exit 2
    fi

    # 提取必需字段
    TASK_ID=$(jq -r '.task_id // empty' "$input_file")
    RUN_ID=$(jq -r '.run_id // empty' "$input_file")
    WORKSPACE=$(jq -r '.workspace // empty' "$input_file")
    ACTOR=$(jq -r '.actor // empty' "$input_file")
    TASK_TYPE=$(jq -r '.task_type // empty' "$input_file")
    SCHEMA_VERSION=$(jq -r '.schema_version // "1.0.0"' "$input_file")
    TIMESTAMP=$(jq -r '.timestamp // empty' "$input_file")

    # 提取 input 详情
    DESCRIPTION=$(jq -r '.input.description // empty' "$input_file")
    FILES=$(jq -r '.input.files // [] | join(",")' "$input_file")
    LOCK_MODE=$(jq -r '.input.constraints.lock_mode // "automated"' "$input_file")
    READ_ONLY=$(jq -r '.input.constraints.read_only // false' "$input_file")
    TIMEOUT=$(jq -r '.input.constraints.timeout // 3600' "$input_file")

    # 验证必需字段
    local missing_fields=()
    [[ -z "$TASK_ID" ]] && missing_fields+=("task_id")
    [[ -z "$RUN_ID" ]] && missing_fields+=("run_id")
    [[ -z "$WORKSPACE" ]] && missing_fields+=("workspace")
    [[ -z "$ACTOR" ]] && missing_fields+=("actor")
    [[ -z "$TASK_TYPE" ]] && missing_fields+=("task_type")
    [[ -z "$TIMESTAMP" ]] && missing_fields+=("timestamp")

    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        error "Missing required fields: ${missing_fields[*]}"
        exit 2
    fi
}

# 获取任务上下文文件路径
get_context_file() {
    local task_id="$1"
    echo "$CONTEXT_DIR/${task_id}.context.json"
}

# ==================== 任务准备 ====================

cmd_prepare() {
    local input_file="$1"

    info "========================================="
    info "准备任务执行环境"
    info "========================================="
    echo ""

    # 解析任务输入
    info "解析任务输入: $(basename "$input_file")"
    parse_task_input "$input_file"
    success "任务输入解析完成"
    echo ""

    # 显示任务信息
    info "任务信息:"
    info "  Task ID:    $TASK_ID"
    info "  Run ID:     $RUN_ID"
    info "  Workspace:  $WORKSPACE"
    info "  Actor:      $ACTOR"
    info "  Task Type:  $TASK_TYPE"
    info "  Lock Mode:  $LOCK_MODE"
    info "  Read Only:  $READ_ONLY"
    echo ""
    info "任务描述:"
    echo "  $DESCRIPTION"
    echo ""

    if [[ -n "$FILES" ]]; then
        info "相关文件:"
        IFS=',' read -ra FILE_ARRAY <<< "$FILES"
        for file in "${FILE_ARRAY[@]}"; do
            info "  - $file"
        done
        echo ""
    fi

    # 获取锁（如果需要）
    if [[ "$LOCK_MODE" != "none" ]]; then
        info "获取 workspace 锁..."
        if "$GUARD_SCRIPT" --acquire-lock --workspace="$WORKSPACE" \
            --actor="$ACTOR" --task-id="$TASK_ID" --lock-mode="$LOCK_MODE"; then
            success "成功获取 $WORKSPACE workspace 锁"
        else
            error "无法获取 workspace 锁（可能被其他任务占用）"
            exit 1
        fi
        echo ""
    else
        info "任务模式: 无锁模式 (read-only)"
        echo ""
    fi

    # 保存任务上下文
    local context_file
    context_file=$(get_context_file "$TASK_ID")

    cat > "$context_file" <<EOF
{
  "task_id": "$TASK_ID",
  "run_id": "$RUN_ID",
  "workspace": "$WORKSPACE",
  "actor": "$ACTOR",
  "task_type": "$TASK_TYPE",
  "schema_version": "$SCHEMA_VERSION",
  "start_timestamp": "$TIMESTAMP",
  "lock_mode": "$LOCK_MODE",
  "input_file": "$input_file",
  "status": "in_progress"
}
EOF

    success "任务上下文已保存: $context_file"
    echo ""

    # 显示下一步操作
    info "========================================="
    info "下一步操作"
    info "========================================="
    echo ""
    info "1. 在 Claude Code 中执行任务:"
    echo "   - 任务描述: $DESCRIPTION"
    if [[ -n "$FILES" ]]; then
        echo "   - 相关文件: $FILES"
    fi
    echo ""
    info "2. 任务完成后运行:"
    echo "   ./run_agent.sh --complete --task-id=\"$TASK_ID\" \\"
    echo "     --status=<completed|partial|failed> \\"
    echo "     --conclusion=\"任务结论\""
    echo ""
    info "3. 如需取消任务:"
    echo "   ./run_agent.sh --cancel --task-id=\"$TASK_ID\""
    echo ""
}

# ==================== 任务完成 ====================

cmd_complete() {
    local task_id="$1"
    local status="${2:-completed}"
    local conclusion="${3:-}"
    local evidence_file="${4:-}"

    info "========================================="
    info "完成任务并释放资源"
    info "========================================="
    echo ""

    # 读取任务上下文
    local context_file
    context_file=$(get_context_file "$task_id")

    if [[ ! -f "$context_file" ]]; then
        error "任务上下文文件不存在: $context_file"
        error "请先运行 --prepare 准备任务"
        exit 2
    fi

    # 解析上下文
    local workspace actor lock_mode input_file
    workspace=$(jq -r '.workspace' "$context_file")
    actor=$(jq -r '.actor' "$context_file")
    lock_mode=$(jq -r '.lock_mode' "$context_file")
    input_file=$(jq -r '.input_file' "$context_file")

    info "任务信息:"
    info "  Task ID:   $task_id"
    info "  Workspace: $workspace"
    info "  Status:    $status"
    echo ""

    # 验证 status 有效性
    case "$status" in
        completed|partial|failed|skipped)
            ;;
        *)
            error "Invalid status: $status (must be: completed, partial, failed, skipped)"
            exit 2
            ;;
    esac

    # 生成 task-output JSON
    local output_file="$REPO_ROOT/.task-outputs/${task_id}-output.json"
    mkdir -p "$REPO_ROOT/.task-outputs"

    local end_timestamp
    end_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 基础输出结构
    local output_json
    output_json=$(jq -n \
        --arg task_id "$task_id" \
        --arg run_id "$(jq -r '.run_id' "$context_file")" \
        --arg workspace "$workspace" \
        --arg actor "$actor" \
        --arg task_type "$(jq -r '.task_type' "$context_file")" \
        --arg schema_version "$(jq -r '.schema_version' "$context_file")" \
        --arg timestamp "$end_timestamp" \
        --arg status "$status" \
        --arg conclusion "$conclusion" \
        '{
            task_id: $task_id,
            run_id: $run_id,
            workspace: $workspace,
            actor: $actor,
            task_type: $task_type,
            schema_version: $schema_version,
            timestamp: $timestamp,
            output: {
                status: $status,
                conclusion: $conclusion,
                evidence: [],
                risk: [],
                next_steps: []
            }
        }')

    # 如果提供了 evidence 文件，合并进去
    if [[ -n "$evidence_file" ]] && [[ -f "$evidence_file" ]]; then
        info "合并 evidence 数据: $(basename "$evidence_file")"
        output_json=$(echo "$output_json" | jq --slurpfile evidence "$evidence_file" \
            '.output.evidence = $evidence[0].evidence // []' \
            '| .output.risk = $evidence[0].risk // []' \
            '| .output.next_steps = $evidence[0].next_steps // []' \
            '| .output.result = $evidence[0].result // {}')
    fi

    # 写入输出文件
    echo "$output_json" | jq '.' > "$output_file"
    success "Task output 已生成: $output_file"
    echo ""

    # 释放锁（如果需要）
    if [[ "$lock_mode" != "none" ]]; then
        info "释放 workspace 锁..."
        if "$GUARD_SCRIPT" --release-lock --workspace="$workspace" \
            --actor="$actor" --task-id="$task_id" --force; then
            success "成功释放 $workspace workspace 锁"
        else
            warn "释放锁失败（锁可能已被抢占或超时）"
        fi
        echo ""
    fi

    # 清理上下文文件
    rm -f "$context_file"
    success "任务上下文已清理"
    echo ""

    success "========================================="
    success "任务完成"
    success "========================================="
    echo ""
    info "输出文件: $output_file"
    echo ""
}

# ==================== 任务取消 ====================

cmd_cancel() {
    local task_id="$1"
    local reason="${2:-User cancelled}"

    info "========================================="
    info "取消任务"
    info "========================================="
    echo ""

    # 读取任务上下文
    local context_file
    context_file=$(get_context_file "$task_id")

    if [[ ! -f "$context_file" ]]; then
        error "任务上下文文件不存在: $context_file"
        exit 2
    fi

    # 解析上下文
    local workspace actor lock_mode
    workspace=$(jq -r '.workspace' "$context_file")
    actor=$(jq -r '.actor' "$context_file")
    lock_mode=$(jq -r '.lock_mode' "$context_file")

    info "取消任务: $task_id"
    info "原因: $reason"
    echo ""

    # 释放锁（如果需要）
    if [[ "$lock_mode" != "none" ]]; then
        info "释放 workspace 锁..."
        "$GUARD_SCRIPT" --release-lock --workspace="$workspace" \
            --actor="$actor" --task-id="$task_id" --force || true
        success "锁已释放"
        echo ""
    fi

    # 清理上下文文件
    rm -f "$context_file"
    success "任务上下文已清理"
    echo ""

    success "任务已取消"
}

# ==================== 主函数 ====================

usage() {
    cat <<EOF
用法: run_agent.sh <command> [options]

命令:
  --prepare         准备任务执行环境（获取锁，显示任务信息）
  --complete        完成任务并释放资源（释放锁，生成输出）
  --cancel          取消任务并释放资源

准备任务选项:
  --input=<file>    任务输入 JSON 文件（必需）

完成任务选项:
  --task-id=<id>         任务 ID（必需）
  --status=<status>      任务状态 (completed/partial/failed/skipped，默认: completed)
  --conclusion=<text>    任务结论（1-2 句话摘要）
  --evidence=<file>      Evidence JSON 文件（可选）

取消任务选项:
  --task-id=<id>    任务 ID（必需）
  --reason=<text>   取消原因（可选）

示例:
  # 1. 准备任务
  ./run_agent.sh --prepare --input=task-input.json

  # 2. 在 Claude Code 中执行任务
  # ... 完成任务 ...

  # 3. 完成任务（简单模式）
  ./run_agent.sh --complete --task-id=bug-fix-123 \\
    --status=completed --conclusion="Bug fixed by disabling interaction"

  # 4. 完成任务（带 evidence）
  ./run_agent.sh --complete --task-id=bug-fix-123 \\
    --status=completed --conclusion="Bug fixed" --evidence=evidence.json

  # 5. 取消任务
  ./run_agent.sh --cancel --task-id=bug-fix-123
EOF
}

main() {
    # 检查依赖
    check_dependencies

    # 解析命令
    local command=""
    local input_file=""
    local task_id=""
    local status="completed"
    local conclusion=""
    local evidence_file=""
    local reason="User cancelled"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prepare)
                command="prepare"
                shift
                ;;
            --complete)
                command="complete"
                shift
                ;;
            --cancel)
                command="cancel"
                shift
                ;;
            --input=*)
                input_file="${1#*=}"
                shift
                ;;
            --task-id=*)
                task_id="${1#*=}"
                shift
                ;;
            --status=*)
                status="${1#*=}"
                shift
                ;;
            --conclusion=*)
                conclusion="${1#*=}"
                shift
                ;;
            --evidence=*)
                evidence_file="${1#*=}"
                shift
                ;;
            --reason=*)
                reason="${1#*=}"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # 执行命令
    case "$command" in
        prepare)
            if [[ -z "$input_file" ]]; then
                error "Missing required option: --input"
                usage
                exit 1
            fi
            cmd_prepare "$input_file"
            ;;
        complete)
            if [[ -z "$task_id" ]]; then
                error "Missing required option: --task-id"
                usage
                exit 1
            fi
            cmd_complete "$task_id" "$status" "$conclusion" "$evidence_file"
            ;;
        cancel)
            if [[ -z "$task_id" ]]; then
                error "Missing required option: --task-id"
                usage
                exit 1
            fi
            cmd_cancel "$task_id" "$reason"
            ;;
        *)
            error "No command specified"
            usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
