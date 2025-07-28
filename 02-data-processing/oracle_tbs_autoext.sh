#!/bin/bash
# Oracle Tablespace Auto-Extension Script (Enhanced)
# Author: LuciferLiu
# Description: Monitors tablespace usage and adds datafiles when usage exceeds threshold
# 监控Oracle表空间使用率，当使用率超过指定阈值时自动添加数据文件，Oracle 表空间不足？用 Shell 脚本实现自动扩容！
# https://www.modb.pro/db/1940799093543022592

# 参数默认值
THRESHOLD=90
VERBOSE=false
MAIL_TO=""
LOG_DIR="$(pwd)/logs"
LOG_FILE=""

# 显示帮助信息
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t, --threshold <value>  Set usage threshold percentage (default: 90)"
    echo "  -m, --mail <email>       Send report to specified email address"
    echo "  -v, --verbose            Display execution progress on console"
    echo "  -l, --logdir <dir>       Set log directory (default: ./logs)"
    echo "  -h, --help               Show this help message"
    echo
    echo "Example:"
    echo "  $0 -t 85 -m admin@example.com -v"
    exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -m|--mail)
            MAIL_TO="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--logdir)
            LOG_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Invalid option: $1"
            show_help
            ;;
    esac
done

# 创建日志目录
mkdir -p "$LOG_DIR"

# 设置日志文件名（包含时间戳）
LOG_FILE="${LOG_DIR}/tablespace_monitor_$(date +%Y%m%d_%H%M%S).log"

# 日志记录函数
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    
    if [ "$VERBOSE" = true ]; then
        echo "$msg"
    fi
}

# 错误处理函数
error_exit() {
    log "ERROR: $1"
    log "===== 脚本执行失败 ====="
    exit 1
}

# 检查邮件发送依赖
check_mail_dependency() {
    if ! command -v mailx &> /dev/null; then
        log "警告：未找到 mailx 命令，邮件功能将不可用"
        return 1
    fi
    return 0
}

# 发送邮件
send_email() {
    if [ -z "$MAIL_TO" ]; then
        return
    fi
    
    if ! check_mail_dependency; then
        log "无法发送邮件：缺少 mailx 命令"
        return
    fi
    
    local subject="Oracle Tablespace Monitor Report - ${ORACLE_SID} - $(date +%Y-%m-%d)"
    
    {
        echo "Subject: $subject"
        echo "To: $MAIL_TO"
        echo "Content-Type: text/plain; charset=UTF-8"
        echo
        cat "$LOG_FILE"
    } | mailx -s "$subject" "$MAIL_TO" 2>> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log "报告已发送至: $MAIL_TO"
    else
        log "邮件发送失败"
    fi
}

# 检查Oracle环境变量
check_oracle_env() {
    if [ -z "$ORACLE_SID" ]; then
        error_exit "ORACLE_SID 环境变量未设置!"
    fi

    if [ -z "$ORACLE_HOME" ]; then
        ORACLE_HOME=$(grep "^${ORACLE_SID}:" /etc/oratab | cut -d: -f2)
        if [ -z "$ORACLE_HOME" ]; then
            error_exit "无法从 /etc/oratab 获取 ORACLE_HOME"
        fi
        export ORACLE_HOME
    fi
    export PATH=$ORACLE_HOME/bin:$PATH
}

# 获取表空间使用率函数
get_ts_usage() {
    local ts_name=$1
    local usage_result
    
    if [[ "$DB_VERSION" == 11* ]]; then
        usage_result=$(sqlplus -S /nolog <<EOF
conn / as sysdba
set pagesize 0 feedback off verify off heading off echo off
SELECT ROUND(used_percent, 2) 
FROM dba_tablespace_usage_metrics 
WHERE tablespace_name = '$ts_name';
EOF
        )
    else
        usage_result=$(sqlplus -S /nolog <<EOF
conn / as sysdba
set pagesize 0 feedback off verify off heading off echo off
SELECT ROUND(used_percent, 2) 
FROM cdb_tablespace_usage_metrics 
WHERE tablespace_name = '$ts_name' AND con_id NOT IN (1,2);
EOF
        )
    fi
    
    # 清理结果并返回
    echo "$usage_result" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# 获取表空间列表
get_tablespace_list() {
    local threshold=$1
    
    if [[ "$DB_VERSION" == 11* ]]; then
        sqlplus -S /nolog <<EOF
conn / as sysdba
set pagesize 0 feedback off verify off heading off echo off
SELECT d.tablespace_name
FROM dba_tablespace_usage_metrics d
WHERE round(d.used_percent,2) > $threshold;
EOF
    else
        sqlplus -S /nolog <<EOF
conn / as sysdba
set pagesize 0 feedback off verify off heading off echo off
SELECT d.tablespace_name
FROM cdb_tablespace_usage_metrics d
WHERE d.con_id not in (1,2) 
AND round(d.used_percent,2) > $threshold;
EOF
    fi
}

# 获取数据文件目录
get_datafile_directory() {
    local ts_name=$1
    sqlplus -S /nolog <<EOF
conn / as sysdba
set pagesize 0 feedback off verify off heading off echo off
SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1)) 
FROM dba_data_files 
WHERE tablespace_name = '$ts_name' AND ROWNUM = 1;
EOF
}

