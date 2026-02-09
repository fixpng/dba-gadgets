#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import time
import requests
import datetime
import json
from requests import Session
import sys
import pymysql
import socket
"""
zabbix监控sr存活状态脚本, 提前建好 monitor库 和每个节点一个检查表
逻辑如下：
1. 发送请求到 StarRocks StreamLoad 的 URL (更新检查表时间)
2. 检查响应状态码，如果响应状态码为 200, 则检查响应内容
3. 如果响应内容为 Success, 则等待 5 秒，然后检查表的 update_time 字段是否与当前时间一致
状态码说明：
1: 正常， 2: 请求超时， 3: 请求异常， 4: StreamLoad 失败， 5: 数据库查询超时， 6: 数据库查询异常
"""

host = sys.argv[1]
table = sys.argv[2]
# StarRocks StreamLoad 的URL
streamload_url = f'http://{host}:8030/api/monitor/{table}/_stream_load'
cur_timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
# 构建 StreamLoad 请求
data = {
    "id": 1,
    "update_time": cur_timestamp
}

# 设置 Basic 认证的用户名和密码
username = 'monitor'
password = 'Monitor.COM2025*'
# 构建请求头
headers = {
    'format': 'json',
    'Expect': '100-continue'
}
class LoadSession(Session):
    def rebuild_auth(self, prepared_request, response):
        """
        No code here means requests will always preserve the Authorization
        header when redirected.
        """

# 发送请求并获取响应
session = LoadSession()
session.timeout = 5
session.auth = (username, password)

def check_query():
    try:
        connection = pymysql.connect(
            host=host,
            port=9030,
            user=username,
            password=password,
            database='monitor',
            connect_timeout=session.timeout
        )

    # 创建游标
        cursor = connection.cursor()

    # 执行查询
        query = f'SELECT update_time FROM monitor.{table} WHERE id = 1'
        cursor.execute(query)

    # 获取结果
        result = cursor.fetchone()

    # 提取 update_time 的值
        update_time = result[0] if result else None
    except pymysql.MySQLError as e:
        if isinstance(e, pymysql.err.OperationalError) and 'timed out' in str(e):
            print("5")  # 超时错误
            sys.exit()
        else:
            print("6")  # 其他错误
            sys.exit()

    except socket.timeout:
        print("5")  # Socket 超时错误
        sys.exit()

    finally:
    # 关闭游标和连接
        cursor.close()
        connection.close()
    return update_time

try:
    response = session.put(streamload_url, data=json.dumps(data), headers=headers,allow_redirects=True)
    # 检查响应状态码
    if response.status_code == 200:
        status = response.json()
        if status['Status'] == 'Success':
            time.sleep(5) # 延迟一下，等待 StreamLoad 完成，关键！避免误告警
            update_time = check_query()
            if str(update_time) == cur_timestamp:
                print("1")
            else:
                print("4")
        else:
            print("4")
    else:
        print("3")
except requests.exceptions.Timeout:
    print("2")
    sys.exit()
except requests.exceptions.RequestException:
    print("3")
    sys.exit()
finally:
    session.close()
