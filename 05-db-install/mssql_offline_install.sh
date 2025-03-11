#!/bin/bash
# 【脚本说明】
# 二进制安装，支持RPM包安装
# 1、下载SQL server RPM包上传到/opt目录下
# 2、建议服务器内存需≥4GB，建议swap空间≥2GB
# 3. SQL server RPM可以通过官网下载
# https://learn.microsoft.com/zh-cn/
# 直接执行脚本，自动化安装，本脚本适用于Linux7,其他操作系统可能涉及yum的配置不同，请自行修改
#==============================================================#
# 脚本名     :   mssql_offline_install.sh
# 创建时间   :   2024-03-08 22:00:00
# 更新时间   :   2025-02-10 10:00:00
# 描述      :    SQL Server离线安装脚本
# Linux系统 :    Liunx7
# 脚本路径   :   /opt
# 版本      :   3.0.0
# 作者      :   公众号:IT邦德，Oracle ACE
# 说明      :   其他版本替换相应的二进制包即可
#==============================================================#

#==============================================================#
#                        挂载光驱                               #
#==============================================================#
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
#           本地yum配置                                         #
#==============================================================#
mkdir -p /tmp/confbak/yumbak/
mv /etc/yum.repos.d/*  /tmp/confbak/yumbak/  >/dev/null 2>&1
## 确认操作系统的版本，配置yum
echo "[LocalRepo]" >> /etc/yum.repos.d/my.repo
echo "name=mssql_offline_install" >> /etc/yum.repos.d/my.repo
echo "baseurl=file:///mnt/" >> /etc/yum.repos.d/my.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/my.repo
echo "enabled=1" >> /etc/yum.repos.d/my.repo


# 强制root权限运行
if [[ $EUID -ne 0 ]]; then
   echo "必须使用root权限运行" >&2
   exit 1
fi

# 配置参数（安装前需修改）
INSTALL_DIR="/opt"   # 离线包存放路径
SA_PASSWORD="Your@StrongPwd123"    # 需包含大小写+数字+特殊字符
INSTALL_MODE="Evaluation"
TCP_PORT=1433

# 安装日志记录
yum install tree >/dev/null 2>&1
rm -rf /var/offline_install.log
touch /var/offline_install.log 
LOG_FILE="/var/offline_install.log"

# 校验离线包完整性
echo "1.校验离线安装包"
REQUIRED_FILES=(
  "mssql-server-*.rpm"         # 主程序包
  "mssql-tools-*.rpm"          # 命令行工具
  "unixODBC-*.rpm"             # 关键依赖
)
for file in "${REQUIRED_FILES[@]}"; do
  if ! ls $INSTALL_DIR/$file &> /dev/null; then
    echo "缺失文件：$file，请检查$INSTALL_DIR目录" >&2
    exit 1
  fi
done

# 安装基础依赖
echo "2.安装系统依赖"
yum install -y gcc glibc-devel libstdc++-devel >/dev/null 2>&1
yum -y install firewalld policycoreutils-python libsss_nss_idmap libatomic python3 >> $LOG_FILE 2>&1 || {
  echo "依赖安装失败，请检查离线包中的ODBC等组件"; exit 1
}

# 安装主程序（自动处理依赖顺序）
echo "3.安装SQL Server组件..."
##yum remove mssql-server -y
##rm -rf /var/opt/mssql/
rpm -ivh $INSTALL_DIR/unixODBC-*.rpm >> $LOG_FILE 2>&1
rpm -ivh $INSTALL_DIR/mssql-server-*.rpm >> $LOG_FILE 2>&1
rpm -ivh $INSTALL_DIR/msodbcsq*.rpm >> $LOG_FILE 2>&1

# 初始配置
echo "4.运行初始配置"
sudo MSSQL_PID=$INSTALL_MODE \
ACCEPT_EULA=Y \
MSSQL_TCP_PORT='1433' \
MSSQL_SA_PASSWORD=$SA_PASSWORD \
/opt/mssql/bin/mssql-conf -n setup

# 防火关闭
echo "5.关闭防火墙"
systemctl stop firewalld.service  >/dev/null 2>&1
systemctl disable firewalld.service  >/dev/null 2>&1 
systemctl status firewalld.service  >/dev/null 2>&1

## 关闭SELinux
sed -i '/^SELINUX=/d' /etc/selinux/config
echo "SELINUX=disabled" >> /etc/selinux/config
# cat /etc/selinux/config|grep "SELINUX=disabled"
setenforce 0 >/dev/null 2>&1

# 验证安装
echo "6.验证服务状态"
if ! systemctl is-active mssql-server &> /dev/null; then
  echo "服务未运行，检查日志：/var/opt/mssql/log/errorlog" >&2
  exit 1
fi

# 安装命令行工具
echo "7.安装SQLCMD工具"
rpm -ivh $INSTALL_DIR/mssql-tools-*.rpm >> $LOG_FILE 2>&1
cat << EOF >> /etc/profile.d/mssql.sh
export PATH=\$PATH:/opt/mssql-tools/bin
EOF

source /etc/profile.d/mssql.sh

echo "8.安装成功！连接命令"
echo "sqlcmd -S localhost -U sa -P '$SA_PASSWORD'"
echo "详细日志：$LOG_FILE"