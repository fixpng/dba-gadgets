#!/bin/bash
# =========================================================================
# Vastbase G100 自动化安装脚本 v17
# 作者: 青学会会长
# =========================================================================
# 用途: Vastbase G100 单机静默安装，支持主流 Linux 发行版 (RHEL/CentOS/Rocky/麒麟/欧拉/Ubuntu/Debian) 及 x86_64/ARM64
#
# 使用方法:
#   cd /soft/vb
#   chmod +x vastbase_g100_install_v17.sh
#   ./vastbase_g100_install_v17.sh \
#     --hostname vbtest --ip 10.10.205.112 \
#     --vbhome /home/vastbase/local/vastbase \
#     --vbdata /home/vastbase/data/vastbase \
#     --password 'Vbase@123' --encrypt-key 'Aa123456' \
#     --compatibility A --isinitdb true
#
# 必填参数:
#   --hostname       主机名
#   --ip             本机IP
#   --vbhome         软件安装目录
#   --vbdata         数据目录
#   --password       数据库密码
#   --encrypt-key    加密密钥
#   --compatibility  兼容模式 (A=Oracle, B=MySQL, C=Teradata, PG=PostgreSQL, MSSQL=SQLServer)
#   --isinitdb       是否初始化 (true|false)
#
# 可选参数:
#   --port (默认5432) --user (默认vastbase) --wal-dir --archive-dir --enable-systemd
#
# 前置要求:
#   1. 手动创建 /soft/vb 目录
#   2. 放入 Vastbase G100 安装包和 license 文件
#
# 运行后选择: 1=安装 2=卸载 3=退出
# =========================================================================

set -u
umask 022

# -------------------------------------------------------------------------
# 1. 默认配置与参数解析
# -------------------------------------------------------------------------
DEFAULT_SERVER="vb1"
DEFAULT_IP="192.168.133.98"
DEFAULT_VBUSER="vastbase"
DEFAULT_VBHOME="/home/vastbase/local/vastbase"
DEFAULT_VBDATA="/home/vastbase/data/vastbase"
DEFAULT_VBPORT="5432"
DEFAULT_VBPASSWORD="Vbase@123"
DEFAULT_ENCRYPTION_KEY="Aa123456"
DEFAULT_DB_COMPATIBILITY="A"
DEFAULT_MAX_CONNECTIONS="500"
DEFAULT_SHARED_BUFFERS="256"
DEFAULT_WAL_DIR=""
DEFAULT_ARCHIVE_DIR=""
DEFAULT_NTP=""
DEFAULT_SOFT_DIR="/soft/vb"
DEFAULT_LOGFILE="/soft/vastbase_install.log"
DEFAULT_ISINITDB="true"
DEFAULT_ENABLE_SYSTEMD="false"
DEFAULT_KEEP_MEDIA="true"
DEFAULT_KEEP_USER="true"
DEFAULT_KEEP_LOGS="true"

server=$DEFAULT_SERVER
server_ip=$DEFAULT_IP
vb_user=$DEFAULT_VBUSER
VBHOME=$DEFAULT_VBHOME
VBDATA=$DEFAULT_VBDATA
VBPORT=$DEFAULT_VBPORT
VBPASSWORD=$DEFAULT_VBPASSWORD
encryption_key=$DEFAULT_ENCRYPTION_KEY
db_compatibility=$DEFAULT_DB_COMPATIBILITY
max_connections=$DEFAULT_MAX_CONNECTIONS
shared_buffers=$DEFAULT_SHARED_BUFFERS
wal_dir=$DEFAULT_WAL_DIR
archive_dir=$DEFAULT_ARCHIVE_DIR
ntp_server=$DEFAULT_NTP
SOFT_DIR=$DEFAULT_SOFT_DIR
LOGFILE=$DEFAULT_LOGFILE
isinitdb=$DEFAULT_ISINITDB
enable_systemd=$DEFAULT_ENABLE_SYSTEMD
keep_media=$DEFAULT_KEEP_MEDIA
keep_user=$DEFAULT_KEEP_USER
keep_logs=$DEFAULT_KEEP_LOGS

OS_ID="unknown"
OS_VERSION="unknown"
OS_NAME="unknown"
OS_FAMILY="unknown"
ARCH_RAW="unknown"
ARCH_FAMILY="unknown"
PKG_MGR="unknown"

usage() {
    echo -e "\x1B[01;96m Usage: $0 [OPTIONS] \x1B[0m"
    echo ""
    echo "选项说明:"
    echo "  --ip <ip>              设置本机IP地址 (默认: $DEFAULT_IP)"
    echo "  --hostname <name>      设置主机名 (默认: $DEFAULT_SERVER)"
    echo "  --ntp <ip>             设置NTP时间服务器IP (可选)"
    echo "  --user <name>          设置安装用户 (默认: $DEFAULT_VBUSER)"
    echo "  --vbhome <path>        设置软件安装目录 (默认: $DEFAULT_VBHOME)"
    echo "  --vbdata <path>        设置数据目录 (默认: $DEFAULT_VBDATA)"
    echo "  --port <port>          设置监听端口 (默认: $DEFAULT_VBPORT)"
    echo "  --password <pwd>       设置数据库初始密码 (默认: $DEFAULT_VBPASSWORD)"
    echo "  --encrypt-key <key>    设置数据库加密密钥 (默认: $DEFAULT_ENCRYPTION_KEY)"
    echo "  --compatibility <mode> 设置兼容模式，支持 A|B|C|PG|MSSQL (默认: $DEFAULT_DB_COMPATIBILITY)"
    echo "  --max-connections <n>  设置最大连接数 (默认: $DEFAULT_MAX_CONNECTIONS)"
    echo "  --wal-dir <path>       设置 WAL 日志目录（可选，安装后自动迁移 pg_wal/pg_xlog）"
    echo "  --archive-dir <path>   设置归档日志目录（可选，安装后自动开启 archive_mode）"
    echo "  --soft-dir <path>      设置安装包目录 (默认: $DEFAULT_SOFT_DIR)"
    echo "  --isinitdb <bool>      是否安装时实例化 true|false (默认: $DEFAULT_ISINITDB)"
    echo "  --enable-systemd <b>   是否创建 systemd 服务 true|false (默认: $DEFAULT_ENABLE_SYSTEMD)"
    echo "  --logfile <path>       设置日志文件 (默认: $DEFAULT_LOGFILE)"
    echo "  -h, --help             显示帮助信息"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ip) server_ip="$2"; shift ;;
        --hostname) server="$2"; shift ;;
        --ntp) ntp_server="$2"; shift ;;
        --user) vb_user="$2"; shift ;;
        --vbhome) VBHOME="$2"; shift ;;
        --vbdata) VBDATA="$2"; shift ;;
        --port) VBPORT="$2"; shift ;;
        --password) VBPASSWORD="$2"; shift ;;
        --encrypt-key) encryption_key="$2"; shift ;;
        --compatibility) db_compatibility="$2"; shift ;;
        --max-connections) max_connections="$2"; shift ;;
        --shared-buffers) shared_buffers="$2"; log_warn "--shared-buffers 参数已废弃，当前版本不再写入初始化参数文件"; shift ;;
        --wal-dir) wal_dir="$2"; shift ;;
        --archive-dir) archive_dir="$2"; shift ;;
        --soft-dir) SOFT_DIR="$2"; shift ;;
        --isinitdb) isinitdb="$2"; shift ;;
        --enable-systemd) enable_systemd="$2"; shift ;;
        --logfile) LOGFILE="$2"; shift ;;
        --keep-media) keep_media="$2"; shift ;;
        --keep-user) keep_user="$2"; shift ;;
        --keep-logs) keep_logs="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "未知参数: $1"; usage ;;
    esac
    shift
done

RSP_FILE="$SOFT_DIR/db_install.rsp"
WORK_DIR="$SOFT_DIR"
SERVICE_FILE="/etc/systemd/system/vastbase.service"
ENV_FILE="/home/${vb_user}/.bash_profile"
VASTBASE_BIN=""
LICENSE_FILE=""
INSTALLER_TAR=""
INSTALLER_DIR=""
INSTALLER_CMD=""

