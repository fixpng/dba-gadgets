#!/bin/bash
set -euo pipefail

log() { echo -e "\033[32m[$(date '+%Y-%m-%d %H:%M:%S')] $*\033[0m"; }

read -p "请输入 openssh 版本号（格式如：9.9、10.0，请不要低于当前版本，最新版本请到openssh官网查看。）: " SSH_VER
OPENSSH_PKG="openssh-${SSH_VER}p1.tar.gz"
OPENSSH_DIR="openssh-${SSH_VER}p1"

# 判断包管理器
if command -v yum >/dev/null 2>&1; then
    PM="yum"
elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"
else
    log "暂不支持此操作系统版本。"
    exit 1
fi

log "正在执行操作系统版本判断，请稍后..."
#rpm包手动下载 https://mirrors.cloud.tencent.com/centos

if [ ! -f /etc/os-release ]; then
    log "未检测到 /etc/os-release，无法判断系统类型，脚本退出。"
    exit 1
fi
os_id=$(awk -F'=' '/^ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release)
v=$(awk -F'=' '/^VERSION_ID=/{gsub(/"/,"",$2); print int($2)}' /etc/os-release)

if [ "$os_id" = "centos" ]; then
    if [ "$v" -eq 6 ]; then
        if ! command -v wget >/dev/null 2>&1; then
            rpm -ivh https://mirrors.cloud.tencent.com/centos/6/os/x86_64/Packages/wget-1.12-10.el6.x86_64.rpm
        fi
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        mv /etc/yum.repos.d/media.repo /etc/yum.repos.d/media.repo.backup
        wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/centos6_base.repo
        sed -i 's#http#https#g' /etc/yum.repos.d/CentOS-Base.repo
        $PM clean all
        $PM makecache
    elif [ "$v" -eq 7 ]; then
        if ! command -v wget >/dev/null 2>&1; then
            rpm -ivh https://mirrors.cloud.tencent.com/centos/7/os/x86_64/Packages/wget-1.14-18.el7_6.1.x86_64.rpm
        fi
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/centos7_base.repo
        sed -i 's#http#https#g' /etc/yum.repos.d/CentOS-Base.repo
        $PM clean all
        $PM makecache
    elif [ "$v" -eq 8 ]; then
        if ! command -v wget >/dev/null 2>&1; then
            rpm -ivh https://mirrors.cloud.tencent.com/centos/8.4.2105/AppStream/x86_64/os/Packages/wget-1.19.5-10.el8.x86_64.rpm
        fi
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/centos8_base.repo
        sed -i 's#http#https#g' /etc/yum.repos.d/CentOS-Base.repo
        $PM clean all
        $PM makecache
    else
        echo "不支持的CentOS版本"
        exit 1
    fi
else
    echo "非CentOS系统，直接安装依赖和openssh。"
    # 直接安装依赖和openssh，不做repo切换
    $PM install  -y gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel rpm-build perl
    $PM install -y zlib-devel
    $PM install pam-devel keyutils-libs libcom_err-devel libselinux-devel libsepol-devel -y
fi
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce 0 || true

log "正在执行系统依赖包检查..."
# 检查基础命令
for cmd in wget tar make gcc; do
    if ! command -v $cmd >/dev/null 2>&1; then
        log "未检测到 $cmd，自动安装..."
        $PM install -y $cmd
    fi
done
# 合并依赖安装
$PM install -y gcc gcc-c++ glibc make autoconf openssl openssl-devel pcre-devel pam-devel rpm-build perl zlib-devel keyutils-libs libcom_err-devel libselinux-devel libsepol-devel

log "下载最新 openssh..."

#新版本openssh下载地址：https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/, 如果有最新版本，替换下面最新版本即可。
if [ -f /tmp/${OPENSSH_PKG} ]; then
    log "openssh 压缩包已存在，先删除后重新下载。"
    rm -f /tmp/${OPENSSH_PKG}
fi
wget -O /tmp/${OPENSSH_PKG} https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/${OPENSSH_PKG}
if [ $? -ne 0 ] || [ ! -s /tmp/${OPENSSH_PKG} ]; then
    log "openssh 下载失败，删除旧包..."
    rm -f /tmp/${OPENSSH_PKG}
    exit 1
fi
log "下载完成，文件大小：$(du -h /tmp/${OPENSSH_PKG} | cut -f1)"

log "删除低版本 OpenSSH rpm 包..."
openssh_pkgs=$(rpm -qa | grep openssh || true)
if [ -n "$openssh_pkgs" ]; then
    set +e
    rpm -e --nodeps $openssh_pkgs
    set -e
fi
rpm -e openssh-server --nodeps || true
rpm -e openssh-clients --nodeps || true
rpm -e openssh-askpass || true
service sshd stop || true
rm -rf /etc/ssh/* || true

log "openssh 压缩包解压..."
cd /tmp
tar -zxvf ${OPENSSH_PKG}
cd ${OPENSSH_DIR}
mv /etc/ssh /etc/ssh_bak || true
chown -R root.root /tmp/${OPENSSH_DIR}

log "准备进行 openssh 安装..."
if command -v ssh >/dev/null 2>&1 && ssh -V 2>&1 | grep -q "OpenSSH_${SSH_VER}"; then
    log "系统已安装 openssh ${SSH_VER}，无需重复编译。"
else
if [ "$v" -eq 6 ]; then
    log '编译ssh中...'
    wget -P /usr/local/src/ https://gitee.com/securitypass/auto-scirpt/raw/master/download/openssl-1.1.1d.tar.gz
    cd /usr/local/src/
    tar -zxf openssl-1.1.1g.tar.gz
    cd /usr/local/src/openssl-1.1.1g
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl --shared zlib && make && make install
    mv /usr/bin/openssl /usr/bin/openssl_1.0.1e_bak
    cp /usr/local/openssl/bin/openssl /usr/bin/openssl
    openssl 
    ldd $(which openssl)
    cp /usr/local/openssl/lib/libssl.so.1.1 /usr/lib64/
    cp /usr/local/openssl/lib/libcrypto.so.1.1 /usr/lib64/
    cd /usr/local/openssl/lib
    cat /etc/ld.so.conf
    echo "/usr/local/openssl/lib" >> /etc/ld.so.conf
    ldconfig
    ldconfig -v
    cd /tmp/${OPENSSH_DIR}/
    ./configure --prefix=/usr --sysconfdir=/etc/ssh --with-pam --with-zlib --with-md5-passwords --with-tcp-wrappers  && make && make install
    if [ $? -eq 0 ]; then
        log '编译ssh完成！'
        chmod 600 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key
    else 
        log "编译错误请检查日志！"
        exit 1
    fi
elif [ "$v" -eq 7 ]; then
    log '编译ssl中...'
    cd /usr/local/src/
    wget -P /usr/local/src/ https://gitee.com/securitypass/auto-scirpt/raw/master/download/openssl-1.1.1d.tar.gz
    tar -zxf openssl-1.1.1d.tar.gz
    cd /usr/local/src/openssl-1.1.1d
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl --shared zlib && make && make install
    mv /usr/bin/openssl /usr/bin/openssl_1.0.1e_bak
    cp /usr/local/openssl/bin/openssl /usr/bin/openssl
    cp /usr/local/openssl/lib/libssl.so.1.1 /usr/lib64/
    cp /usr/local/openssl/lib/libcrypto.so.1.1 /usr/lib64/
    cd /usr/local/openssl/lib
    cat /etc/ld.so.conf
    echo "/usr/local/openssl/lib" >> /etc/ld.so.conf
    ldconfig
    ldconfig -v
    log "当前ssl版本: $(openssl version)"
    sleep 2

    log '开始编译ssh...'
    cd /tmp/${OPENSSH_DIR}
    ./configure --prefix=/usr --sysconfdir=/etc/ssh --with-pam --with-zlib --with-md5-passwords --with-tcp-wrappers --with-ssl-dir=/usr/local/openssl  && make && make install
    if [ $? -eq 0 ]; then
        log '编译ssh完成！'
        chmod 600 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key
    else
        log "编译错误请检查日志！"
        exit 1
    fi

elif [ "$v" -eq 8 ] || [ "$os_id" != "centos" ] || { [ "$os_id" = "centos" ] && [ "$v" -ne 6 ] && [ "$v" -ne 7 ] && [ "$v" -ne 8 ]; }; then
    log '编译ssh中...'
    $PM update openssh || true
    cd /tmp/${OPENSSH_DIR}
    ./configure --prefix=/usr --sysconfdir=/etc/ssh --with-md5-passwords --with-pam --with-zlib --with-tcp-wrappers --with-ssl-dir=/usr/local/ssl --without-hardening && make && make install
    if [ $? -eq 0 ]; then
        log '编译ssh完成！'
        chmod 600 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key
    else
        log "编译错误请检查日志！"
        exit 1
    fi
fi
fi

log "修改配置文件 /etc/ssh/sshd_config..."
sed -i.bak 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
sed -i '/^GSSAPICleanupCredentials/s/GSSAPICleanupCredentials yes/#GSSAPICleanupCredentials yes/' /etc/ssh/sshd_config || true
sed -i '/^GSSAPIAuthentication/s/GSSAPIAuthentication yes/#GSSAPIAuthentication yes/' /etc/ssh/sshd_config || true
sed -i '/^GSSAPIAuthentication/s/GSSAPIAuthentication no/#GSSAPIAuthentication no/' /etc/ssh/sshd_config || true
sed -i 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config || true

log "添加自动启动项..."

if [ "$v" -eq 6 ]; then
    cd /tmp/${OPENSSH_DIR}
    cp -a /tmp/${OPENSSH_DIR}/contrib/redhat/sshd.init /etc/init.d/sshd
    cp -a /tmp/${OPENSSH_DIR}/contrib/redhat/sshd.pam /etc/pam.d/sshd.pam
    cp -a /tmp/${OPENSSH_DIR}/sshd /usr/sbin/sshd
    chmod +x /etc/init.d/sshd
    chkconfig --add sshd
    chkconfig sshd on
    service sshd restart
elif [ "$v" -eq 7 ]; then
    cd /tmp/${OPENSSH_DIR}
    cp -a /tmp/${OPENSSH_DIR}/contrib/redhat/sshd.init /etc/init.d/sshd
    cp -a /tmp/${OPENSSH_DIR}/sshd /usr/sbin/sshd
    chmod +x /etc/init.d/sshd
    systemctl enable sshd
    systemctl restart sshd
elif [ "$v" -eq 8 ] || [ "$os_id" != "centos" ] || { [ "$os_id" = "centos" ] && [ "$v" -ne 6 ] && [ "$v" -ne 7 ] && [ "$v" -ne 8 ]; }; then
    cd /tmp/${OPENSSH_DIR}
    cp -a /tmp/${OPENSSH_DIR}/contrib/redhat/sshd.init /etc/init.d/sshd
    cp -a /tmp/${OPENSSH_DIR}/sshd /usr/sbin/sshd
    chmod +x /etc/init.d/sshd
    systemctl enable sshd
    systemctl restart sshd
fi

if command -v ssh >/dev/null 2>&1; then
    log 'openssh升级成功！'
    ssh -V
else
    log 'openssh升级失败，请检查日志！'
fi
log "All done."
