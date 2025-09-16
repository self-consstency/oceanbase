#!/bin/bash
# view_cache_data.sh - 查看存储的缓存性能数据

DB_HOST="127.0.0.1"
DB_PORT="10000"
DB_USER="root@tenant1"
DB_PASS=""

echo "=== 缓存性能数据分析 ==="
echo "时间: $(date)"
echo

# 1. 最近的数据
echo "1. 最近的数据:"
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS -e "
USE cache_monitor;
SELECT 
    test_time,
    cache_name,
    hit_rate,
    store_size_mb,
    kv_count
FROM cache_performance_log 
ORDER BY test_time DESC 
LIMIT 10;
"

echo

# 2. 各缓存的平均性能
echo "2. 各缓存的平均性能:"
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS -e "
USE cache_monitor;
SELECT 
    cache_name,
    COUNT(*) AS sample_count,
    ROUND(AVG(hit_rate), 2) AS avg_hit_rate,
    ROUND(MAX(hit_rate), 2) AS max_hit_rate,
    ROUND(MIN(hit_rate), 2) AS min_hit_rate,
    ROUND(AVG(store_size_mb), 2) AS avg_size_mb
FROM cache_performance_log 
GROUP BY cache_name
ORDER BY avg_hit_rate DESC;
"

echo

# 3. 性能统计
echo "3. 性能统计:"
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS -e "
USE cache_monitor;
SELECT 
    '总采样次数' AS metric,
    COUNT(*) AS value
FROM cache_performance_log
UNION ALL
SELECT 
    '监控时长(分钟)',
    ROUND(TIMESTAMPDIFF(MINUTE, MIN(test_time), MAX(test_time)), 2)
FROM cache_performance_log
UNION ALL
SELECT 
    '平均命中率(%)',
    ROUND(AVG(hit_rate), 2)
FROM cache_performance_log
UNION ALL
SELECT 
    '总内存使用(MB)',
    ROUND(SUM(store_size_mb), 2)
FROM cache_performance_log;
"
