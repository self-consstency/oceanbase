#!/bin/bash

# 分析缓存差值监控日志脚本
# 统计运行期间的命中率（排除起始值）

set -e

# 检查参数
if [ $# -eq 0 ]; then
    echo "用法: $0 <日志文件>"
    echo "示例: $0 cache_delta_20240908_143000.log"
    echo ""
    echo "可用的日志文件："
    ls -la cache_delta_*.log 2>/dev/null || echo "没有找到日志文件"
    exit 1
fi

LOG_FILE="$1"

if [ ! -f "$LOG_FILE" ]; then
    echo "错误：日志文件 '$LOG_FILE' 不存在"
    exit 1
fi

echo "=========================================="
echo "缓存差值监控日志分析（运行期间命中率统计）"
echo "日志文件: $LOG_FILE"
echo "=========================================="

# 1. 基本统计信息
echo "1. 监控期间基本统计："
echo "开始时间: $(head -n 3 "$LOG_FILE" | tail -n 1 | cut -d' ' -f3-)"
echo "结束时间: $(tail -n 1 "$LOG_FILE" | cut -d',' -f1)"
echo "总记录数: $(wc -l < "$LOG_FILE")"
echo ""

# 2. 按缓存名称统计运行期间命中率
echo "2. 各缓存运行期间命中率统计："
awk -F',' '
NR > 3 {  # 跳过注释行
    cache_name = $2
    hit_delta = $3
    miss_delta = $4
    hit_rate = $5
    memory_mb = $6
    
    # 累加统计（只统计有请求的记录）
    if (hit_delta > 0 || miss_delta > 0) {
        total_hit[cache_name] += hit_delta
        total_miss[cache_name] += miss_delta
        total_memory[cache_name] = memory_mb
        count[cache_name]++
        hit_rate_sum[cache_name] += hit_rate
    }
}
END {
    printf "%-20s %-12s %-12s %-10s %-12s %-8s %-10s\n", "缓存名称", "总命中增量", "总未命中增量", "运行命中率", "内存使用", "记录数", "平均命中率"
    printf "%-20s %-12s %-12s %-10s %-12s %-8s %-10s\n", "--------------------", "------------", "------------", "----------", "------------", "--------", "----------"
    
    for (cache in total_hit) {
        # 计算运行期间命中率 = 总命中增量 / (总命中增量 + 总未命中增量)
        total_requests = total_hit[cache] + total_miss[cache]
        runtime_hit_rate = (total_requests > 0) ? (total_hit[cache] * 100.0 / total_requests) : 0
        avg_hit_rate = (count[cache] > 0) ? (hit_rate_sum[cache] / count[cache]) : 0
        
        printf "%-20s %-12d %-12d %-9.2f%% %-12s %-8d %-9.2f%%\n", 
               cache, total_hit[cache], total_miss[cache], runtime_hit_rate, total_memory[cache] "MB", count[cache], avg_hit_rate
    }
}' "$LOG_FILE"

echo ""
echo "=========================================="

# 3. 运行期间性能趋势分析
echo "3. 运行期间性能趋势分析："
awk -F',' '
NR > 3 {
    cache_name = $2
    hit_delta = $3
    miss_delta = $4
    hit_rate = $5
    
    # 只统计有请求的记录
    if (hit_delta > 0 || miss_delta > 0) {
        hit_rates[cache_name] = hit_rates[cache_name] " " hit_rate
        count[cache_name]++
    }
}
END {
    for (cache in hit_rates) {
        if (count[cache] > 1) {
            split(hit_rates[cache], rates, " ")
            min_rate = rates[2]
            max_rate = rates[2]
            for (i = 2; i <= count[cache] + 1; i++) {
                if (rates[i] < min_rate) min_rate = rates[i]
                if (rates[i] > max_rate) max_rate = rates[i]
            }
            printf "%-20s: 最低 %.2f%%, 最高 %.2f%%, 波动 %.2f%%\n", 
                   cache, min_rate, max_rate, max_rate - min_rate
        }
    }
}' "$LOG_FILE"

echo ""
echo "=========================================="

# 4. 运行期间总体统计
echo "4. 运行期间总体统计："
awk -F',' '
NR > 3 {
    hit_delta = $3
    miss_delta = $4
    
    # 只统计有请求的记录
    if (hit_delta > 0 || miss_delta > 0) {
        total_hit += hit_delta
        total_miss += miss_delta
        record_count++
    }
}
END {
    total_requests = total_hit + total_miss
    overall_hit_rate = (total_requests > 0) ? (total_hit * 100.0 / total_requests) : 0
    
    printf "总命中增量: %d\n", total_hit
    printf "总未命中增量: %d\n", total_miss
    printf "总请求增量: %d\n", total_requests
    printf "运行期间总体命中率: %.2f%%\n", overall_hit_rate
    printf "有效记录数: %d\n", record_count
}' "$LOG_FILE"

echo ""
echo "=========================================="

# 5. 生成CSV报告
CSV_FILE="${LOG_FILE%.log}_runtime_analysis.csv"
echo "5. 生成CSV分析报告: $CSV_FILE"

cat > "$CSV_FILE" << EOF
缓存名称,总命中增量,总未命中增量,运行命中率,内存使用MB,记录数,平均命中率
EOF

awk -F',' '
NR > 3 {
    cache_name = $2
    hit_delta = $3
    miss_delta = $4
    hit_rate = $5
    memory_mb = $6
    
    # 过滤掉表头行和无效数据
    if (cache_name != "CACHE_NAME" && cache_name != "缓存名称" && cache_name != "" && (hit_delta > 0 || miss_delta > 0)) {
        total_hit[cache_name] += hit_delta
        total_miss[cache_name] += miss_delta
        total_memory[cache_name] = memory_mb
        count[cache_name]++
        hit_rate_sum[cache_name] += hit_rate
    }
}
END {
    for (cache in total_hit) {
        # 计算运行期间命中率
        total_requests = total_hit[cache] + total_miss[cache]
        runtime_hit_rate = (total_requests > 0) ? (total_hit[cache] * 100.0 / total_requests) : 0
        avg_hit_rate = (count[cache] > 0) ? (hit_rate_sum[cache] / count[cache]) : 0
        
        printf "%s,%d,%d,%.2f,%s,%d,%.2f\n", 
               cache, total_hit[cache], total_miss[cache], runtime_hit_rate, total_memory[cache], count[cache], avg_hit_rate
    }
}' "$LOG_FILE" >> "$CSV_FILE"

echo "CSV报告已生成: $CSV_FILE"
echo ""

# 6. 运行期间性能建议
echo "6. 运行期间性能优化建议："
awk -F',' '
NR > 3 {
    cache_name = $2
    hit_delta = $3
    miss_delta = $4
    hit_rate = $5
    
    # 只统计有请求的记录
    if (hit_delta > 0 || miss_delta > 0) {
        total_hit[cache_name] += hit_delta
        total_miss[cache_name] += miss_delta
        count[cache_name]++
        hit_rate_sum[cache_name] += hit_rate
    }
}
END {
    for (cache in total_hit) {
        if (count[cache] > 0) {
            # 计算运行期间命中率
            total_requests = total_hit[cache] + total_miss[cache]
            runtime_hit_rate = (total_requests > 0) ? (total_hit[cache] * 100.0 / total_requests) : 0
            
            if (runtime_hit_rate < 50) {
                suggestion = "运行期间命中率较低，建议增加缓存大小或检查访问模式"
            } else if (runtime_hit_rate < 80) {
                suggestion = "运行期间命中率偏低，建议优化访问策略"
            } else if (runtime_hit_rate >= 95) {
                suggestion = "运行期间性能优秀，无需优化"
            } else {
                suggestion = "运行期间性能良好"
            }
            
            printf "%-20s: 运行命中率 %.2f%% - %s\n", cache, runtime_hit_rate, suggestion
        }
    }
}' "$LOG_FILE"

echo ""
echo "=========================================="
echo "分析完成！"
echo "详细数据已保存到: $CSV_FILE"
echo "=========================================="
