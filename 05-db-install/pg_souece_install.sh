#!/bin/bash
# 【脚本说明】
# 源码，支持PG各种版本
# 1、下载PG源码安装包后上传到/opt目录下
# 2、ISO系统镜像需要挂载，后期用于YUM
# 3、MY_SERVER_IP、MY_HOSTNAME根据自己环境修改
# 4、PG_VERSION为版本号，如果其他版本请更改
# 直接执行脚本，自动化安装，本脚本适用于Linux7,其他操作系统可能涉及yum的配置不同，请自行修改
#==============================================================#
# 脚本名     :   pg_souece_install.sh
# 创建时间   :   2024-03-08 22:00:00
# 更新时间   :   2024-03-09 23:00:00
# 描述      :    PostgreSQL数据库源码一键安装脚本（单机）
# Linux系统 :    Liunx7
# PG版本    :    14.11
# 脚本路径   :   /opt
# 版本      :   2.0.0
# 作者      :   王丁丁，公众号:IT邦德，PostgreSQL ACE Partner
# 说明      :   其他版本替换相应的源码包即可
#==============================================================#
#==============================================================#
#                         基础参数                              #
#==============================================================#
##需要设置的参数
#本机服务器IP
export MY_SERVER_IP=192.168.3.20
#本机服务器主机名
export MY_HOSTNAME=pgpcp
#PostgreSQL相关RPM包上传根目录
export MY_SOFT_BASE=/opt
#PG源码包
export PG_SOFT=postgresql-14.11.tar.gz
#PG版本
export PG_VERSION=14.11
## ISO系统镜像存放目录
export MY_DIRECTORY_ISO=/opt
##PG源码包存放的目录
export MY_DIRECTORY_SOFT=$MY_SOFT_BASE
##PG脚本存放的目录
export MY_DIRECTORY_SCRIPT=$MY_SOFT_BASE
#==============================================================#
#           PG安装相关配置                                       #
#==============================================================#
#PG根目录
export MY_PG_HOME=/pgccc
#PG数据目录
export PGDATA=$MY_PG_HOME/pgdata
#PG家目录
export PGHOME=/pgccc/pgsql
##PG源码编译目录
export MY_PG_COMPILE=/pgccc/soft/postgresql-$PG_VERSION
##判断安装包是否上传
if [ -f $MY_DIRECTORY_SOFT/$PG_SOFT ]; then 
    echo "PG Source Soft Already Upload"
else
    echo "Please Upload PG Source Soft First"
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
## 2.3 安装PG依赖
yum install -y openssl openssl-devel pam pam-devel libxml2 libxml2-devel \
libxslt libxslt-devel perl perl-devel python-devel perl-ExtUtils-Embed \
readline readline-devel bzip2 zlib zlib-devel ntp ntpdate \
gettext gettext-devel bison flex gcc gcc-c++ libicu-devel \
boost-devel gmp* mpfr* libevent* libpython3.6m >/dev/null 2>&1
echo "2.3 Install PG dependency Completed."
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
if id -u postgres >/dev/null 2>&1; then
    echo "postgres User Exists."
else
    groupadd -g 70000 postgres  >/dev/null 2>&1
    useradd -u 70000 -g postgres postgres >/dev/null 2>&1
    echo postgres | passwd --stdin postgres  >/dev/null 2>&1
    echo "User postgres Created Completed."
fi
echo "2.6 Establish users and groups Completed."
## 2.7 创建相关目录
mkdir -p $MY_PG_HOME/{pgdata,archive,scripts,backup,pgsql,soft}
chown -R postgres:postgres $MY_PG_HOME
chmod -R 775 $MY_PG_HOME
echo "2.7 PG Directories Created Completed."
## 2.8 修改postgres用户环境变量
echo 'export PS1="[\u@\h \W]\$"'  >> /home/postgres/.bash_profile
su - postgres -c "
cat >> /home/postgres/.bash_profile <<EOF
export LANG=en_US.UTF-8
export PGPORT=5432
export PGDATA=$PGDATA
export PGHOME=$PGHOME
export PATH=$PGHOME/bin:$PATH:.
export PGUSER=postgres
export PGDATABASE=postgres
EOF
"
source /home/postgres/.bash_profile >/dev/null 2>&1
echo "2.8 Configure postgres Env Completed."
#==============================================================#
#           3.PG数据库安装工作                                    #
#==============================================================#
## 3.1 解压数据库软件
echo "3.1 Start Unzip PG Software."
cp $MY_DIRECTORY_SOFT/$PG_SOFT $MY_PG_HOME/soft
cd $MY_PG_HOME/soft
tar -zxvf $MY_PG_HOME/soft/$PG_SOFT
chown -R postgres:postgres $MY_PG_HOME/soft
chmod 755 -R $MY_PG_HOME/soft
echo "3.1 Unzip PG Software Completed."
## 3.2 PG编译安装
su - postgres -c "$MY_PG_COMPILE/configure --prefix=$PGHOME --without-readline" >/dev/null 2>&1
cd $MY_PG_COMPILE
su - postgres -c "make -j 4 && make install" >/dev/null 2>&1
su - postgres -c "$PGHOME/bin/initdb -D $PGDATA -E UTF8 --locale=en_US.utf8 -U postgres" >/dev/null 2>&1
echo "3.2 PG Compile Installation."
## 3.3 配置数据库参数
su - postgres -c "
cat >> $PGDATA/postgresql.conf <<EOF
listen_addresses = '*'
port=5432
logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%a.log'
log_truncate_on_rotation = on
EOF
"
echo "postgresql.conf successfully"
su - postgres -c "
cat > $PGDATA/pg_hba.conf << EOF
# TYPE  DATABASE    USER    ADDRESS       METHOD
local     all       all                    trust
host      all       all   127.0.0.1/32     trust
host      all       all    0.0.0.0/0      md5
host   replication  all    0.0.0.0/0      md5
local  replication  all                    trust
EOF
"
echo "pg_hba.conf successfully"
systemctl start ntpd  >/dev/null 2>&1 
systemctl enable ntpd  >/dev/null 2>&1
echo "3.3 Configure database parameters successfully"