#!/bin/bash
# 【脚本说明】
# 二进制安装
# 1、下载MySQL二进制安装包后上传到/opt目录下
# 2、ISO系统镜像需要挂载，后期用于YUM
# 3、脚本中最后修了root密码为：Jeames@007
# 4、脚本中配置了二进制自启动数据库到服务
# 直接执行脚本，自动化安装，本脚本适用于Linux7,其他操作系统可能涉及yum的配置不同，请自行修改
#==============================================================#
# 脚本名     :   mysql_generic_install.sh
# 创建时间   :   2024-03-08 22:00:00
# 更新时间   :   2025-02-10 10:00:00
# 描述      :    MySQL数据库二进制一键安装脚本（单机）
# Linux系统 :    Liunx7
# MySQL版本 :    8.0.27
# 脚本路径   :   /opt
# 版本      :   3.0.0
# 作者      :   公众号:IT邦德，Oracle ACE
# 说明      :   其他版本替换相应的二进制包即可
#==============================================================#
#==============================================================#
#                         基础参数                              #
#==============================================================#
##需要设置的参数
#本机服务器IP
export MY_SERVER_IP=192.168.3.10
#本机服务器主机名
export MY_HOSTNAME=mysql
#MySQL相关RPM包上传根目录
export MY_SOFT_BASE=/opt
#MySQL二进制包
export MY_HOME=/mysql
export MY_SOFT=mysql-8.0.27-linux-glibc2.12-x86_64.tar.xz
## ISO系统镜像存放目录
export MY_DIRECTORY_ISO=/opt
##MySQL二进制包存放的目录
export MY_DIRECTORY_SOFT=$MY_SOFT_BASE
##MySQL脚本存放的目录
export MY_DIRECTORY_SCRIPT=$MY_SOFT_BASE
##判断安装包是否上传
if [ -f $MY_DIRECTORY_SOFT/$MY_SOFT ]; then 
    echo "MySQL GENERIC Soft Already Upload"
else
    echo "Please Upload MySQL GENERIC Soft First"
    exit
fi
#==============================================================#
#                        挂载光驱                               #
#==============================================================#
## 1.将ISO系统镜像上传到系统
## 2.将数据库软件上传到系统
## 确认是否有光驱设备
echo " "
MY_ISO=`mount | grep iso9660`
if [ ! -n "$MY_ISO" ];then
    echo "Please Mount A CD ISO Image First"
    exit
else
    mount /dev/cdrom /mnt/ >/dev/null 2>&1
    echo "Mount A CD ISO Image Already"
