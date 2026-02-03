#!/bin/bash
#
# Multi-Agent 协调器
#
# 功能：管理多个 Agent 任务的协调执行
# 版本：v0.1.0
# 创建日期：2026-02-03

set -euo pipefail

# ==================== 配置 ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_AGENT_SCRIPT="$SCRIPT_DIR/run_agent.sh"
COORDINATOR_DIR="$REPO_ROOT/.coordinator"

# 确保协调器目录存在
mkdir -p "$COORDINATOR_DIR"

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

    if [[ ! -x "$RUN_AGENT_SCRIPT" ]]; then
        error "run_agent.sh not found or not executable: $RUN_AGENT_SCRIPT"
        exit 3
    fi
}

# 生成协调器 ID
generate_coordinator_id() {
    echo "coordinator-$(date -u +%Y%m%d-%H%M%S)"
}

# 生成 run ID
generate_run_id() {
    echo "run-$(date -u +%Y%m%d-%H%M%S)"
}

# 获取协调器状态文件路径
get_coordinator_state_file() {
    local coordinator_id="$1"
    echo "$COORDINATOR_DIR/${coordinator_id}-state.json"
}

# ==================== 任务准备 ====================

cmd_start() {
    local config_file="$1"

    info "========================================="
    info "启动 Multi-Agent 协调器"
    info "========================================="
    echo ""

    # 验证配置文件
    if [[ ! -f "$config_file" ]]; then
        error "配置文件不存在: $config_file"
        exit 2
    fi

    if ! jq empty "$config_file" 2>/dev/null; then
        error "配置文件格式错误: $config_file"
        exit 2
    fi

    # 解析配置
    local coordinator_id run_id description execution_mode
    coordinator_id=$(jq -r '.coordinator_id // empty' "$config_file")
    run_id=$(jq -r '.run_id // empty' "$config_file")
    description=$(jq -r '.description // empty' "$config_file")
    execution_mode=$(jq -r '.execution_mode // "sequential"' "$config_file")

    # 如果没有提供 ID，自动生成
    if [[ -z "$coordinator_id" ]]; then
        coordinator_id=$(generate_coordinator_id)
    fi

    if [[ -z "$run_id" ]]; then
        run_id=$(generate_run_id)
    fi

    info "协调器信息:"
    info "  Coordinator ID: $coordinator_id"
    info "  Run ID:         $run_id"
    info "  Description:    $description"
    info "  Execution Mode: $execution_mode"
    echo ""

    # 读取任务列表
    local task_count
    task_count=$(jq '.tasks | length' "$config_file")

    if [[ "$task_count" -eq 0 ]]; then
        error "配置文件中没有任务"
        exit 2
    fi

    info "任务列表 ($task_count 个任务):"
    echo ""

    # 创建任务输入文件目录
    local task_inputs_dir="$COORDINATOR_DIR/${coordinator_id}-inputs"
    mkdir -p "$task_inputs_dir"

    # 为每个任务生成 task-input JSON
    local task_states="[]"
    for ((i=0; i<task_count; i++)); do
        local task_id workspace actor task_type
        task_id=$(jq -r ".tasks[$i].task_id" "$config_file")
        workspace=$(jq -r ".tasks[$i].workspace" "$config_file")
        actor=$(jq -r ".tasks[$i].actor" "$config_file")
        task_type=$(jq -r ".tasks[$i].task_type" "$config_file")

        info "任务 #$((i+1)): $task_id"
        info "  Workspace: $workspace"
        info "  Actor:     $actor"
        info "  Type:      $task_type"

        # 生成 task-input JSON
        local task_input_file="$task_inputs_dir/${task_id}-input.json"
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        jq -n \
            --arg task_id "$task_id" \
            --arg run_id "$run_id" \
            --arg workspace "$workspace" \
            --arg actor "$actor" \
            --arg task_type "$task_type" \
            --arg timestamp "$timestamp" \
            --argjson input "$(jq ".tasks[$i].input" "$config_file")" \
            '{
                task_id: $task_id,
                run_id: $run_id,
                workspace: $workspace,
                actor: $actor,
                task_type: $task_type,
                schema_version: "1.0.0",
                timestamp: $timestamp,
                input: $input
            }' > "$task_input_file"

        success "  Generated: $task_input_file"

        # 记录任务状态
        task_states=$(echo "$task_states" | jq \
            --arg task_id "$task_id" \
            --arg input_file "$task_input_file" \
            --arg status "pending" \
            '. += [{
                task_id: $task_id,
                input_file: $input_file,
                status: $status,
                prepared: false,
                completed: false
            }]')

        echo ""
    done

    # 保存协调器状态
    local state_file
    state_file=$(get_coordinator_state_file "$coordinator_id")

    jq -n \
        --arg coordinator_id "$coordinator_id" \
        --arg run_id "$run_id" \
        --arg description "$description" \
        --arg execution_mode "$execution_mode" \
        --arg config_file "$config_file" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --argjson tasks "$task_states" \
        '{
            coordinator_id: $coordinator_id,
            run_id: $run_id,
            description: $description,
            execution_mode: $execution_mode,
            config_file: $config_file,
            start_timestamp: $timestamp,
            status: "started",
            tasks: $tasks
        }' > "$state_file"

    success "协调器状态已保存: $state_file"
    echo ""

    # 显示下一步操作
    info "========================================="
    info "下一步操作"
    info "========================================="
    echo ""
    info "1. 准备所有任务:"
    echo "   ./coordinator.sh --prepare --coordinator-id=\"$coordinator_id\""
    echo ""
    info "2. 查看任务状态:"
    echo "   ./coordinator.sh --status --coordinator-id=\"$coordinator_id\""
    echo ""
    info "3. 生成汇总报告:"
    echo "   ./coordinator.sh --summary --coordinator-id=\"$coordinator_id\""
    echo ""
}

