import argparse
import pymysql
import random
import time
import re
import queue
from concurrent.futures import ThreadPoolExecutor, as_completed
"""
MySQL高并发测试脚本
脚本功能：
1. 支持CRUD四种操作的高并发测试。
2. 支持配置并发数、总操作数、提交前等待时间等参数。
3. 支持循环执行多轮测试，便于观察稳定性，防止偶发问题影响结果。

python mysql_concurrency_test.py -h

# 300并发插入2000条数据
python mysql_concurrency_test.py --concurrency 300 --operation insert --total 2000
# 增加提交前等待10毫秒，循环10轮，实际插入 2000*10 = 20000条, 禁用连接池
python mysql_concurrency_test.py --concurrency 300 --operation insert --total 2000  --wait-ms 10 --loops 10 --no-pool

# 200并发更新1000条数据
python mysql_concurrency_test.py --concurrency 200 --operation update --total 1000
python mysql_concurrency_test.py --concurrency 200 --operation update --total 1000 --wait-ms 10 --loops 10
# 150并发删除500条数据
python mysql_concurrency_test.py --concurrency 150 --operation delete --total 500
python mysql_concurrency_test.py --concurrency 150 --operation delete --total 500 --wait-ms 10 --loops 10
# 50并发查询100次
python mysql_concurrency_test.py --concurrency 50 --operation select --total 100
python mysql_concurrency_test.py --concurrency 50 --operation select --total 100 --wait-ms 10 --loops 10


数据库初始化SQL（请提前执行，确保测试环境准备就绪）：
-- 1. 创建测试数据库（若不存在）
CREATE DATABASE IF NOT EXISTS testdb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE testdb;

-- 2. 创建测试表（含索引，模拟真实场景）
DROP TABLE IF EXISTS user_operation_log;
CREATE TABLE user_operation_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    operation_type VARCHAR(20) NOT NULL COMMENT 'insert/update/delete',
    operation_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    content VARCHAR(100) NOT NULL COMMENT '操作内容'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='高并发测试表';

-- 3. 初始化1000条基础数据（用于更新/删除操作）
INSERT INTO user_operation_log (user_id, operation_type, content)
SELECT 
    FLOOR(1 + RAND() * 100) AS user_id,
    'insert' AS operation_type,
    CONCAT('初始化数据_', FLOOR(1 + RAND() * 10000)) AS content
FROM INFORMATION_SCHEMA.COLUMNS LIMIT 1000;

-- 4. 创建索引提升操作效率（避免高并发下锁等待）
CREATE INDEX idx_user_id ON user_operation_log(user_id);
CREATE INDEX idx_operation_time ON user_operation_log(operation_time);
"""

# MySQL连接配置（适配你的容器环境）
MYSQL_CONFIG = {
    'host': '192.168.31.122',
    'port': 3306,
    'user': 'root',
    'password': 'root.COM2025*',
    'database': 'testdb',
    'charset': 'utf8mb4',
    'connect_timeout': 5  # 避免连接超时阻塞
}

# 等待提交前的毫秒数（可通过 --wait-ms 设置，默认0）
WAIT_MS = 0

# 统一配置：随机 user_id 的范围（供 insert/update/select 使用）
USER_ID_MIN = 1
USER_ID_MAX = 200

# 私有连接池（模块内部使用）
_CONN_POOL = None

def init_conn_pool(size):
    """初始化连接池，size 为池大小。若全部连接创建失败则禁止使用池."""
    global _CONN_POOL
    # 如果已经存在且大小相同，直接复用
    if _CONN_POOL and getattr(_CONN_POOL, "_pool_size", None) == size:
        print(f"复用已存在连接池：大小={size}")
        return
    if size <= 0:
        _CONN_POOL = None
        return
    # 如果存在但大小不同，先关闭旧池
    if _CONN_POOL:
        close_conn_pool()
    q = queue.Queue(maxsize=size)
    created = 0
    for _ in range(size):
        try:
            conn = pymysql.connect(**MYSQL_CONFIG)
            q.put(conn)
            created += 1
        except Exception as e:
            print(f"创建连接失败（池）: {e}")
    if created == 0:
        _CONN_POOL = None
        print("未能创建任何池内连接，回退为按需创建连接模式")
    else:
        # 记录池对象及大小，便于复用判断
        q._pool_size = size
        _CONN_POOL = q
        print(f"初始化连接池：目标={size}，实际创建={created}")

