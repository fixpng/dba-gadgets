#!/bin/bash

set -e  # 遇到错误立即退出

# 本地数据库配置
ROOT_PASSWORD="root.COM2025"
SLAVE_HOST=127.0.0.1
SLAVE_PORT=3307  # 从 docker-compose.yaml 看，从库映射到 3307 端口

# 检查参数是否完整
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <master_ip> <master_port> <root_user> <root_password>"
    echo "Example: $0 192.168.1.100 3306 root root_password"
    exit 1
fi

# 参数配置
MASTER_IP="$1"
MASTER_PORT="$2"
MASTER_ROOT_USER="$3"
MASTER_ROOT_PASSWORD="$4"
REPL_USER="repl"
REPL_PASSWORD="repl.COM2025"  # 可根据需要修改

# 获取本地 IP 地址（从容器内部看到的IP，可能是 Docker 网络IP）
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then
    echo "Failed to retrieve local IP address."
    exit 1
fi
echo "Local IP address for replication: $LOCAL_IP"

# 检测 MySQL 版本（主库和从库）
echo "Detecting MySQL versions..."
MASTER_VERSION=$(mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -sN -e "SELECT VERSION();" 2>/dev/null || echo "")
SLAVE_VERSION=$(mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -sN -e "SELECT VERSION();" 2>/dev/null || echo "")

if [ -z "$MASTER_VERSION" ]; then
    echo "ERROR: Cannot connect to master MySQL server."
    exit 1
fi

if [ -z "$SLAVE_VERSION" ]; then
    echo "ERROR: Cannot connect to slave MySQL server."
    exit 1
fi

echo "Master MySQL version: $MASTER_VERSION"
echo "Slave MySQL version: $SLAVE_VERSION"

# 提取主版本号（5.7 或 8.0）
MASTER_MAJOR_VERSION=$(echo "$MASTER_VERSION" | cut -d. -f1)
MASTER_MINOR_VERSION=$(echo "$MASTER_VERSION" | cut -d. -f2)
SLAVE_MAJOR_VERSION=$(echo "$SLAVE_VERSION" | cut -d. -f1)
SLAVE_MINOR_VERSION=$(echo "$SLAVE_VERSION" | cut -d. -f2)

# 判断是否使用新语法（MySQL 8.0.23+）
USE_NEW_SYNTAX=0
if [ "$SLAVE_MAJOR_VERSION" -eq 8 ] && [ "$SLAVE_MINOR_VERSION" -ge 23 ]; then
    USE_NEW_SYNTAX=1
    echo "Using MySQL 8.0.23+ syntax (CHANGE REPLICATION SOURCE TO)"
elif [ "$SLAVE_MAJOR_VERSION" -eq 8 ] && [ "$SLAVE_MINOR_VERSION" -lt 23 ]; then
    echo "Using MySQL 8.0 (< 8.0.23) syntax (CHANGE MASTER TO)"
else
    echo "Using MySQL 5.7 syntax (CHANGE MASTER TO)"
fi

# 检查 GTID 是否启用
echo "Checking GTID status..."
MASTER_GTID_MODE=$(mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -sN -e "SELECT @@GLOBAL.gtid_mode;" 2>/dev/null || echo "OFF")
SLAVE_GTID_MODE=$(mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -sN -e "SELECT @@GLOBAL.gtid_mode;" 2>/dev/null || echo "OFF")

echo "Master GTID mode: $MASTER_GTID_MODE"
echo "Slave GTID mode: $SLAVE_GTID_MODE"

USE_GTID=0
if [ "$MASTER_GTID_MODE" != "OFF" ] && [ "$SLAVE_GTID_MODE" != "OFF" ]; then
    USE_GTID=1
    echo "GTID is enabled, will use GTID-based replication"
else
    echo "GTID is not enabled, will use binlog file/position replication"
fi

# 1. 在主库创建复制用户（分开执行以避免 GTID 一致性错误）
echo "Creating replication user on master..."
# 先删除可能存在的用户
mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "DROP USER IF EXISTS '$REPL_USER'@'$LOCAL_IP';" 2>/dev/null || true
mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "DROP USER IF EXISTS '$REPL_USER'@'%';" 2>/dev/null || true

# 创建用户（单独执行，避免 GTID 一致性错误）
mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "CREATE USER '$REPL_USER'@'$LOCAL_IP' IDENTIFIED BY '$REPL_PASSWORD';" || {
    echo "Warning: Failed to create user with specific IP, trying with wildcard..."
    mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "CREATE USER '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASSWORD';"
    REPL_HOST="%"
}

