#!/bin/bash
#
# 日志生成工具
#
# 功能：从 task-output JSON 生成标准化的操作日志
# 版本：v0.1.0
# 创建日期：2026-02-03

set -euo pipefail

# ==================== 配置 ====================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/projectBasicInfo/logs"
TEMPLATE_FILE="$SCRIPT_DIR/log_templates/task-log-template.md"

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
}

# 转义 Markdown 特殊字符
escape_markdown() {
    local text="$1"
    # 简单转义（如果包含特殊字符）
    echo "$text"
}

# 格式化时间戳
format_timestamp() {
    local timestamp="$1"
    # ISO 8601 格式已经很好了，直接返回
    echo "$timestamp"
}

# 生成 evidence 列表
generate_evidence_list() {
    local output_file="$1"
    local evidence_count
    evidence_count=$(jq '.output.evidence | length' "$output_file")

    if [[ "$evidence_count" -eq 0 ]]; then
        echo ""
        return
    fi

    local evidence_list=""
    for ((i=0; i<evidence_count; i++)); do
        local kind path description snippet
        kind=$(jq -r ".output.evidence[$i].kind" "$output_file")
        path=$(jq -r ".output.evidence[$i].path" "$output_file")
        description=$(jq -r ".output.evidence[$i].description // \"\"" "$output_file")
        snippet=$(jq -r ".output.evidence[$i].snippet // \"\"" "$output_file")

        evidence_list+="### Evidence #$((i+1)): $kind\n\n"
        evidence_list+="- **路径**: \`$path\`\n"

        if [[ "$kind" == "file" ]]; then
            local start_line end_line
            start_line=$(jq -r ".output.evidence[$i].range.start_line // \"\"" "$output_file")
            end_line=$(jq -r ".output.evidence[$i].range.end_line // \"\"" "$output_file")
            if [[ -n "$start_line" ]] && [[ -n "$end_line" ]]; then
                evidence_list+="- **行号**: L$start_line-L$end_line\n"
            fi
        elif [[ "$kind" == "commit" ]]; then
            local commit_hash
            commit_hash=$(jq -r ".output.evidence[$i].range.commit_hash // \"\"" "$output_file")
            if [[ -n "$commit_hash" ]]; then
                evidence_list+="- **Commit**: \`$commit_hash\`\n"
            fi
        fi

        if [[ -n "$description" ]]; then
            evidence_list+="- **说明**: $description\n"
        fi

        if [[ -n "$snippet" ]]; then
            evidence_list+="\n\`\`\`\n$snippet\n\`\`\`\n"
        fi

        evidence_list+="\n"
    done

    echo -e "$evidence_list"
}

# 生成 risk 列表
generate_risk_list() {
    local output_file="$1"
    local risk_count
    risk_count=$(jq '.output.risk | length' "$output_file")

    if [[ "$risk_count" -eq 0 ]]; then
        echo ""
        return
    fi

    local risk_list=""
    for ((i=0; i<risk_count; i++)); do
        local level description impact mitigation
        level=$(jq -r ".output.risk[$i].level" "$output_file")
        description=$(jq -r ".output.risk[$i].description" "$output_file")
        impact=$(jq -r ".output.risk[$i].impact // \"\"" "$output_file")
        mitigation=$(jq -r ".output.risk[$i].mitigation // \"\"" "$output_file")

        case "$level" in
            high)
                risk_list+="### 🔴 高风险 #$((i+1))\n\n"
                ;;
            medium)
                risk_list+="### 🟡 中风险 #$((i+1))\n\n"
                ;;
            low)
                risk_list+="### 🟢 低风险 #$((i+1))\n\n"
                ;;
            *)
                risk_list+="### Risk #$((i+1))\n\n"
                ;;
        esac

        risk_list+="- **描述**: $description\n"
        if [[ -n "$impact" ]]; then
            risk_list+="- **影响**: $impact\n"
        fi
        if [[ -n "$mitigation" ]]; then
            risk_list+="- **缓解措施**: $mitigation\n"
        fi
        risk_list+="\n"
    done

    echo -e "$risk_list"
}

