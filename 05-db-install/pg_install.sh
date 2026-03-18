#!/bin/bash
# =========================================================================
# PostgreSQL 自动化安装脚本 v8
# 作者: 青学会会长
# =========================================================================
# 用途: PostgreSQL 12+ 源码编译安装，支持自定义 IP/端口/路径/密码
# 
# 使用方法:
#   ./pg_install.sh --ip 192.168.70.222 --hostname pg-primary --port 5433 \
#                   --password 'ComplexPass@123' --pgdata /data/pg_data \
#                   --pghome /opt/pgsql
#
# 参数说明:
#   --ip         本机IP (默认: 192.168.133.98)
#   --hostname   主机名 (默认: pg2)
#   --port       端口   (默认: 5432)
#   --password   postgres密码 (默认: postgres)
#   --pgdata     数据目录 (默认: /data/pg_data)
#   --pghome     安装目录 (默认: /opt/pgsql)
#   --ntp        NTP服务器IP (可选)
#   -h, --help   显示帮助
#
# 前置要求:
#   1. 手动创建 /soft 目录
#   2. 将 postgresql-*.tar.gz 放入 /soft/
#       mkdir -p /soft
#       cd /soft
#       wget https://ftp.postgresql.org/pub/source/v14.8/postgresql-14.8.tar.gz
#   3. 如无法联网，将 OS ISO 镜像放入 /soft/*.iso
#
# 运行后选择: 1=安装 2=卸载 3=退出
# =========================================================================

# -------------------------------------------------------------------------
# 1. 默认配置与参数解析
# -------------------------------------------------------------------------


# 设置默认值
DEFAULT_SERVER="pg2"
DEFAULT_IP="192.168.133.98"
DEFAULT_PGHOME="/opt/pgsql"
DEFAULT_PGDATA="/data/pg_data"
DEFAULT_PGPORT="5432"
DEFAULT_PGPASSWORD="postgres"
DEFAULT_NTP=""

# 初始化变量
server=$DEFAULT_SERVER
server_ip=$DEFAULT_IP
ntp_server=$DEFAULT_NTP
PGHOME=$DEFAULT_PGHOME
PGDATA=$DEFAULT_PGDATA
PGPORT=$DEFAULT_PGPORT
PGPASSWORD=$DEFAULT_PGPASSWORD

# 系统检测
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    else
        OS_ID="unknown"
        OS_VERSION="unknown"
    fi
    log_info "检测到系统: $OS_NAME ($OS_ID $OS_VERSION)"
}

# 帮助函数
usage() {
    echo -e "\x1B[01;96m Usage: $0 [OPTIONS] \x1B[0m"
    echo ""
    echo "选项说明:"
    echo "  --ip <ip>          设置本机IP地址 (默认: $DEFAULT_IP)"
    echo "  --hostname <name>  设置主机名 (默认: $DEFAULT_SERVER)"
    echo "  --ntp <ip>         设置NTP时间服务器IP (可选)"
    echo "  --pghome <path>    设置PG软件安装目录 (默认: $DEFAULT_PGHOME)"
    echo "  --pgdata <path>    设置PG数据存储目录 (默认: $DEFAULT_PGDATA)"
    echo "  --port <port>      设置PG监听端口 (默认: $DEFAULT_PGPORT)"
    echo "  --password <pwd>   设置postgres用户密码 (默认: $DEFAULT_PGPASSWORD)"
    echo "  -h, --help         显示帮助信息"
    exit 1
}

# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ip) server_ip="$2"; shift ;;
        --hostname) server="$2"; shift ;;
        --ntp) ntp_server="$2"; shift ;;
        --pghome) PGHOME="$2"; shift ;;
        --pgdata) PGDATA="$2"; shift ;;
        --port) PGPORT="$2"; shift ;;
        --password) PGPASSWORD="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "未知参数: $1"; usage ;;
    esac
    shift
done

# 衍生变量配置
postgresql_conf=$PGDATA/postgresql.conf
hba_conf=$PGDATA/pg_hba.conf
pg_backup=/pgbackup
pg_arch=$pg_backup/arch
LOGFILE=/soft/pg_install.log

