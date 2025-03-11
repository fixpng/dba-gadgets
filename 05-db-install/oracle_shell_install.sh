#!/bin/bash
# 【脚本说明】
# 静默，单机版，支持容器创建
# 1、下载19C安装包LINUX.X64_193000_db_home.zip后上传到/opt目录下
# 2、ISO系统镜像需要挂载，后期用于YUM
# 3、MY_SERVER_IP、MY_HOSTNAME根据自己环境修改
# 4、MY_ORA_SID为实例名、MY_ORA_MEMORY为分配到内存大小，根据实际情况修改
# 5、createAsContainerDatabase=TRUE表示容器数据库，改为false后就是非容器
# 直接执行脚本，自动化安装，本脚本适用于Linux7,其他操作系统可能涉及yum的配置不同，请自行修改
#==============================================================#
# 脚本名     :   oracle_shell_install.sh
# 创建时间   :   2023-06-13 10:02:09
# 更新时间   :   2025-02-10 10:02:09
# 描述      :    Oracle19C数据库一键安装脚本（单机CDB\NO-CDB）
# 路径      :   /soft/oracle_shell_install
# 版本      :   2.0.0
# 作者      :   王丁丁 公众号：IT邦德
#==============================================================#
#==============================================================#
#                         基础参数                              #
#==============================================================#
##需要设置的参数
#本机服务器IP
export MY_SERVER_IP=192.168.6.5
#本机服务器主机名
export MY_HOSTNAME=dbhost
#ORACLE软件上传根目录
export MY_SOFT_BASE=/opt
#ORACLE软件名
export MY_ORA_SOFT1=LINUX.X64_193000_db_home.zip
## ISO系统镜像存放目录
export MY_DIRECTORY_ISO=/opt
##ORACLE软件存放的目录
export MY_DIRECTORY_SOFT=$MY_SOFT_BASE
##ORACLE脚本存放的目录
export MY_DIRECTORY_SCRIPT=$MY_SOFT_BASE
#==============================================================#
#                         软件准备                              #
#==============================================================#
## 1.将ISO系统镜像上传到系统
## 2.将数据库软件上传到系统
#if [ ! -d /opt/iso ]; then 
#创建镜像目录
#mkdir /opt/iso
#fi
##确认是否有光驱设备
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
#           Oracle软件安装相关配置                              #
#==============================================================#

#ORACLE软件安装根目录
export MY_DIR=/u01
##ORACLE BASE目录
export MY_ORA_BASE=$MY_DIR/app/oracle
##ORACLE HOME目录
export MY_ORA_HOME=$MY_ORA_BASE/product/19.3.0/dbhome_1
##ORACLE INVENTORY目录
export MY_INVENTORY_LOC=$MY_DIR/app/oraInventory
#ORACLE SID变量
export MY_ORA_SID=orcl
#ORACLE SYS密码
export MY_ORA_PASSWD=oracle
#数据分配的内存
export MY_ORA_MEMORY=1500
##数据文件存放目录
export MY_ORA_DATA=$MY_ORA_BASE/oradata
##判断ORACLE软件是否上传
if [ -f $MY_DIRECTORY_SOFT/$MY_ORA_SOFT1 ]; then 
    echo "Oracle Software Already Upload"
else
    echo "Please Upload Oracle Software First"
    exit