# 授予权限（单独执行）
if [ "${REPL_HOST:-$LOCAL_IP}" = "%" ]; then
    mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';"
else
    mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'$LOCAL_IP';"
    # 同时创建一个通配符用户作为备用
    mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASSWORD';" 2>/dev/null || true
    mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';" 2>/dev/null || true
fi

# 刷新权限（单独执行）
mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

echo "Replication user created successfully"

# 2. 停止从库复制（如果正在运行）
echo "Stopping existing replication if any..."
if [ "$USE_NEW_SYNTAX" -eq 1 ]; then
    mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -e "STOP REPLICA;" 2>/dev/null || true
    mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -e "RESET REPLICA ALL;" 2>/dev/null || true
else
    mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -e "STOP SLAVE;" 2>/dev/null || true
    mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -e "RESET SLAVE ALL;" 2>/dev/null || true
fi

# 3. 配置从库复制
echo "Configuring replication..."

if [ "$USE_GTID" -eq 1 ]; then
    # 使用 GTID 方式
    echo "Configuring replication using GTID..."
    if [ "$USE_NEW_SYNTAX" -eq 1 ]; then
        # MySQL 8.0.23+ 新语法
        mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" <<EOF
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='$MASTER_IP',
  SOURCE_PORT=$MASTER_PORT,
  SOURCE_USER='$REPL_USER',
  SOURCE_PASSWORD='$REPL_PASSWORD',
  SOURCE_AUTO_POSITION=1;
START REPLICA;
EOF
    else
        # MySQL 5.7 和 8.0 (< 8.0.23) 语法
        mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" <<EOF
CHANGE MASTER TO
  MASTER_HOST='$MASTER_IP',
  MASTER_PORT=$MASTER_PORT,
  MASTER_USER='$REPL_USER',
  MASTER_PASSWORD='$REPL_PASSWORD',
  MASTER_AUTO_POSITION=1;
START SLAVE;
EOF
    fi
else
    # 使用 binlog 文件/位置方式
    echo "Fetching master status..."
    MASTER_STATUS=$(mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G" 2>/dev/null)
    BINLOG_FILE=$(echo "$MASTER_STATUS" | grep -i "File:" | awk '{print $2}')
    BINLOG_POS=$(echo "$MASTER_STATUS" | grep -i "Position:" | awk '{print $2}')

    if [ -z "$BINLOG_FILE" ] || [ -z "$BINLOG_POS" ]; then
        echo "ERROR: Failed to retrieve binlog file or position from master."
        echo "Master status output:"
        echo "$MASTER_STATUS"
        exit 1
    fi

    echo "Master binlog file: $BINLOG_FILE, position: $BINLOG_POS"

    if [ "$USE_NEW_SYNTAX" -eq 1 ]; then
        # MySQL 8.0.23+ 新语法
        mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" <<EOF
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='$MASTER_IP',
  SOURCE_PORT=$MASTER_PORT,
  SOURCE_USER='$REPL_USER',
  SOURCE_PASSWORD='$REPL_PASSWORD',
  SOURCE_LOG_FILE='$BINLOG_FILE',
  SOURCE_LOG_POS=$BINLOG_POS;
START REPLICA;
EOF
    else
        # MySQL 5.7 和 8.0 (< 8.0.23) 语法
        mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" <<EOF
CHANGE MASTER TO
  MASTER_HOST='$MASTER_IP',
  MASTER_PORT=$MASTER_PORT,
  MASTER_USER='$REPL_USER',
  MASTER_PASSWORD='$REPL_PASSWORD',
  MASTER_LOG_FILE='$BINLOG_FILE',
  MASTER_LOG_POS=$BINLOG_POS;
START SLAVE;
EOF
    fi
fi

# 4. 等待一下让复制启动
sleep 2

# 5. 检查从库状态
echo ""
echo "=========================================="
echo "Checking replication status..."
echo "=========================================="

if [ "$USE_NEW_SYNTAX" -eq 1 ]; then
    mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -e "SHOW REPLICA STATUS\G" | grep -E "Replica_IO_State|Replica_IO_Running|Replica_SQL_Running|Last_IO_Error|Last_SQL_Error|Source_Host|Source_User|Replicate_Do_DB|Replicate_Ignore_DB"
else
    mysql -h "$SLAVE_HOST" -P "$SLAVE_PORT" -u root -p"$ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_State|Slave_IO_Running|Slave_SQL_Running|Last_IO_Error|Last_SQL_Error|Master_Host|Master_User|Replicate_Do_DB|Replicate_Ignore_DB"
fi

echo ""
echo "=========================================="
echo "Replication setup completed!"
echo "=========================================="
