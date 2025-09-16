#!/bin/bash
# compare_approaches.sh - 对比不同 SQL 执行方式

DB_HOST="127.0.0.1"
DB_PORT="10000"
DB_USER="root@tenant1"

echo "=== 方式1：单次执行多个语句（容易出错）==="
echo "尝试执行："
echo "CREATE DATABASE IF NOT EXISTS test_db;"
echo "USE test_db;"
echo "CREATE TABLE IF NOT EXISTS test_table (id INT);"
echo "INSERT INTO test_table VALUES (1);"
echo "SELECT * FROM test_table;"
echo

# 方式1：单次执行
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;
CREATE TABLE IF NOT EXISTS test_table (id INT);
INSERT INTO test_table VALUES (1);
SELECT * FROM test_table;
" 2>&1

echo
echo "=== 方式2：分离执行（更稳定）==="
echo "步骤1：创建数据库和表"
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
CREATE DATABASE IF NOT EXISTS test_db;
USE test_db;
CREATE TABLE IF NOT EXISTS test_table2 (id INT);
" 2>&1

echo "步骤2：插入数据"
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
USE test_db;
INSERT INTO test_table2 VALUES (2);
" 2>&1

echo "步骤3：查询数据"
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "
USE test_db;
SELECT * FROM test_table2;
" 2>&1

echo
echo "=== 清理测试数据 ==="
mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -e "DROP DATABASE IF EXISTS test_db;" 2>/dev/null
