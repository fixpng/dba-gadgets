#!/bin/bash
# mongodump多实例批量备份脚本（包含用户和权限）
# 下载对应版本工具
# https://www.mongodb.com/try/download/database-tools

# 定义基本目录和日期变量
BASEDIR="/datacfs/mongobak"
BKDATE=$(date "+%Y%m%d")
LOGFILE="${BASEDIR}/backup_mongo.log"
MONGODUMP="mongodump"
MONGOEXPORT="mongoexport"
MONGOSH="mongosh"
RETENTION_DAYS=6

# 主机和备份配置信息（IP:端口, 用户名, 密码, 认证数据库）
declare -A MONGO_CONFIGS=(
    ["127.0.0.1:27017"]="backup_user aaa123456 admin"
    ["devmongo.fixpng.top:27017"]="backup_user aaa123456b admin"
)

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# 创建备份目录并执行备份
for HOST_PORT in "${!MONGO_CONFIGS[@]}"; do
    IFS=':' read -r HOST PORT <<< "$HOST_PORT"
    CREDENTIAL="${MONGO_CONFIGS[$HOST_PORT]}"
    USERPASS=(${CREDENTIAL})
    USER=${USERPASS[0]}
    PASS=${USERPASS[1]}
    AUTH_DB=${USERPASS[2]}

    BACKUP_DIR="${BASEDIR}/${HOST_PORT}/${BKDATE}"
    mkdir -pv "$BACKUP_DIR"

    # 获取数据库列表
    DBS=$($MONGOSH --host "$HOST" --port "$PORT" --username "$USER" --password "$PASS" --authenticationDatabase "$AUTH_DB" --quiet --eval "db.adminCommand('listDatabases').databases.map(db => db.name).join('\n')" | grep -Ev "(admin|local|config)")

    # 备份用户和权限
    log "Backing up users and roles for ${HOST}:${PORT} to ${BACKUP_DIR}/users.json"
    $MONGOEXPORT --host "$HOST" --port "$PORT" --username "$USER" --password "$PASS" --authenticationDatabase "$AUTH_DB" --db admin --collection system.users --out "${BACKUP_DIR}/users.json"

    for DB in $DBS; do
        BACKUP_FILE="${BACKUP_DIR}/${DB}.gz"
        log "Backing up ${HOST}:${PORT} database ${DB} to ${BACKUP_FILE}"
        $MONGODUMP --host "$HOST" --port "$PORT" --username "$USER" --password "$PASS" --authenticationDatabase "$AUTH_DB" --db "$DB" --archive="$BACKUP_FILE" --gzip
    done
done

# 删除超过指定天数的备份
log "Removing backups older than ${RETENTION_DAYS} days"
find "$BASEDIR"/* -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;