# 软件查找
db_pkg=$(ls /soft/postgresql-*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$db_pkg" ]; then
    db="postgresql-14.8.tar.gz"
else
    db=$(basename "$db_pkg")
fi
dbn=$(echo $db | awk -F ".tar" '{print $1}')

# -------------------------------------------------------------------------
# 2. 基础函数定义
# -------------------------------------------------------------------------

log_info() {
    echo -e "\x1B[01;96m [INFO] $1 \x1B[0m"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

log_error() {
    echo -e "\x1B[01;91m [ERROR] $1 \x1B[0m"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >> $LOGFILE
}

check_params() {
    echo -e "\x1B[01;93m ============ 当前配置确认 ============ \x1B[0m"
    echo "  主机名 (Hostname) : $server"
    echo "  本机IP (IP Addr)  : $server_ip"
    echo "  端口 (Port)       : $PGPORT"
    echo "  安装目录 (PGHOME) : $PGHOME"
    echo "  数据目录 (PGDATA) : $PGDATA"
    echo "  用户密码          : $PGPASSWORD"
    echo "  安装包            : /soft/$db"
    echo " ======================================"
}

# --- 内存计算 ---
calc_memory_params() {
    mem_total=$(free -g | grep -E "Mem:" | awk '{print $2}')
    [ -z "$mem_total" ] && mem_total=4

    # 处理非数值情况
    if ! [[ "$mem_total" =~ ^[0-9]+$ ]]; then
        mem_total=4
    fi

    if [ $mem_total -gt 60 ]; then
        sharedbuffers=$(echo "$mem_total*0.5" | bc 2>/dev/null || echo "$mem_total/2" | awk '{print int($1)}')
        effectivecachesize=$(echo "$mem_total*0.5" | bc 2>/dev/null || echo "$mem_total/2" | awk '{print int($1)}')
    else
        sharedbuffers=$(echo "$mem_total*0.25" | bc 2>/dev/null || echo "$mem_total/4" | awk '{print int($1)}')
        effectivecachesize=$(echo "$mem_total*0.75" | bc 2>/dev/null || echo "$mem_total*3/4" | awk '{print int($1)}')
        mem_total_calc=64
    fi
    [ -z "$mem_total_calc" ] && mem_total_calc=$mem_total

    # 确保至少 128MB
    sharedbuffers_int=$(echo "$sharedbuffers" | awk '{printf "%d", $1}')
    if [ $sharedbuffers_int -lt 128 ]; then
        sharedbuffers=128
    fi

    # 确保至少 256MB
    effectivecachesize_int=$(echo "$effectivecachesize" | awk '{printf "%d", $1}')
    if [ $effectivecachesize_int -lt 256 ]; then
        effectivecachesize=256
    fi

    # 安全检查
    huge_mem=$(echo "$sharedbuffers*1024/2+200" | bc 2>/dev/null)
    [ -z "$huge_mem" ] && huge_mem=200

    shmax=$(($mem_total_calc*1024*1024*1024))
    shmall=$((($mem_total_calc*1024*1024*1024)/4096))

    # CPU 数获取
    CPUS=$(lscpu 2>/dev/null | grep -E "^CPU\(s\):|^CPU:" | head -n 1 | awk -F ' ' '{print $2}')
    [ -z "$CPUS" ] && CPUS=$(nproc 2>/dev/null || echo "4")
    [ -z "$CPUS" ] && CPUS=4
}

# --- YUM 配置 ---
f1_yum_config() {
    log_info "--------1. 安装基础系统工具--------"

    # 安装基础系统工具
    log_info "检查并安装基础系统工具..."
    if ! rpm -q coreutils &>/dev/null || ! command -v sed &>/dev/null || ! command -v expr &>/dev/null; then
        log_info "安装基础系统工具包..."
        yum install -y coreutils util-linux which sed grep gawk bc diffutils 2>/dev/null || {
            log_error "基础系统工具安装失败！"
            exit 1
        }
    fi

    # 验证关键命令
    for cmd in sed awk grep expr bc; do
        if ! command -v $cmd &>/dev/null; then
            log_error "关键命令 $cmd 不可用，请检查系统安装！"
            exit 1
        fi
    done
    log_info "基础系统工具检查通过。"

    log_info "--------2. YUM 依赖安装--------"

    # 如果已安装 readline-devel，跳过
    if rpm -q readline-devel &>/dev/null; then
        log_info "readline-devel 已安装，跳过依赖安装。"
        return 0
    fi

    # 备份原有 repo
    mkdir -p /etc/yum.repos.d/bak
    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/ 2>/dev/null

    # 检查 ISO 文件
    iso_file=$(ls /soft/*.iso 2>/dev/null | head -n1)
    if [ -z "$iso_file" ]; then
        log_error "错误：/soft/ 目录下未找到 .iso 文件！请上传操作系统 ISO 镜像。"
        exit 1
    fi

    log_info "找到ISO文件: $iso_file"

    # 检查 /mnt 是否已挂载 ISO
    if mountpoint -q /mnt 2>/dev/null; then
        current_iso=$(mount | grep "on /mnt" | awk '{print $1}')
        if [ "$current_iso" == "$iso_file" ]; then
            log_info "ISO 文件已正确挂载到 /mnt，跳过重新挂载"
        else
            log_info "检测到其他 ISO 已挂载，尝试重新挂载..."
            umount -l /mnt 2>/dev/null || umount -f /mnt 2>/dev/null || true
            sleep 1
            mkdir -p /mnt
            if ! mount "$iso_file" /mnt; then
                log_error "ISO 挂载失败！请检查文件是否损坏或被占用。"
                exit 1
            fi
            log_info "ISO 重新挂载成功"
        fi
    else
        log_info "挂载 ISO 文件到 /mnt..."
        mkdir -p /mnt
        if ! mount "$iso_file" /mnt; then
            log_error "ISO 挂载失败！请检查文件是否损坏。"
            exit 1
        fi
        log_info "ISO 挂载成功"
    fi

    # 自动检测 ISO 结构类型
    if [ -d "/mnt/BaseOS" ] && [ -d "/mnt/AppStream" ]; then
        log_info "检测到标准 RHEL8/9 ISO 结构"
        cat > /etc/yum.repos.d/local.repo <<'EOF_INNER'
[BaseOS]
name=BaseOS
baseurl=file:///mnt/BaseOS
gpgcheck=0
enabled=1
[AppStream]
name=AppStream
baseurl=file:///mnt/AppStream
gpgcheck=0
enabled=1
EOF_INNER
    elif [ -d "/mnt/Packages" ] && [ -d "/mnt/repodata" ]; then
        log_info "检测到 EL7 或 银河麒麟 V10 ISO 结构"
        cat > /etc/yum.repos.d/local.repo <<'EOF_INNER'
[local]
name=Local Repo
baseurl=file:///mnt
gpgcheck=0
enabled=1
EOF_INNER
    elif [ -d "/mnt/addons" ] && [ -d "/mnt/repodata" ]; then
        log_info "检测到 Kylin 定制 ISO 结构（addons）"
        cat > /etc/yum/repos.d/local.repo <<'EOF_INNER'
[local]
name=Local Repo
baseurl=file:///mnt
gpgcheck=0
enabled=1
EOF_INNER
    else
        log_error "不支持的 ISO 结构！请确认是完整版 DVD 镜像。"
        log_error "当前 /mnt/ 内容：$(ls /mnt/)"
        exit 1
    fi

    # 清理缓存并生成新缓存
    yum clean all >/dev/null 2>&1
    if ! yum makecache; then
        log_error "YUM 缓存生成失败！ISO 可能不完整或不匹配系统版本。"
        exit 1
    fi

    # 安装编译依赖
    log_info "正在安装编译依赖..."
    yum groupinstall -y "Development Tools" 2>/dev/null || true
    if ! yum install -y \
        readline-devel zlib-devel openssl-devel \
        gcc gcc-c++ make cmake bison flex \
        libxml2-devel libxslt-devel python3-devel \
        perl perl-ExtUtils-Embed libicu-devel; then
        log_error "依赖安装失败！"
        exit 1
    fi

    # 关键包验证
    for pkg in gcc readline-devel zlib-devel; do
        if ! rpm -q "$pkg" &>/dev/null; then
            log_error "关键依赖 $pkg 未安装成功！"
            exit 1
        fi
    done

    log_info "所有依赖安装成功。"
}

# --- 系统配置 ---
f1_os_config(){
    log_info "--------3. 系统参数配置 (Hosts, Time, Sysctl)--------"
    hostnamectl set-hostname $server
    sed -i "/$server_ip/d" /etc/hosts
    echo "$server_ip  $server" >> /etc/hosts

    timedatectl set-timezone 'Asia/Shanghai'
    if [ -n "$ntp_server" ]; then
        yum install -y chrony
        if ! grep -q "$ntp_server" /etc/chrony.conf; then
            echo "server $ntp_server iburst" >> /etc/chrony.conf
        fi
        systemctl restart chronyd
    fi

    systemctl stop firewalld 2>/dev/null
    systemctl disable firewalld 2>/dev/null
    setenforce 0 2>/dev/null
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

    # NUMA
    if ! grep -q "numa=off" /etc/default/grub; then
        sed -i '/GRUB_CMDLINE_LINUX/{s/quiet/quiet transparent_hugepage=never numa=off/}' /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
    fi

    # Sysctl
    if ! grep -q "#for_pg" /etc/sysctl.conf; then
cat >> /etc/sysctl.conf <<EOF_INNER
#for_pg
kernel.sem = 10000 10240000 10000 1024
kernel.shmall = $shmall
kernel.shmmax = $shmax
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_max = 1048576
vm.swappiness=5
vm.nr_hugepages=$huge_mem
vm.overcommit_memory=2
EOF_INNER
    fi
    sysctl -p

    # Limits
    if ! grep -q "#for_pg" /etc/security/limits.conf; then
cat >> /etc/security/limits.conf <<'EOF_INNER'
#for_pg
postgres soft nofile 1048576
postgres hard nofile 1048576
postgres soft nproc 131072
postgres hard nproc 131072
postgres soft stack 32768
postgres hard stack 32768
postgres soft core unlimited
postgres hard core unlimited
EOF_INNER
    fi

    if [ -f /etc/security/limits.d/20-nproc.conf ]; then
       echo "* - nproc 131072" >> /etc/security/limits.d/20-nproc.conf
    fi
}

# --- 用户与安装 ---
f1_install_pg(){
    log_info "--------4. 创建用户与编译安装--------"
    groupadd postgres 2>/dev/null
    id postgres &>/dev/null || useradd -g postgres postgres
    echo "$PGPASSWORD" | passwd --stdin postgres

    # 目录处理
    mkdir -p $PGHOME
    mkdir -p $PGDATA
    mkdir -p $pg_arch

    # 确保父目录权限
    chown -R postgres:postgres $PGHOME
    chown -R postgres:postgres $(dirname $PGDATA) 2>/dev/null
    chown -R postgres:postgres $PGDATA
    chown -R postgres:postgres $pg_backup
    chmod 700 $PGDATA

    # 配置 postgres 用户环境
    log_info "配置 postgres 用户环境..."
    cat > /home/postgres/.bash_profile <<'EOF_INNER'
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs
PATH=$PATH:$HOME/bin

export PATH

# 系统基础路径（确保基础命令可用）
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH
EOF_INNER

    # 环境变量（不设置 PGPORT）
    cat >> /home/postgres/.bash_profile <<EOF_INNER
export PGHOME=$PGHOME
export PGDATA=$PGDATA
export PATH=\$PGHOME/bin:\$PATH
export LD_LIBRARY_PATH=\$PGHOME/lib:\$LD_LIBRARY_PATH
export LANG="en_US.UTF-8"
EOF_INNER

    # 解压编译
    cd /soft
    rm -rf "$dbn"
    tar xf $db 2>/dev/null
    if [ ! -d "/soft/$dbn" ]; then
        log_error "解压 毕败，请检查 $db 是否存在"
        exit 1
    fi
    chown -R postgres:postgres /soft/$dbn

    # 编译
    log_info "开始编译..."
    su - postgres -c "export PATH=/usr/bin:/bin:/usr/sbin:/sbin:\$PATH; export PGHOME=$PGHOME; cd /soft/$dbn; ./configure --prefix=\$PGHOME && make -j 4 && make install"
    
    if [ $? -eq 0 ]; then
        # contrib 目录编译
        if [ -d "/soft/$dbn/contrib" ]; then
            log_info "编译 contrib 目录..."
            su - postgres -c "export PATH=/usr/bin:/bin:/usr/sbin:/sbin:\$PATH; export PGHOME=$PGHOME; cd /soft/$dbn/contrib; make -j 4 && make install"
        else
            log_info "contrib 目录不存在，跳过 contrib 编译"
        fi
    else
        log_error "编译失败！"
        exit 1
    fi
}

# --- 初始化与配置 ---
f2_db_config(){
    log_info "--------5. 初始化数据库与配置--------"
    su - postgres -c "echo \"$PGPASSWORD\" > ~/.pgpass"
    chmod 0600 /home/postgres/.pgpass

    # 清空数据目录（如果存在）
    if [ -n "$(ls -A $PGDATA)" ]; then
        log_info "清理已存在的数据目录..."
        rm -rf $PGDATA/*
    fi

    # 初始化数据库
    log_info "初始化数据库集群..."
    su - postgres -c "export PGPORT=$PGPORT; export PGHOME=$PGHOME; $PGHOME/bin/initdb --username=postgres --pwfile=/home/postgres/.pgpass -D $PGDATA -E UTF8 --locale C"

    if [ $? -ne 0 ]; then
        log_error "数据库初始化失败！"
        exit 1
    fi

    # 验证配置文件存在
    if [ ! -f "$postgresql_conf" ] || [ ! -f "$hba_conf" ]; then
        log_error "配置文件生成失败！"
        exit 1
    fi

    # 备份原配置文件
    cp $postgresql_conf ${postgresql_conf}.bak.$(date +%Y%m%d_%H%M%S)

    # 修改监听地址和端口
    log_info "修改 postgresql.conf..."
    
    # 删除所有相关配置（包括注释行）
    sed -i '/^#listen_addresses/d' $postgresql_conf
    sed -i '/^listen_addresses/d' $postgresql_conf
    sed -i '/^#port/d' $postgresql_conf
    sed -i '/^port/d' $postgresql_conf
    
    # 追加正确的配置
    cat >> $postgresql_conf <<EOF_INNER

# ==================== 监听配置 ====================
listen_addresses = '*'
port = $PGPORT

# ==================== 内存参数 ====================
EOF_INNER
    
    # 使用固定的合理值
    shared_buffers_mb=128
    effective_cache_size_mb=256
    
    log_info "配置内存参数: shared_buffers=${shared_buffers_mb}MB, effective_cache_size=${effective_cache_size_mb}MB"
    
    # 追加内存参数
    cat >> $postgresql_conf <<EOF_INNER
shared_buffers = ${shared_buffers_mb}MB
effective_cache_size = ${effective_cache_size_mb}MB
EOF_INNER
    
    # 并行查询配置
    cat >> $postgresql_conf <<EOF_INNER
max_parallel_workers_per_gather = ${CPUS}
max_parallel_workers = ${CPUS}
EOF_INNER
    
    # 🔧 修复：使用符合要求的 WAL 参数（至少 32MB）
    min_wal_size_mb=64
    max_wal_size_mb=256
    
    log_info "配置 WAL 参数: min_wal_size=${min_wal_size_mb}MB, max_wal_size=${max_wal_size_mb}MB"
    
    # 追加优化参数
    cat >> $postgresql_conf <<EOF_INNER

# ==================== 日志配置 ====================
logging_collector = on
log_directory = 'log'
log_destination = 'csvlog'

# ==================== 归档配置 ====================
archive_mode = on
archive_command = 'test ! -f $pg_arch/%f && cp %p $pg_arch/%f'

# ==================== WAL 配置 ====================
min_wal_size = ${min_wal_size_mb}MB
max_wal_size = ${max_wal_size_mb}MB
EOF_INNER

    # 重写 pg_hba.conf
    log_info "配置 pg_hba.conf..."
    cp $hba_conf ${hba_conf}.bak.$(date +%Y%m%d_%H%M%S)
    cat > $hba_conf <<'EOF_INNER'
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local (socket) connections:
local   all             all                                     peer

# IPv4 local connections:
host    all             all             127.0.0.1/32            trust

# IPv4 remote connections:
host    all             all             0.0.0.0/0               md5

# IPv6 local connections:
host    all             all             ::1/128                 trust

# IPv6 remote connections:
host    all             all             ::/0                    md5

# Replication connections:
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
host    replication     all             0.0.0.0/0               md5
host    replication     all             ::/0                    md5
EOF_INNER

    # 确保日志目录存在并设置正确权限
    log_info "创建日志目录并设置权限..."
    mkdir -p $PGDATA/log
    chown -R postgres:postgres $PGDATA/log
    chmod 700 $PGDATA/log
    
    # 验证配置文件内容
    log_info "验证配置文件..."
    echo "=== listen_addresses ==="
    grep "^listen_addresses" $postgresql_conf
    echo "=== port ==="
    grep "^port" $postgresql_conf
    echo "=== shared_buffers ==="
    grep "^shared_buffers" $postgresql_conf
    echo "=== min_wal_size ==="
    grep "^min_wal_size" $postgresql_conf
    echo "=== max_wal_size ==="
    grep "^max_wal_size" $postgresql_conf
}

# --- 启动服务（手动启动方式）---
f2_startup(){
    log_info "--------6. 手动启动 PostgreSQL--------"
    log_info "当前系统: $OS_NAME ($OS_ID $OS_VERSION)"

    # 验证关键文件和目录
    log_info "验证 PostgreSQL 环境..."
    if [ ! -d "$PGDATA" ]; then
        log_error "PGDATA 目录不存在: $PGDATA"
        exit 1
    fi
    if [ ! -f "$PGHOME/bin/pg_ctl" ]; then
        log_error "pg_ctl 可执行文件不存在: $PGHOME/bin/pg_ctl"
        exit 1
    fi

    # 确保日志目录存在
    mkdir -p $PGDATA/log
    chown -R postgres:postgres $PGDATA/log

    # 在 root 下清理残留文件
    log_info "清理残留文件..."
    pkill -9 postgres 2>/dev/null || true
    sleep 2
    rm -f /tmp/.s.PGSQL.${PGPORT}*
    rm -f /tmp/.s.PGSQL.${PGPORT}.lock
    rm -f /var/run/postgresql/.s.PGSQL.${PGPORT}*
    rm -f $PGDATA/postmaster.pid

    # 确保 /tmp 权限正确
    log_info "检查 /tmp 权限..."
    chmod 1777 /tmp
    ls -ld /tmp

    # 确保数据目录权限正确
    log_info "检查数据目录权限..."
    chown -R postgres:postgres $PGDATA
    chmod 700 $PGDATA
    ls -ld $PGDATA

    # 直接手动启动
    log_info "启动 PostgreSQL（手动方式）..."
    su - postgres -c "export PGPORT=$PGPORT; export PGDATA=$PGDATA; export PGHOME=$PGHOME; export PATH=/usr/bin:/bin:\$PATH; $PGHOME/bin/pg_ctl start -D $PGDATA -l $PGDATA/log/postgresql.log -o '-p $PGPORT'" 2>&1

    if [ $? -eq 0 ]; then
        sleep 5
        
        # 验证监听状态
        log_info "验证监听状态..."
        netstat -tlnp | grep $PGPORT || ss -tlnp | grep $PGPORT
        
        # 测试连接
        log_info "测试本地连接（Unix socket）..."
        su - postgres -c "psql -U postgres -c 'SELECT version();'" 2>&1
        
        log_info "测试本地连接（127.0.0.1:$PGPORT）..."
        su - postgres -c "psql -h 127.0.0.1 -p $PGPORT -U postgres -c 'SELECT version();'" 2>&1
        
        log_info "测试连接（$server_ip:$PGPORT）..."
        su - postgres -c "psql -h $server_ip -p $PGPORT -U postgres -c 'SELECT version();'" 2>&1
        
        log_info "============================================================"
        log_info "PostgreSQL 安装成功！"
        log_info "============================================================"
        echo ""
        echo -e "\x1B[01;93m ========== 连接信息 ========== \x1B[0m"
        echo "  软件目录: $PGHOME"
        echo "  数据目录: $PGDATA"
        echo "  监听端口: $PGPORT"
        echo "  IP 地址: $server_ip"
        echo ""
        echo -e "\x1B[01;92m ========== 启动命令 ========== \x1B[0m"
        echo "  启动: su - postgres -c \"$PGHOME/bin/pg_ctl start -D $PGDATA -l \$PGDATA/log/postgresql.log -o '-p $PGPORT'\""
        echo "  停止: su - postgres -c \"$PGHOME/bin/pg_ctl stop -D $PGDATA\""
        echo "  状态: su - postgres -c \"$PGHOME/bin/pg_ctl status -D $PGDATA\""
        echo ""
        echo -e "\x1B[01;92m ========== 连接命令 ========== \x1B[0m"
        echo "  本地: psql -h 127.0.0.1 -p $PGPORT -U postgres"
        echo "  远程: psql -h $server_ip -p $PGPORT -U postgres"
        echo "  主机名: psql -h $server -p $PGPORT -U postgres"
        echo ""
        echo -e "\x1B[01;96m ========== 下一步操作 ========== \x1B[0m"
        echo "  1. 切换到 postgres 用户: su - postgres"
        echo "  2. 启动 PostgreSQL: pg_ctl start -D \$PGDATA -l \$PGDATA/log/postgresql.log -o '-p $PGPORT'"
        echo "  3. 连接数据库: psql -h $server_ip -p $PGPORT -U postgres"
        echo "============================================================"
        echo ""
        echo -e "\x1B[01;93m 切换到 postgres 用户：\x1B[0m"
        echo "  su - postgres"
        echo ""
        echo -e "\x1B[01;93m 然后执行启动命令：\x1B[0m"
        echo "  pg_ctl start -D \$PGDATA -l \$PGDATA/log/postgresql.log -o '-p $PGPORT'"
        
    else
        log_error "PostgreSQL 启动失败！"
        log_error "请检查以下信息："
        log_error "  1. 查看 PG 日志: tail -f $PGDATA/log/postgresql.log"
        log_error "  2. 检查端口占用: netstat -tlnp | grep $PGPORT"
        log_error "  3. 检查配置: $PGHOME/bin/pg_ctl status -D $PGDATA"
        
        # 显示最近的错误日志
        if [ -f "$PGDATA/log/postgresql.log" ]; then
            log_error "========= 最近错误日志 ========="
            tail -n 30 $PGDATA/log/postgresql.log
            log_error "=============================="
        fi
        exit 1
    fi
}

# --- 卸载逻辑 ---
node_deconfig(){
    echo -e "\x1B[01;91m [WARNING] 正在根据当前参数配置进行卸载... \x1B[0m"
    echo "  目标 PGHOME: $PGHOME"
    echo "  目标 PGDATA: $PGDATA"
    read -p "确认删除以上目录及用户吗? [y/N]: " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        su - postgres -c "$PGHOME/bin/pg_ctl stop -D $PGDATA" 2>/dev/null || true
        pkill -9 postgres 2>/dev/null
        rm -rf $PGHOME
        rm -rf $PGDATA
        rm -rf /pgbackup
        rm -rf /soft/$dbn
        userdel -r postgres 2>/dev/null
        echo "卸载完成。"
    else
        echo "取消操作。"
    fi
}

# -------------------------------------------------------------------------
# 3. 主流程控制
# -------------------------------------------------------------------------

main_install(){
    detect_os
    check_params
    calc_memory_params
    f1_yum_config
    f1_os_config
    f1_install_pg
    f2_db_config
    f2_startup
}

# 菜单
echo -e "\n\x1B[01;96m ============ PostgreSQL 部署工具 ============ \x1B[0m"
echo -e "  1. 开始安装 (使用传入参数)"
echo -e "  2. 卸载清理 (Uninstall)"
echo -e "  3. 退出 (Exit)"
echo -e "============================================="
read -p "请输入选项 [1-3]: " key

case $key in
    1) main_install ;;
    2) node_deconfig ;;
    3) exit 0 ;;
    *) echo "无效输入" ;;
esac