#!/bin/bash
# test_cache.sh - 测试缓存监控

DB_HOST="127.0.0.1"
DB_PORT="10000"
DB_USER="root@tenant1"
TENANT_ID="1004"

echo "测试缓存监控..."

mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
SELECT 
    CACHE_NAME AS '缓存名称',
    CONCAT(ROUND(HIT_RATIO, 2), '%%') AS '命中率',
    CONCAT(ROUND(CACHE_SIZE / 1024 / 1024, 2), 'MB') AS '内存使用',
    TOTAL_HIT_CNT AS '命中次数',
    TOTAL_MISS_CNT AS '未命中次数',
    PRIORITY AS '优先级'
FROM oceanbase.GV\$OB_KVCACHE 
WHERE TENANT_ID = $TENANT_ID
    AND CACHE_NAME IN (
        'user_block_cache',
        'index_block_cache', 
        'user_row_cache',
        'bf_cache',
        'fuse_row_cache',
        'storage_meta_cache'
    )
ORDER BY HIT_RATIO DESC;
"
