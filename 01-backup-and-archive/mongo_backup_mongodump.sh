#!/bin/bash
# 最简单的mongodump批量备份脚本

# 定义基本目录和日期变量
BASEDIR="/datacfs/mongobak"
BKDATE=$(date "+%Y%m%d")
LOGFILE="${BASEDIR}/backup_mongo.log"
# MongoDB 命令路径
MONGODUMP="/usr/local/mongodb/bin/mongodump"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}


# 主机和备份配置信息（IP, 端口, 用户名, 密码, 数据库）
declare -A MONGO_CONFIGS=(
    ["fatmongo.fixpng.top"]="27017 backup_user:aaa123456 admin"
    ["devmongo.fixpng.top"]="27017 backup_user:aaa123456 admin"
    ["10.9.120.11"]="27017 backup:aaa123456b admin"
    ["10.9.120.12"]="27017 backup:aaa123456b admin"
)

# 创建备份目录并执行备份
for HOST in "${!MONGO_CONFIGS[@]}"; do
    IFS=' ' read -r PORT CREDENTIAL AUTH_DB DB <<< "${MONGO_CONFIGS[$HOST]}"
    USERPASS=(${CREDENTIAL//:/ })
    USER=${USERPASS[0]}
    PASS=${USERPASS[1]}

    BACKUP_DIR="${BASEDIR}/${HOST}/${BKDATE}"
    mkdir -pv "$BACKUP_DIR"

    DATABASE_FLAG=""
    if [ -n "$DB" ]; then
        DATABASE_FLAG="-d $DB"
    fi

    log "Backing up ${HOST}:${PORT} to ${BACKUP_DIR}"
    $MONGODUMP --host "$HOST" --port "$PORT" -u"$USER" -p"$PASS" --authenticationDatabase="$AUTH_DB" $DATABASE_FLAG -o "$BACKUP_DIR"
done

# 删除超过6天的备份
log "Removing backups older than 6 days"
find "$BASEDIR"/* -type d -mtime +6 -exec rm -rf {} \;