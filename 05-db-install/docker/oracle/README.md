# Oracle XE

## 单实例
```sh
mkdir -pv /data/oracle && cd /data/oracle
mkdir -pv ./data
# 修改权限（重要！）
chown -R 54321:54321 ./data

cat > .env <<EOF
ORACLE_VERSION=21-full
ORACLE_PASSWORD=root.COM2025*
EOF

docker-compose up -d
docker logs -f oracle
```

## 连接
```sh
docker exec -it oracle sqlplus system/root.COM2025*@127.0.0.1:1521/XE

SELECT * FROM v$version;
```

## 配置
编辑 `.env` 文件修改版本和密码