# -------------------------------------------------------------------------
# 2. 基础函数定义
# -------------------------------------------------------------------------
init_log() {
    mkdir -p "$(dirname "$LOGFILE")"
    touch "$LOGFILE" 2>/dev/null || {
        echo "无法写入日志文件: $LOGFILE"
        exit 1
    }
}

log_info() {
    echo -e "\x1B[01;96m [INFO] $1 \x1B[0m"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

log_warn() {
    echo -e "\x1B[01;93m [WARN] $1 \x1B[0m"
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

log_error() {
    echo -e "\x1B[01;91m [ERROR] $1 \x1B[0m"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE"
}

run_cmd() {
    log_info "执行命令: $*"
    bash -lc "$*" >> "$LOGFILE" 2>&1
    return $?
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "请使用 root 用户执行本脚本"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=${ID:-unknown}
        OS_VERSION=${VERSION_ID:-unknown}
        OS_NAME=${PRETTY_NAME:-unknown}
        os_like=$(echo "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')
    else
        os_like=""
    fi

    ARCH_RAW=$(uname -m 2>/dev/null || echo unknown)
    case "$ARCH_RAW" in
        x86_64|amd64) ARCH_FAMILY="x86_64" ;;
        aarch64|arm64) ARCH_FAMILY="arm64" ;;
        *) ARCH_FAMILY="$ARCH_RAW" ;;
    esac

    case "$(echo "$OS_ID" | tr '[:upper:]' '[:lower:]')" in
        rhel|redhat|centos|rocky|almalinux|anolis|opencloudos|kylin|uos|uniontech|openeuler|euleros)
            OS_FAMILY="rhel"
            ;;
        ubuntu|debian|linuxmint)
            OS_FAMILY="debian"
            ;;
        *)
            if echo "$os_like" | grep -Eq 'rhel|fedora|centos|suse'; then
                OS_FAMILY="rhel"
            elif echo "$os_like" | grep -Eq 'debian|ubuntu'; then
                OS_FAMILY="debian"
            else
                OS_FAMILY="unknown"
            fi
            ;;
    esac

    if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    else
        PKG_MGR="unknown"
    fi

    log_info "检测到系统: $OS_NAME ($OS_ID $OS_VERSION), 系列=$OS_FAMILY, 架构=$ARCH_FAMILY, 包管理器=$PKG_MGR"
}

check_os_support() {
    local major_version
    major_version=$(echo "$OS_VERSION" | awk -F. '{print $1}')
    [ -z "$major_version" ] && major_version=0

    case "$OS_FAMILY" in
        rhel)
            if [ "$major_version" -lt 7 ]; then
                log_error "当前 RHEL 系操作系统版本过低，仅支持 Red Hat / CentOS / Rocky / Alma / 麒麟 / 欧拉等 7 及以上版本"
                exit 1
            fi
            ;;
        debian)
            case "$(echo "$OS_ID" | tr '[:upper:]' '[:lower:]')" in
                ubuntu)
                    if [ "$major_version" -lt 18 ]; then
                        log_error "当前 Ubuntu 版本过低，建议使用 Ubuntu 18.04 及以上版本"
                        exit 1
                    fi
                    ;;
                debian)
                    if [ "$major_version" -lt 10 ]; then
                        log_error "当前 Debian 版本过低，建议使用 Debian 10 及以上版本"
                        exit 1
                    fi
                    ;;
            esac
            ;;
        *)
            log_error "当前系统暂未纳入脚本支持范围: $OS_NAME"
            exit 1
            ;;
    esac

    case "$ARCH_FAMILY" in
        x86_64|arm64) ;;
        *)
            log_error "当前 CPU 架构暂未纳入脚本支持范围: $ARCH_RAW，仅支持 x86_64 / aarch64(arm64)"
            exit 1
            ;;
    esac
}

check_params() {
    echo -e "\x1B[01;93m ============ 当前配置确认 ============ \x1B[0m"
    echo "  主机名 (Hostname)    : $server"
    echo "  本机IP (IP Addr)     : $server_ip"
    echo "  安装用户 (User)      : $vb_user"
    echo "  安装目录 (VBHOME)    : $VBHOME"
    echo "  数据目录 (VBDATA)    : $VBDATA"
    echo "  端口 (Port)          : $VBPORT"
    echo "  初始密码             : $VBPASSWORD"
    echo "  加密密钥             : $encryption_key"
    echo "  兼容模式             : $db_compatibility"
    echo "  最大连接数           : $max_connections"
    echo "  shared_buffers(MB)   : $shared_buffers"
    echo "  软件目录             : $SOFT_DIR"
    echo "  安装后实例化         : $isinitdb"
    echo "  生成 systemd 服务    : $enable_systemd"
    echo "  日志文件             : $LOGFILE"
    echo "  卸载保留介质         : $keep_media"
    echo "  卸载保留用户         : $keep_user"
    echo "  卸载保留日志         : $keep_logs"
    echo "  系统系列             : $OS_FAMILY"
    echo "  CPU架构              : $ARCH_FAMILY"
    echo " ======================================"
}

validate_params() {
    [[ "$VBPORT" =~ ^[0-9]+$ ]] || { log_error "端口必须是数字"; exit 1; }
    [ "$VBPORT" -gt 0 ] && [ "$VBPORT" -lt 65535 ] || { log_error "端口范围非法: $VBPORT"; exit 1; }

    [[ "$max_connections" =~ ^[0-9]+$ ]] || { log_error "max_connections 必须是数字"; exit 1; }
    [[ "$shared_buffers" =~ ^[0-9]+$ ]] || { log_error "shared_buffers 必须是数字(MB)"; exit 1; }

    isinitdb="$(echo "$isinitdb" | tr '[:upper:]' '[:lower:]' | xargs)"
    case "$isinitdb" in
        true|false) ;;
        *) log_error "--isinitdb 仅支持 true|false，且不要带多余空格"; exit 1 ;;
    esac

    case "$enable_systemd" in
        true|false|TRUE|FALSE) ;;
        *) log_error "--enable-systemd 仅支持 true|false"; exit 1 ;;
    esac
    case "$keep_media" in
        true|false|TRUE|FALSE) ;;
        *) log_error "--keep-media 仅支持 true|false"; exit 1 ;;
    esac
    case "$keep_user" in
        true|false|TRUE|FALSE) ;;
        *) log_error "--keep-user 仅支持 true|false"; exit 1 ;;
    esac
    case "$keep_logs" in
        true|false|TRUE|FALSE) ;;
        *) log_error "--keep-logs 仅支持 true|false"; exit 1 ;;
    esac

    db_compatibility=$(echo "$db_compatibility" | tr '[:lower:]' '[:upper:]')
    case "$db_compatibility" in
        A|B|C|PG|MSSQL) ;;
        MYSQL)
            log_warn "检测到兼容模式 MYSQL，已自动转换为官方模式值 B"
            db_compatibility="B"
            ;;
        ORACLE)
            log_warn "检测到兼容模式 ORACLE，已自动转换为官方模式值 A"
            db_compatibility="A"
            ;;
        POSTGRESQL)
            log_warn "检测到兼容模式 POSTGRESQL，已自动转换为官方模式值 PG"
            db_compatibility="PG"
            ;;
        SQLSERVER|SQL_SERVER)
            log_warn "检测到兼容模式 SQLSERVER，已自动转换为官方模式值 MSSQL"
            db_compatibility="MSSQL"
            ;;
        *) log_error "--compatibility 仅支持 A|B|C|PG|MSSQL (可兼容 MYSQL/ORACLE/POSTGRESQL/SQLSERVER 别名)"; exit 1 ;;
    esac
}

