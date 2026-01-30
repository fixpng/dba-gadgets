# Redis

## 系统环境
vm.overcommit_memory=1

Redis 要求开启这个配置的核心原因是：Redis 的 RDB 持久化、AOF 重写、主从复制时会申请大量内存，Linux 默认的内存超配策略（vm.overcommit_memory=0）会判断物理内存是否足够，可能导致 Redis 的内存申请失败；而设置为1后，Linux 会允许所有内存申请，避免 Redis 在低内存场景下的持久化 / 复制失败，这是 Redis 官方推荐的系统配置。
```sh
sysctl vm.overcommit_memory=1
echo 'vm.overcommit_memory=1' | sudo tee -a /etc/sysctl.conf
sysctl -p
sysctl vm.overcommit_memory
```

## 单实例
```sh
mkdir -pv /data/redis && cd /data/redis
mkdir -pv ./data ./conf

cat > .env <<EOF
REDIS_VERSION=7.2
EOF

docker-compose up -d
docker logs -f redis
```

## 连接
```sh
docker exec -it redis redis-cli -a "root.COM2025*"
info
```

## 配置
编辑 `conf/redis.conf` 修改密码等配置