# 添加数据文件
add_datafile() {
    local ts_name=$1
    local file_path=$2
    
    sqlplus -S /nolog <<EOF
conn / as sysdba
ALTER TABLESPACE $ts_name ADD DATAFILE '$file_path' 
    SIZE 100M 
    AUTOEXTEND ON 
    NEXT 50M 
    MAXSIZE UNLIMITED;
EOF
    return $?
}

# 主函数
main() {
    log "===== 开始表空间检查 ====="
    log "数据库实例: $ORACLE_SID"
    log "Oracle Home: $ORACLE_HOME"
    log "使用阈值: ${THRESHOLD}%"
    log "日志文件: $LOG_FILE"
    
    # 获取数据库版本
    DB_VERSION=$(sqlplus -S /nolog <<EOF
conn / as sysdba
set pagesize 0 feedback off verify off heading off echo off
SELECT version FROM v\$instance;
EOF
    )
    
    log "数据库版本: $DB_VERSION"
    
    # 获取需要处理的表空间
    log "查询使用率超过 ${THRESHOLD}% 的表空间..."
    TS_LIST=$(get_tablespace_list $THRESHOLD)
    
    # 检查是否获取到表空间
    if [ -z "$TS_LIST" ]; then
        log "所有表空间使用率均低于 ${THRESHOLD}%，无需操作"
        log "===== 检查结束 ====="
        send_email
        exit 0
    fi
    
    log "需要处理的表空间:"
    log "$(echo "$TS_LIST" | tr '\n' ' ')"
    
    # 处理每个需要扩展的表空间
    for TS in $TS_LIST; do
        # 清理表空间名称
        CLEAN_TS=$(echo "$TS" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # 获取处理前的使用率
        PRE_USAGE=$(get_ts_usage "$CLEAN_TS")
        log "处理前: 表空间 $CLEAN_TS 使用率 = ${PRE_USAGE}%"
        
        # 生成唯一的数据文件名
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        NEW_FILE="${CLEAN_TS}_autoext_${TIMESTAMP}.dbf"
        
        # 获取数据文件存储路径
        DATA_DIR=$(get_datafile_directory "$CLEAN_TS")
        CLEAN_DIR=$(echo "$DATA_DIR" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ -z "$CLEAN_DIR" ]; then
            log "错误！无法获取表空间 $CLEAN_TS 的数据文件路径"
            continue
        fi
        
        FULL_PATH="${CLEAN_DIR}${NEW_FILE}"
        log "将添加数据文件: $FULL_PATH"
        
        # 添加数据文件
        add_datafile "$CLEAN_TS" "$FULL_PATH" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log "成功添加数据文件"
            
            # 等待1秒让统计信息更新
            sleep 1
            
            # 获取处理后的使用率
            POST_USAGE=$(get_ts_usage "$CLEAN_TS")
            log "处理后: 表空间 $CLEAN_TS 使用率 = ${POST_USAGE}%"
            
            # 计算变化量
            USAGE_DIFF=$(awk -v pre="$PRE_USAGE" -v post="$POST_USAGE" 'BEGIN {printf "%.2f", pre - post}')
            log "使用率变化: ${PRE_USAGE}% -> ${POST_USAGE}% (差值: ${USAGE_DIFF}%)"
        else
            log "错误！添加数据文件失败"
            log "表空间 $CLEAN_TS 处理失败，使用率仍为 ${PRE_USAGE}%"
        fi
    done
    
    log "===== 操作完成 ====="
    send_email
}

# 初始化检查
check_oracle_env

# 执行主程序
main