check_network() {
    log_info "检测网络连接..."
    if ping -c 1 -W 2 223.5.5.5 >/dev/null 2>&1 || \
       ping -c 1 -W 2 114.114.114.114 >/dev/null 2>&1 || \
       curl -s --connect-timeout 3 https://www.baidu.com >/dev/null 2>&1; then
        log_info "网络连接正常"
        return 0
    fi
    log_warn "网络连接不可用"
    return 1
}

calc_memory_params() {
    mem_total_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
    [ -z "$mem_total_mb" ] && mem_total_mb=8192
    [[ "$mem_total_mb" =~ ^[0-9]+$ ]] || mem_total_mb=8192
    mem_total=$(((mem_total_mb + 1023) / 1024))

    if [ "$mem_total_mb" -le 4096 ]; then
        shared_buffers_calc=256
        effective_cache_size_mb=$((mem_total_mb / 2))
        vm_swappiness=10
        dirty_background_bytes=$((128 * 1024 * 1024))
        dirty_bytes=$((512 * 1024 * 1024))
        huge_mem=0
        file_max=1048576
        aio_max_nr=1048576
        mem_tier="small"
        log_warn "检测到内存较小(${mem_total_mb}MB)，建议至少配置 8GB swap 以避免安装器或数据库运行期 OOM"
    elif [ "$mem_total_mb" -le 16384 ]; then
        shared_buffers_calc=$((mem_total_mb / 8))
        effective_cache_size_mb=$((mem_total_mb * 3 / 4))
        vm_swappiness=5
        dirty_background_bytes=$((256 * 1024 * 1024))
        dirty_bytes=$((1024 * 1024 * 1024))
        huge_mem=$((shared_buffers_calc / 2))
        file_max=2097152
        aio_max_nr=1048576
        mem_tier="medium"
    elif [ "$mem_total_mb" -le 65536 ]; then
        shared_buffers_calc=$((mem_total_mb / 6))
        effective_cache_size_mb=$((mem_total_mb * 3 / 4))
        vm_swappiness=1
        dirty_background_bytes=$((512 * 1024 * 1024))
        dirty_bytes=$((2 * 1024 * 1024 * 1024))
        huge_mem=$((shared_buffers_calc / 2))
        file_max=4194304
        aio_max_nr=2097152
        mem_tier="large"
    else
        shared_buffers_calc=$((mem_total_mb / 4))
        effective_cache_size_mb=$((mem_total_mb / 2))
        vm_swappiness=1
        dirty_background_bytes=$((1024 * 1024 * 1024))
        dirty_bytes=$((4 * 1024 * 1024 * 1024))
        huge_mem=$((shared_buffers_calc / 2))
        file_max=8388608
        aio_max_nr=4194304
        mem_tier="xlarge"
    fi

    [ "$shared_buffers_calc" -lt 256 ] && shared_buffers_calc=256
    [ "$effective_cache_size_mb" -lt 512 ] && effective_cache_size_mb=512

    CPUS=$(nproc 2>/dev/null)
    [ -z "$CPUS" ] && CPUS=4

    shmax=$((mem_total_mb * 1024 * 1024 / 2))
    shmall=$((mem_total_mb * 1024 * 1024 * 8 / 10 / 4096))

    log_info "内存检测: 总内存=${mem_total_mb}MB(${mem_total}GB), CPUs=${CPUS}, tier=${mem_tier}"
    log_info "OS参数建议: shmmax=${shmax}, shmall=${shmall}, swappiness=${vm_swappiness}, dirty_background_bytes=${dirty_background_bytes}, dirty_bytes=${dirty_bytes}, file-max=${file_max}, aio-max-nr=${aio_max_nr}"
}


calc_db_runtime_params() {
    mem_total_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}')
    [ -z "$mem_total_mb" ] && mem_total_mb=4096
    [[ "$mem_total_mb" =~ ^[0-9]+$ ]] || mem_total_mb=4096

    # 针对 Vastbase G100 单机场景生成“优先可启动”的保守参数。
    if [ "$mem_total_mb" -le 4096 ]; then
        db_shared_buffers="128MB"
        db_max_connections="50"
        db_max_process_memory="4GB"
        db_wal_buffers="16MB"
        db_cstore_buffers="128MB"
        db_max_prepared_transactions="50"
        db_work_mem="4MB"
        db_maintenance_work_mem="64MB"
        db_effective_cache_size="512MB"
        db_temp_buffers="8MB"
        db_mem_tier="small"
    elif [ "$mem_total_mb" -le 8192 ]; then
        db_shared_buffers="256MB"
        db_max_connections="100"
        db_max_process_memory="6GB"
        db_wal_buffers="16MB"
        db_cstore_buffers="256MB"
        db_max_prepared_transactions="100"
        db_work_mem="8MB"
        db_maintenance_work_mem="128MB"
        db_effective_cache_size="2GB"
        db_temp_buffers="8MB"
        db_mem_tier="medium"
    elif [ "$mem_total_mb" -le 16384 ]; then
        db_shared_buffers="512MB"
        db_max_connections="200"
        db_max_process_memory="8GB"
        db_wal_buffers="32MB"
        db_cstore_buffers="512MB"
        db_max_prepared_transactions="200"
        db_work_mem="16MB"
        db_maintenance_work_mem="256MB"
        db_effective_cache_size="4GB"
        db_temp_buffers="16MB"
        db_mem_tier="large"
    else
        db_shared_buffers="1GB"
        db_max_connections="300"
        db_max_process_memory="12GB"
        db_wal_buffers="64MB"
        db_cstore_buffers="1GB"
        db_max_prepared_transactions="300"
        db_work_mem="16MB"
        db_maintenance_work_mem="512MB"
        db_effective_cache_size="8GB"
        db_temp_buffers="16MB"
        db_mem_tier="xlarge"
    fi

    # 用户传入的 max_connections 作为上限参考；小内存机器不盲目放大。
    if [[ "$max_connections" =~ ^[0-9]+$ ]] && [ "$max_connections" -gt 0 ]; then
        if [ "$max_connections" -lt "$db_max_connections" ]; then
            db_max_connections="$max_connections"
        fi
    fi

    log_info "数据库参数建议: tier=${db_mem_tier}, shared_buffers=${db_shared_buffers}, max_connections=${db_max_connections}, max_process_memory=${db_max_process_memory}, wal_buffers=${db_wal_buffers}, cstore_buffers=${db_cstore_buffers}"
}

upsert_pg_conf_param() {
    local conf_file="$1"
    local key="$2"
    local value="$3"
    local escaped_key escaped_value
    escaped_key=$(printf '%s' "$key" | sed 's/[][\/.^$*]/\\&/g')
    escaped_value=$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')
    if grep -Eq "^[#[:space:]]*${escaped_key}[[:space:]]*=" "$conf_file"; then
        sed -i "s|^[#[:space:]]*${escaped_key}[[:space:]]*=.*|${key} = ${escaped_value}|" "$conf_file"
    else
        printf '%s = %s\n' "$key" "$value" >> "$conf_file"
    fi
}

f2_tune_postgresql_conf() {
    [ "${isinitdb,,}" = "true" ] || return 0
    local conf_file="$VBDATA/postgresql.conf"
    [ -f "$conf_file" ] || { log_warn "未找到配置文件，跳过数据库参数调优: $conf_file"; return 0; }

    log_info "--------8. 安装后按内存自动调整数据库参数--------"
    calc_db_runtime_params

    cp -f "$conf_file" "${conf_file}.bak.$(date +%F_%H%M%S)" >> "$LOGFILE" 2>&1 || true

    upsert_pg_conf_param "$conf_file" "shared_buffers" "$db_shared_buffers"
    upsert_pg_conf_param "$conf_file" "max_connections" "$db_max_connections"
    upsert_pg_conf_param "$conf_file" "max_process_memory" "$db_max_process_memory"
    upsert_pg_conf_param "$conf_file" "wal_buffers" "$db_wal_buffers"
    upsert_pg_conf_param "$conf_file" "cstore_buffers" "$db_cstore_buffers"
    upsert_pg_conf_param "$conf_file" "max_prepared_transactions" "$db_max_prepared_transactions"
    upsert_pg_conf_param "$conf_file" "work_mem" "$db_work_mem"
    upsert_pg_conf_param "$conf_file" "maintenance_work_mem" "$db_maintenance_work_mem"
    upsert_pg_conf_param "$conf_file" "effective_cache_size" "$db_effective_cache_size"
    upsert_pg_conf_param "$conf_file" "temp_buffers" "$db_temp_buffers"

    log_info "已写入数据库参数: shared_buffers=${db_shared_buffers}, max_connections=${db_max_connections}, max_process_memory=${db_max_process_memory}, wal_buffers=${db_wal_buffers}, cstore_buffers=${db_cstore_buffers}"
}

