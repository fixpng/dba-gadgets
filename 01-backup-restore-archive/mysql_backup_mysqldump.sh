#!/bin/bash
# mysqldump多实例批量备份脚本

# 定义基本目录和日期变量
BASEDIR="/datacfs/mysqlbak"
BKDATE=$(date "+%Y%m%d")
LOGFILE="${BASEDIR}/backup_mysql.log"
# mysqldump 和 mysql 命令路径
MYSQLDUMP="mysqldump"
MYSQL="mysql"
PT_SHOW_GRANTS="pt-show-grants"
# 保留备份的天数
RETENTION_DAYS=6

# 主机和备份配置信息（IP:端口, 用户名, 密码）
declare -A MYSQL_CONFIGS=(
    ["127.0.0.1:3306"]="backup_user aaa123456"
    ["devmysql.fixpng.top:3306"]="backup aaa123456b"
)

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# 创建备份目录并执行备份
for HOST_PORT in "${!MYSQL_CONFIGS[@]}"; do
    IFS=':' read -r HOST PORT <<< "$HOST_PORT"
    CREDENTIAL="${MYSQL_CONFIGS[$HOST_PORT]}"
    USERPASS=(${CREDENTIAL})
    USER=${USERPASS[0]}
    PASS=${USERPASS[1]}

    BACKUP_DIR="${BASEDIR}/${HOST_PORT}/${BKDATE}"
    mkdir -pv "$BACKUP_DIR"

    # 获取数据库列表
    DBS=$($MYSQL --host="$HOST" --port="$PORT" -u"$USER" -p"$PASS" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|sys)")

    # 备份用户权限
    GRANTS_FILE="${BACKUP_DIR}/grants.sql"
    log "Backing up grants for ${HOST}:${PORT} to ${GRANTS_FILE}"
    $PT_SHOW_GRANTS --host="$HOST" --port="$PORT" --user="$USER" --password="$PASS" > "${GRANTS_FILE}"

    for DB in $DBS; do
        BACKUP_FILE="${BACKUP_DIR}/${DB}.sql.gz"
        log "Backing up ${HOST}:${PORT} database ${DB} to ${BACKUP_FILE}"
        $MYSQLDUMP --host="$HOST" --port="$PORT" -u"$USER" -p"$PASS" --single-transaction --set-gtid-purged=OFF "$DB" | gzip > "${BACKUP_FILE}"
    done
done

# 删除超过指定天数的备份
log "Removing backups older than ${RETENTION_DAYS} days"
find "$BASEDIR"/* -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;