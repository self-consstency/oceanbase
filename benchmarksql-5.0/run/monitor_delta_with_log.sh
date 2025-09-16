#!/bin/bash

# 缓存性能差值监控脚本（带日志记录）
# 实时监控缓存性能变化并记录到日志文件

set -e

# 配置参数
DB_HOST="127.0.0.1"
DB_PORT="10000"
DB_USER="root@tenant1"
TENANT_ID="1004"
INTERVAL=5  # 监控间隔（秒）
LOG_FILE="cache_delta_$(date +%Y%m%d_%H%M%S).log"

echo "=========================================="
echo "缓存性能差值监控脚本（带日志记录）"
echo "监控间隔: ${INTERVAL}秒"
echo "日志文件: ${LOG_FILE}"
echo "按 Ctrl+C 停止监控"
echo "=========================================="

# 创建日志文件头
cat > "$LOG_FILE" << EOF
# 缓存性能差值监控日志
# 开始时间: $(date '+%Y-%m-%d %H:%M:%S')
# 监控间隔: ${INTERVAL}秒
# 格式: 时间戳,缓存名称,命中增量,未命中增量,命中率,内存使用MB,总命中数
EOF

# 获取初始缓存统计
get_cache_stats() {
    mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
    SELECT 
        CACHE_NAME,
        TOTAL_HIT_CNT,
        TOTAL_MISS_CNT,
        CACHE_SIZE,
        HIT_RATIO
    FROM oceanbase.GV\$OB_KVCACHE 
    WHERE TENANT_ID = $TENANT_ID
    ORDER BY CACHE_SIZE DESC;
    " 2>/dev/null
}

# 计算差值并显示
calculate_delta() {
    local prev_stats="$1"
    local curr_stats="$2"
    local timestamp="$3"
    
    echo "时间: $timestamp"
    echo "=========================================================================================================="
    printf "%-20s %-12s %-12s %-10s %-12s %-12s\n" "缓存名称" "命中增量" "未命中增量" "命中率" "内存使用" "总命中数"
    echo "=========================================================================================================="
    
    # 使用awk计算差值
    echo "$curr_stats" | awk -v prev="$prev_stats" -v ts="$timestamp" '
    BEGIN {
        # 解析上一次的数据
        split(prev, prev_lines, "\n")
        for (i in prev_lines) {
            if (prev_lines[i] ~ /^[a-zA-Z_]/) {
                split(prev_lines[i], fields, "\t")
                prev_hit[fields[1]] = fields[2]
                prev_miss[fields[1]] = fields[3]
            }
        }
    }
    /^[a-zA-Z_]/ {
        cache_name = $1
        curr_hit = $2
        curr_miss = $3
        cache_size = $4
        hit_ratio = $5
        
        # 计算差值
        hit_delta = curr_hit - (prev_hit[cache_name] + 0)
        miss_delta = curr_miss - (prev_miss[cache_name] + 0)
        
        # 计算当前命中率（基于增量）
        total_requests = hit_delta + miss_delta
        current_hit_rate = (total_requests > 0) ? (hit_delta * 100.0 / total_requests) : 0
        
        # 格式化内存使用
        memory_mb = sprintf("%.2f", cache_size / 1024 / 1024)
        
        # 根据命中率添加颜色标识
        if (current_hit_rate >= 95) {
            hit_rate_color = "\033[32m"  # 绿色 - 优秀
        } else if (current_hit_rate >= 80) {
            hit_rate_color = "\033[33m"  # 黄色 - 良好
        } else if (current_hit_rate >= 50) {
            hit_rate_color = "\033[35m"  # 紫色 - 一般
        } else {
            hit_rate_color = "\033[31m"  # 红色 - 较差
        }
        
        printf "%-20s %-12d %-12d %s%-9.2f%%\033[0m %-12s %-12d\n", 
               cache_name, hit_delta, miss_delta, hit_rate_color, current_hit_rate, memory_mb, curr_hit
        
        # 记录到日志文件
        print ts "," cache_name "," hit_delta "," miss_delta "," current_hit_rate "," memory_mb "," curr_hit >> "'$LOG_FILE'"
    }'
    echo ""
}

# 主监控循环
echo "开始监控缓存性能变化..."
echo ""

# 获取初始数据
prev_stats=$(get_cache_stats)

while true; do
    sleep $INTERVAL
    
    # 获取当前数据
    curr_stats=$(get_cache_stats)
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 计算并显示差值
    calculate_delta "$prev_stats" "$curr_stats" "$timestamp"
    
    # 更新上一次的数据
    prev_stats="$curr_stats"
done