find_install_media() {

    log_info "扫描安装包目录: $SOFT_DIR"
    [ -d "$SOFT_DIR" ] || { log_error "安装包目录不存在: $SOFT_DIR"; exit 1; }

    INSTALLER_CMD=$(find "$SOFT_DIR" -maxdepth 3 -type f -name "vastbase_installer" | head -n 1)
    [ -z "$INSTALLER_CMD" ] && INSTALLER_CMD=$(find "$SOFT_DIR" -maxdepth 3 -type f -perm -u+x | grep -E '/vastbase_installer$' | head -n 1)

    INSTALLER_TAR=$(find "$SOFT_DIR" -maxdepth 1 -type f         \( -iname "Vastbase-G100*.tar" -o -iname "Vastbase-G100*.tar.gz" -o -iname "Vastbase-G100*.tgz"         -o -iname "vastbase*g100*.tar" -o -iname "vastbase*g100*.tar.gz" -o -iname "vastbase*g100*.tgz"         -o -iname "*installer*.tar" -o -iname "*installer*.tar.gz" -o -iname "*installer*.tgz" \) | head -n 1)

    LICENSE_FILE=$(find "$SOFT_DIR" -maxdepth 1 -type f \( -iname "*.lic" -o -iname "license*" -o -iname "*.dat" \) | head -n 1)

    if [ -z "$INSTALLER_CMD" ] && [ -z "$INSTALLER_TAR" ]; then
        log_error "未找到 Vastbase G100 安装介质。请将 Vastbase-G100*.tar / .tar.gz / .tgz 或已解压的 vastbase_installer 放入 $SOFT_DIR"
        exit 1
    fi

    if [ -z "$LICENSE_FILE" ]; then
        log_warn "未在 $SOFT_DIR 找到 license 文件，若当前版本强制要求 license，请手工放置后再执行安装"
    fi

    [ -n "$INSTALLER_TAR" ] && log_info "找到安装介质压缩包: $INSTALLER_TAR"
    [ -n "$INSTALLER_CMD" ] && log_info "找到安装程序: $INSTALLER_CMD"
    [ -n "$LICENSE_FILE" ] && log_info "找到 license: $LICENSE_FILE"
}

check_sha256_if_exists() {
    [ -z "$INSTALLER_TAR" ] && return 0
    sha_file="${INSTALLER_TAR}.sha256"
    if [ -f "$sha_file" ]; then
        log_info "检测到校验文件，开始校验安装包完整性"
        (cd "$(dirname "$INSTALLER_TAR")" && sha256sum -c "$(basename "$sha_file")") >> "$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            log_error "安装包 sha256 校验失败"
            exit 1
        fi
        log_info "安装包 sha256 校验通过"
    else
        log_warn "未检测到 ${sha_file}，跳过 sha256 校验"
    fi
}

# -------------------------------------------------------------------------
# 3. 环境准备
# -------------------------------------------------------------------------
f1_basic_tools() {
    log_info "--------1. 安装基础系统工具--------"

    case "$PKG_MGR" in
        yum)
            yum install -y tar gzip which curl sed gawk grep coreutils util-linux shadow-utils net-tools lsof iproute procps-ng findutils chrony >/dev/null 2>&1 || true
            ;;
        dnf)
            dnf install -y tar gzip which curl sed gawk grep coreutils util-linux shadow-utils net-tools lsof iproute procps-ng findutils chrony >/dev/null 2>&1 || true
            ;;
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update >/dev/null 2>&1 || true
            apt-get install -y tar gzip curl sed gawk grep coreutils util-linux passwd net-tools lsof iproute2 procps findutils chrony >/dev/null 2>&1 || true
            ;;
        *)
            log_warn "未识别到可用包管理器，跳过依赖安装，请确保基础命令已存在"
            ;;
    esac

    for cmd in tar sed awk grep id hostnamectl find ss; do
        command -v "$cmd" >/dev/null 2>&1 || { log_error "缺少关键命令: $cmd"; exit 1; }
    done
    log_info "基础系统工具检查通过"
}

f1_os_config() {
    log_info "--------2. 系统参数配置 (Hosts, Time, Sysctl, Limits)--------"

    hostnamectl set-hostname "$server" >> "$LOGFILE" 2>&1 || true
    sed -i "/^[[:space:]]*${server_ip}[[:space:]]\+/d" /etc/hosts
    grep -q "${server_ip}  ${server}" /etc/hosts || echo "$server_ip  $server" >> /etc/hosts

    timedatectl set-timezone 'Asia/Shanghai' >> "$LOGFILE" 2>&1 || true
    if [ -n "$ntp_server" ]; then
        case "$PKG_MGR" in
            yum) yum install -y chrony >> "$LOGFILE" 2>&1 || true ;;
            dnf) dnf install -y chrony >> "$LOGFILE" 2>&1 || true ;;
            apt)
                export DEBIAN_FRONTEND=noninteractive
                apt-get update >> "$LOGFILE" 2>&1 || true
                apt-get install -y chrony >> "$LOGFILE" 2>&1 || true
                ;;
        esac
        if [ -f /etc/chrony.conf ] && ! grep -q "$ntp_server" /etc/chrony.conf; then
            echo "server $ntp_server iburst" >> /etc/chrony.conf
            systemctl restart chronyd >> "$LOGFILE" 2>&1 || systemctl restart chrony >> "$LOGFILE" 2>&1 || true
        fi
    fi

    # Vastbase 官方显式要求 RemoveIPC=no，否则安装器会阻塞
    if [ -f /etc/systemd/logind.conf ]; then
        grep -q '^RemoveIPC=' /etc/systemd/logind.conf           && sed -i 's/^RemoveIPC=.*/RemoveIPC=no/' /etc/systemd/logind.conf           || echo 'RemoveIPC=no' >> /etc/systemd/logind.conf
    fi
    if [ -f /usr/lib/systemd/system/systemd-logind.service ]; then
        grep -q '^RemoveIPC=' /usr/lib/systemd/system/systemd-logind.service           && sed -i 's/^RemoveIPC=.*/RemoveIPC=no/' /usr/lib/systemd/system/systemd-logind.service           || sed -i '/^\[Service\]/a RemoveIPC=no' /usr/lib/systemd/system/systemd-logind.service
        systemctl daemon-reload >> "$LOGFILE" 2>&1 || true
        systemctl restart systemd-logind >> "$LOGFILE" 2>&1 || true
    fi

    systemctl stop firewalld >/dev/null 2>&1 || true
    systemctl disable firewalld >/dev/null 2>&1 || true
    systemctl stop ufw >/dev/null 2>&1 || true
    systemctl disable ufw >/dev/null 2>&1 || true
    setenforce 0 >/dev/null 2>&1 || true
    [ -f /etc/selinux/config ] && sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

    awk 'BEGIN{skip=0} /#for_vastbase_begin/{skip=1; next} /#for_vastbase_end/{skip=0; next} skip==0{print}' /etc/sysctl.conf > /etc/sysctl.conf.vbtmp && mv /etc/sysctl.conf.vbtmp /etc/sysctl.conf
    cat >> /etc/sysctl.conf <<EOF_SYSCTL
