#!/usr/bin/python3
#coding:utf-8
"""
starrocks 原生快照备份(v2.5 只备份表，因为全库备时会报错，视图不支持)
https://docs.starrocks.io/zh/docs/3.2/administration/management/Backup_and_restore/
"""

import pymysql
import time
import logging
import subprocess
import datetime

logging.basicConfig(filename='/var/log/backup_log.txt', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

#   create user  'backup'@'127.0.0.1' identified by 'BndStarRocksBackup*';  
#   GRANT REPOSITORY ON SYSTEM to user 'backup'@'127.0.0.1';
#   GRANT SELECT,EXPORT  ON *.*  to user 'backup'@'127.0.0.1';
# 数据库连接配置
db_config = {
    'host': '127.0.0.1',
    'user': 'backup',
    'password': 'BndStarRocksBackup*',
    'database': 'information_schema',  
    'port': 9030,  
}

# 备份仓库名
BACKUP_REPO = "backup_repo" 

# 执行SQL命令的函数
def execute_sql(sql, fetch=True):
    connection = pymysql.connect(**db_config)
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql)
            if fetch:
                return cursor.fetchall()
            else:
                connection.commit()
    finally:
        connection.close()


# 备份数据库的主函数
def main():
    # 获取所有数据库的库名
    logging.info("Starting to fetch database names.")
    databases = execute_sql("SHOW DATABASES")
    databases = [db[0] for db in databases if db[0] not in ['information_schema', 'mysql', 'performance_schema', 'sys', '_statistics_']]  # 排除系统库
    logging.info(f"{datetime.datetime.now()} Fetched databases: {databases}")

    for db in databases:
        # 获取每个数据库中所有 BASE TABLE 的表名
        tables = execute_sql(f"""
            SELECT TABLE_NAME
            FROM tables
            WHERE TABLE_SCHEMA = '{db}' AND TABLE_TYPE = 'BASE TABLE';
        """)
        base_tables = [table[0] for table in tables]
        if not base_tables:
            logging.info(f"{datetime.datetime.now()} No base tables found in database {db}. Skipping backup.")
            continue

        logging.info(f"{datetime.datetime.now()} Base tables in {db}: {base_tables}")
        # 生成备份时间戳并执行备份命令
        timestamp = time.strftime('%Y%m%d%H%M%S')
#        base_tables_str = ', '.join(base_tables)
        base_tables_str = ', '.join(f'`{table}`' for table in base_tables)
        backup_command = f"BACKUP SNAPSHOT {db}.{db}_{timestamp}_backup  TO {BACKUP_REPO} ON ({base_tables_str});"
        execute_sql(backup_command, fetch=False)

        # 检查备份状态
        while True:
            backup_status = execute_sql(f"SHOW BACKUP FROM {db}")
            state = backup_status[0][3]  # 假设State字段在第三列
            backup_log = f"{datetime.datetime.now()} Backup finished for database {db}"
            print(backup_log)
            logging.info(backup_log)
            if state == 'FINISHED':
                finished_log = f"{datetime.datetime.now()} Backup finished for database {db}"
                print(finished_log)
                logging.info(finished_log)
                dbbak_status = "1"
                break
            elif state == 'CANCELLED':
                cancelled_log = f"{datetime.datetime.now()} Backup cancelled for database {db}"
                print(cancelled_log)
                logging.error(cancelled_log)
                dbbak_status = "0"
                break
            else:
                time.sleep(60)  # 休眠1分钟后再检查状态

if __name__ == "__main__":
    main()

