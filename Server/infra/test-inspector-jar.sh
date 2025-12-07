#!/usr/bin/env bash
#======================================
# 观之后端 - Inspector 版本测试脚本
# 创建日期: 2025-12-04
#
# 说明：此脚本用于在生产服务器上测试 Inspector 版本 JAR
#       使用独立端口 8086 避免与正在运行的生产服务冲突
#======================================

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

#======================================
# 颜色输出配置
#======================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#======================================
# 环境变量配置
#======================================
echo_info "设置测试环境变量..."

# 数据库配置（与生产环境相同）
export DB_HOST="52.83.127.15"
export DB_PORT="3306"
export DB_NAME="ONETTOO"
export DB_USER="root"
export DB_PWD="xxxx"  # ← 待填入：真实的数据库密码

# Redis 配置（与生产环境相同）
export REDIS_HOST="52.83.127.15"
export REDIS_PORT="6379"
export REDIS_DB="0"
export REDIS_PWD="xxxx"  # ← 待填入：真实的 Redis 密码

# JWT 配置（与生产环境相同）
export JWT_SECRET="xxxx"  # ← 待填入：生产环境的 JWT 密钥

# 测试端口（避免与生产环境冲突）
export SERVER_PORT="8086"

#======================================
# 环境变量验证
#======================================
echo_info "验证必需的环境变量..."

required_vars=(
    "DB_HOST"
    "DB_PORT"
    "DB_NAME"
    "DB_USER"
    "DB_PWD"
    "REDIS_HOST"
    "REDIS_PORT"
    "REDIS_PWD"
    "JWT_SECRET"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ] || [ "${!var}" = "xxxx" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo_error "以下环境变量未正确设置或仍为占位符："
    for var in "${missing_vars[@]}"; do
        echo_error "  - $var"
    done
    echo_error "请在脚本中填入真实值后再启动"
    exit 1
fi

#======================================
# 打印配置信息（不打印敏感信息）
#======================================
echo_info "测试配置："
echo "  数据库主机: $DB_HOST"
echo "  数据库端口: $DB_PORT"
echo "  数据库名称: $DB_NAME"
echo "  数据库用户: $DB_USER"
echo "  数据库密码: ******"
echo "  Redis 主机: $REDIS_HOST"
echo "  Redis 端口: $REDIS_PORT"
echo "  Redis 密码: ******"
echo "  JWT 密钥: ******"
echo "  测试端口: $SERVER_PORT"

#======================================
# 检查 JAR 文件是否存在
#======================================
JAR_FILE="/root/onettoo/back/onettoo-0.0.1-SNAPSHOT-inspector-20251204.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo_error "JAR 文件不存在: $JAR_FILE"
    exit 1
fi

echo_info "找到 JAR 文件: $JAR_FILE"

#======================================
# 检查测试端口占用
#======================================
if lsof -Pi :$SERVER_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo_warn "测试端口 $SERVER_PORT 已被占用"
    echo_warn "如需停止占用进程，请运行: lsof -ti:$SERVER_PORT | xargs kill -9"
    read -p "是否继续启动？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "已取消启动"
        exit 0
    fi
fi

#======================================
# JVM 参数配置（测试用较小内存）
#======================================
JVM_OPTS="-Xms256m -Xmx1024m"
JVM_OPTS="$JVM_OPTS -XX:+UseG1GC"
JVM_OPTS="$JVM_OPTS -XX:MaxGCPauseMillis=200"

#======================================
# 启动测试
#======================================
echo_info "启动 Inspector 版本测试服务..."
echo_info "JVM 参数: $JVM_OPTS"
echo_info "Spring Profile: prod"
echo_info "测试端口: $SERVER_PORT"
echo ""
echo_warn "==================== 重要提示 ===================="
echo_warn "此为测试启动，使用端口 $SERVER_PORT"
echo_warn "生产环境服务仍在 8085 端口运行"
echo_warn "测试完成后，请使用 Ctrl+C 停止此进程"
echo_warn "=================================================="
echo ""

# 前台启动，便于观察日志
java $JVM_OPTS \
    -Dserver.port=$SERVER_PORT \
    -jar $JAR_FILE \
    --spring.profiles.active=prod

# 如果测试通过需要后台运行，使用以下命令：
# nohup java $JVM_OPTS \
#     -Dserver.port=$SERVER_PORT \
#     -jar $JAR_FILE \
#     --spring.profiles.active=prod \
#     > /root/onettoo/logs/inspector-test.log 2>&1 &
#
# echo $! > /root/onettoo/inspector-test.pid
# echo_info "测试服务已在后台启动，PID: $(cat /root/onettoo/inspector-test.pid)"
# echo_info "日志文件: /root/onettoo/logs/inspector-test.log"
# echo_info "查看日志: tail -f /root/onettoo/logs/inspector-test.log"
# echo_info "停止测试: kill $(cat /root/onettoo/inspector-test.pid)"