#for_vastbase_begin
fs.aio-max-nr = $aio_max_nr
fs.file-max = $file_max
kernel.shmmax = $shmax
kernel.shmall = $shmall
kernel.sem = 250 1024000 100 4096
net.ipv4.ip_local_port_range = 10000 65535
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576
vm.swappiness = $vm_swappiness
vm.overcommit_memory = 0
vm.dirty_background_bytes = $dirty_background_bytes
vm.dirty_bytes = $dirty_bytes
vm.nr_hugepages = $huge_mem
#for_vastbase_end
EOF_SYSCTL
    sysctl -p >> "$LOGFILE" 2>&1 || true

    awk 'BEGIN{skip=0} /#for_vastbase_begin/{skip=1; next} /#for_vastbase_end/{skip=0; next} skip==0{print}' /etc/security/limits.conf > /etc/security/limits.conf.vbtmp && mv /etc/security/limits.conf.vbtmp /etc/security/limits.conf
    cat >> /etc/security/limits.conf <<EOF_LIMITS
#for_vastbase_begin
${vb_user} soft nproc unlimited
${vb_user} hard nproc unlimited
${vb_user} soft stack unlimited
${vb_user} hard stack unlimited
${vb_user} soft core unlimited
${vb_user} hard core unlimited
${vb_user} soft memlock unlimited
${vb_user} hard memlock unlimited
${vb_user} soft nofile 1024000
${vb_user} hard nofile 1024000
#for_vastbase_end
EOF_LIMITS

    [ -f /etc/pam.d/login ] && grep -q 'pam_limits.so' /etc/pam.d/login || echo 'session    required     pam_limits.so' >> /etc/pam.d/login
}

f1_prepare_user_dirs() {

    log_info "--------3. 创建用户与目录--------"

    getent group "$vb_user" >/dev/null 2>&1 || groupadd "$vb_user"
    id "$vb_user" >/dev/null 2>&1 || useradd -m -g "$vb_user" "$vb_user"

    echo "$vb_user:$VBPASSWORD" | chpasswd >> "$LOGFILE" 2>&1 || true

    mkdir -p "$SOFT_DIR"
    chmod 755 /soft >/dev/null 2>&1 || true

    mkdir -p "$(dirname "$VBHOME")" "$VBDATA" "/home/${vb_user}/data/db_coredump"
    chmod 700 "$VBDATA"
    chmod 770 "/home/${vb_user}/data" >/dev/null 2>&1 || true
    chown -R "$vb_user:$vb_user" "/home/${vb_user}" "$SOFT_DIR"
    [ -d "$(dirname "$VBHOME")" ] && chown -R "$vb_user:$vb_user" "$(dirname "$VBHOME")"
    [ -d "$VBDATA" ] && chown -R "$vb_user:$vb_user" "$VBDATA"
}

f1_unpack_installer() {
    log_info "--------4. 解压安装包/识别安装程序--------"
    cd "$SOFT_DIR" || exit 1

    if [ -z "$INSTALLER_CMD" ] && [ -n "$INSTALLER_TAR" ]; then
        case "$INSTALLER_TAR" in
            *.tar.gz|*.tgz)
                tar -xzvf "$INSTALLER_TAR" >> "$LOGFILE" 2>&1 || {
                    log_error "安装包解压失败: $INSTALLER_TAR"
                    exit 1
                }
                ;;
            *.tar)
                tar -xvf "$INSTALLER_TAR" >> "$LOGFILE" 2>&1 || {
                    log_error "安装包解压失败: $INSTALLER_TAR"
                    exit 1
                }
                ;;
            *)
                log_error "暂不支持的安装包格式: $INSTALLER_TAR"
                exit 1
                ;;
        esac
    else
        log_info "检测到已解压安装程序，跳过解压步骤"
    fi

    INSTALLER_CMD=$(find "$SOFT_DIR" -maxdepth 5 -type f -name "vastbase_installer" | head -n 1)
    [ -z "$INSTALLER_CMD" ] && INSTALLER_CMD=$(find "$SOFT_DIR" -maxdepth 5 -type f -perm -u+x | grep -E '/vastbase_installer$' | head -n 1)

    if [ -z "$INSTALLER_CMD" ]; then
        log_error "未找到 vastbase_installer 可执行程序，请确认安装介质已完整解压"
        exit 1
    fi

    INSTALLER_DIR=$(dirname "$INSTALLER_CMD")
    chmod +x "$INSTALLER_CMD"
    chown -R "$vb_user:$vb_user" "$SOFT_DIR"

    if [ ! -d "$INSTALLER_DIR/locales" ]; then
        ALT_LOCALES=$(find "$SOFT_DIR" -maxdepth 5 -type d -name locales | head -n 1)
        if [ -n "$ALT_LOCALES" ]; then
            log_warn "当前安装目录下未找到 locales，自动调整安装目录为: $(dirname "$ALT_LOCALES")"
            INSTALLER_DIR=$(dirname "$ALT_LOCALES")
            INSTALLER_CMD=$(find "$INSTALLER_DIR" -maxdepth 2 -type f -name "vastbase_installer" | head -n 1)
        fi
    fi

    log_info "安装目录识别为: $INSTALLER_DIR"
    log_info "安装程序识别为: $INSTALLER_CMD"
    [ -d "$INSTALLER_DIR/locales" ] && log_info "检测到 locales 目录: $INSTALLER_DIR/locales" || log_warn "未在安装目录检测到 locales 目录，安装器可能无法正常启动"
}

# -------------------------------------------------------------------------
# 4. 静默安装配置与执行
# -------------------------------------------------------------------------
f2_write_rsp() {
    log_info "--------5. 生成静默安装参数文件--------"

    # 部分版本对 db_install.rsp 的格式较为严格：
    # 1) 文件名必须为 db_install.rsp
    # 2) 参数格式需严格贴近官方示例
    # 3) 末尾不能有空行
    # 4) 建议使用 Unix LF 换行
    # 因此这里使用逐行 printf 精确写入，避免 heredoc 带来的格式偏差。
    VBPASSWORD="$(echo "$VBPASSWORD" | xargs)"
    encryption_key="$(echo "$encryption_key" | xargs)"
    VBHOME="$(echo "$VBHOME" | xargs)"
    VBDATA="$(echo "$VBDATA" | xargs)"
    VBPORT="$(echo "$VBPORT" | xargs)"
    max_connections="$(echo "$max_connections" | xargs)"
    db_compatibility="$(echo "$db_compatibility" | xargs | tr '[:lower:]' '[:upper:]')"
    isinitdb="$(echo "$isinitdb" | xargs | tr '[:upper:]' '[:lower:]')"

    : > "$RSP_FILE"
    printf 'vastbase_password = %s
' "$VBPASSWORD" >> "$RSP_FILE"
    printf 'encryption_key = %s
' "$encryption_key" >> "$RSP_FILE"
    printf 'vastbase_home = %s
' "$VBHOME" >> "$RSP_FILE"
    printf 'vastbase_data = %s
' "$VBDATA" >> "$RSP_FILE"
    printf 'port = %s
' "$VBPORT" >> "$RSP_FILE"
    printf 'max_connections = %s
' "$max_connections" >> "$RSP_FILE"
    printf 'db_compatibility = %s
' "$db_compatibility" >> "$RSP_FILE"
    printf 'isinitdb = %s' "$isinitdb" >> "$RSP_FILE"

    # 清理潜在的 CRLF 和文件尾部空行
    sed -i 's/
$//' "$RSP_FILE"
    awk 'NF { last = NR } { lines[NR] = $0 } END { for (i = 1; i <= last; i++) print lines[i] }' "$RSP_FILE" > "${RSP_FILE}.tmp"
    mv -f "${RSP_FILE}.tmp" "$RSP_FILE"

    chown "$vb_user:$vb_user" "$RSP_FILE"
    chmod 600 "$RSP_FILE"

    log_info "静默安装参数文件已生成: $RSP_FILE"
    log_info "静默安装参数文件内容如下(敏感值已记录到日志请妥善保管):"
    sed 's/^vastbase_password = .*/vastbase_password = ******/' "$RSP_FILE" >> "$LOGFILE"
}

