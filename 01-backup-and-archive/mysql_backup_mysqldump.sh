#!/bin/bash
# mysqldump多实例批量备份脚本

# 定义基本目录和日期变量
BASEDIR="/datacfs/mysqlbak"
BKDATE=$(date "+%Y%m%d")
LOGFILE="${BASEDIR}/backup_mysql.log"
# mysqldump 和 mysql 命令路径
MYSQLDUMP="/usr/bin/mysqldump"
MYSQL="/usr/bin/mysql"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# 主机和备份配置信息（IP, 端口, 用户名, 密码）
declare -A MYSQL_CONFIGS=(
    ["127.0.0.1"]="3306 backup_user:aaa123456"
    ["devmysql.fixpng.top"]="3306 backup:aaa123456b"
)

# 创建备份目录并执行备份
for HOST in "${!MYSQL_CONFIGS[@]}"; do
    IFS=' ' read -r PORT CREDENTIAL <<< "${MYSQL_CONFIGS[$HOST]}"
    USERPASS=(${CREDENTIAL//:/ })
    USER=${USERPASS[0]}
    PASS=${USERPASS[1]}

    BACKUP_DIR="${BASEDIR}/${HOST}/${BKDATE}"
    mkdir -pv "$BACKUP_DIR"

    # 获取数据库列表
    DBS=$($MYSQL --host="$HOST" --port="$PORT" -u"$USER" -p"$PASS" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|sys)")

    for DB in $DBS; do
        BACKUP_FILE="${BACKUP_DIR}/${DB}.sql.gz"
        log "Backing up ${HOST}:${PORT} database ${DB} to ${BACKUP_FILE}"
        $MYSQLDUMP --host="$HOST" --port="$PORT" -u"$USER" -p"$PASS" --single-transaction --set-gtid-purged=OFF "$DB" | gzip > "${BACKUP_FILE}"
    done
done

# 删除超过6天的备份
log "Removing backups older than 6 days"
find "$BASEDIR"/* -type d -mtime +6 -exec rm -rf {} \;