import csv
import os
import pymysql
from datetime import datetime

"""
读取 CSV 文件内容，创建数据库表（文件名为表名，表第一行为字段名，根据数据类型创建对应字段），并插入数据到 MySQL
脚本简陋，仅在不能使用其他工具情况下使用
配置在最底下
"""

def mysql_csv_to_table(file_path, db_config):
    # 从文件名中提取表名
    table_name = os.path.splitext(os.path.basename(file_path))[0]

    # 连接到 MySQL 数据库
    connection = pymysql.connect(
        host=db_config["host"],
        user=db_config["user"],
        password=db_config["password"],
        database=db_config["database"],
        port=db_config.get("port", 3306)  # 默认端口为 3306
    )
    cursor = connection.cursor()

    try:
        # 读取 CSV 文件
        with open(file_path, mode='r', encoding='utf-8') as file:
            reader = csv.reader(file)
            headers = next(reader)  # 第一行为列名

            # 扫描前 100 行以推断列的数据类型
            sample_rows = [row for _, row in zip(range(100), reader)]
            column_types = []
            for i, header in enumerate(headers):
                column_values = [row[i] for row in sample_rows if len(row) > i]
                if all(value.strip().isdigit() for value in column_values if value.strip()):
                    column_types.append("BIGINT")
                elif all(is_valid_decimal(value.strip()) for value in column_values if value.strip()):
                    column_types.append("DECIMAL(36,6)")
                elif all(is_valid_date(value.strip(), "%Y-%m-%d") for value in column_values if value.strip()):
                    column_types.append("DATE")
                else:
                    # 如果值混合、为空或非数字，则默认为 TEXT 或 VARCHAR
                    max_length = max((len(value) for value in column_values if value.strip()), default=0)
                    if max_length <= 255:
                        column_types.append("VARCHAR(255)")
                    else:
                        column_types.append("TEXT")

            # 重置读取器以在推断类型后重新读取所有数据
            file.seek(0)
            next(reader)  # 跳过列名
            all_rows = []
            for row in reader:
                processed_row = [
                    None if (col_type in ["BIGINT", "DECIMAL(36,6)", "DATE"] and not value.strip()) else value
                    for value, col_type in zip(row, column_types)
                ]
                all_rows.append(processed_row)

            # 创建表
            columns = ", ".join(f"`{name}` {col_type}" for name, col_type in zip(headers, column_types))
            create_table_query = f"CREATE TABLE IF NOT EXISTS `{table_name}` ({columns});"
            cursor.execute(create_table_query)

            # 插入数据
            insert_query = f"INSERT INTO `{table_name}` ({', '.join(f'`{col}`' for col in headers)}) VALUES ({', '.join(['%s'] * len(headers))})"
            # cursor.execute(f"TRUNCATE TABLE `{table_name}`")  # 插入前清空表
            cursor.executemany(insert_query, all_rows)

        # 提交更改
        connection.commit()
    except Exception as e:
        connection.rollback()
        print(f"错误: {e}")
    finally:
        cursor.close()
        connection.close()

# 检查值是否为有效日期
def is_valid_date(value, date_format):
    try:
        datetime.strptime(value, date_format)
        return True
    except ValueError:
        return False

# 检查值是否为有效小数
def is_valid_decimal(value):
    try:
        float(value)
        return True
    except ValueError:
        return False


mysql_csv_to_table("/tmp/tmp_20250417_test.csv", {
    "host": "127.0.0.1",
    "user": "test",
    "password": "aaa123",
    "database": "testdb",
    "port": 3306  
})