f2_config_profile() {

    log_info "--------6. 配置 ${vb_user} 用户环境--------"

    touch "$ENV_FILE"
    chown "$vb_user:$vb_user" "$ENV_FILE"

    sed -i '/#vastbase_env_begin/,/#vastbase_env_end/d' "$ENV_FILE"
    cat >> "$ENV_FILE" <<EOF_ENV
#vastbase_env_begin
export VASTBASE_HOME=$VBHOME
export GAUSSHOME=$VBHOME
export PGDATA=$VBDATA
export PATH=\$VASTBASE_HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH
export LD_LIBRARY_PATH=\$VASTBASE_HOME/lib:\$LD_LIBRARY_PATH
export LANG=en_US.UTF-8
#vastbase_env_end
EOF_ENV
}


precheck_installer_runtime() {
    log_info "--------6.5 安装器运行前预检查--------"
    [ -x "$INSTALLER_CMD" ] || { log_error "安装程序不可执行: $INSTALLER_CMD"; exit 1; }

    if [ ! -d "$INSTALLER_DIR/locales" ]; then
        log_error "安装目录缺少 locales 资源目录: $INSTALLER_DIR/locales"
        log_error "这通常意味着 INSTALLER_DIR 识别错了，或安装包未完整解压"
        exit 1
    fi

    log_info "系统架构: $(uname -m 2>/dev/null || true)"
    command -v file >/dev/null 2>&1 && file "$INSTALLER_CMD" >> "$LOGFILE" 2>&1 || true
    command -v lscpu >/dev/null 2>&1 && lscpu >> "$LOGFILE" 2>&1 || true
    grep -m1 -E 'model name|Processor|cpu model|Hardware' /proc/cpuinfo >> "$LOGFILE" 2>&1 || true

    if command -v file >/dev/null 2>&1; then
        installer_desc=$(file "$INSTALLER_CMD" 2>/dev/null || true)
        case "$ARCH_FAMILY" in
            x86_64)
                echo "$installer_desc" | grep -Eq 'x86-64|80386|x86_64|AMD64' || {
                    log_error "安装器文件与当前机器架构疑似不匹配。当前机器=$ARCH_FAMILY, 安装器信息: $installer_desc"
                    log_error "请确认下载的是 x86_64 对应安装包，而不是 ARM/其他平台包"
                    exit 1
                }
                ;;
            arm64)
                echo "$installer_desc" | grep -Eq 'aarch64|ARM aarch64|ARM64' || {
                    log_error "安装器文件与当前机器架构疑似不匹配。当前机器=$ARCH_FAMILY, 安装器信息: $installer_desc"
                    log_error "请确认下载的是 ARM64 对应安装包，而不是 x86_64/其他平台包"
                    exit 1
                }
                ;;
        esac
    fi

    # 安装器必须至少能正常打印帮助，否则继续调整 db_install.rsp 没有意义
    tmp_help="${SOFT_DIR}/.vastbase_installer_help.$$"
    su - "$vb_user" -c "cd '$INSTALLER_DIR' && ./vastbase_installer --help" > "$tmp_help" 2>&1
    help_rc=$?
    cat "$tmp_help" >> "$LOGFILE"
    if [ $help_rc -ne 0 ]; then
        if grep -Eqi 'internal/cpu|runtime\.cpuinit|illegal instruction|segmentation fault|panic:|SIGILL|trace/breakpoint trap' "$tmp_help"; then
            log_error "安装器在解析参数前即崩溃，属于安装器二进制与当前 CPU/虚拟化环境不兼容，不是 db_install.rsp 配置问题"
            log_error "请更换与当前平台匹配的 Vastbase 安装包，或在物理机/兼容虚拟化环境中执行安装"
            log_error "建议先执行: uname -m ; lscpu ; file '$INSTALLER_CMD'"
            rm -f "$tmp_help"
            exit 1
        fi
        log_warn "安装器 --help 返回非 0，后续将继续尝试静默安装；详细输出已写入日志"
    else
        log_info "安装器 --help 预检查通过"
    fi
    rm -f "$tmp_help"
}

f2_install_vastbase() {
    log_info "--------7. 执行 Vastbase G100 静默安装--------"

    [ -x "$INSTALLER_CMD" ] || { log_error "安装程序不可执行: $INSTALLER_CMD"; exit 1; }
    [ -f "$RSP_FILE" ] || { log_error "静默安装文件不存在: $RSP_FILE"; exit 1; }

    if [ -n "$LICENSE_FILE" ]; then
        log_info "检测到 license 文件，将与安装目录一起保留供安装程序读取"
    fi

    # 为兼容不同小版本安装器：
    # 1) 在 SOFT_DIR 保留原始 db_install.rsp
    # 2) 在 INSTALLER_DIR 放置同名响应文件
    # 3) 优先使用官方命令 --silent -responseFile 绝对路径
    # 4) 失败后回退到安装目录内直接读取 db_install.rsp
    cp -f "$RSP_FILE" "$INSTALLER_DIR/db_install.rsp"
    chown "$vb_user:$vb_user" "$INSTALLER_DIR/db_install.rsp"
    chmod 600 "$INSTALLER_DIR/db_install.rsp"

    log_info "安装目录: $INSTALLER_DIR"
    log_info "安装程序: ./vastbase_installer"
    log_info "响应文件(官方推荐路径): $RSP_FILE"
    if [ ! -d "$INSTALLER_DIR/locales" ]; then
        log_error "安装目录缺少 locales 资源目录: $INSTALLER_DIR/locales"
        exit 1
    fi

    log_info "安装器帮助输出如下(用于定位参数兼容性):"
    su - "$vb_user" -c "cd '$INSTALLER_DIR' && ./vastbase_installer --help" >> "$LOGFILE" 2>&1 || true

    su - "$vb_user" -c "cd '$INSTALLER_DIR' && ./vastbase_installer --silent -responseFile '$RSP_FILE'" >> "$LOGFILE" 2>&1
    rc=$?
    if [ $rc -ne 0 ]; then
        log_warn "使用 --silent -responseFile 方式安装失败，尝试在安装目录执行 ./vastbase_installer --silent"
        su - "$vb_user" -c "cd '$INSTALLER_DIR' && ./vastbase_installer --silent" >> "$LOGFILE" 2>&1
        rc=$?
    fi
    if [ $rc -ne 0 ]; then
        log_error "Vastbase 静默安装失败，请检查日志: $LOGFILE"
        log_error "重点检查项: 1) db_install.rsp 是否严格为 key = value 格式且末尾无空行 2) 安装/数据目录是否为空 3) license 文件是否可读 4) 安装器是否与当前架构匹配 5) 是否在 installer 资源目录内执行"
        exit 1
    fi

    log_info "Vastbase 静默安装完成"
}


strip_managed_block() {
    local file="$1"
    local begin_tag="$2"
    local end_tag="$3"
    [ -f "$file" ] || return 0
    awk -v b="$begin_tag" -v e="$end_tag" '
    $0 ~ b {skip=1; next}
    $0 ~ e {skip=0; next}
    skip==0 {print}
    ' "$file" > "${file}.tmp" && mv -f "${file}.tmp" "$file"
}

set_or_append_conf() {
    local file="$1"
    local key="$2"
    local value="$3"
    [ -f "$file" ] || return 0
    if grep -qE "^[#[:space:]]*${key}[[:space:]]*=" "$file"; then
        sed -i "s|^[#[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
    else
        echo "${key} = ${value}" >> "$file"
    fi
}

