# PostgreSQL

## 单实例
```sh
mkdir -pv /data/postgresql && cd /data/postgresql
mkdir -pv ./data ./conf

cat > .env <<EOF
POSTGRES_VERSION=15
POSTGRES_USER=postgres
POSTGRES_PASSWORD=root.COM2025*
POSTGRES_DB=postgres
EOF

docker-compose up -d
docker logs -f postgresql
```

## 连接
```sh
docker exec -it postgresql psql -U postgres -d postgres

SELECT current_database(),current_user,pg_is_in_recovery(),version();
```

## 配置
编辑 `conf/postgresql.conf` 和 `conf/pg_hba.conf` 修改配置