fi
#==============================================================#
#           1.本地yum配置                                       #
#==============================================================#
mkdir -p /tmp/confbak/yumbak/
mv /etc/yum.repos.d/*  /tmp/confbak/yumbak/  >/dev/null 2>&1
## 确认操作系统的版本，配置yum
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Distribution: $ID"
    echo "Version: $VERSION_ID"
    if [ "$ID" = "8" ];then
        echo "[localREPO]" >> /etc/yum.repos.d/my.repo
        echo "name=localhost8" >> /etc/yum.repos.d/my.repo
        echo "baseurl=file:///mnt/BaseOS" >> /etc/yum.repos.d/my.repo
        echo "gpgcheck=0" >> /etc/yum.repos.d/my.repo
        echo "enabled=1" >> /etc/yum.repos.d/my.repo

        echo "[localREPO_APP]" >> /etc/yum.repos.d/my.repo
        echo "name=localhost8_app" >> /etc/yum.repos.d/my.repo
        echo "baseurl=file:///mnt/AppStream" >> /etc/yum.repos.d/my.repo
        echo "gpgcheck=0" >> /etc/yum.repos.d/my.repo
        echo "enabled=1" >> /etc/yum.repos.d/my.repo
    else
        echo "[Oracle]" >> /etc/yum.repos.d/my.repo
        echo "name=oracle_install" >> /etc/yum.repos.d/my.repo
        echo "baseurl=file:///mnt/" >> /etc/yum.repos.d/my.repo
        echo "gpgcheck=0" >> /etc/yum.repos.d/my.repo
        echo "enabled=1" >> /etc/yum.repos.d/my.repo
    fi
else
    echo "No OS Release file found."
fi
yum -y install bc  >/dev/null 2>&1
echo "1 Configure yum Completed."
#==============================================================#
#           2.安装前准备工作                                     #
#==============================================================#
## 2.1 设置主机名
hostnamectl set-hostname $MY_HOSTNAME
sed -i '/^HOSTNAME=/d' /etc/sysconfig/network
echo "HOSTNAME=$MY_HOSTNAME" >> /etc/sysconfig/network
echo "2.1 Configure hostname completed."
## 2.2 修改hosts
cp /etc/hosts /tmp/confbak
cat >> /etc/hosts <<EOF
$MY_SERVER_IP $MY_HOSTNAME
EOF
echo "2.2 Configure Hosts Completed."
## 2.3 安装MySQL依赖
yum -y install ntp ncurses ncurses-devel openssl-devel bison gcc gcc-c++ make >/dev/null 2>&1
echo "2.3 Install MySQL dependency Completed."
## 2.4 关闭防火墙
systemctl stop firewalld.service  >/dev/null 2>&1
systemctl disable firewalld.service  >/dev/null 2>&1 
systemctl status firewalld.service  >/dev/null 2>&1
echo "2.4 Disable Firewalld Service Completed."
## 2.5 关闭SELinux
sed -i '/^SELINUX=/d' /etc/selinux/config
echo "SELINUX=disabled" >> /etc/selinux/config
# cat /etc/selinux/config|grep "SELINUX=disabled"
setenforce 0 >/dev/null 2>&1
echo "2.5 close SELinux completed."
## 2.6 建立用户和组
if id -u mysql >/dev/null 2>&1; then
    echo "mysql User Exists."
else
    groupadd -g 60000 mysql  >/dev/null 2>&1
    useradd -u 60000 -g mysql mysql >/dev/null 2>&1
    echo mysql | passwd --stdin mysql  >/dev/null 2>&1
    echo "2.6 User mysql Created Completed."
fi
echo "2.6 Establish users and groups Completed."
## 2.7 创建相关目录
mkdir -p $MY_HOME/{app,conf}
mkdir -p $MY_HOME/data/mysql3306/{pid,socket,log,binlog,errlog,relaylog,slowlog,tmp}
chown -R mysql:mysql $MY_HOME
chmod -R 775 $MY_HOME
echo "2.7 MySQL Directories Created Completed."
## 2.8 修改MySQL用户环境变量
echo 'export PS1="[\u@\h \W]\$"'  >> /home/mysql/.bash_profile

cat >> /home/mysql/.bash_profile <<EOF
export MYSQL_HOME=$MY_HOME/app/mysql
export PATH=$PATH:$HOME/.local/bin:$HOME/bin:$MY_HOME/app/mysql/bin
EOF

source /home/mysql/.bash_profile > /dev/null

echo "2.8 Configure MySQL Env Completed."
#==============================================================#
#           3.MySQL数据库安装工作                                    #
#==============================================================#
## 3.1 解压数据库软件
echo "3.1 Start Unzip MySQL Software."
cp $MY_DIRECTORY_SOFT/$MY_SOFT $MY_HOME/app
cd $MY_HOME/app
tar xvf $MY_HOME/app/$MY_SOFT
mv ${MY_SOFT/%.tar.xz/} mysql
chown -R mysql:mysql $MY_HOME/app
chmod 755 -R $MY_HOME/app
echo "3.1 Unzip MySQL Software Completed."
## 3.2 配置数据库参数
su - mysql -c "
cat >> $MY_HOME/conf/mysql.cnf <<EOF
[mysqld]
server_id = 803306
default-storage-engine= InnoDB
socket=/tmp/mysql.sock
basedir=$MY_HOME/app/mysql
datadir=$MY_HOME/data/mysql3306/data/
log-error=$MY_HOME/data/mysql3306/log/mysqld.log
pid-file=$MY_HOME/data/mysql3306/pid/mysqld.pid
port=3306
default_authentication_plugin=mysql_native_password
transaction_isolation=READ-COMMITTED
max_connections=1500
back_log=500
wait_timeout=1800
max_user_connections=800
innodb_buffer_pool_size=1024M
innodb_log_file_size=512M
innodb_log_buffer_size=40M
slow_query_log=ON
long_query_time=5
# log settings #
slow_query_log = ON
slow_query_log_file = $MY_HOME/data/mysql3306/slowlog/slow3306.log
log_error = $MY_HOME/data/mysql3306/errlog/err3306.log
log_error_verbosity = 3
log_bin = $MY_HOME/data/mysql3306/binlog/mysql_bin
log_bin_index = $MY_HOME/data/mysql3306/binlog/mysql_binlog.index
general_log_file = $MY_HOME/mysql/mysql3306/generallog/general.log
log_queries_not_using_indexes = 1
log_slow_admin_statements = 1
expire_logs_days = 90
binlog_expire_logs_seconds = 2592000
long_query_time = 2
min_examined_row_limit = 100
log_throttle_queries_not_using_indexes = 1000
innodb_flush_log_at_trx_commit=1
EOF
"
echo "3.2 mysql.cnf successfully"
## 3.3 MySQL二进制安装
su - mysql -c "mysqld --defaults-file=$MY_HOME/conf/mysql.cnf --initialize --user=mysql --basedir=$MY_HOME/app/mysql --datadir=$MY_HOME/data/mysql3306/data/
" >/dev/null 2>&1

rm -rf /etc/systemd/system/mysql.service
systemctl daemon-reload

cat > /etc/systemd/system/mysql.service <<EOF
[Unit]
Description=MySQL Server
After=network.target
[Service]
#二进制启动mysqld的命令
ExecStart=$MY_HOME/app/mysql/bin/mysqld_safe --defaults-file=$MY_HOME/conf/mysql.cnf  
ExecStop=$MY_HOME/app/mysql/bin/mysqladmin -u root -p shutdown
User=mysql
Group=mysql
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mysql.service
systemctl start mysql.service

echo "3.3 MySQL Compile Installation."
systemctl start ntpd  >/dev/null 2>&1 
systemctl enable ntpd  >/dev/null 2>&1

## 3.4 修改密码
Pass=$(grep 'A temporary password' $MY_HOME/data/mysql3306/errlog/err3306.log |awk '{print $NF}')
echo -e "mysql default passwd is: ${Pass}"
# 修改密码，请执行以下语句
echo -e "alter user root@'localhost' identified with mysql_native_password by 'root';"
echo "Configure database parameters successfully"