normalize_single_node_wal_ha() {
    local conf="$1"
    [ -f "$conf" ] || return 0

    if [ -n "$archive_dir" ]; then
        set_or_append_conf "$conf" "wal_level" "archive"
        set_or_append_conf "$conf" "archive_mode" "on"
    else
        set_or_append_conf "$conf" "wal_level" "minimal"
        set_or_append_conf "$conf" "archive_mode" "off"
    fi

    # 单机场景固定关闭热备与 WAL streaming
    set_or_append_conf "$conf" "hot_standby" "off"
    set_or_append_conf "$conf" "max_wal_senders" "0"

    # 清掉脚本管理块外可能残留的重复值后，再追加一次最终值，确保文件尾部最终生效
    cat >> "$conf" <<EOF_SINGLE_NODE_FINAL

#for_vastbase_single_node_final_begin
hot_standby = off
max_wal_senders = 0
EOF_SINGLE_NODE_FINAL

    if [ -n "$archive_dir" ]; then
        cat >> "$conf" <<EOF_SINGLE_NODE_ARCH
wal_level = archive
archive_mode = on
#for_vastbase_single_node_final_end
EOF_SINGLE_NODE_ARCH
    else
        cat >> "$conf" <<EOF_SINGLE_NODE_MIN
wal_level = minimal
archive_mode = off
#for_vastbase_single_node_final_end
EOF_SINGLE_NODE_MIN
    fi
}


f2_config_wal_archive() {
    log_info "--------8. 配置 WAL / 归档日志路径--------"
    local conf="$VBDATA/postgresql.conf"
    [ -f "$conf" ] || { log_warn "未找到 postgresql.conf，跳过 WAL/归档配置"; return 0; }

    if [ -n "$wal_dir" ]; then
        local wal_link=""
        if [ -e "$VBDATA/pg_wal" ] || [ -L "$VBDATA/pg_wal" ]; then
            wal_link="$VBDATA/pg_wal"
        elif [ -e "$VBDATA/pg_xlog" ] || [ -L "$VBDATA/pg_xlog" ]; then
            wal_link="$VBDATA/pg_xlog"
        fi

        mkdir -p "$wal_dir"
        chown -R "$vb_user:$vb_user" "$wal_dir"
        chmod 700 "$wal_dir"

        if [ -n "$wal_link" ]; then
            if [ -L "$wal_link" ]; then
                rm -f "$wal_link"
                ln -sfn "$wal_dir" "$wal_link"
            else
                if [ -n "$(ls -A "$wal_link" 2>/dev/null)" ]; then
                    cp -a "$wal_link"/. "$wal_dir"/ >> "$LOGFILE" 2>&1 || true
                fi
                rm -rf "$wal_link"
                ln -s "$wal_dir" "$wal_link"
            fi
            chown -h "$vb_user:$vb_user" "$wal_link" >/dev/null 2>&1 || true
            log_info "WAL 目录已切换为: $wal_dir"
        else
            log_warn "未识别到 pg_wal/pg_xlog 目录，跳过 WAL 目录迁移"
        fi
    fi

    strip_managed_block "$conf" "^#for_vastbase_archive_begin$" "^#for_vastbase_archive_end$"
    strip_managed_block "$conf" "^#for_vastbase_single_node_final_begin$" "^#for_vastbase_single_node_final_end$"

    if [ -n "$archive_dir" ]; then
        mkdir -p "$archive_dir"
        chown -R "$vb_user:$vb_user" "$archive_dir"
        chmod 700 "$archive_dir"

        cat >> "$conf" <<EOF_ARCH
#for_vastbase_archive_begin
archive_command = 'test ! -f ${archive_dir}/%f && cp %p ${archive_dir}/%f'
archive_timeout = 300s
#for_vastbase_archive_end
EOF_ARCH
        log_info "归档日志目录已配置: $archive_dir"
    else
        log_info "未指定归档目录，按单机默认关闭 archive_mode"
    fi

    normalize_single_node_wal_ha "$conf"
    chown "$vb_user:$vb_user" "$conf"
    log_info "单机 WAL/HA 参数已归一化: hot_standby=off, max_wal_senders=0"
}

f2_post_check() {
    log_info "--------10. 安装后检查与启动验证--------"

    if [ ! -d "$VBHOME" ]; then
        log_error "软件目录不存在: $VBHOME"
        exit 1
    fi

    VASTBASE_BIN="$VBHOME/bin"
    if [ ! -x "$VASTBASE_BIN/vb_ctl" ]; then
        log_warn "未找到 vb_ctl: $VASTBASE_BIN/vb_ctl"
    fi

    if [ "${isinitdb,,}" = "true" ]; then
        if [ ! -d "$VBDATA" ]; then
            log_error "数据目录不存在: $VBDATA"
            exit 1
        fi

        su - "$vb_user" -c "source '$ENV_FILE' >/dev/null 2>&1; '$VASTBASE_BIN/vb_ctl' status -D '$VBDATA'" >> "$LOGFILE" 2>&1 || true

        if ! ss -tlnp 2>/dev/null | grep -q ":${VBPORT} "; then
            log_warn "当前未检测到端口 ${VBPORT} 监听，尝试启动数据库"
            su - "$vb_user" -c "source '$ENV_FILE' >/dev/null 2>&1; '$VASTBASE_BIN/vb_ctl' start -D '$VBDATA'" >> "$LOGFILE" 2>&1
            sleep 5
        fi

        if ss -tlnp 2>/dev/null | grep -q ":${VBPORT} "; then
            log_info "数据库监听正常: ${VBPORT}"
        else
            log_warn "未检测到 ${VBPORT} 监听，请手工检查启动日志"
        fi

        if [ -x "$VASTBASE_BIN/vsql" ]; then
            su - "$vb_user" -c "source '$ENV_FILE' >/dev/null 2>&1; '$VASTBASE_BIN/vsql' -h 127.0.0.1 -p '$VBPORT' -d postgres -U '$vb_user' -W '$VBPASSWORD' -c 'select version();'" >> "$LOGFILE" 2>&1 || true
        elif [ -x "$VASTBASE_BIN/gsql" ]; then
            log_warn "未找到 vsql，回退使用 gsql 执行连接验证"
            su - "$vb_user" -c "source '$ENV_FILE' >/dev/null 2>&1; '$VASTBASE_BIN/gsql' -h 127.0.0.1 -p '$VBPORT' -d postgres -U '$vb_user' -W '$VBPASSWORD' -c 'select version();'" >> "$LOGFILE" 2>&1 || true
        else
            log_warn "未找到 vsql/gsql，跳过数据库连接验证"
        fi
    else
        log_warn "本次为非实例化安装(isinitdb=false)，未自动进行数据库启动验证"
    fi
}

f2_create_systemd() {
    if [ "${enable_systemd,,}" != "true" ]; then
        return 0
    fi

    log_info "--------11. 创建 systemd 服务--------"

    cat > "$SERVICE_FILE" <<EOF_SERVICE
[Unit]
Description=Vastbase G100 Database Service
After=network.target

[Service]
Type=forking
User=$vb_user
Group=$vb_user
Environment=VASTBASE_HOME=$VBHOME
Environment=GAUSSHOME=$VBHOME
Environment=PGDATA=$VBDATA
Environment=PATH=$VBHOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
ExecStart=$VBHOME/bin/vb_ctl start -D $VBDATA
ExecStop=$VBHOME/bin/vb_ctl stop -D $VBDATA -m fast
ExecReload=$VBHOME/bin/vb_ctl restart -D $VBDATA -m fast
PIDFile=$VBDATA/postmaster.pid
TimeoutStartSec=120
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF_SERVICE

    systemctl daemon-reload >> "$LOGFILE" 2>&1 || true
    systemctl enable vastbase >> "$LOGFILE" 2>&1 || true
    log_info "systemd 服务已创建: vastbase.service"
}

# -------------------------------------------------------------------------
# 5. 卸载逻辑
# -------------------------------------------------------------------------
remove_vastbase_env() {
    if [ -f "$ENV_FILE" ]; then
        sed -i '/#vastbase_env_begin/,/#vastbase_env_end/d' "$ENV_FILE" || true
    fi
}

