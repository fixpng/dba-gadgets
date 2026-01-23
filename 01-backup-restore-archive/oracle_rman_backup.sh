#!/bin/bash
#===============================================================================
# Oracle RMAN 备份脚本
#
# 目的:
#   - 对 Oracle 数据库执行全量/增量备份（示例为 LEVEL 0 全备），备份归档日志，
#     备份控制文件，并将生成的备份文件传输到备用主机（备库）。
#
# 前提依赖:
#   - 在主/备服务器上已配置好 SSH 公钥认证（无密码 scp），并能相互访问。
#   - ORACLE_HOME/ORACLE_SID 环境变量按实际环境设置，且有 rman 可用。
#   - 备份目录有足够磁盘空间，且脚本运行用户有读写权限。
#   - rman 在 PATH 中可执行，scp 可用。
#
# 主要功能:
#   - 配置并执行 RMAN 备份（控制文件自动备份、数据库备份、归档日志备份）。
#   - 清理过期备份与日志（使用 RMAN 的 CROSSCHECK/DELETE 命令）。
#   - 将当日生成的备份文件通过 scp 传输到配置的备用主机（带重试机制）。
#   - 记录详细日志并返回合适的退出码（0 成功，1 失败）。
#
# 重要变量说明（脚本内可修改）:
#   - ORACLE_HOME, ORACLE_SID, PATH: Oracle 环境
#   - BACKUP_DIR: 本地备份存放路径
#   - STANDBY_HOST/STANDBY_USER/STANDBY_DIR: 备库主机与目标路径
#   - RETENTION_DAYS: RMAN 恢复窗口保留天数
#   - LOG_RETENTION_DAYS: 本地 rman_backup_*.log 的保留天数
#
# 使用方法:
#   - 本脚本可直接由 oracle 用户手动运行：
#       ./oracle_rman_backup.sh
#   - 或加入 cron 定期执行（示例：每天 2:30 执行）:
#       30 2 * * * /bin/bash /home/oracle/scripts/oracle_rman_backup.sh >> /home/backup/rman_cron.log 2>&1
#
# 退出码:
#   - 0: RMAN 备份及关键文件传输成功
#   - 1: 备份或传输失败（请查看日志）
#
# 日志与故障处理:
#   - 脚本在运行时会把 stdout/stderr 重定向到本日日志文件（BACKUP_DIR/rman_backup_YYYY-MM-DD.log）。
#   - scp 传输有重试（默认 3 次），失败后记录并终止该文件的传输，但继续汇总其它任务结果。
#
# 安全与注意事项:
#   - 请勿以 root 用户运行（除非故意），建议以 oracle 用户运行。
#   - 确保备份目录权限仅授予可信用户，备份文件可能包含敏感数据。
#   - 在生产环境变更 RETENTION/DELETE 命令前请确认恢复策略。
#
# 变更记录:
#   - 2026-01-23: 完善脚本头部说明（用途、依赖、变量说明、cron 示例、日志/错误策略）。
#
#===============================================================================

# 遇到错误不立即退出，由脚本自行处理错误
set +e

#-------------------------------------------------------------------------------
# 配置变量（根据实际环境修改）
#-------------------------------------------------------------------------------
export ORACLE_HOME=/home/oracle/u01/app/oracle/product/19.3.0/db
export ORACLE_SID=interlib
export PATH=$ORACLE_HOME/bin:$PATH

# 备份目录（统一路径）
BACKUP_DIR="/home/backup"
# 备库信息
STANDBY_HOST="172.10.1.9"
STANDBY_USER="oracle"
STANDBY_DIR="/home/backup"
# 保留策略（天）
RETENTION_DAYS=7
# 日志保留天数
LOG_RETENTION_DAYS=30
# 备份日期
BKDATE=$(date +%F)
# 日志文件
LOGFILE="${BACKUP_DIR}/rman_backup_${BKDATE}.log"

#-------------------------------------------------------------------------------
# 函数定义
#-------------------------------------------------------------------------------

# 日志输出函数
log_msg() {
    echo "[$(date '+%F %T')] $1"
}

# 错误退出函数
error_exit() {
    log_msg "错误: $1"
    exit 1
}