# ==================== 任务准备 ====================

cmd_prepare() {
    local coordinator_id="$1"

    info "========================================="
    info "准备所有任务"
    info "========================================="
    echo ""

    # 读取协调器状态
    local state_file
    state_file=$(get_coordinator_state_file "$coordinator_id")

    if [[ ! -f "$state_file" ]]; then
        error "协调器状态文件不存在: $state_file"
        error "请先运行 --start 命令"
        exit 2
    fi

    # 获取任务列表
    local task_count
    task_count=$(jq '.tasks | length' "$state_file")

    info "准备 $task_count 个任务..."
    echo ""

    # 为每个任务运行 run_agent.sh --prepare
    local prepared_count=0
    local failed_count=0

    for ((i=0; i<task_count; i++)); do
        local task_id input_file prepared
        task_id=$(jq -r ".tasks[$i].task_id" "$state_file")
        input_file=$(jq -r ".tasks[$i].input_file" "$state_file")
        prepared=$(jq -r ".tasks[$i].prepared" "$state_file")

        if [[ "$prepared" == "true" ]]; then
            info "任务 $task_id: 已准备，跳过"
            ((prepared_count++)) || true
            continue
        fi

        info "准备任务: $task_id"

        if "$RUN_AGENT_SCRIPT" --prepare --input="$input_file"; then
            success "任务 $task_id: 准备成功"
            ((prepared_count++)) || true

            # 更新状态
            local updated_state
            updated_state=$(jq ".tasks[$i].prepared = true | .tasks[$i].status = \"prepared\"" "$state_file")
            echo "$updated_state" > "$state_file"
        else
            error "任务 $task_id: 准备失败"
            ((failed_count++)) || true

            # 更新状态
            local updated_state
            updated_state=$(jq ".tasks[$i].status = \"prepare_failed\"" "$state_file")
            echo "$updated_state" > "$state_file"
        fi

        echo ""
    done

    # 更新协调器状态
    local updated_state
    if [[ "$failed_count" -eq 0 ]]; then
        updated_state=$(jq '.status = "prepared"' "$state_file")
    else
        updated_state=$(jq '.status = "prepare_partial"' "$state_file")
    fi
    echo "$updated_state" > "$state_file"

    # 显示结果
    info "========================================="
    info "准备结果"
    info "========================================="
    success "成功: $prepared_count 个任务"
    if [[ "$failed_count" -gt 0 ]]; then
        error "失败: $failed_count 个任务"
    fi
    echo ""

    if [[ "$failed_count" -eq 0 ]]; then
        info "下一步:"
        info "1. 在 Claude Code 中依次完成每个任务"
        info "2. 每个任务完成后运行:"
        echo "   ./run_agent.sh --complete --task-id=<task-id> --status=<status> --conclusion=\"...\""
        info "3. 所有任务完成后运行:"
        echo "   ./coordinator.sh --summary --coordinator-id=\"$coordinator_id\""
        echo ""
    fi
}

# ==================== 任务状态 ====================