node_deconfig() {
    local confirm rm_media rm_user rm_logs rm_wal rm_archive
    echo -e "\033[01;91m [WARNING] 正在根据当前参数配置进行卸载... \033[0m"
    echo "  目标用户 : $vb_user"
    echo "  软件目录 : $VBHOME"
    echo "  数据目录 : $VBDATA"
    echo "  WAL目录  : ${wal_dir:-<未单独指定>}"
    echo "  归档目录 : ${archive_dir:-<未单独指定>}"
    echo "  介质目录 : $SOFT_DIR"
    echo "  日志文件 : $LOGFILE"
    echo ""
    read -r -p "确认开始卸载? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "取消操作。"
        return 0
    fi

    rm_media=${keep_media,,}
    rm_user=${keep_user,,}
    rm_logs=${keep_logs,,}
    rm_wal="true"
    rm_archive="true"

    read -r -p "是否删除安装介质目录 $SOFT_DIR ? [y/N]: " ans_media
    [[ "$ans_media" == "y" || "$ans_media" == "Y" ]] && rm_media=false
    read -r -p "是否删除安装用户及家目录 $vb_user ? [y/N]: " ans_user
    [[ "$ans_user" == "y" || "$ans_user" == "Y" ]] && rm_user=false
    read -r -p "是否删除日志文件 $LOGFILE ? [y/N]: " ans_logs
    [[ "$ans_logs" == "y" || "$ans_logs" == "Y" ]] && rm_logs=false
    if [ -n "$wal_dir" ]; then
        read -r -p "是否删除 WAL 目录 $wal_dir ? [y/N]: " ans_wal
        [[ "$ans_wal" == "y" || "$ans_wal" == "Y" ]] && rm_wal=false
    fi
    if [ -n "$archive_dir" ]; then
        read -r -p "是否删除归档目录 $archive_dir ? [y/N]: " ans_arc
        [[ "$ans_arc" == "y" || "$ans_arc" == "Y" ]] && rm_archive=false
    fi

    log_info "开始卸载 Vastbase 组件"

    systemctl stop vastbase >> "$LOGFILE" 2>&1 || true
    systemctl disable vastbase >> "$LOGFILE" 2>&1 || true

    if [ -x "$VBHOME/bin/vb_ctl" ] && id "$vb_user" >/dev/null 2>&1; then
        su - "$vb_user" -c "$VBHOME/bin/vb_ctl stop -D '$VBDATA' -m fast" >> "$LOGFILE" 2>&1 || true
        su - "$vb_user" -c "$VBHOME/bin/vb_ctl stop -D '$VBDATA' -m immediate" >> "$LOGFILE" 2>&1 || true
    fi

    pkill -9 -u "$vb_user" postgres >/dev/null 2>&1 || true
    pkill -9 -u "$vb_user" gaussdb >/dev/null 2>&1 || true
    pkill -9 -u "$vb_user" vb_ctl >/dev/null 2>&1 || true

    rm -f "$SERVICE_FILE"
    systemctl daemon-reload >/dev/null 2>&1 || true

    remove_vastbase_env
    rm -f "$RSP_FILE"
    rm -f "$INSTALLER_DIR/db_install.rsp" >/dev/null 2>&1 || true
    rm -f "$VBDATA/postmaster.pid" >/dev/null 2>&1 || true
    rm -f "$VBDATA/postmaster.opts" >/dev/null 2>&1 || true
    rm -f "$VBDATA/postmaster.pid.lock" >/dev/null 2>&1 || true

    rm -rf "$VBHOME" "$VBDATA"

    if [ -n "$wal_dir" ]; then
        if [ "$rm_wal" = "false" ]; then
            log_info "删除 WAL 目录: $wal_dir"
            rm -rf "$wal_dir"
        else
            log_info "按要求保留 WAL 目录: $wal_dir"
        fi
    fi

    if [ -n "$archive_dir" ]; then
        if [ "$rm_archive" = "false" ]; then
            log_info "删除归档目录: $archive_dir"
            rm -rf "$archive_dir"
        else
            log_info "按要求保留归档目录: $archive_dir"
        fi
    fi

    if [ "$rm_media" = "false" ]; then
        log_info "删除安装介质目录: $SOFT_DIR"
        rm -rf "$SOFT_DIR"
    else
        log_info "按要求保留安装介质目录: $SOFT_DIR"
    fi

    if [ "$rm_logs" = "false" ]; then
        log_info "删除日志文件: $LOGFILE"
        rm -f "$LOGFILE"
    else
        log_info "按要求保留日志文件: $LOGFILE"
    fi

    if [ "$rm_user" = "false" ]; then
        if id "$vb_user" >/dev/null 2>&1; then
            userdel -r "$vb_user" >/dev/null 2>&1 || true
        fi
        getent group "$vb_user" >/dev/null 2>&1 && groupdel "$vb_user" >/dev/null 2>&1 || true
        log_info "已删除安装用户及用户组: $vb_user"
    else
        log_info "按要求保留安装用户及家目录: $vb_user"
    fi

    sed -i "/^[[:space:]]*${server_ip}[[:space:]]\+${server}$/d" /etc/hosts >/dev/null 2>&1 || true
    echo "卸载完成。"
}

# -------------------------------------------------------------------------
# 6. 主流程控制# -------------------------------------------------------------------------
# 6. 主流程控制
# -------------------------------------------------------------------------
main_install() {
    require_root
    init_log
    detect_os
    check_os_support
    validate_params
    check_params
    calc_memory_params
    check_network || true
    find_install_media
    check_sha256_if_exists
    f1_basic_tools
    f1_os_config
    f1_prepare_user_dirs
    f1_unpack_installer
    f2_write_rsp
    f2_config_profile
    f2_install_vastbase
    f2_config_wal_archive
    f2_tune_postgresql_conf
    f2_post_check
    f2_create_systemd

    echo ""
    echo -e "\x1B[01;92m ============================================================ \x1B[0m"
    echo -e "\x1B[01;92m Vastbase G100 安装流程执行完成 \x1B[0m"
    echo -e "\x1B[01;92m ============================================================ \x1B[0m"
    echo "  安装用户 : $vb_user"
    echo "  软件目录 : $VBHOME"
    echo "  数据目录 : $VBDATA"
    echo "  监听端口 : $VBPORT"
    echo "  日志文件 : $LOGFILE"
    echo ""
    echo -e "\x1B[01;93m ========== 常用命令 ========== \x1B[0m"
    echo "  切换用户: su - $vb_user"
    echo "  启动数据库: $VBHOME/bin/vb_ctl start -D $VBDATA"
    echo "  停止数据库: $VBHOME/bin/vb_ctl stop -D $VBDATA -m fast"
    echo "  查看状态: $VBHOME/bin/vb_ctl status -D $VBDATA"
    echo "  连接数据库: $VBHOME/bin/vsql -h 127.0.0.1 -p $VBPORT -d Vastbase -U $vb_user"
    [ -n "$wal_dir" ] && echo "  WAL 目录: $wal_dir"
    [ -n "$archive_dir" ] && echo "  归档目录: $archive_dir"
    if [ "${isinitdb,,}" = "true" ]; then
        echo "  自动调优: shared_buffers=${db_shared_buffers:-N/A}, max_connections=${db_max_connections:-N/A}, max_process_memory=${db_max_process_memory:-N/A}"
    fi
    echo ""
    if [ "${enable_systemd,,}" = "true" ]; then
        echo -e "\x1B[01;96m ========== systemd ========== \x1B[0m"
        echo "  启动: systemctl start vastbase"
        echo "  停止: systemctl stop vastbase"
        echo "  状态: systemctl status vastbase"
    fi
}

# 菜单
printf "\n\x1B[01;96m ============ Vastbase G100 部署工具 v7 ============ \x1B[0m\n"
printf "  1. 开始安装 (使用传入参数)\n"
printf "  2. 卸载清理 (Uninstall)\n"
printf "  3. 退出 (Exit)\n"
printf "=============================================\n"
read -r -p "请输入选项 [1-3]: " key

case "$key" in
    1) main_install ;;
    2) require_root; init_log; node_deconfig ;;
    3) exit 0 ;;
    *) echo "无效输入" ;;
esac
