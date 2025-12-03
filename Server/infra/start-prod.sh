#!/usr/bin/env bash

#======================================
# 观之后端 - 生产环境启动脚本（模板）
# 创建日期: 2025-12-03
#
# ⚠️ 重要说明：
# 1. 此脚本目前仅作为模板使用，不会自动在服务器上执行
# 2. 真实的密码和密钥需要由管理员手动填入或通过 AWS Secrets Manager 等机制注入
# 3. 在部署到生产环境前，请先在测试环境验证所有配置
# 4. 切勿将包含真实密码的脚本提交到版本控制系统
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
echo_info "设置生产环境变量..."

# 数据库配置
export DB_HOST="52.83.127.15"
export DB_PORT="3306"
export DB_NAME="ONETTOO"
export DB_USER="root"
export DB_PWD="xxxx"  # ← 待填入：真实的数据库密码

# Redis 配置
export REDIS_HOST="52.83.127.15"
export REDIS_PORT="6379"
export REDIS_DB="0"
export REDIS_PWD="xxxx"  # ← 待填入：真实的 Redis 密码

# JWT 配置
export JWT_SECRET="xxxx"  # ← 待填入：生产环境独立的 JWT 密钥（88位Base64）

# 可选：Knife4j 配置（生产环境已禁用，如需启用才设置）
# export KNIFE4J_USER="onettoo"
# export KNIFE4J_PWD="xxxx"

# 可选：管理员配置
# export ADMIN_PHONE="13810269627"

# 可选：图片存储路径
# export IMAGE_PATH="/data/onettoo/images/"

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
echo_info "当前配置："
echo "  数据库主机: $DB_HOST"
echo "  数据库端口: $DB_PORT"
echo "  数据库名称: $DB_NAME"
echo "  数据库用户: $DB_USER"
echo "  数据库密码: ******"
echo "  Redis 主机: $REDIS_HOST"
echo "  Redis 端口: $REDIS_PORT"
echo "  Redis 密码: ******"
echo "  JWT 密钥: ******"

#======================================
# 检查 JAR 文件是否存在
#======================================
JAR_FILE="onettoo-0.0.1-SNAPSHOT.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo_error "JAR 文件不存在: $JAR_FILE"
    echo_error "请确保已编译并将 JAR 文件放置在当前目录"
    exit 1
fi

echo_info "找到 JAR 文件: $JAR_FILE"

#======================================
# 检查端口占用
#======================================
SERVER_PORT=${SERVER_PORT:-8085}

if lsof -Pi :$SERVER_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo_warn "端口 $SERVER_PORT 已被占用"
    echo_warn "如需停止旧进程，请运行: lsof -ti:$SERVER_PORT | xargs kill -9"
    read -p "是否继续启动？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "已取消启动"
        exit 0
    fi
fi

#======================================
# JVM 参数配置
#======================================
JVM_OPTS="-Xms512m -Xmx2048m"
JVM_OPTS="$JVM_OPTS -XX:+UseG1GC"
JVM_OPTS="$JVM_OPTS -XX:MaxGCPauseMillis=200"
JVM_OPTS="$JVM_OPTS -XX:+HeapDumpOnOutOfMemoryError"
JVM_OPTS="$JVM_OPTS -XX:HeapDumpPath=./logs/heapdump.hprof"

#======================================
# 启动应用
#======================================
echo_info "启动观之后端服务（生产模式）..."
echo_info "JVM 参数: $JVM_OPTS"
echo_info "Spring Profile: prod"

# 启动命令
java $JVM_OPTS \
    -jar $JAR_FILE \
    --spring.profiles.active=prod

# 如果需要后台运行，可以使用以下命令：
# nohup java $JVM_OPTS \
#     -jar $JAR_FILE \
#     --spring.profiles.active=prod \
#     > ./logs/onettoo.log 2>&1 &
#
# echo $! > onettoo.pid
# echo_info "应用已在后台启动，PID: $(cat onettoo.pid)"
# echo_info "日志文件: ./logs/onettoo.log"

#======================================
# 启动后检查（如果是前台运行，此代码不会执行）
#======================================
# sleep 5
# if ps -p $(cat onettoo.pid) > /dev/null 2>&1; then
#     echo_info "应用启动成功！"
#     echo_info "查看日志: tail -f ./logs/onettoo.log"
# else
#     echo_error "应用启动失败，请检查日志"
#     exit 1
# fi
