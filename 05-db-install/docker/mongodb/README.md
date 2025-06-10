# mongo
mongo7+ docker-compose文件 及配置模板，默认配置 conf/mongod.conf 为4c8g

## 单实例
```sh
# 拉取 git 仓库
mkdir -pv /data/mongo/
# 启动
cd /data/mongo/
mkdir ./data/ && chown -R 1001:1001 ./data/
docker-compose up -d

# 进入 mongo 命令行
docker exec -it mongodb mongosh -u root -p "root.COM2025*" --authenticationDatabase=admin admin
mongosh 127.0.0.1:27017  -u root -p "root.COM2025*" --authenticationDatabase=admin admin
```

## 副本集（单节点）
启动副本集
```sh
# 拉取 git 仓库
mkdir -pv /data/mongo/
# 启动
cd /data/mongo/
mkdir ./data/ && chown -R 1001:1001 ./data/

# 生成 keyfile
openssl rand -base64 756 > .mongodb-keyfile && chmod 600 .mongodb-keyfile && chown 1001:1001 .mongodb-keyfile

# 编辑 /etc/mongod.conf 文件，添加以下内容：
cat <<EOL >> ./conf/mongod.conf
  keyFile: /etc/mongodb-keyfile
replication:
  replSetName: "rs0"
EOL

# 修改 docker-compose.yaml 文件，添加 keyfile 映射：
sed -i '/volumes:/a \ \ \ \ \ \ - .mongodb-keyfile:/etc/mongodb-keyfile' docker-compose.yaml

# 启动
docker-compose up -d

# 进入 mongo 命令行
docker exec -it mongodb mongosh -u root -p "root.COM2025*" --authenticationDatabase=admin admin
mongosh 127.0.0.1:27017  -u root -p "root.COM2025*" --authenticationDatabase=admin admin
```

初始化副本集
```js
// 初始化（host改为宿主机ip地址）
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "168.192.1.1:27017" }
  ]
})

// 验证副本集状态
rs.status()
rs.conf()
```