# 生成 next_steps 列表
generate_next_steps_list() {
    local output_file="$1"
    local steps_count
    steps_count=$(jq '.output.next_steps | length' "$output_file")

    if [[ "$steps_count" -eq 0 ]]; then
        echo ""
        return
    fi

    local steps_list=""
    for ((i=0; i<steps_count; i++)); do
        local action priority owner
        action=$(jq -r ".output.next_steps[$i].action" "$output_file")
        priority=$(jq -r ".output.next_steps[$i].priority // \"\"" "$output_file")
        owner=$(jq -r ".output.next_steps[$i].owner // \"\"" "$output_file")

        steps_list+="$((i+1)). **$action**"
        if [[ -n "$priority" ]]; then
            steps_list+=" (优先级: $priority)"
        fi
        if [[ -n "$owner" ]]; then
            steps_list+=" - 负责人: $owner"
        fi
        steps_list+="\n"
    done

    echo -e "$steps_list"
}

# 生成 result 详情
generate_result_details() {
    local output_file="$1"

    # 检查是否有 result 对象
    local has_result
    has_result=$(jq '.output.result // {} | length' "$output_file")

    if [[ "$has_result" -eq 0 ]]; then
        echo ""
        return
    fi

    # 将 result JSON 格式化为 Markdown
    local result_json
    result_json=$(jq '.output.result' "$output_file")

    echo '```json'
    echo "$result_json"
    echo '```'
}

# 生成日志文件名
generate_log_filename() {
    local task_id="$1"
    local actor="$2"
    local date
    date=$(date -u +"%Y-%m-%d")

    echo "${date}-${task_id}-${actor}.md"
}

# 生成任务标题
generate_task_title() {
    local task_type="$1"
    local task_id="$2"

    case "$task_type" in
        bug-rootcause)
            echo "Bug 根因分析: $task_id"
            ;;
        patch-plan)
            echo "补丁计划: $task_id"
            ;;
        deployment)
            echo "部署操作: $task_id"
            ;;
        code-review)
            echo "代码审查: $task_id"
            ;;
        test-execution)
            echo "测试执行: $task_id"
            ;;
        exploration)
            echo "代码探索: $task_id"
            ;;
        refactoring)
            echo "重构: $task_id"
            ;;
        dependency-update)
            echo "依赖更新: $task_id"
            ;;
        documentation)
            echo "文档编写: $task_id"
            ;;
        rollback)
            echo "回滚操作: $task_id"
            ;;
        environment-setup)
            echo "环境配置: $task_id"
            ;;
        data-migration)
            echo "数据迁移: $task_id"
            ;;
        *)
            echo "任务: $task_id"
            ;;
    esac
}

