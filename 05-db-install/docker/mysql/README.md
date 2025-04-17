# MySQL8

- mysql8+ docker-compose文件 及 my.cnf 配置模板
- 默认配置 conf/my.cnf 为4c8g

## 客户端
mysql 仅安装客户端（mysql-community-client）
https://dev.mysql.com/downloads/mysql/
```powershell
# 查看当前系统的发行版本信息下载对应版本，mysql版本方面一般是向下兼容的
cat /etc/os-release 
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-community-client-8.0.39-1.el7.x86_64.rpm
rpm -ivh mysql-community-client-8.0.39-1.el7.x86_64.rpm  --nodeps --force
mysql --version
```

## 单实例
```powershell
# 拉取 git 仓库
cd /data/ && git clone https://git.bndxqc.cn/dba/mysql8.git
# 启动
cd ./mysql8 && docker-compose up -d
# 进入 mysql 命令行
docker exec -it mysql mysql -h127.0.0.1 -P3306 -uroot -p"root.COM2020"
mysql  -h127.0.0.1  -uroot -P3306 -p"root.COM2020"
```

## 主从复制
主库启动步骤与单实例相同，从库启动及配置如下
> setup_replication.sh 脚本只适用于：主库也是初始搭建，空库、没有数据的状态
```powershell
# 拉取 git 仓库
cd /data/ && git clone https://git.bndxqc.cn/dba/mysql8.git
# 拷贝 slave 的配置及 docker-compose 并启动
cd ./mysql8 &&  yes | cp -Rf ./slave/* ./  && docker-compose up -d
# 设置主从(192.168.1.100 为主库ip)
sh ./setup_replication.sh 192.168.1.100 3306 root "root.COM2020"
# 进入从库 mysql 命令行
docker exec -it mysql-slave mysql -h127.0.0.1 -P3306 -uroot -p"root.COM2020"
mysql -h127.0.0.1 -P3306 -uroot -p"root.COM2020"
# 查看状态
show slave status \G;
```

业务同步测试(主库执行)
```sql
create database testdb;
use testDB;
create table t1 as select 1 as A,222 AS b;
insert into t1 select 2,333;
```