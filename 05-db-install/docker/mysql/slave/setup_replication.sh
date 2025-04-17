#!/bin/bash

# 本地数据库配置
ROOT_PASSWORD="root.COM2025"
SLAVE_HOST=3306

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

# 获取本地 IP 地址
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then
    echo "Failed to retrieve local IP address."
    exit 1
fi
echo "Local IP address for replication: $LOCAL_IP"

# 1. 在主库创建复制用户并限制为本地 IP
echo "Creating replication user on master with IP restriction..."
mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "
CREATE USER IF NOT EXISTS '$REPL_USER'@'$LOCAL_IP' IDENTIFIED BY '$REPL_PASSWORD';
GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'$LOCAL_IP';
FLUSH PRIVILEGES;
"

# 2. 获取主库的 binlog 文件和位置
echo "Fetching master status..."
MASTER_STATUS=$(mysql -h "$MASTER_IP" -P "$MASTER_PORT" -u "$MASTER_ROOT_USER" -p"$MASTER_ROOT_PASSWORD" -e "SHOW MASTER STATUS\G")
BINLOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
BINLOG_POS=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')

if [ -z "$BINLOG_FILE" ] || [ -z "$BINLOG_POS" ]; then
    echo "Failed to retrieve binlog file or position from master."
    exit 1
fi

echo "Master binlog file: $BINLOG_FILE, position: $BINLOG_POS"

# 3. 在从库配置主从复制信息并启动复制
echo "Configuring slave to connect to master..."
mysql -h $LOCAL_IP -P $SLAVE_HOST -u root -p"$ROOT_PASSWORD" -e "
CHANGE MASTER TO
  MASTER_HOST='$MASTER_IP',
  MASTER_PORT=$MASTER_PORT,
  MASTER_USER='$REPL_USER',
  MASTER_PASSWORD='$REPL_PASSWORD',
  MASTER_LOG_FILE='$BINLOG_FILE',
  MASTER_LOG_POS=$BINLOG_POS;
START SLAVE;
"

# 4. 检查从库状态
echo "Checking slave status..."
mysql -h $LOCAL_IP -P $SLAVE_HOST -u root -p"$ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_State|Slave_IO_Running|Slave_SQL_Running|Last_IO_Error|Last_SQL_Error"
