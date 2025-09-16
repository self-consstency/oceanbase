#!/bin/bash

# TPC-C 重置和重新开始脚本
# 用于在完成一轮测试后重置状态并开始新的实验

set -e

# 配置参数
DB_HOST="127.0.0.1"
DB_PORT="10000"
DB_USER="root@tenant1"
TENANT_ID="1004"
BENCHMARK_DIR="/media/nvme/ldz_test/oceanbase/benchmarksql-5.0/run"

echo "=========================================="
echo "TPC-C 重置和重新开始脚本"
echo "=========================================="

# 1. 停止所有相关进程
echo "1. 停止所有相关进程..."
pkill -f "monitor_cache_database.sh" || true
pkill -f "collect_cache_data.sh" || true
pkill -f "runSQL.sh" || true
pkill -f "runBenchmark.sh" || true
sleep 2

# 2. 清理缓存性能数据（可选）
echo "2. 清理历史缓存性能数据..."
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
USE cache_monitor;
DELETE FROM cache_performance_log WHERE timestamp < DATE_SUB(NOW(), INTERVAL 1 HOUR);
" 2>/dev/null || echo "  跳过清理历史数据（表可能不存在）"

# 3. 重置OceanBase缓存统计
echo "3. 重置OceanBase缓存统计..."
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
-- 重置缓存统计信息
ALTER SYSTEM FLUSH CACHE;
-- 清理系统缓存
ALTER SYSTEM CLEAR CACHE;
" 2>/dev/null || echo "  缓存重置命令执行完成"

# 4. 等待系统稳定
echo "4. 等待系统稳定..."
sleep 5

# 5. 检查OceanBase状态
echo "5. 检查OceanBase状态..."
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
SELECT 
    'OceanBase状态检查' AS '检查项',
    COUNT(*) AS '缓存组数量'
FROM oceanbase.GV\$OB_KVCACHE 
WHERE TENANT_ID = $TENANT_ID;
" 2>/dev/null || {
    echo "  错误：无法连接到OceanBase，请检查服务状态"
    exit 1
}

# 6. 清理TPC-C数据（可选 - 如果需要完全重新开始）
read -p "是否要清理TPC-C数据并重新加载？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "6. 清理TPC-C数据..."
    cd $BENCHMARK_DIR
    
    # 删除表
    echo "  删除TPC-C表..."
    mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
    USE tpccdb;
    DROP TABLE IF EXISTS order_line, orders, new_order, stock, item, customer, district, warehouse;
    " 2>/dev/null || echo "  表删除完成"
    
    # 重新创建表
    echo "  重新创建TPC-C表..."
    ./runSQL.sh props.ob sql/tableCreates.sql
    
    # 重新加载数据
    echo "  重新加载TPC-C数据..."
    ./runLoader.sh props.ob
fi

# 7. 显示当前缓存状态
echo "7. 当前缓存状态："
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
SELECT 
    CACHE_NAME AS '缓存名称',
    CONCAT(ROUND(HIT_RATIO, 2), '%') AS '命中率',
    CONCAT(ROUND(CACHE_SIZE / 1024 / 1024, 2), 'MB') AS '内存使用',
    TOTAL_HIT_CNT AS '命中次数',
    TOTAL_MISS_CNT AS '未命中次数'
FROM oceanbase.GV\$OB_KVCACHE 
WHERE TENANT_ID = $TENANT_ID
ORDER BY CACHE_SIZE DESC;
"

echo "=========================================="
echo "重置完成！现在可以开始新的TPC-C实验"
echo "=========================================="
echo ""
echo "开始新实验的步骤："
echo "1. 启动缓存监控："
echo "   ./monitor_cache_database.sh"
echo ""
echo "2. 在另一个终端运行TPC-C："
echo "   ./runBenchmark.sh props.ob"
echo ""
echo "3. 实验结束后停止监控："
echo "   pkill -f monitor_cache_database.sh"
echo ""
echo "4. 分析数据："
echo "   ./view_cache_data.sh"
echo "   mysql -h127.0.0.1 -P10000 -uroot@tenant1 < analyze_cache_data.sql"
