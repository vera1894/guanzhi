#!/usr/bin/env bash
#======================================
# Inspector JAR 简化测试脚本
# 说明：使用服务器现有的 application.yml 配置
# 不传递环境变量，让服务使用配置文件中的默认值
#======================================

set -e

echo "=========================================="
echo "Inspector JAR 测试 (使用现有配置)"
echo "=========================================="
echo ""

# 检查是否有root权限
if [[ $EUID -ne 0 ]]; then
   echo "此脚本需要 root 权限，请使用 sudo 运行"
   exit 1
fi

# 切换到工作目录
cd /root/onettoo/back

# 停止可能存在的测试进程
echo "[1/4] 停止旧的测试进程..."
pkill -9 -f 'port=8086.*onettoo-inspector-fixed' 2>/dev/null || echo "  没有找到旧进程"

# 检查 JAR 文件
echo ""
echo "[2/4] 检查 JAR 文件..."
if [ ! -f "onettoo-inspector-fixed.jar" ]; then
    echo "  错误: 找不到 onettoo-inspector-fixed.jar"
    exit 1
fi
echo "  找到: onettoo-inspector-fixed.jar ($(ls -lh onettoo-inspector-fixed.jar | awk '{print $5}'))"

# 检查配置文件
echo ""
echo "[3/4] 检查配置文件..."
if [ ! -f "application.yml" ]; then
    echo "  错误: 找不到 application.yml"
    exit 1
fi
echo "  找到: application.yml"

# 启动服务
echo ""
echo "[4/4] 启动 Inspector 测试服务..."
echo "  端口: 8086"
echo "  配置: application.yml (使用默认值)"
echo "  日志: /root/onettoo/logs/inspector-simple-test.log"
echo ""

# 使用 Java 17 启动
JAVA17=/usr/lib/jvm/java-17-amazon-corretto/bin/java

nohup "$JAVA17" \
    -Xms256m \
    -Xmx1024m \
    -XX:+UseG1GC \
    -Dserver.port=8086 \
    -jar onettoo-inspector-fixed.jar \
    --spring.profiles.active=prod \
    > /root/onettoo/logs/inspector-simple-test.log 2>&1 &

TEST_PID=$!
echo "  进程已启动，PID: $TEST_PID"

# 等待服务启动
echo ""
echo "等待服务启动..."
sleep 10

# 检查进程状态
if ps -p $TEST_PID > /dev/null 2>&1; then
    echo "✓ 进程运行正常"
    echo ""
    echo "检查端口..."
    if lsof -i :8086 > /dev/null 2>&1; then
        echo "✓ 端口 8086 正在监听"
        echo ""
        echo "=========================================="
        echo "测试服务启动成功!"
        echo "=========================================="
        echo "进程 ID: $TEST_PID"
        echo "端口: 8086"
        echo "查看日志: tail -f /root/onettoo/logs/inspector-simple-test.log"
        echo "停止服务: kill $TEST_PID"
        echo ""
    else
        echo "✗ 端口 8086 未监听，请查看日志"
        tail -30 /root/onettoo/logs/inspector-simple-test.log
        exit 1
    fi
else
    echo "✗ 进程已退出，启动失败"
    echo ""
    echo "日志内容："
    tail -50 /root/onettoo/logs/inspector-simple-test.log
    exit 1
fi
