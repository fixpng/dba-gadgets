import redis

"""
批量删除Redis列表中的元素，直到列表为空。
"""
def batch_delete_list(redis_conn, list_name, batch_size):

    start = 0
    end = batch_size - 1
    while True:
        length = redis_conn.llen(list_name)  # 获取列表当前长度
        if length == 0:
            break  # 如果列表长度为0，则退出循环
        elif length <= end:
            # 如果列表长度小于等于批次大小，直接删除列表
            redis_conn.delete(list_name)
            break
        else:
            # 使用LTRIM命令删除列表中[start, end]范围外的元素
            redis_conn.ltrim(list_name, end + 1, -1)

if __name__ == "__main__":
    # 创建Redis连接实例
    redis_conn = redis.Redis(host='127.0.0.1', port=6379, db=0, password="xxxxxxxxxx")
    # 定义要操作的列表名称和每次处理的元素数量
    list_name = "AKB48_1212_DATA"
    batch_size = 200
    # 调用函数执行批量删除操作
    batch_delete_list(redis_conn, list_name, batch_size)