# 从 task-output 生成日志
generate_log() {
    local output_file="$1"
    local custom_title="${2:-}"

    info "从 task-output 生成日志: $(basename "$output_file")"

    # 验证输出文件
    if [[ ! -f "$output_file" ]]; then
        error "Task output file not found: $output_file"
        exit 2
    fi

    if ! jq empty "$output_file" 2>/dev/null; then
        error "Invalid JSON format: $output_file"
        exit 2
    fi

    # 提取字段
    local task_id run_id workspace actor task_type schema_version timestamp
    local status conclusion description start_timestamp

    task_id=$(jq -r '.task_id' "$output_file")
    run_id=$(jq -r '.run_id' "$output_file")
    workspace=$(jq -r '.workspace' "$output_file")
    actor=$(jq -r '.actor' "$output_file")
    task_type=$(jq -r '.task_type' "$output_file")
    schema_version=$(jq -r '.schema_version' "$output_file")
    timestamp=$(jq -r '.timestamp' "$output_file")
    status=$(jq -r '.output.status' "$output_file")
    conclusion=$(jq -r '.output.conclusion' "$output_file")

    # 尝试从 task-context 获取开始时间和描述
    local context_file="$REPO_ROOT/.task-contexts/${task_id}.context.json"
    if [[ -f "$context_file" ]]; then
        start_timestamp=$(jq -r '.start_timestamp // ""' "$context_file")
        description=$(jq -r '.description // ""' "$context_file")
    else
        start_timestamp=""
        description=""
    fi

    # 如果没有 context，尝试从 input 文件读取（coordinator 场景）
    if [[ -z "$description" ]]; then
        # 尝试查找 coordinator inputs
        local possible_input="$REPO_ROOT/.coordinator/"*"-inputs/${task_id}-input.json"
        if ls $possible_input 2>/dev/null | head -1 > /dev/null; then
            local input_file=$(ls $possible_input 2>/dev/null | head -1)
            description=$(jq -r '.input.description // ""' "$input_file")
            start_timestamp=$(jq -r '.timestamp // ""' "$input_file")
        fi
    fi

    # 生成日志内容
    local date
    date=$(date -u +"%Y-%m-%d")

    local task_title
    if [[ -n "$custom_title" ]]; then
        task_title="$custom_title"
    else
        task_title=$(generate_task_title "$task_type" "$task_id")
    fi

    local evidence_list risk_list next_steps_list result_details
    evidence_list=$(generate_evidence_list "$output_file")
    risk_list=$(generate_risk_list "$output_file")
    next_steps_list=$(generate_next_steps_list "$output_file")
    result_details=$(generate_result_details "$output_file")

    # 生成日志文件
    local log_filename
    log_filename=$(generate_log_filename "$task_id" "$actor")
    local log_file="$LOG_DIR/$log_filename"

    # 创建日志内容
    cat > "$log_file" <<EOF
# $task_title

**日期**: $date
**操作者**: $actor
**工作空间**: $workspace
**任务类型**: $task_type
**任务 ID**: $task_id
**Run ID**: $run_id
**执行状态**: $status

---

## 任务概述

$description

---

## 执行结果

**状态**: $status
**结论**: $conclusion

EOF

    # 添加 evidence（如果存在）
    if [[ -n "$evidence_list" ]]; then
        cat >> "$log_file" <<EOF
---

## 证据 (Evidence)

$evidence_list
EOF
    fi

    # 添加 risk（如果存在）
    if [[ -n "$risk_list" ]]; then
        cat >> "$log_file" <<EOF
---

## 风险 (Risk)

$risk_list
EOF
    fi

    # 添加 next_steps（如果存在）
    if [[ -n "$next_steps_list" ]]; then
        cat >> "$log_file" <<EOF
---

## 后续步骤 (Next Steps)

$next_steps_list
EOF
    fi

    # 添加 result 详情（如果存在）
    if [[ -n "$result_details" ]]; then
        cat >> "$log_file" <<EOF
---

## 任务结果详情

$result_details

EOF
    fi

    # 添加执行信息
    cat >> "$log_file" <<EOF
---

## 执行信息

- **开始时间**: $start_timestamp
- **结束时间**: $timestamp
- **任务输出文件**: \`$output_file\`
- **Schema 版本**: $schema_version

---

*此日志由 Agent 任务执行系统自动生成*
EOF

    success "日志已生成: $log_file"
    echo "$log_file"
}

# ==================== 主函数 ====================

usage() {
    cat <<EOF
用法: generate_log.sh [options]

选项:
  --output=<file>      Task output JSON 文件（必需）
  --title=<text>       自定义日志标题（可选）

示例:
  # 从 task-output 生成日志
  ./generate_log.sh --output=.task-outputs/task-123-output.json

  # 使用自定义标题
  ./generate_log.sh --output=.task-outputs/task-123-output.json \\
    --title="自定义任务标题"
EOF
}

main() {
    # 检查依赖
    check_dependencies

    # 解析参数
    local output_file=""
    local custom_title=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output=*)
                output_file="${1#*=}"
                shift
                ;;
            --title=*)
                custom_title="${1#*=}"
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

    # 验证参数
    if [[ -z "$output_file" ]]; then
        error "Missing required option: --output"
        usage
        exit 1
    fi

    # 确保日志目录存在
    mkdir -p "$LOG_DIR"

    # 生成日志
    generate_log "$output_file" "$custom_title"
}

# 执行主函数
main "$@"
