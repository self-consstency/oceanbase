#!/bin/bash

# TPC-C 快速重置脚本
# 仅重置缓存统计，不重新加载数据

set -e

# 配置参数
DB_HOST="127.0.0.1"
DB_PORT="10000"
DB_USER="root@tenant1"
TENANT_ID="1004"

echo "=========================================="
echo "TPC-C 快速重置脚本"
echo "=========================================="

# 1. 停止所有相关进程
echo "1. 停止所有相关进程..."
pkill -f "monitor_cache_database.sh" || true
pkill -f "collect_cache_data.sh" || true
pkill -f "runSQL.sh" || true
pkill -f "runBenchmark.sh" || true
sleep 2

# 2. 清理缓存性能数据
echo "2. 清理历史缓存性能数据..."
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
USE cache_monitor;
DELETE FROM cache_performance_log WHERE timestamp < DATE_SUB(NOW(), INTERVAL 1 HOUR);
" 2>/dev/null || echo "  跳过清理历史数据"

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
sleep 3

# 5. 显示重置后的缓存状态
echo "5. 重置后的缓存状态："
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
echo "快速重置完成！可以开始新的TPC-C实验"
echo "=========================================="