def close_conn_pool():
    """关闭连接池中的所有连接并清理"""
    global _CONN_POOL
    if not _CONN_POOL:
        return
    while not _CONN_POOL.empty():
        try:
            conn = _CONN_POOL.get_nowait()
            try:
                conn.close()
            except:
                pass
        except queue.Empty:
            break
    _CONN_POOL = None

def get_conn_from_pool(timeout=5):
    """尝试从池中获取连接；失败时返回 (conn, False) 表示非池连接"""
    global _CONN_POOL
    if _CONN_POOL:
        try:
            conn = _CONN_POOL.get(timeout=timeout)
            return conn, True
        except Exception:
            # 池不可用或超时，回退到按需创建
            conn = get_mysql_conn()
            return conn, False
    else:
        conn = get_mysql_conn()
        return conn, False

def release_conn(conn, from_pool):
    """归还连接到池或关闭临时连接"""
    global _CONN_POOL
    if from_pool and _CONN_POOL:
        try:
            _CONN_POOL.put(conn, block=False)
            return
        except Exception:
            pass
    # 不能归还则关闭
    try:
        if conn:
            conn.close()
    except:
        pass

def get_mysql_conn():
    """创建MySQL连接（每个线程独立连接）"""
    try:
        conn = pymysql.connect(**MYSQL_CONFIG)
        return conn
    except Exception as e:
        print(f"创建连接失败：{str(e)}")
        return None

def execute_insert(conn):
    """执行插入操作"""
    try:
        with conn.cursor() as cursor:
            user_id = random.randint(USER_ID_MIN, USER_ID_MAX)
            content = f"并发插入_用户{user_id}_时间{int(time.time())}_随机数{random.randint(1000, 9999)}"
            sql = """
                INSERT INTO user_operation_log (user_id, operation_type, content)
                VALUES (%s, 'insert', %s)
            """
            cursor.execute(sql, (user_id, content))
            # 在提交前可选等待（毫秒）
            if WAIT_MS > 0:
                time.sleep(WAIT_MS / 1000.0)
            conn.commit()
        return f"插入成功：user_id={user_id}"
    except Exception as e:
        conn.rollback()
        return f"插入失败：{str(e)}"

def execute_update(conn):
    """执行更新操作（更新插入的数据）"""
    try:
        with conn.cursor() as cursor:
            # 随机选择1条已存在的数据更新（使用统一范围）
            user_id = random.randint(USER_ID_MIN, USER_ID_MAX)
            new_content = f"并发更新_时间{int(time.time())}_随机数{random.randint(1000, 9999)}"
            sql = """
                UPDATE user_operation_log 
                SET content = %s, operation_type = 'update', operation_time = NOW()
                WHERE user_id = %s and operation_type = 'insert'
                LIMIT 1
            """
            affected_rows = cursor.execute(sql, (new_content, user_id))
            # 在提交前可选等待（毫秒）
            if WAIT_MS > 0:
                time.sleep(WAIT_MS / 1000.0)
            conn.commit()
            if affected_rows > 0:
                return f"更新成功：user_id={user_id}"
            else:
                return f"更新失败：未找到符合条件的初始化数据"
    except Exception as e:
        conn.rollback()
        return f"更新失败：{str(e)}"

def execute_delete(conn):
    """执行删除操作（删除已更新/插入的数据）"""
    try:
        with conn.cursor() as cursor:
            # 随机删除1条有效数据
            user_id = random.randint(USER_ID_MIN, USER_ID_MAX)
            sql = """
                DELETE FROM user_operation_log 
                WHERE user_id = %s
                LIMIT 1
            """
            affected_rows = cursor.execute(sql, (user_id,))
            # 在提交前可选等待（毫秒）
            if WAIT_MS > 0:
                time.sleep(WAIT_MS / 1000.0)
            conn.commit()
            if affected_rows > 0:
                return f"删除成功：user_id={user_id}"
            else:
                return f"删除失败：未找到符合条件的有效数据"
    except Exception as e:
        conn.rollback()
        return f"删除失败：{str(e)}"

def execute_select(conn):
    """执行查询操作：随机选取一个 user_id 的一条有效记录并返回"""
    try:
        with conn.cursor() as cursor:
            user_id = random.randint(USER_ID_MIN, USER_ID_MAX)
            sql = """
                SELECT id, user_id, operation_type, content, operation_time
                FROM user_operation_log
                WHERE user_id = %s
                ORDER BY RAND()
                LIMIT 1
            """
            cursor.execute(sql, (user_id,))
            row = cursor.fetchone()
            # 在返回前可选等待（毫秒），模拟处理时延
            if WAIT_MS > 0:
                time.sleep(WAIT_MS / 1000.0)
            if row:
                return f"查询成功：id={row[0]} user_id={row[1]} type={row[2]}"
            else:
                return f"查询失败：未找到 user_id={user_id} 的符合条件的数据"
    except Exception as e:
        return f"查询失败：{str(e)}"

