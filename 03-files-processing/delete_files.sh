#!/bin/bash

# 删除指定条件的文件的方法
delete_files() {
    local DIRECTORY="$1"       # 要操作的目录
    local PREFIX="$2"          # 文件前缀
    local RETENTION_DAYS="$3"  # 保留周期（天）

    # 查找符合条件的文件，但跳过每月1号的文件
    find "$DIRECTORY" -type f -name "${PREFIX}*" -mtime +$RETENTION_DAYS | while read -r FILE; do
        # 获取文件的修改日期（只取日）
        FILE_DATE=$(date -r "$FILE" '+%d')

        if [ "$FILE_DATE" != "01" ]; then
            # 如果不是1号，删除文件（保留每月1号的数据库备份）
            rm -f "$FILE"

            # 记录删除操作
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Deleted $FILE"
        else
            # 如果是1号，记录跳过操作
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Skipped $FILE (1st of the month)"
        fi
    done
}

# 删除空文件夹的方法
delete_empty_dirs() {
    local DIRECTORY="$1"

    # 查找并删除空文件夹
    find "$DIRECTORY" -type d -empty -delete
}

# 调用方法
# delete_files "/data/scripts/test1" "test_file_" 7
# delete_files "/data/scripts/test2" "test_file_" 15

# mysql
delete_files "/dbbackup/mysql/" "mysql-rds-" 180
delete_files "/dbbackup/mysql/" "mysql-rds-uat" 30

# mongodb
delete_files "/dbbackup/mongodb/" "DDS-mdb-" 180
delete_files "/dbbackup/mongodb/" "DDS-mdb-uat" 30

# nebula
delete_files "/dbbackup/nebula/" "BACKUP_" 180
delete_empty_dirs "/dbbackup/nebula/"