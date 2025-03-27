"""
starrocks 批量修改物化视图副本数，可配置修改前和修改后的副本数。(删除重建)
SR (v3.2.15)当前物化视图无法修改副本数，已反馈官方：
MySQL [information_schema]> ALTER  MATERIALIZED VIEW  dsj_dwd.mv_zt_hhy_staff_user_company_info SET ("replication_num" = "1");
ERROR 1064 (HY000): Unexpected exception: Getting analyzing error. Detail message: Modify failed because unknown properties: {replication_num=1}, please add `session.` prefix if you want add session variables for mv(eg, "session.query_timeout"="30000000").. 
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


def fetch_materialized_views():
    """查询所有指定 replication_num 的物化视图"""
    query = f"""
    SELECT TABLE_SCHEMA, TABLE_NAME
    FROM information_schema.tables_config 
    WHERE TABLE_ENGINE = 'MATERIALIZED_VIEW' 
    AND PROPERTIES LIKE '%"replication_num":"{REPLICATION_NUM_BEFORE}"%';
    """
    connection = pymysql.connect(**DB_CONFIG)
    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
            return cursor.fetchall()
    finally:
        connection.close()


def get_create_view_statement(schema, table):
    """获取物化视图的创建语句"""
    query = f"SHOW CREATE TABLE `{schema}`.`{table}`;"
    connection = pymysql.connect(**DB_CONFIG)
    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
            result = cursor.fetchone()
            return result[1]  # 返回创建语句
    finally:
        connection.close()


def drop_view(schema, table):
    """删除物化视图"""
    query = f"DROP MATERIALIZED VIEW `{schema}`.`{table}`;"
    connection = pymysql.connect(**DB_CONFIG)
    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
        connection.commit()
    finally:
        connection.close()


def create_view(create_statement):
    """创建物化视图"""
    print(create_statement)
    connection = pymysql.connect(**DB_CONFIG)
    try:
        with connection.cursor() as cursor:
            cursor.execute(create_statement)
        connection.commit()
    finally:
        connection.close()


def update_replication_num(schema, create_statement):
    """修改创建语句中的 replication_num"""
    return create_statement.replace(
        f'"replication_num" = "{REPLICATION_NUM_BEFORE}"',
        f'"replication_num" = "{REPLICATION_NUM_AFTER}"'
    ).replace("CREATE MATERIALIZED VIEW ", f"CREATE MATERIALIZED VIEW `{schema}`.")


def main():
    # 获取所有指定 replication_num 的物化视图
    views = fetch_materialized_views()
    for schema, table in views:
        print(f"Processing view: {schema}.{table}")

        # 获取创建语句
        create_statement = get_create_view_statement(schema, table)
        print("Original create statement fetched.")

        # 修改 replication_num
        updated_statement = update_replication_num(schema, create_statement)
        print(f"Create statement updated with replication_num={REPLICATION_NUM_AFTER}.")
        time.sleep(0.5)

        # 删除原视图
        drop_view(schema, table)
        print(f"Original view dropped: {schema}.{table}")
        time.sleep(0.5)

        # 重新创建视图
        create_view(updated_statement)
        print(f"View recreated with updated replication_num={REPLICATION_NUM_AFTER}.----------")


if __name__ == "__main__":
    main()