# 修改 worker：使用池获取/归还连接
def worker(operation_type):
    """工作线程：从连接池获取连接 + 执行指定操作，结束后归还或关闭连接"""
    conn, from_pool = get_conn_from_pool(timeout=5)
    if not conn:
        return "连接MySQL失败"
    try:
        if operation_type == 'insert':
            result = execute_insert(conn)
        elif operation_type == 'update':
            result = execute_update(conn)
        elif operation_type == 'delete':
            result = execute_delete(conn)
        elif operation_type == 'select':
            result = execute_select(conn)
        else:
            result = "无效的操作类型"
        return result
    finally:
        release_conn(conn, from_pool)

# 调整 run_iteration：可选初始化连接池（pool_size<=0 则自动选择 min(concurrency,100)）
def run_iteration(concurrency, operation, total):
    start_time = time.time()
    results = []
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        tasks = [executor.submit(worker, operation) for _ in range(total)]
        for task in as_completed(tasks):
            results.append(task.result())

    success_count = sum(1 for res in results if "成功" in res)
    fail_count = total - success_count
    # 汇总影响行数（解析 "影响行数=NUMBER"）
    total_affected = 0
    for r in results:
        m = re.search(r"影响行数=(\d+)", r)
        if m:
            total_affected += int(m.group(1))
    end_time = time.time()
    cost_time = round(end_time - start_time, 2)
    failures = [r for r in results if "失败" in r][:10]
    return success_count, fail_count, cost_time, failures, total_affected

def main():
    # 解析命令行参数
    parser = argparse.ArgumentParser(description="MySQL高并发测试脚本")
    parser.add_argument('--concurrency', type=int, required=True, help="并发数（例如：200）")
    parser.add_argument('--operation', type=str, required=True, 
                        choices=['insert', 'update', 'delete', 'select'], help="操作类型（insert/update/delete/select）")
    parser.add_argument('--total', type=int, default=1000, help="总操作次数（默认：1000）")
    parser.add_argument('--wait-ms', type=int, default=0, help="提交前等待多少毫秒（默认：0）")
    parser.add_argument('--loops', type=int, default=1, help="循环次数，默认1；设置0或负值表示无限循环直到手动终止")
    parser.add_argument('--no-pool', action='store_true', help="禁用本地连接池（默认启用）")
    args = parser.parse_args()
 
    # 将等待时间应用到模块级变量
    global WAIT_MS
    WAIT_MS = max(0, args.wait_ms)
    use_pool = not args.no_pool

    loops = args.loops
    infinite = (loops <= 0)
 
    print(f"开始测试：并发数={args.concurrency}，操作类型={args.operation}，总操作次数={args.total}，提交前等待={WAIT_MS}ms，循环次数={'无限' if infinite else loops}，连接池={'启用' if use_pool else '禁用'}")
 
    # 如果启用则初始化连接池（大小与 concurrency 一致），多轮复用
    if use_pool:
        init_conn_pool(args.concurrency)
    try:
         if infinite:
             i = 1
             while True:
                 print(f"\n---- 第 {i} 轮开始 ----")
                 success_count, fail_count, cost_time, failures, _ = run_iteration(args.concurrency, args.operation, args.total)
                 print(f"第{i}轮完成：耗时={cost_time}秒，成功={success_count}，失败={fail_count}")
                 if failures:
                     print("失败详情（前10条）：")
                     for res in failures:
                         print(f"- {res}")
                 i += 1
         else:
             for i in range(1, loops + 1):
                 print(f"\n---- 第 {i} 轮开始 ----")
                 success_count, fail_count, cost_time, failures, _ = run_iteration(args.concurrency, args.operation, args.total)
                 print(f"第{i}轮完成：耗时={cost_time}秒，成功={success_count}，失败={fail_count}")
                 if failures:
                     print("失败详情（前10条）：")
                     for res in failures:
                         print(f"- {res}")
    except KeyboardInterrupt:
        print("\n手动终止测试。退出。")
    finally:
        # 程序结束或被中断时若启用了池则统一关闭连接池
        if use_pool:
            close_conn_pool()
 
if __name__ == "__main__":
    main()