# SCP 传输函数（带重试机制）
scp_transfer() {
    local file_type="$1"
    local file_pattern="$2"
    local max_retry=3
    local retry_count=0

    local files=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "${file_pattern}" -mtime 0 2>/dev/null)

    if [ -z "$files" ]; then
        log_msg "没有当天${file_type}需要传输。"
        return 0
    fi

    log_msg "正在传输${file_type}到备库..."

    for file in $files; do
        retry_count=0
        while [ $retry_count -lt $max_retry ]; do
            if scp -o ConnectTimeout=30 -o BatchMode=yes "$file" "${STANDBY_USER}@${STANDBY_HOST}:${STANDBY_DIR}/" 2>/dev/null; then
                log_msg "传输成功: $(basename $file)"
                break
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $max_retry ]; then
                    log_msg "传输失败，第 ${retry_count} 次重试: $(basename $file)"
                    sleep 5
                else
                    log_msg "传输失败（已重试${max_retry}次）: $(basename $file)"
                    return 1
                fi
            fi
        done
    done

    log_msg "${file_type}传输完成。"
    return 0
}

#-------------------------------------------------------------------------------
# 主程序开始
#-------------------------------------------------------------------------------

# 确保备份目录存在
mkdir -p "${BACKUP_DIR}" || error_exit "无法创建备份目录: ${BACKUP_DIR}"

# 重定向输出到日志
exec >> "${LOGFILE}" 2>&1

log_msg "========== RMAN 备份开始 =========="
log_msg "ORACLE_SID: ${ORACLE_SID}"
log_msg "备份目录: ${BACKUP_DIR}"

# 清理过期日志文件
log_msg "清理 ${LOG_RETENTION_DAYS} 天前的日志文件..."
find "${BACKUP_DIR}" -type f -name "rman_backup_*.log" -mtime +${LOG_RETENTION_DAYS} -exec rm -f {} \; 2>/dev/null
log_msg "日志清理完成。"

# 执行 RMAN 备份
log_msg "开始执行 RMAN 备份..."

rman target / <<EOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF ${RETENTION_DAYS} DAYS;
CONFIGURE RETENTION POLICY TO REDUNDANCY ${RETENTION_DAYS};
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUP_DIR}/autoctl_%F.bak';

CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

BACKUP INCREMENTAL LEVEL 0 DATABASE
  FORMAT '${BACKUP_DIR}/db_level0_${BKDATE}_%U.bak'
  TAG 'DB_LEVEL0_${BKDATE}';

BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL
  FORMAT '${BACKUP_DIR}/arch_${BKDATE}_%U.bak'
  TAG 'ARCH_${BKDATE}'
  DELETE INPUT;

BACKUP AS COMPRESSED BACKUPSET CURRENT CONTROLFILE
  FORMAT '${BACKUP_DIR}/ctl_${BKDATE}_%U.bak'
  TAG 'CTL_${BKDATE}';

EXIT
EOF

RMAN_STATUS=$?

if [ $RMAN_STATUS -eq 0 ]; then
    log_msg "RMAN 备份成功完成。"
else
    log_msg "警告: RMAN 备份返回非零状态码: ${RMAN_STATUS}"
fi

# 验证备份文件是否生成
db_backup_count=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name "db_level0_${BKDATE}_*.bak" -mtime 0 2>/dev/null | wc -l)
if [ "$db_backup_count" -eq 0 ]; then
    error_exit "未找到当天的数据库备份文件，备份可能失败！"
fi
log_msg "验证通过: 找到 ${db_backup_count} 个数据库备份文件。"

# 传输备份文件到备库
log_msg "---------- 开始传输文件到备库 ----------"

scp_transfer "数据库备份文件" "db_level0_${BKDATE}_*.bak"
DB_SCP_STATUS=$?

scp_transfer "归档日志文件" "arch_${BKDATE}_*.bak"
ARCH_SCP_STATUS=$?

scp_transfer "控制文件备份" "ctl_${BKDATE}_*.bak"
CTL_SCP_STATUS=$?

# 汇总结果
log_msg "========== RMAN 备份结束 =========="
log_msg "备份状态: $([ $RMAN_STATUS -eq 0 ] && echo '成功' || echo '失败')"
log_msg "数据库文件传输: $([ $DB_SCP_STATUS -eq 0 ] && echo '成功' || echo '失败')"
log_msg "归档日志传输: $([ $ARCH_SCP_STATUS -eq 0 ] && echo '成功' || echo '失败')"
log_msg "控制文件传输: $([ $CTL_SCP_STATUS -eq 0 ] && echo '成功' || echo '失败')"

# 返回整体状态
if [ $RMAN_STATUS -eq 0 ] && [ $DB_SCP_STATUS -eq 0 ]; then
    log_msg "所有任务执行成功。"
    exit 0
else
    log_msg "部分任务执行失败，请检查日志。"
    exit 1
fi