cmd_status() {
    local coordinator_id="$1"

    info "========================================="
    info "协调器状态"
    info "========================================="
    echo ""

    # 读取协调器状态
    local state_file
    state_file=$(get_coordinator_state_file "$coordinator_id")

    if [[ ! -f "$state_file" ]]; then
        error "协调器状态文件不存在: $state_file"
        exit 2
    fi

    # 显示协调器信息
    local run_id description status start_timestamp
    run_id=$(jq -r '.run_id' "$state_file")
    description=$(jq -r '.description' "$state_file")
    status=$(jq -r '.status' "$state_file")
    start_timestamp=$(jq -r '.start_timestamp' "$state_file")

    info "Coordinator ID: $coordinator_id"
    info "Run ID:         $run_id"
    info "Description:    $description"
    info "Status:         $status"
    info "Start Time:     $start_timestamp"
    echo ""

    # 检查每个任务的状态
    local task_count
    task_count=$(jq '.tasks | length' "$state_file")

    info "任务状态 ($task_count 个任务):"
    echo ""

    local pending_count=0
    local prepared_count=0
    local completed_count=0
    local failed_count=0

    for ((i=0; i<task_count; i++)); do
        local task_id task_status prepared completed
        task_id=$(jq -r ".tasks[$i].task_id" "$state_file")
        task_status=$(jq -r ".tasks[$i].status" "$state_file")
        prepared=$(jq -r ".tasks[$i].prepared" "$state_file")
        completed=$(jq -r ".tasks[$i].completed" "$state_file")

        # 检查任务是否已完成（通过检查 task-output 文件）
        local output_file="$REPO_ROOT/.task-outputs/${task_id}-output.json"
        if [[ -f "$output_file" ]] && [[ "$completed" != "true" ]]; then
            # 任务已完成但状态未更新
            task_status="completed"
            completed="true"

            # 更新状态
            local updated_state
            updated_state=$(jq ".tasks[$i].completed = true | .tasks[$i].status = \"completed\"" "$state_file")
            echo "$updated_state" > "$state_file"
        fi

        # 显示任务状态
        case "$task_status" in
            pending)
                info "  $((i+1)). $task_id: ⏳ 待准备"
                ((pending_count++)) || true
                ;;
            prepared)
                info "  $((i+1)). $task_id: 🔄 已准备，待执行"
                ((prepared_count++)) || true
                ;;
            completed)
                success "  $((i+1)). $task_id: ✅ 已完成"
                ((completed_count++)) || true
                ;;
            prepare_failed|failed)
                error "  $((i+1)). $task_id: ❌ 失败"
                ((failed_count++)) || true
                ;;
            *)
                info "  $((i+1)). $task_id: ❓ $task_status"
                ;;
        esac
    done

    echo ""
    info "========================================="
    info "统计信息"
    info "========================================="
    info "待准备: $pending_count"
    info "已准备: $prepared_count"
    success "已完成: $completed_count"
    if [[ "$failed_count" -gt 0 ]]; then
        error "失败: $failed_count"
    fi
    echo ""

    # 显示下一步操作
    if [[ "$completed_count" -eq "$task_count" ]]; then
        info "✅ 所有任务已完成！"
        info "运行以下命令生成汇总报告:"
        echo "  ./coordinator.sh --summary --coordinator-id=\"$coordinator_id\""
        echo ""
    elif [[ "$pending_count" -gt 0 ]]; then
        info "运行以下命令准备任务:"
        echo "  ./coordinator.sh --prepare --coordinator-id=\"$coordinator_id\""
        echo ""
    elif [[ "$prepared_count" -gt 0 ]]; then
        info "请在 Claude Code 中完成已准备的任务"
        echo ""
    fi
}

# ==================== 生成汇总 ====================

