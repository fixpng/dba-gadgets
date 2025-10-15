import threading
import time
import random
import pymysql
from datetime import datetime
"""
模拟业务操作，测试ProxySQL的读写分离和负载均衡功能
# 创建测试表1
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

# 创建测试表2
CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'completed', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

# 插入测试数据
INSERT INTO users (username, email) VALUES 
('user1', 'user1@example.com'),
('user2', 'user2@example.com'),
('user3', 'user3@example.com');

INSERT INTO orders (user_id, amount, status) VALUES
(1, 99.99, 'completed'),
(2, 150.50, 'pending'),
(1, 29.99, 'completed');


mysql -h192.168.31.122 -P6033 -utestapp -pTest*123456 testdb
"""

# 数据库连接配置（连接ProxySQL）
DB_CONFIG = {
    'host': '192.168.31.122',
    'port': 6033,
    'user': 'testapp',
    'password': 'Test*123456',
    'db': 'testdb',
    'charset': 'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}
# 记录错误
errors = []
errors_lock = threading.Lock()
stop_logging = threading.Event()

def log_errors_realtime(interval=1):
    """实时打印错误日志"""
    last_printed = 0
    while not stop_logging.is_set():
        with errors_lock:
            new_errors = errors[last_printed:]
            if new_errors:
                for err in new_errors:
                    print(f"[错误] {err}")
                last_printed += len(new_errors)
        time.sleep(interval)
def get_connection():
    """获取数据库连接"""
    try:
        conn = pymysql.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        with errors_lock:
            errors.append(f"连接错误: {str(e)}")
        return None
def test_query():
    """测试查询操作"""
    thread_id = threading.current_thread().name
    try:
        conn = get_connection()
        if not conn:
            return
            
        with conn.cursor() as cursor:
            # 随机查询用户或订单
            if random.random() > 0.5:
                cursor.execute("SELECT * FROM users LIMIT 10")
                result = cursor.fetchall()
                print(f"{thread_id} 查询到 {len(result)} 个用户记录")
            else:
                cursor.execute("SELECT * FROM orders LIMIT 10")
                result = cursor.fetchall()
                print(f"{thread_id} 查询到 {len(result)} 个订单记录")
    except Exception as e:
        with errors_lock:
            errors.append(f"{thread_id} 查询错误: {str(e)}")
    finally:
        if conn:
            conn.close()
def test_insert():
    """测试插入操作"""
    thread_id = threading.current_thread().name
    try:
        conn = get_connection()
        if not conn:
            return
            
        with conn.cursor() as cursor:
            # 随机插入用户或订单
            if random.random() > 0.5:
                username = f"user_{int(time.time() % 10000)}"
                email = f"{username}@example.com"
                cursor.execute(
                    "INSERT INTO users (username, email) VALUES (%s, %s)",
                    (username, email)
                )
                conn.commit()
                print(f"{thread_id} 插入用户 {username} 成功")
            else:
                user_id = random.randint(1, 10)  # 假设已有用户ID范围
                amount = round(random.uniform(10, 1000), 2)
                status = random.choice(['pending', 'completed', 'cancelled'])
                cursor.execute(
                    "INSERT INTO orders (user_id, amount, status) VALUES (%s, %s, %s)",
                    (user_id, amount, status)
                )
                conn.commit()
                print(f"{thread_id} 插入订单 成功")
    except Exception as e:
        with errors_lock:
            errors.append(f"{thread_id} 插入错误: {str(e)}")
    finally:
        if conn:
            conn.close()
def test_update():
    """测试更新操作"""
    thread_id = threading.current_thread().name
    try:
        conn = get_connection()
        if not conn:
            return
            
        with conn.cursor() as cursor:
            # 随机更新用户或订单
            if random.random() > 0.5:
                cursor.execute("SELECT id FROM users ORDER BY RAND() LIMIT 1")
                result = cursor.fetchone()
                if result:
                    user_id = result['id']
                    new_email = f"updated_{user_id}@example.com"
                    cursor.execute(
                        "UPDATE users SET email = %s WHERE id = %s",
                        (new_email, user_id)
                    )
                    conn.commit()
                    print(f"{thread_id} 更新用户 {user_id} 成功")
            else:
                cursor.execute("SELECT id FROM orders WHERE status = 'pending' ORDER BY RAND() LIMIT 1")
                result = cursor.fetchone()
                if result:
                    order_id = result['id']
                    cursor.execute(
                        "UPDATE orders SET status = 'completed' WHERE id = %s",
                        (order_id,)
                    )
                    conn.commit()
                    print(f"{thread_id} 更新订单 {order_id} 成功")
    except Exception as e:
        with errors_lock:
            errors.append(f"{thread_id} 更新错误: {str(e)}")
    finally:
        if conn:
            conn.close()
def worker():
    """工作线程，随机执行查询、插入或更新操作"""
    while True:
        try:
            # 随机选择操作类型
            action = random.choices(
                [test_query, test_insert, test_update],
                weights=[5, 2, 3],  # 查询操作比例更高
                k=1
            )[0]
            action()
            # 随机休眠一段时间
            time.sleep(random.uniform(0.1, 1))
        except Exception as e:
            with errors_lock:
                errors.append(f"工作线程错误: {str(e)}")
            time.sleep(1)
def main():
    """主函数，启动多个工作线程"""
    print(f"开始测试: {datetime.now()}")
    print(f"连接到: {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    # 启动实时日志线程
    log_thread = threading.Thread(target=log_errors_realtime, daemon=True)
    log_thread.start()
    
    # 启动10个工作线程
    threads = []
    for i in range(10):
        t = threading.Thread(target=worker, name=f"线程-{i+1}")
        t.daemon = True  # 守护线程，主程序退出时自动结束
        t.start()
        threads.append(t)
    
    # 运行30分钟后自动结束
    try:
        time.sleep(1800)
    except KeyboardInterrupt:
        print("手动终止测试")
    stop_logging.set()
    log_thread.join(timeout=2)
    # 打印错误统计
    print(f"\n测试结束: {datetime.now()}")
    print(f"总错误数: {len(errors)}")
    if errors:
        print("错误列表:")
        for err in errors[:10]:  # 只显示前10个错误
            print(f"- {err}")
        if len(errors) > 10:
            print(f"- ... 还有 {len(errors)-10} 个错误未显示")
if __name__ == "__main__":
    main()
