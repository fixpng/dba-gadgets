# mongo
mongo7+ docker-compose文件 及配置模板，默认配置 conf/mongod.conf 为4c8g

```
# 拉取 git 仓库
mkdir -pv /data/mongo/
# 启动
cd /data/mongo/
mkdir ./data/ && chown -R 1001:1001 ./data/
docker-compose up -d
# 进入 mysql 命令行
docker exec -it mongodb mongosh -u root -p "root.COM2025" --authenticationDatabase=admin admin
mongosh 127.0.0.1:27017  -u root -p "root.COM2025" --authenticationDatabase=admin admin
```