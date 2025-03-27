"""
starrocks 批量修改表副本数，可配置修改前和修改后的副本数。
普通表及分区表。
"""
import pymysql
import time


# 副本数配置
REPLICATION_NUM_BEFORE = "3"  # 修改前的副本数
REPLICATION_NUM_AFTER = "1"   # 修改后的副本数

# 数据库连接配置
DB_CONFIG = {
    "host": "127.0.0.1",
    "user": "root",
    "password": "root.COM2025*",
    "database": "information_schema",
    "port": 9030,
}


def fetch_tables_with_replication_num(connection):
    """查询指定 replication_num 的普通表"""
    query = f"""
    SELECT TABLE_SCHEMA, TABLE_NAME 
    FROM information_schema.tables_config 
    WHERE TABLE_ENGINE='OLAP' AND PROPERTIES LIKE '%"replication_num":"{REPLICATION_NUM_BEFORE}"%'
    """
    with connection.cursor() as cursor:
        cursor.execute(query)
        return cursor.fetchall()


def fetch_partition_tables_with_replication_num(connection):
    """查询指定 replication_num 的分区表"""
    query = f"""
    SELECT TABLE_SCHEMA, TABLE_NAME 
    FROM information_schema.tables_config 
    WHERE TABLE_ENGINE='OLAP' AND PARTITION_KEY <> '' AND PROPERTIES LIKE '%"replication_num":"{REPLICATION_NUM_BEFORE}"%'
    """
    with connection.cursor() as cursor:
        cursor.execute(query)
        return cursor.fetchall()


def alter_table_replication_num(connection, schema, table):
    """修改普通表的 replication_num"""
    alter_sql = (
        f'ALTER TABLE `{schema}`.`{table}` SET ("default.replication_num" = "{REPLICATION_NUM_AFTER}")'
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute(alter_sql)
            print(f"[INFO] Successfully altered table: {schema}.{table}")
    except Exception as e:
        print(f"[ERROR] Failed to alter table {schema}.{table}: {str(e)}")


def alter_partition_replication_num(connection, schema, table):
    """修改分区表的 replication_num"""
    alter_sql = f'ALTER TABLE `{schema}`.`{table}` MODIFY PARTITION (*) SET("replication_num"="{REPLICATION_NUM_AFTER}")'
    try:
        with connection.cursor() as cursor:
            cursor.execute(alter_sql)
            print(f"[INFO] Successfully altered partition table: {schema}.{table}")
    except Exception as e:
        print(f"[ERROR] Failed to alter partition table {schema}.{table}: {str(e)}")


def main():
    # 连接数据库
    connection = pymysql.connect(**DB_CONFIG)
    try:
        # 获取需要修改的普通表
        tables = fetch_tables_with_replication_num(connection)
        if not tables:
            print(f"[INFO] No normal tables found with replication_num={REPLICATION_NUM_BEFORE}.")
        else:
            # 遍历并修改普通表
            for schema, table in tables:
                alter_table_replication_num(connection, schema, table)
                time.sleep(0.5)

        # 获取需要修改的分区表
        partition_tables = fetch_partition_tables_with_replication_num(connection)
        if not partition_tables:
            print(f"[INFO] No partition tables found with replication_num={REPLICATION_NUM_BEFORE}.")
        else:
            # 遍历并修改分区表
            for schema, table in partition_tables:
                alter_partition_replication_num(connection, schema, table)
                time.sleep(0.5)

        # 提交事务
        connection.commit()
    finally:
        connection.close()


if __name__ == "__main__":
    main()