#!/bin/bash
# collect_cache_data.sh - 后台收集缓存数据到数据库

DB_HOST="127.0.0.1"
DB_PORT="10000"
DB_USER="root@tenant1"
DB_PASS=""
TENANT_ID="1004"

echo "开始后台收集缓存性能数据到数据库..."
echo "使用 'mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS < analyze_cache_data.sql' 查看数据"

# 后台运行数据收集
while true; do
    mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS -e "
    -- 确保监控数据库存在
    CREATE DATABASE IF NOT EXISTS cache_monitor;
    USE cache_monitor;
    
    -- 创建缓存性能记录表（如果不存在）
    CREATE TABLE IF NOT EXISTS cache_performance_log (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        test_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        cache_name VARCHAR(128),
        tenant_id BIGINT,
        hit_count BIGINT,
        miss_count BIGINT,
        hit_rate DECIMAL(5,2),
        store_size_mb DECIMAL(10,2),
        kv_count BIGINT,
        recent_get_cnt BIGINT,
        score DECIMAL(10,2),
        INDEX idx_test_time (test_time),
        INDEX idx_cache_name (cache_name)
    );
    
    -- 插入当前缓存性能数据
    INSERT INTO cache_performance_log (
        cache_name, tenant_id, hit_count, miss_count, hit_rate, 
        store_size_mb, kv_count, recent_get_cnt, score
    )
    SELECT 
        CACHE_NAME,
        TENANT_ID,
        HIT_COUNT,
        MISS_COUNT,
        ROUND(HIT_COUNT * 100.0 / (HIT_COUNT + MISS_COUNT), 2),
        ROUND(STORE_SIZE / 1024 / 1024, 2),
        KV_CNT,
        RECENT_GET_CNT,
        SCORE
    FROM GV\$OB_KVCACHE 
    WHERE TENANT_ID = $TENANT_ID
        AND CACHE_NAME IN (
            'user_block_cache',
            'index_block_cache', 
            'user_row_cache',
            'bf_cache',
            'fuse_row_cache',
            'storage_meta_cache'
        );
    " 2>/dev/null
    
    sleep 10  # 每10秒收集一次数据
done