cmd_summary() {
    local coordinator_id="$1"

    info "========================================="
    info "生成汇总报告"
    info "========================================="
    echo ""

    # 读取协调器状态
    local state_file
    state_file=$(get_coordinator_state_file "$coordinator_id")

    if [[ ! -f "$state_file" ]]; then
        error "协调器状态文件不存在: $state_file"
        exit 2
    fi

    # 检查所有任务是否完成
    local task_count
    task_count=$(jq '.tasks | length' "$state_file")

    local completed_count=0
    local failed_count=0
    local task_outputs="[]"

    for ((i=0; i<task_count; i++)); do
        local task_id
        task_id=$(jq -r ".tasks[$i].task_id" "$state_file")

        local output_file="$REPO_ROOT/.task-outputs/${task_id}-output.json"
        if [[ -f "$output_file" ]]; then
            info "收集任务输出: $task_id"

            # 读取 task-output
            local task_output
            task_output=$(jq '.' "$output_file")

            # 添加到汇总
            task_outputs=$(echo "$task_outputs" | jq --argjson output "$task_output" '. += [$output]')

            # 检查任务状态
            local output_status
            output_status=$(jq -r '.output.status' "$output_file")

            case "$output_status" in
                completed)
                    ((completed_count++)) || true
                    ;;
                partial|failed|skipped)
                    ((failed_count++)) || true
                    ;;
            esac
        else
            warn "任务输出不存在: $task_id"
            ((failed_count++)) || true
        fi
    done

    echo ""

    # 生成汇总文件
    local summary_file="$COORDINATOR_DIR/${coordinator_id}-summary.json"
    local end_timestamp
    end_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq -n \
        --arg coordinator_id "$coordinator_id" \
        --arg run_id "$(jq -r '.run_id' "$state_file")" \
        --arg description "$(jq -r '.description' "$state_file")" \
        --arg start_timestamp "$(jq -r '.start_timestamp' "$state_file")" \
        --arg end_timestamp "$end_timestamp" \
        --arg total_tasks "$task_count" \
        --arg completed_tasks "$completed_count" \
        --arg failed_tasks "$failed_count" \
        --argjson task_outputs "$task_outputs" \
        '{
            coordinator_id: $coordinator_id,
            run_id: $run_id,
            description: $description,
            start_timestamp: $start_timestamp,
            end_timestamp: $end_timestamp,
            summary: {
                total_tasks: ($total_tasks | tonumber),
                completed_tasks: ($completed_tasks | tonumber),
                failed_tasks: ($failed_tasks | tonumber),
                success_rate: (($completed_tasks | tonumber) / ($total_tasks | tonumber) * 100 | floor)
            },
            task_outputs: $task_outputs
        }' > "$summary_file"

    success "汇总报告已生成: $summary_file"
    echo ""

    # 显示汇总信息
    info "========================================="
    info "汇总信息"
    info "========================================="
    info "总任务数: $task_count"
    success "成功: $completed_count"
    if [[ "$failed_count" -gt 0 ]]; then
        error "失败: $failed_count"
    fi

    local success_rate
    success_rate=$((completed_count * 100 / task_count))
    info "成功率: $success_rate%"
    echo ""

    # 更新协调器状态
    local updated_state
    if [[ "$failed_count" -eq 0 ]]; then
        updated_state=$(jq '.status = "completed"' "$state_file")
    else
        updated_state=$(jq '.status = "partial"' "$state_file")
    fi
    echo "$updated_state" > "$state_file"

    success "✅ 协调器执行完成"
    echo ""
}

# ==================== 主函数 ====================

usage() {
    cat <<EOF
用法: coordinator.sh <command> [options]

命令:
  --start      启动协调器（解析配置，生成任务输入）
  --prepare    准备所有任务（调用 run_agent.sh --prepare）
  --status     查看任务执行状态
  --summary    生成汇总报告

启动协调器选项:
  --config=<file>    协调器配置文件（必需）

其他命令选项:
  --coordinator-id=<id>    协调器 ID（必需）

示例:
  # 1. 启动协调器
  ./coordinator.sh --start --config=coordinator-config.json

  # 2. 准备所有任务
  ./coordinator.sh --prepare --coordinator-id=coordinator-20260203-120000

  # 3. 查看状态
  ./coordinator.sh --status --coordinator-id=coordinator-20260203-120000

  # 4. 生成汇总报告
  ./coordinator.sh --summary --coordinator-id=coordinator-20260203-120000
EOF
}

main() {
    # 检查依赖
    check_dependencies

    # 解析命令
    local command=""
    local config_file=""
    local coordinator_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --start)
                command="start"
                shift
                ;;
            --prepare)
                command="prepare"
                shift
                ;;
            --status)
                command="status"
                shift
                ;;
            --summary)
                command="summary"
                shift
                ;;
            --config=*)
                config_file="${1#*=}"
                shift
                ;;
            --coordinator-id=*)
                coordinator_id="${1#*=}"
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
        start)
            if [[ -z "$config_file" ]]; then
                error "Missing required option: --config"
                usage
                exit 1
            fi
            cmd_start "$config_file"
            ;;
        prepare)
            if [[ -z "$coordinator_id" ]]; then
                error "Missing required option: --coordinator-id"
                usage
                exit 1
            fi
            cmd_prepare "$coordinator_id"
            ;;
        status)
            if [[ -z "$coordinator_id" ]]; then
                error "Missing required option: --coordinator-id"
                usage
                exit 1
            fi
            cmd_status "$coordinator_id"
            ;;
        summary)
            if [[ -z "$coordinator_id" ]]; then
                error "Missing required option: --coordinator-id"
                usage
                exit 1
            fi
            cmd_summary "$coordinator_id"
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