fi
#==============================================================#
#           本地yum配置                                         #
#==============================================================#
mkdir -p /tmp/confbak/yumbak/
mv /etc/yum.repos.d/*  /tmp/confbak/yumbak/  >/dev/null 2>&1
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
#==============================================================#
#           内核参数计算                                        #
#==============================================================#
##服务器内存大小G单位
export MY_MEMORY_GB=`free -g | grep Mem | awk '{print $2}'`
 
##根据内存计算内核参数大小
export MY_SHMMAX=`echo "$MY_MEMORY_GB*1024*1024*1024*0.9" | bc | awk -F "." '{print $1}'`
export MY_SHMALL=`echo "$MY_MEMORY_GB*1024*1024*1024*0.9/4" | bc | awk -F "." '{print $1}'`
#==============================================================#
#           安装前准备工作                                      #
#==============================================================#
## 1.1 设置主机名
hostnamectl set-hostname $MY_HOSTNAME
sed -i '/^HOSTNAME=/d' /etc/sysconfig/network
echo "HOSTNAME=$MY_HOSTNAME" >> /etc/sysconfig/network
echo "1.1 Configure hostname completed."
## 1.2 修改hosts
cp /etc/hosts /tmp/confbak
cat >> /etc/hosts <<EOF
$MY_SERVER_IP $MY_HOSTNAME
EOF
echo "1.2 Configure Hosts Completed."
## 1.3 安装数据库依赖包
yum -y install bc binutils compat-libcap1 compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc \
glibc-devel ksh libaio libaio-devel libXrender libXrender-devel libX11 libXau libXi libXtst libgcc libstdc++ \
libstdc++-devel libxcb make policycoreutils policycoreutils-python smartmontools sysstat  >/dev/null 2>&1
cd $MY_DIRECTORY_SOFT
echo "1.3 Install rpm Software Completed."
## 1.4 关闭防火墙
systemctl stop firewalld.service  >/dev/null 2>&1
systemctl disable firewalld.service  >/dev/null 2>&1 
systemctl status firewalld.service  >/dev/null 2>&1
echo "1.4 Disable Firewalld Service Completed."
## 1.5 关闭SELinux
cp /etc/selinux/config /tmp/confbak/config
sed -i '/^SELINUX=/d' /etc/selinux/config
echo "SELINUX=disabled" >> /etc/selinux/config
# cat /etc/selinux/config|grep "SELINUX=disabled"
setenforce 0 >/dev/null 2>&1
echo "1.5 Disable SELINUX Completed."
## 1.6 建立用户和组
if id -u oracle >/dev/null 2>&1; then
    echo "Oracle User Exists."
else
    groupadd -g 14321 oinstall  >/dev/null 2>&1
    groupadd -g 14322 dba  >/dev/null 2>&1
    groupadd -g 14323 oper  >/dev/null 2>&1
    groupadd -g 14324 backupdba  >/dev/null 2>&1
    groupadd -g 14325 dgdba  >/dev/null 2>&1
    groupadd -g 14326 kmdba  >/dev/null 2>&1
    groupadd -g 14327 racdba  >/dev/null 2>&1    
    useradd -u 1101 -g oinstall -G dba,backupdba,dgdba,kmdba,racdba,oper oracle  >/dev/null 2>&1
    echo oracle123 | passwd --stdin oracle  >/dev/null 2>&1
    echo "1.6 User Created Completed."
fi
## 1.7 创建相关目录
mkdir -p $MY_ORA_HOME
chown -R oracle:oinstall $MY_DIR/app
chmod -R 775 $MY_DIR/app
echo "1.7 Oracle Directories Created Completed."
## 1.8 修改内核参数
cp /etc/sysctl.conf /tmp/confbak/sysctl.conf
cat >> /etc/sysctl.conf  <<EOF
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
kernel.shmmax = $MY_SHMMAX
kernel.shmall = $MY_SHMALL
EOF
sysctl -p  >/dev/null 2>&1
echo "1.8 Configure Linux Kernal Parameter Completed."
## 1.9 修改文件限制
cp /etc/security/limits.conf /tmp/confbak/limits.conf
cat >> /etc/security/limits.conf   <<EOF
oracle              soft    nproc   2047
oracle              hard    nproc   16384
oracle              soft    nofile  1024
oracle              hard    nofile  65536
oracle              soft    stack   10240
EOF
echo "1.9 Configure Linux Resource Limit Completed."
## 1.10 配置系统环境变量
cp /etc/profile /tmp/confbak/profile
cat >> /etc/profile  <<EOF
if [ $USER = "oracle" ]; then
    if [ $SHELL = "/bin/ksh" ]; then
        ulimit -p 16384
        ulimit -n 65536
    else
        ulimit -u 16384 -n 65536
    fi
fi
EOF
echo "1.10 Configure Linux Profile Env Completed."
## 1.11 配置NOZEROCONFIG
cat >> /etc/sysconfig/network <<EOF
NOZEROCONF=yes
EOF
echo "1.11 Configure Nozeroconfig Completed."
## 1.12 修改oracle用户环境变量
export MY_LD_LIBRARY_PATH=$MY_ORA_HOME/lib
export MY_CLASSPATH=$MY_ORA_HOME/JRE
su - oracle -c "
cat >> /home/oracle/.bash_profile  <<EOF
ORACLE_SID=$MY_ORA_SID; export ORACLE_SID
ORACLE_UNQNAME=$MY_ORA_SID; export ORACLE_UNQNAME
ORACLE_BASE=$MY_ORA_BASE; export ORACLE_BASE
ORACLE_HOME=$MY_ORA_HOME; export ORACLE_HOME
JAVA_HOME=/usr/local/java; export JAVA_HOME
ORACLE_PATH=$MY_DIR/app/common/oracle/sql; export ORACLE_PATH
ORACLE_TERM=xterm; export ORACLE_TERM
TNS_ADMIN=$MY_ORA_HOME/network/admin; export TNS_ADMIN
ORA_NLS11=$MY_ORA_HOME/nls/data; export ORA_NLS11
PATH=/usr/sbin:$PATH; export PATH
PATH=$MY_ORA_HOME/bin:$MY_DIR/app/common/oracle/bin:$PATH; export PATH
#LD_LIBRARY_PATH=$MY_ORA_HOME/lib
LD_LIBRARY_PATH=${MY_LD_LIBRARY_PATH}:$MY_ORA_HOME/oracm/lib
LD_LIBRARY_PATH=${MY_LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export LD_LIBRARY_PATH
#CLASSPATH=$MY_ORA_HOME/JRE
CLASSPATH=${MY_CLASSPATH}:$MY_ORA_HOME/jlib
CLASSPATH=${MY_CLASSPATH}:$MY_ORA_HOME/rdbms/jlib
CLASSPATH=${MY_CLASSPATH}:$MY_ORA_HOME/network/jlib
export CLASSPATH
THREADS_FLAG=native; export THREADS_FLAG
export TEMP=/tmp
export TMPDIR=/tmp
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
umask 022
EOF
"
source /home/oracle/.bash_profile >/dev/null 2>&1
echo "1.12 Configure Oracle Env Completed."
## 1.13 解压数据库软件
echo "1.13 Start Unzip Oracle Software."
cd $MY_DIRECTORY_SOFT
rm -rf $MY_DIRECTORY_SOFT/database
chown oracle.oinstall $MY_DIRECTORY_SOFT/$MY_ORA_SOFT1 -R
chmod 755 -R $MY_DIRECTORY_SOFT/$MY_ORA_SOFT1
su - oracle -c "unzip -q $MY_DIRECTORY_SOFT/$MY_ORA_SOFT1 -d $MY_ORA_HOME" &
while true;
do 
    echo -n ".";sleep 2;
    MY_EXEC=`ps -ef | grep unzip | grep -Evi grep`
    if [ "$MY_EXEC" = "" ] 
    then
        break;
    fi 
done
echo " "
echo "1.13 Unzip Oracle Software Completed."
#==============================================================#
#           数据库安装工作                                      #
#==============================================================#
## 2.1 创建数据库软件静默安装文件
mkdir -p $MY_INVENTORY_LOC
chown oracle.oinstall $MY_INVENTORY_LOC
if [ ! -d "$MY_DIRECTORY_SCRIPT" ]; then 
    mkdir -p $MY_DIRECTORY_SCRIPT
fi
cd  $MY_DIRECTORY_SCRIPT
rm -rf db_install.rsp
cat >> db_install.rsp   <<EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0 
oracle.install.option=INSTALL_DB_SWONLY 
UNIX_GROUP_NAME=oinstall 
INVENTORY_LOCATION=$MY_INVENTORY_LOC
ORACLE_BASE=$MY_ORA_BASE
ORACLE_HOME=$MY_ORA_HOME
oracle.install.db.InstallEdition=EE 
oracle.install.db.OSDBA_GROUP=dba 
oracle.install.db.OSOPER_GROUP=oper 
oracle.install.db.OSBACKUPDBA_GROUP=backupdba 
oracle.install.db.OSDGDBA_GROUP=dgdba 
oracle.install.db.OSKMDBA_GROUP=kmdba 
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=true 
oracle.install.db.rootconfig.configMethod=ROOT
oracle.install.db.config.starterdb.type=DATA_WAREHOUSE
EOF
chown oracle.oinstall $MY_DIRECTORY_SCRIPT -R
echo "2.1 Create Silent Configure File Completed."
## 2.2 静默安装数据库软件
chown oracle.oinstall $MY_DIRECTORY_SCRIPT/db_install.rsp
su - oracle -c "$MY_ORA_HOME/runInstaller -silent -force -noconfig -ignorePrereq -responseFile $MY_DIRECTORY_SCRIPT/db_install.rsp"
while true;
do 
    echo -n ".";sleep 2;
    MY_EXEC=`ps -ef | grep java | grep -Evi grep`
    if [ "$MY_EXEC" = "" ] 
    then
        break;
    fi 
done
echo " "
if [ $? -eq 0 ]; then
    sh $MY_INVENTORY_LOC/orainstRoot.sh  >/dev/null 2>&1
    sh $MY_ORA_HOME/root.sh  >/dev/null 2>&1
    
    NOW_DATE=`date +%Y-%m-%d`
    echo "Check  $MY_ORA_HOME/install/root_"$MY_HOSTNAME"_"$NOW_DATE"_xxx.log for the output of root script"
    echo " "
    echo "2.2 Install Oracle Software Completed."
else
  echo "2.2 Install Oracle Software Failed."
fi
## 2.3 静默配置数据库监听
cd  $MY_DIRECTORY_SCRIPT
rm -rf netca.rsp
cat >> netca.rsp   <<EOF
[GENERAL]
RESPONSEFILE_VERSION="19.3"
CREATE_TYPE="CUSTOM"
[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"LISTENER"}
LISTENER_PROTOCOLS={"TCP;1521"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;1521"}
EOF
chown oracle.oinstall $MY_DIRECTORY_SCRIPT/netca.rsp
su - oracle -c "$MY_ORA_HOME/bin/netca -silent -responseFile $MY_DIRECTORY_SCRIPT/netca.rsp"  >/dev/null 2>&1
echo "2.3 Configure Oracle Listener Completed."
## 2.4 配置静默创建数据库文件
cd  $MY_DIRECTORY_SCRIPT
rm -rf dbca.rsp
cat >> dbca.rsp   <<EOF
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v19.0.0
templateName=General_Purpose.dbc
gdbName=$MY_ORA_SID
sid=$MY_ORA_SID
createAsContainerDatabase=TRUE
numberOfPDBs=1
pdbName=pdb01
pdbAdminPassword=$MY_ORA_PASSWD
sysPassword=$MY_ORA_PASSWD
systemPassword=$MY_ORA_PASSWD
datafileDestination=$MY_ORA_BASE/oradata
recoveryAreaDestination=$MY_ORA_BASE/fast_recovery_area
storageType=FS
characterSet=AL32UTF8
nationalCharacterSet=UTF8
sampleSchema=true
totalMemory=$MY_ORA_MEMORY
databaseType=OLTP
databaseConfigType=SI
emConfiguration=NONE
EOF
echo "2.4 Create Silent Configure File Completed."
## 2.5 静默创建数据库
if [ ! -d "$MY_ORA_BASE/oradata" ]; then 
    mkdir $MY_ORA_BASE/oradata
fi
if [ ! -d "$MY_ORA_BASE/fast_recovery_area" ]; then 
    mkdir $MY_ORA_BASE/fast_recovery_area
fi
chown oracle.oinstall $MY_ORA_BASE/oradata
chown oracle.oinstall $MY_ORA_BASE/fast_recovery_area
chown oracle.oinstall $MY_DIRECTORY_SCRIPT/dbca.rsp
su - oracle -c "$MY_ORA_HOME/bin/dbca -silent -createDatabase -responseFile $MY_DIRECTORY_SCRIPT/dbca.rsp"
echo "2.5 Create Database Completed."
echo "Oracle successfully installed"