#!/usr/bin/python3
#coding:utf-8
"""
starrocks 原生快照全实例恢复
https://docs.starrocks.io/zh/docs/3.2/administration/management/Backup_and_restore/
"""

import pymysql
import time
from datetime import datetime

REPO_NAME = 'uat_backup_repo'  # 仓库名
REPLICATION_NUM = 3  # 副本数
MAX_RETRIES = 3  # 最大重试次数

def create_connection():
    """创建并返回一个数据库连接"""
    return pymysql.connect(
        host='127.0.0.1',  # 主机地址
        user='root',  # 用户名
        password='',  # 密码
        port=9030
    )

def log(message):
    """打印带时间戳的日志信息"""
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{current_time}] {message}")

def show_snapshots():
    """显示指定仓库的所有快照"""
    connection = create_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(f"SHOW SNAPSHOT ON {REPO_NAME}")
        return cursor.fetchall()
    finally:
        cursor.close()
        connection.close()

def parse_snapshot_name(snapshot_name):
    """解析快照名称以提取库名和时间戳"""
    parts = snapshot_name.split('_')
    if len(parts) < 2 or not parts[-1] == 'backup':
        raise ValueError(f"Invalid snapshot name format: {snapshot_name}")
    
    db_name = '_'.join(parts[:-2])  # 库名由除最后两个部分外的所有部分组成
    timestamp_str = parts[-2]
    try:
        timestamp = datetime.strptime(timestamp_str, '%Y%m%d%H%M%S')
    except ValueError:
        raise ValueError(f"Invalid timestamp format in snapshot name: {timestamp_str}")
    
    return db_name, timestamp

def restore_snapshot(snapshot, db_name):
    """恢复指定的快照"""
    connection = create_connection()
    cursor = connection.cursor()
    try:
        timestamp = snapshot[1]  # 假设时间戳在第二个位置
        backup_name = snapshot[0]
        sql = f"RESTORE SNAPSHOT {db_name}.{backup_name} FROM {REPO_NAME} PROPERTIES (\"backup_timestamp\"=\"{timestamp}\", \"replication_num\"=\"{REPLICATION_NUM}\")"
        log(f"Executing SQL: {sql}")
        cursor.execute(sql)
        connection.commit()
        log(f"Started restoring snapshot: {backup_name} to database: {db_name}")
    except Exception as e:
        log(f"Error occurred while restoring snapshot: {e}")
        return False
    finally:
        cursor.close()
        connection.close()
    return True

def get_restore_status(db_name):
    """获取恢复任务的状态"""
    connection = create_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(f"SHOW RESTORE FROM {db_name}")
        restores = cursor.fetchall()
        for restore in restores:
            job_id, label, timestamp, db_name, state, *_ = restore
            if state in ('FINISHED', 'CANCELLED'):
                log(f"Restore job {job_id} for {label} in {db_name} has finished.")
                return True
            elif state in ['PENDING', 'SNAPSHOTING', 'DOWNLOAD', 'DOWNLOADING', 'COMMIT', 'COMMITTING']:
                log(f"Restore job {job_id} for {label} in {db_name} is still in progress.")
                return False
            else:
                log(f"Restore job {job_id} for {label} in {db_name} was cancelled or failed.")
                return False
        return False
    finally:
        cursor.close()
        connection.close()

def check_and_create_db(db_name):
    """检查数据库是否存在，如果不存在则创建"""
    connection = create_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(f"SHOW DATABASES LIKE '{db_name}'")
        if cursor.fetchone() is None:
            log(f"Database {db_name} does not exist, creating it now...")
            cursor.execute(f"CREATE DATABASE {db_name}")
            connection.commit()
            log(f"Database {db_name} created successfully.")
        else:
            log(f"Database {db_name} already exists.")
    finally:
        cursor.close()
        connection.close()

def restore_db(snapshot, db_name):
    check_and_create_db(db_name)  # 检查并创建数据库
    if db_name in ('information_schema', 'mysql', 'performance_schema', 'sys', '_statistics_'):
        return  # 系统数据库不需要恢复

    start_time = datetime.now()  # 记录开始时间

    retries = 0
    while retries < MAX_RETRIES:
        if restore_snapshot(snapshot, db_name):
            while True:
                if get_restore_status(db_name):
                    elapsed_seconds = (datetime.now() - start_time).total_seconds()
                    log(f"Restore job for {db_name} has finished. Total elapsed time: {elapsed_seconds:.0f} seconds")
                    return
                else:
                    elapsed_seconds = (datetime.now() - start_time).total_seconds()
                    log(f"Restore job for {db_name} is still in progress... Elapsed time: {elapsed_seconds:.0f} seconds")
                    time.sleep(30)  # 每隔30秒检查一次状态
        else:
            retries += 1
            log(f"Retrying restore for {db_name} ({retries}/{MAX_RETRIES})")
            time.sleep(5)  # 等待5秒后重试

    log(f"Failed to restore {db_name} after {MAX_RETRIES} attempts")

def main():
    # 获取所有快照
    snapshots = show_snapshots()
    
    # 解析快照名称并分组
    latest_snapshots = {}
    for snapshot in snapshots:
        snapshot_name, timestamp_str, status = snapshot
        if status != 'OK':
            continue
        
        try:
            db_name, _ = parse_snapshot_name(snapshot_name)
            if db_name not in latest_snapshots:
                latest_snapshots[db_name] = snapshot
            else:
                _, latest_timestamp = parse_snapshot_name(latest_snapshots[db_name][0])
                if _ > latest_timestamp:
                    latest_snapshots[db_name] = snapshot
        except ValueError as e:
            log(e)

    # 顺序执行每个数据库的恢复操作
    for db_name, snapshot in latest_snapshots.items():
        restore_db(snapshot, db_name)

if __name__ == "__main__":
    main()