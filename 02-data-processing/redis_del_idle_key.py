import redis
from redis.exceptions import ConnectionError

"""
删除满足特定条件的Redis键：键的闲置时间超过x秒，且没有设置TTL
"""

def del_idle_key(redis_conn,del_time):
    try:
        # 获取所有的键
        cursor = '0'
        while cursor != 0:
            # 使用SCAN命令获取键
            cursor, keys = redis_conn.scan(cursor=int(cursor), count=10000)  # count参数可以根据需要调整

            # 遍历每个键并检查闲置时间和大小
            for key in keys:
                # 检查键的闲置时间
                idle_time = redis_conn.object("idletime", key)
                # 检查键是否有TTL
                ttl = redis_conn.ttl(key)
                # 判断是否满足删除条件
                if idle_time > del_time and ttl == -1:
                    print(f"删除 {key} 因为它已经闲置了 {idle_time} 秒，并且没有设置TTL。")
                    redis_conn.delete(key)

    except ConnectionError as e:
        print(f"连接Redis失败: {e}")
    except Exception as e:
        print(f"发生错误: {e}")

if __name__ == "__main__":
    # 建立Redis连接
    redis_conn = redis.Redis(host="127.0.0.1", port=6379, password="xxxxxxxxxx")

    # 键的闲置时间超过3天（259200秒）
    del_time = 259200
    del_idle_key(redis_conn,del_time)