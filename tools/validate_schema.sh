#!/bin/bash
#
# Schema 验证工具
#
# 功能：验证任务输出是否符合 Schema 规范
# 版本：v0.1.0
# 创建日期：2026-02-03

set -euo pipefail

# ==================== 配置 ====================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_DIR="$REPO_ROOT/projectBasicInfo/agent-schema"
OUTPUT_SCHEMA="$SCHEMA_DIR/task-output.schema.json"

# 验证计数器
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

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
    echo "❌ $*"
}

# 检查是否安装了 jq
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it first:"
        error "  macOS: brew install jq"
        error "  Linux: sudo apt-get install jq"
        exit 3
    fi
}

# 验证 JSON 格式
validate_json_syntax() {
    local file="$1"

    if jq empty "$file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 验证必需字段
validate_required_fields() {
    local file="$1"
    local has_error=0

    # 检查是否有 output 对象（示例文件结构）
    local base_path=""
    local field_prefix=""
    if jq -e ".output.task_id" "$file" > /dev/null 2>&1; then
        base_path=".output"
        field_prefix=".output."
    else
        base_path="."
        field_prefix="."
    fi

    # 检查根级别必需字段
    local required_fields=("task_id" "run_id" "workspace" "actor" "task_type" "schema_version" "timestamp" "output")

    for field in "${required_fields[@]}"; do
        if ! jq -e "${field_prefix}${field}" "$file" > /dev/null 2>&1; then
            error "  Missing required field: $field"
            has_error=1
        fi
    done

    # 检查 output 必需字段
    if jq -e "${field_prefix}output" "$file" > /dev/null 2>&1; then
        if ! jq -e "${field_prefix}output.status" "$file" > /dev/null 2>&1; then
            error "  Missing required field: output.status"
            has_error=1
        fi

        if ! jq -e "${field_prefix}output.conclusion" "$file" > /dev/null 2>&1; then
            error "  Missing required field: output.conclusion"
            has_error=1
        fi
    fi

    return $has_error
}

# 验证 evidence 条件必填规则
validate_evidence() {
    local file="$1"
    local has_error=0

    # 检查是否有 output 对象（示例文件结构）
    local field_prefix=""
    if jq -e ".output.task_id" "$file" > /dev/null 2>&1; then
        field_prefix=".output."
    else
        field_prefix="."
    fi

    # 检查是否有 evidence 数组
    if ! jq -e "${field_prefix}output.evidence" "$file" > /dev/null 2>&1; then
        return 0  # evidence 是可选的
    fi

    # 获取 evidence 数组长度
    local evidence_count
    evidence_count=$(jq "${field_prefix}output.evidence | length" "$file")

    if [[ "$evidence_count" -eq 0 ]]; then
        warn "  Evidence array is empty (at least 1 item recommended)"
        ((WARNINGS++)) || true
        return 0
    fi

    # 检查每个 evidence 项
    for ((i=0; i<evidence_count; i++)); do
        local kind
        kind=$(jq -r "${field_prefix}output.evidence[$i].kind // \"missing\"" "$file")

        local path
        path=$(jq -r "${field_prefix}output.evidence[$i].path // \"missing\"" "$file")

        # 必填字段：kind 和 path
        if [[ "$kind" == "missing" ]]; then
            error "  Evidence[$i]: Missing required field 'kind'"
            has_error=1
        fi

        if [[ "$path" == "missing" ]]; then
            error "  Evidence[$i]: Missing required field 'path'"
            has_error=1
        fi

        # 条件必填：根据 kind 检查 range
        case "$kind" in
            file)
                # file 类型需要 range.start_line 和 range.end_line
                if ! jq -e "${field_prefix}output.evidence[$i].range.start_line" "$file" > /dev/null 2>&1; then
                    error "  Evidence[$i] (kind=file): Missing required field 'range.start_line'"
                    has_error=1
                fi

                if ! jq -e "${field_prefix}output.evidence[$i].range.end_line" "$file" > /dev/null 2>&1; then
                    error "  Evidence[$i] (kind=file): Missing required field 'range.end_line'"
                    has_error=1
                fi
                ;;

            commit)
                # commit 类型需要 range.commit_hash
                if ! jq -e "${field_prefix}output.evidence[$i].range.commit_hash" "$file" > /dev/null 2>&1; then
                    error "  Evidence[$i] (kind=commit): Missing required field 'range.commit_hash'"
                    has_error=1
                fi
                ;;

            log|command_output)
                # log 和 command_output 类型 range 可选
                if ! jq -e "${field_prefix}output.evidence[$i].snippet" "$file" > /dev/null 2>&1; then
                    warn "  Evidence[$i] (kind=$kind): Missing recommended field 'snippet'"
                    ((WARNINGS++)) || true
                fi
                ;;
        esac

        # 推荐字段：snippet
        if [[ "$kind" == "file" ]]; then
            if ! jq -e "${field_prefix}output.evidence[$i].snippet" "$file" > /dev/null 2>&1; then
                warn "  Evidence[$i]: Missing recommended field 'snippet'"
                ((WARNINGS++)) || true
            fi
        fi
    done

    return $has_error
}

