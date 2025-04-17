#!/bin/bash
# mysqldump恢复脚本，包含 pt-show-grants 的权限

# 定义基本目录和日期变量
# mysql 命令路径
MYSQL="mysql"
LOGFILE="./restore_mysql.log"
RESTORE_DIR="/datacfs/mysqlbak/127.0.0.1/20250101"

# 主机和恢复配置信息（IP, 端口, 用户名, 密码）
HOST="127.0.0.1"
PORT="6033"
USER="root"
PASS="aaa123456"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# 检查恢复目录是否存在
if [ ! -d "$RESTORE_DIR" ]; then
    log "Restore directory ${RESTORE_DIR} does not exist"
    exit 1
fi

# 获取备份文件列表
BACKUP_FILES=$(find "$RESTORE_DIR" -name "*.sql.gz")

# 恢复数据库
for BACKUP_FILE in $BACKUP_FILES; do
    DB=$(basename "$BACKUP_FILE" .sql.gz)
    log "Creating database ${DB} if not exists"
    $MYSQL --host="$HOST" --port="$PORT" -u"$USER" -p"$PASS" -e "CREATE DATABASE IF NOT EXISTS \`$DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    log "Restoring database ${DB} from ${BACKUP_FILE}"
    gunzip < "$BACKUP_FILE" | $MYSQL --host="$HOST" --port="$PORT" -u"$USER" -p"$PASS" "$DB"
done

log "Restore completed"

# 恢复用户权限
$MYSQL --host="$HOST" --port="$PORT" -u"$USER" -p"$PASS" < "${RESTORE_DIR}/grants.sql"

log "Grants completed"