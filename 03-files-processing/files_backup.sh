#!/bin/bash

# 描述：此脚本将当前目录中的文件备份到备份目录。
# 作者：krielwus
# 日期：2024-04-10
# 版本：1.0.0
# 许可证：MIT
# 用法：./autoBackupFiles.sh
# 示例：./autoBackupFiles.sh
# 输出：备份目录：/path/to/backup/directory

# 此脚本将当前目录中的文件备份到备份目录。
# 如果备份目录不存在，则会创建备份目录。

# 定义颜色变量
RED='\033[0;31m'
BRIGHT_RED='\033[38;5;196m'  # 新增亮红色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
PINK='\033[38;5;213m'  # 新增粉红色颜色
CYAN='\033[0;36m'
NC='\033[0m'

# 获取当前时间
CURRENT_TIME=$(date +"%Y%m%d%H%M%S")
CURRENT_DATE=$(date +"%Y%m%d")

# 定义日志文件路径
LOG_DIR="/mnt/scriptlog/log"
LOG_FILE="$LOG_DIR/script_log_$CURRENT_TIME.log"

# 定义本地备份目录
LOCAL_BACKUP_DIR="/home/backup/$CURRENT_DATE"

# 定义要备份和传输的文件，替换为实际的本地服务器信息
FILES_TO_BACKUP=("/mnt/jboss/jboss5.1.0/server/default2/deploy/Micro_XN.war" "/mnt/jboss/jboss5.1.0/server/default2/deploy/MicroStationService.war" "/mnt/jboss/jboss5.1.0/server/default2/deploy/ImageProcess.war")

# 检查日志目录和文件
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# 日志记录函数
# 参数：日志消息
log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local colored_message="${CYAN}[$timestamp]${NC} $message"
    echo -e "$colored_message" | tee -a "$LOG_FILE"
}

# 错误处理函数
# 参数：错误消息
handle_error() {
    local error_message="$1"
    log "${RED}$error_message，查看日志: $LOG_FILE${NC}"
    exit 1
}

# 实现本地文件备份函数
local_backup() {
    log "开始本地文件备份..."
    if [ ! -d "$LOCAL_BACKUP_DIR" ]; then
        log "${YELLOW}本地备份目录不存在，创建目录: $LOCAL_BACKUP_DIR${NC}"
        mkdir -p "$LOCAL_BACKUP_DIR"
        if [ $? -ne 0 ]; then
            handle_error "创建本地备份目录失败，请检查权限。"
        fi
    fi
    # 查找当前日期备份目录下已有的数字序号子目录
    backup_numbers=($(find "$LOCAL_BACKUP_DIR" -maxdepth 1 -type d -regex "$LOCAL_BACKUP_DIR/[0-9]+" | sort -n | sed "s|$LOCAL_BACKUP_DIR/||"))
    if [ ${#backup_numbers[@]} -eq 0 ]; then
        next_backup_number=1
    else
        last_number=${backup_numbers[-1]}
        next_backup_number=$((last_number + 1))
    fi
    # 创建新的备份子目录
    current_backup_dir="$LOCAL_BACKUP_DIR/$next_backup_number"
    mkdir -p "$current_backup_dir"

    for file in "${FILES_TO_BACKUP[@]}"; do
        # 修改为判断文件或目录是否存在
        if [ -e "$file" ]; then
            base_name=$(basename "$file")
            backup_file="$current_backup_dir/${base_name%.*}_$CURRENT_TIME.tar.gz"
            log "开始备份文件: $backup_file"
            # 优化 tar 命令，避免输出压缩文件路径
            tar -C "$(dirname "$file")" -czf "$backup_file" --exclude-vcs "$(basename "$file")" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                log "${GREEN}本地 $file 备份成功，备份文件路径: $backup_file${NC}"
            else
                handle_error "本地 $file 备份失败"
            fi
        else
            log "${YELLOW}本地 $file 文件或目录不存在，跳过备份${NC}"
        fi
    done
    log "本地文件备份完成。"
}

# 调用本地文件备份函数
local_backup