# Microsoft SQL Server

## 客户端工具
```sh
# 进入目录
mkdir -pv /data/pkg && cd /data/pkg

# 替换链接为仓库里复制的最新版
wget https://packages.microsoft.com/rhel/8/prod/msodbcsql18-18.6.1.1-1.x86_64.rpm
wget https://packages.microsoft.com/rhel/8/prod/mssql-tools18-18.6.1.1-1.x86_64.rpm

# 安装（先驱动后工具）
yum install -y unixODBC -q
ACCEPT_EULA=Y rpm -ivh msodbcsql18-*.rpm --nodeps
ACCEPT_EULA=Y rpm -ivh mssql-tools18-*.rpm --nodeps

# 把sqlcmd路径写入系统环境变量，所有用户/终端都能用
echo 'export PATH=$PATH:/opt/mssql-tools18/bin' >> /etc/profile
source /etc/profile

# 驱动
odbcinst -i -d -f /opt/microsoft/msodbcsql18/etc/odbcinst.ini
```


## 单实例
```sh
mkdir -pv /data/mssql && cd /data/mssql
mkdir -pv ./data

cat > .env <<EOF
MSSQL_VERSION=2022-latest
SA_PASSWORD=root.COM2025*
MSSQL_PID=Developer
EOF

docker-compose up -d
docker logs -f mssql
```

## 连接
```sh
sqlcmd -S 127.0.0.1 -U sa -P "root.COM2025*" -C

select @@version;
go

select name from sys.databases;
go
```

## 配置
编辑 `.env` 文件修改版本和密码
