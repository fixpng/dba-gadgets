#!/bin/bash
# mongorestore恢复脚本，包含用户和权限的恢复

# 定义基本目录和日期变量
MONGORESTORE="mongorestore"
LOGFILE="./restore_mongo.log"
RESTORE_DIR="/datacfs/mongobak/127.0.0.1:27017/20250101"

# 主机和恢复配置信息（IP, 端口, 用户名, 密码, 认证数据库）
HOST="127.0.0.1"
PORT="27017"
USER="backup_user"
PASS="aaa123456"
AUTH_DB="admin"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# 检查恢复目录是否存在
if [ ! -d "$RESTORE_DIR" ]; then
    log "Restore directory ${RESTORE_DIR} does not exist"
    exit 1
fi

# 恢复用户和权限
USERS_FILE="${RESTORE_DIR}/users.json"
if [ -f "$USERS_FILE" ]; then
    log "Restoring users and roles from ${USERS_FILE}"
    $MONGORESTORE --host "$HOST" --port "$PORT" --username "$USER" --password "$PASS" --authenticationDatabase "$AUTH_DB" --nsInclude "admin.system.users" --drop --dir "${RESTORE_DIR}"
else
    log "Users file ${USERS_FILE} does not exist, skipping user restoration"
fi

# 恢复数据库
BACKUP_FILES=$(find "$RESTORE_DIR" -name "*.gz")

for BACKUP_FILE in $BACKUP_FILES; do
    DB=$(basename "$BACKUP_FILE" .gz)
    log "Restoring database ${DB} from ${BACKUP_FILE}"
    $MONGORESTORE --host "$HOST" --port "$PORT" --username "$USER" --password "$PASS" --authenticationDatabase "$AUTH_DB" \
        --gzip --nsInclude="*" --nsFrom="${DB}.*" --nsTo="${DB}.*" --archive="$BACKUP_FILE"
done

log "Restore completed"