#!/bin/bash
# run_tpcc_with_monitoring.sh - 完整的 TPC-C 测试和缓存监控流程

echo "=== OceanBase TPC-C 测试 + 缓存性能监控 ==="
echo "时间: $(date)"
echo

# 检查 OceanBase 是否运行
echo "1. 检查 OceanBase 状态..."
if ! mysql -h127.0.0.1 -P10000 -uroot@tenant1 -p -e "SELECT 1;" >/dev/null 2>&1; then
    echo "错误: OceanBase 未运行或连接失败"
    echo "请先启动 OceanBase: obd cluster start obtest"
    exit 1
fi
echo "✅ OceanBase 运行正常"
echo

# 创建表
echo "2. 创建 TPC-C 表..."
./runSQL.sh props.ob sql.common/tableCreates_parts.sql
if [ $? -ne 0 ]; then
    echo "错误: 创建表失败"
    exit 1
fi
echo "✅ 表创建完成"
echo

# 加载数据
echo "3. 加载 TPC-C 数据..."
./runLoader.sh props.ob
if [ $? -ne 0 ]; then
    echo "错误: 数据加载失败"
    exit 1
fi
echo "✅ 数据加载完成"
echo

# 启动缓存监控
echo "4. 启动缓存性能监控..."
echo "监控将在后台运行，按任意键开始 TPC-C 测试..."
./monitor_cache_database.sh &
MONITOR_PID=$!
echo "监控进程 ID: $MONITOR_PID"
echo

# 等待用户确认
read -p "按 Enter 开始 TPC-C 测试..."

# 运行 TPC-C 测试
echo "5. 开始 TPC-C 测试..."
echo "测试开始时间: $(date)"
./runBenchmark.sh props.ob
TEST_EXIT_CODE=$?
echo "测试结束时间: $(date)"
echo "测试退出码: $TEST_EXIT_CODE"
echo

# 停止监控
echo "6. 停止缓存监控..."
kill $MONITOR_PID 2>/dev/null
sleep 2
pkill -f monitor_cache_database.sh 2>/dev/null
echo "✅ 监控已停止"
echo

# 分析数据
echo "7. 分析缓存性能数据..."
echo "=== 缓存性能分析报告 ==="
mysql -h127.0.0.1 -P10000 -uroot@tenant1 -p < analyze_cache_data.sql

echo
echo "=== 测试完成 ==="
echo "缓存性能数据已保存到 cache_monitor.cache_performance_log 表"
echo "可以使用以下命令查看数据:"
echo "  ./view_cache_data.sh"
echo "  mysql -h127.0.0.1 -P10000 -uroot@tenant1 -p -e 'USE cache_monitor; SELECT * FROM cache_performance_log ORDER BY test_time DESC LIMIT 10;'"
