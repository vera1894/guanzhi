#!/bin/bash
#
# Agent Guard 测试脚本
#
# 功能：测试 agent_guard.sh 的各种场景
# 版本：v0.1.0
# 创建日期：2026-02-03

set -euo pipefail

# ==================== 配置 ====================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD_SCRIPT="$REPO_ROOT/tools/agent_guard.sh"

# 测试计数器
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ==================== 工具函数 ====================

info() {
    echo "ℹ️  $*"
}

success() {
    echo "✅ $*"
}

error() {
    echo "❌ $*"
}

# 运行测试用例
# 参数: $1=测试名称, $2=预期退出码, $3...=guard 脚本参数
run_test() {
    local test_name="$1"
    local expected_exit_code="$2"
    shift 2

    ((TOTAL_TESTS++)) || true

    info "测试 #$TOTAL_TESTS: $test_name"

    # 运行 guard 脚本（捕获退出码）
    local actual_exit_code=0
    "$GUARD_SCRIPT" "$@" > /dev/null 2>&1 || actual_exit_code=$?

    # 检查退出码
    if [[ "$actual_exit_code" -eq "$expected_exit_code" ]]; then
        success "  通过 (退出码: $actual_exit_code)"
        ((PASSED_TESTS++)) || true
    else
        error "  失败 (预期: $expected_exit_code, 实际: $actual_exit_code)"
        ((FAILED_TESTS++)) || true
    fi

    echo ""
}

# ==================== 测试场景 ====================

main() {
    info "========================================="
    info "Agent Guard 测试套件"
    info "========================================="
    echo ""

    # 场景 1: iOS workspace 内文件访问 - 应该通过
    run_test \
        "场景 1: iOS workspace 内文件访问" \
        0 \
        --check-write \
        --workspace=ios \
        --files="guanzhi/View/FrontPages/SearchView.swift" \
        --actor=ios-developer

    # 场景 2: 跨 workspace 写入检测 - 应该拒绝
    run_test \
        "场景 2: iOS Agent 尝试写入 Backend 文件" \
        1 \
        --check-write \
        --workspace=ios \
        --files="Server/onettoo/src/main/java/Main.java" \
        --actor=ios-developer

    # 场景 3: 例外目录访问 - 应该通过
    run_test \
        "场景 3: Backend Agent 写入日志目录" \
        0 \
        --check-write \
        --workspace=backend \
        --files="projectBasicInfo/logs/2026-02-03-test-cc.md" \
        --actor=backend-developer

    # 场景 4: 多文件同 workspace - 应该通过
    run_test \
        "场景 4: iOS Agent 修改多个 iOS 文件" \
        0 \
        --check-write \
        --workspace=ios \
        --files="guanzhi/View/MapPages/MapView.swift,guanzhi/ModelsForMap/SearchViewModel.swift" \
        --actor=ios-developer

    # 场景 5: 工程文件匹配 - 应该通过
    run_test \
        "场景 5: iOS Agent 修改工程文件" \
        0 \
        --check-write \
        --workspace=ios \
        --files="guanzhi.xcodeproj/project.pbxproj,Podfile" \
        --actor=ios-developer

    # 场景 6: 混合例外目录和 workspace 文件 - 应该通过
    run_test \
        "场景 6: Meta Agent 同时修改 Meta 文件和日志" \
        0 \
        --check-write \
        --workspace=meta \
        --files="projectBasicInfo/00_AGENT_RULES.md,projectBasicInfo/logs/2026-02-03-test-cc.md" \
        --actor=infrastructure

    # 场景 7: Backend workspace 内文件访问 - 应该通过
    run_test \
        "场景 7: Backend workspace 内文件访问" \
        0 \
        --check-write \
        --workspace=backend \
        --files="Server/onettoo/src/main/java/modules/rest/GuanZhiController.java" \
        --actor=backend-developer

    # 场景 8: Admin-Web workspace 内文件访问 - 应该通过
    run_test \
        "场景 8: Admin-Web workspace 内文件访问" \
        0 \
        --check-write \
        --workspace=admin-web \
        --files="admin-web/src/views/ReportManagement.vue" \
        --actor=frontend-developer

    # 场景 9: Meta Agent 尝试写入 iOS 文件 - 应该拒绝
    run_test \
        "场景 9: Meta Agent 尝试写入 iOS 文件" \
        1 \
        --check-write \
        --workspace=meta \
        --files="guanzhi/View/FrontPages/SearchView.swift" \
        --actor=infrastructure

    # 场景 10: 参数错误 - 应该返回退出码 3
    run_test \
        "场景 10: 缺少必需参数（无 --files）" \
        3 \
        --check-write \
        --workspace=ios \
        --actor=ios-developer

    # ==================== 测试总结 ====================

    echo ""
    info "========================================="
    info "测试结果总结"
    info "========================================="
    info "总测试数: $TOTAL_TESTS"
    success "通过: $PASSED_TESTS"
    [[ "$FAILED_TESTS" -gt 0 ]] && error "失败: $FAILED_TESTS" || true
    echo ""

    if [[ "$FAILED_TESTS" -eq 0 ]]; then
        success "✅ 所有测试通过！"
        exit 0
    else
        error "❌ 有 $FAILED_TESTS 个测试失败"
        exit 1
    fi
}

# 执行主函数
main "$@"
