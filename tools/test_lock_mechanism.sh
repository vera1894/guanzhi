#!/bin/bash
#
# 锁机制测试脚本
#
# 功能：测试 agent_guard.sh 的锁机制
# 版本：v0.1.0
# 创建日期：2026-02-03

set -euo pipefail

# ==================== 配置 ====================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD_SCRIPT="$REPO_ROOT/tools/agent_guard.sh"
LOCK_DIR="$REPO_ROOT/.locks"

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

# 清理所有锁文件
cleanup_locks() {
    rm -rf "$LOCK_DIR"/*.lock 2>/dev/null || true
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
    info "锁机制测试套件"
    info "========================================="
    echo ""

    # 清理测试环境
    cleanup_locks

    # === 场景 1-5: 基础锁操作 ===

    # 场景 1: 检查空闲锁 - 应该返回 0
    run_test \
        "场景 1: 检查空闲锁状态" \
        0 \
        --check-lock \
        --workspace=ios

    # 场景 2: 获取空闲锁 - 应该成功
    run_test \
        "场景 2: 获取空闲锁（automated 模式）" \
        0 \
        --acquire-lock \
        --workspace=ios \
        --actor=test-agent-1 \
        --task-id=task-001 \
        --lock-mode=automated

    # 场景 3: 检查已占用的锁 - 应该返回 2（锁冲突）
    run_test \
        "场景 3: 检查已被占用的锁" \
        2 \
        --check-lock \
        --workspace=ios

    # 场景 4: 尝试获取已被占用的锁 - 应该失败（退出码 2）
    run_test \
        "场景 4: 尝试获取已被占用的锁" \
        2 \
        --acquire-lock \
        --workspace=ios \
        --actor=test-agent-2 \
        --task-id=task-002 \
        --lock-mode=automated

    # 场景 5: 更新 heartbeat - 应该成功
    run_test \
        "场景 5: 更新锁的 heartbeat" \
        0 \
        --update-heartbeat \
        --workspace=ios

    # 清理：手动删除锁（因为 release-lock 需要匹配 PID）
    cleanup_locks

    # === 场景 6-10: 多 workspace 锁 ===

    # 场景 6: 同时获取多个 workspace 的锁
    run_test \
        "场景 6: 获取 backend workspace 锁" \
        0 \
        --acquire-lock \
        --workspace=backend \
        --actor=test-agent-3 \
        --task-id=task-003 \
        --lock-mode=automated

    run_test \
        "场景 7: 同时获取 admin-web workspace 锁" \
        0 \
        --acquire-lock \
        --workspace=admin-web \
        --actor=test-agent-3 \
        --task-id=task-003 \
        --lock-mode=automated

    # 场景 8: 不同 workspace 的锁互不影响
    run_test \
        "场景 8: ios workspace 锁应该仍然空闲" \
        0 \
        --check-lock \
        --workspace=ios

    # 清理
    cleanup_locks

    # === 场景 9-12: Interactive 模式锁 ===

    # 场景 9: 获取 interactive 模式锁
    run_test \
        "场景 9: 获取 interactive 模式锁" \
        0 \
        --acquire-lock \
        --workspace=meta \
        --actor=human \
        --task-id=task-interactive-1 \
        --lock-mode=interactive

    # 场景 10: interactive 锁正常显示为被占用
    run_test \
        "场景 10: 检查 interactive 锁状态" \
        2 \
        --check-lock \
        --workspace=meta

    # 清理
    cleanup_locks

    # === 场景 11-15: 僵尸锁检测 ===

    # 场景 11: 创建一个已过期的锁（手动修改时间戳）
    info "场景 11: 创建已过期的僵尸锁"
    mkdir -p "$LOCK_DIR"
    # 创建一个 10 分钟前的时间戳（超过 automated 模式的 5 分钟超时）
    local old_timestamp
    if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        old_timestamp=$(date -u -d '10 minutes ago' +"%Y-%m-%dT%H:%M:%SZ")
    else
        # BSD date (macOS)
        old_timestamp=$(date -u -v-10M +"%Y-%m-%dT%H:%M:%SZ")
    fi

    cat > "$LOCK_DIR/ios.lock" <<EOF
{
  "task_id": "zombie-task",
  "actor": "zombie-agent",
  "lock_mode": "automated",
  "holder_pid": 99999,
  "host": "zombie-host",
  "started_at": "$old_timestamp",
  "heartbeat_at": "$old_timestamp",
  "workspace": "ios"
}
EOF

    # 场景 12: 检查僵尸锁 - 应该返回 2 并警告
    run_test \
        "场景 12: 检查僵尸锁状态" \
        2 \
        --check-lock \
        --workspace=ios

    # 场景 13: 抢占僵尸锁 - 应该成功
    run_test \
        "场景 13: 抢占 automated 模式的僵尸锁" \
        0 \
        --acquire-lock \
        --workspace=ios \
        --actor=preempt-agent \
        --task-id=task-preempt \
        --lock-mode=automated

    # 清理
    cleanup_locks

    # === 场景 14-15: 参数验证 ===

    # 场景 14: 缺少必需参数 - 应该返回 3
    run_test \
        "场景 14: 获取锁但缺少 task-id" \
        3 \
        --acquire-lock \
        --workspace=ios \
        --actor=test-agent

    # 场景 15: 无效的 workspace - 应该返回 3
    run_test \
        "场景 15: 使用无效的 workspace" \
        3 \
        --acquire-lock \
        --workspace=invalid \
        --actor=test-agent \
        --task-id=task-invalid

    # ==================== 测试总结 ====================

    echo ""
    info "========================================="
    info "测试结果总结"
    info "========================================="
    info "总测试数: $TOTAL_TESTS"
    success "通过: $PASSED_TESTS"
    [[ "$FAILED_TESTS" -gt 0 ]] && error "失败: $FAILED_TESTS" || true
    echo ""

    # 清理测试环境
    cleanup_locks

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