# 验证路径格式
validate_path_format() {
    local file="$1"
    local has_error=0

    # 检查是否有 output 对象（示例文件结构）
    local field_prefix=""
    if jq -e ".output.task_id" "$file" > /dev/null 2>&1; then
        field_prefix=".output."
    else
        field_prefix="."
    fi

    # 检查 evidence 路径
    if jq -e "${field_prefix}output.evidence" "$file" > /dev/null 2>&1; then
        local evidence_count
        evidence_count=$(jq "${field_prefix}output.evidence | length" "$file")

        for ((i=0; i<evidence_count; i++)); do
            local path
            path=$(jq -r "${field_prefix}output.evidence[$i].path // \"\"" "$file")

            # 路径不应以 / 开头（相对路径）
            if [[ "$path" == /* ]]; then
                error "  Evidence[$i]: Path should be relative to repo root (should not start with /): $path"
                has_error=1
            fi
        done
    fi

    return $has_error
}

# 验证单个文件
validate_file() {
    local file="$1"
    local file_name
    file_name=$(basename "$file")

    info "验证文件: $file_name"
    ((TOTAL_CHECKS++)) || true

    # 1. JSON 语法检查
    if ! validate_json_syntax "$file"; then
        error "  JSON syntax error"
        ((FAILED_CHECKS++)) || true
        echo ""
        return 1
    fi

    # 2. 必需字段检查
    if ! validate_required_fields "$file"; then
        ((FAILED_CHECKS++)) || true
        echo ""
        return 1
    fi

    # 3. Evidence 条件必填检查
    if ! validate_evidence "$file"; then
        ((FAILED_CHECKS++)) || true
        echo ""
        return 1
    fi

    # 4. 路径格式检查
    if ! validate_path_format "$file"; then
        ((FAILED_CHECKS++)) || true
        echo ""
        return 1
    fi

    success "  验证通过"
    ((PASSED_CHECKS++)) || true
    echo ""
    return 0
}

# ==================== 主逻辑 ====================

main() {
    info "========================================="
    info "Schema 验证工具"
    info "========================================="
    echo ""

    # 检查依赖
    check_dependencies

    # 如果提供了参数，验证指定文件
    if [[ $# -gt 0 ]]; then
        for file in "$@"; do
            if [[ ! -f "$file" ]]; then
                error "文件不存在: $file"
                continue
            fi
            validate_file "$file"
        done
    else
        # 否则验证 examples 目录下的所有示例
        info "验证所有示例文件..."
        echo ""

        for example_file in "$SCHEMA_DIR"/examples/*.json; do
            if [[ -f "$example_file" ]]; then
                validate_file "$example_file"
            fi
        done
    fi

    # 输出总结
    echo ""
    info "========================================="
    info "验证结果总结"
    info "========================================="
    info "总文件数: $TOTAL_CHECKS"
    success "通过: $PASSED_CHECKS"
    [[ "$FAILED_CHECKS" -gt 0 ]] && error "失败: $FAILED_CHECKS" || true
    [[ "$WARNINGS" -gt 0 ]] && warn "警告: $WARNINGS" || true
    echo ""

    if [[ "$FAILED_CHECKS" -eq 0 ]]; then
        success "✅ 所有验证通过！"
        exit 0
    else
        error "❌ 有 $FAILED_CHECKS 个文件验证失败"
        exit 1
    fi
}

# 显示使用说明
usage() {
    cat <<EOF
用法: validate_schema.sh [文件...]

选项:
  <文件>    验证指定的 JSON 文件
  无参数    验证 examples 目录下的所有示例文件

示例:
  # 验证单个文件
  ./validate_schema.sh task-output.json

  # 验证多个文件
  ./validate_schema.sh file1.json file2.json

  # 验证所有示例
  ./validate_schema.sh

验证内容:
  1. JSON 语法正确性
  2. 必需字段完整性
  3. Evidence 条件必填规则（kind/path/range）
  4. 路径格式规范（相对路径）
EOF
}

# 解析参数
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# 执行主函数
main "$@"
