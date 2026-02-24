# Prometheus + Grafana 监控系统

基于 Docker Compose 的 Prometheus 和 Grafana 监控解决方案。

## 组件说明

- **Prometheus**: 开源监控和告警系统，用于收集和存储时间序列数据
- **Grafana**: 开源的可视化平台，用于展示监控数据

## 快速开始

### 1. 启动服务

```bash
cd prometheus-grafana
docker-compose up -d
```

### 2. 访问服务

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
  - 默认用户名: `admin`
  - 默认密码: `admin`
  - 首次登录会要求修改密码

### 3. 验证服务状态

```bash
# 查看容器状态
docker-compose ps

# 查看日志
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## 配置说明

### Prometheus 配置

配置文件位置: `prometheus/prometheus.yml`

主要配置项：
- `scrape_interval`: 抓取指标间隔（默认 15s）
- `evaluation_interval`: 规则评估间隔（默认 15s）
- `scrape_configs`: 监控目标配置
- `rule_files`: 告警规则文件路径

### Grafana 配置

#### 数据源配置

Prometheus 数据源已通过 provisioning 自动配置，配置文件位于：
`grafana/provisioning/datasources/prometheus.yml`

#### 仪表板配置

仪表板目录: `grafana/dashboards/`

可以通过以下方式添加仪表板：
1. 在 Grafana Web UI 中创建并导出 JSON
2. 将 JSON 文件放入 `grafana/dashboards/` 目录
3. 重启 Grafana 容器或等待自动加载

#### 环境变量

可以通过修改 `docker-compose.yaml` 中的环境变量来配置 Grafana：

```yaml
environment:
  - GF_SECURITY_ADMIN_USER=admin          # 管理员用户名
  - GF_SECURITY_ADMIN_PASSWORD=admin      # 管理员密码
  - GF_USERS_ALLOW_SIGN_UP=false          # 禁止用户注册
  - GF_SERVER_ROOT_URL=http://localhost:3000  # 服务根 URL
```

## 添加监控目标

### 1. 修改 Prometheus 配置

编辑 `prometheus/prometheus.yml`，在 `scrape_configs` 部分添加新的监控目标：

```yaml
scrape_configs:
  # 示例：监控 MySQL
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']
        labels:
          instance: 'mysql-server'
          database: 'production'
```

### 2. 重新加载配置

Prometheus 支持热重载配置（已启用 `--web.enable-lifecycle`）：

```bash
# 方法1: 通过 API 重载
curl -X POST http://localhost:9090/-/reload

# 方法2: 重启容器
docker-compose restart prometheus
```

## 常用 Exporter 集成

### Node Exporter（系统监控）

在 `docker-compose.yaml` 中添加：

```yaml
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - monitoring
```

然后在 `prometheus.yml` 中添加：

```yaml
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

### MySQL Exporter

需要先部署 MySQL Exporter，然后在 Prometheus 配置中添加监控目标。

### cAdvisor（容器监控）

在 `docker-compose.yaml` 中添加：

```yaml
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - monitoring
```

## 告警规则

告警规则文件位于 `prometheus/rules/` 目录。

### 创建告警规则

创建 `.yml` 文件，例如 `prometheus/rules/mysql.yml`：

```yaml
groups:
  - name: mysql
    interval: 30s
    rules:
      - alert: MySQLDown
        expr: mysql_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "MySQL instance is down"
          description: "MySQL instance {{ $labels.instance }} has been down for more than 1 minute."
```

### 启用告警管理器（Alertmanager）

1. 在 `docker-compose.yaml` 中添加 Alertmanager 服务
2. 在 `prometheus.yml` 中配置 `alerting` 部分

## 数据持久化

数据存储在 Docker volumes 中：
- `prometheus-data`: Prometheus 时序数据
- `grafana-data`: Grafana 配置和数据

### 备份数据

```bash
# 备份 Prometheus 数据
docker run --rm -v prometheus-grafana_prometheus-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# 备份 Grafana 数据
docker run --rm -v prometheus-grafana_grafana-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/grafana-backup.tar.gz -C /data .
```

### 恢复数据

```bash
# 恢复 Prometheus 数据
docker run --rm -v prometheus-grafana_prometheus-data:/data -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/prometheus-backup.tar.gz"

# 恢复 Grafana 数据
docker run --rm -v prometheus-grafana_grafana-data:/data -v $(pwd):/backup \
  alpine sh -c "cd /data && tar xzf /backup/grafana-backup.tar.gz"
```

## 与其他服务联动

### 监控 MySQL 数据库

#### 方式1：使用 MySQL Exporter（推荐）

1. 在 `docker-compose.yaml` 中添加 MySQL Exporter 服务：

```yaml
  mysql-exporter:
    image: prom/mysqld-exporter:latest
    container_name: mysql-exporter
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: "user:password@(mysql-host:3306)/"
    ports:
      - "9104:9104"
    networks:
      - monitoring
```

2. 在 `prometheus.yml` 中添加监控配置：

```yaml
  - job_name: 'mysql-exporter'
    static_configs:
      - targets: ['mysql-exporter:9104']
        labels:
          instance: 'mysql-server'
          database: 'production'
```

3. 如果 MySQL 在其他 Docker 网络中，需要将 MySQL Exporter 加入该网络：

```yaml
  mysql-exporter:
    # ... 其他配置 ...
    networks:
      - monitoring
      - mysql-network  # MySQL 所在的网络
```

#### 方式2：直接监控 MySQL（需要 MySQL 启用 performance_schema）

在 `prometheus.yml` 中添加：

```yaml
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-host:3306']
```

### 监控 Docker 容器

使用 cAdvisor 监控所有 Docker 容器：

1. 在 `docker-compose.yaml` 中添加 cAdvisor 服务（见上方 cAdvisor 配置示例）
2. 在 `prometheus.yml` 中添加监控配置

### 监控 Redis

1. 在 `docker-compose.yaml` 中添加 Redis Exporter：

```yaml
  redis-exporter:
    image: oliver006/redis_exporter:latest
    container_name: redis-exporter
    restart: unless-stopped
    environment:
      REDIS_ADDR: "redis://redis-host:6379"
      # REDIS_PASSWORD: "your-password"  # 如果 Redis 有密码
    ports:
      - "9121:9121"
    networks:
      - monitoring
```

2. 在 `prometheus.yml` 中添加监控配置

### 监控 PostgreSQL

1. 在 `docker-compose.yaml` 中添加 PostgreSQL Exporter：

```yaml
  postgres-exporter:
    image: quay.io/prometheuscommunity/postgres-exporter:latest
    container_name: postgres-exporter
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: "postgresql://user:password@postgres-host:5432/dbname?sslmode=disable"
    ports:
      - "9187:9187"
    networks:
      - monitoring
```

2. 在 `prometheus.yml` 中添加监控配置

### 监控 MongoDB

1. 在 `docker-compose.yaml` 中添加 MongoDB Exporter：

```yaml
  mongodb-exporter:
    image: percona/mongodb_exporter:latest
    container_name: mongodb-exporter
    restart: unless-stopped
    environment:
      MONGODB_URI: "mongodb://user:password@mongodb-host:27017"
    ports:
      - "9216:9216"
    networks:
      - monitoring
```

2. 在 `prometheus.yml` 中添加监控配置

### 监控应用服务

在应用代码中集成 Prometheus 客户端库，暴露 metrics 端点，然后在 `prometheus.yml` 中添加监控目标。

#### 示例：监控 Go 应用

```go
import (
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "net/http"
)

func main() {
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

在 `prometheus.yml` 中添加：

```yaml
  - job_name: 'go-app'
    static_configs:
      - targets: ['app-host:8080']
        labels:
          instance: 'go-application'
```

### 监控本项目的其他 Docker 服务

#### 监控 MySQL（05-db-install/docker/mysql）

1. 确保 MySQL 容器和 Prometheus 在同一个 Docker 网络中，或创建共享网络
2. 添加 MySQL Exporter 到 `docker-compose.yaml`
3. 配置 MySQL Exporter 连接到 MySQL 容器

#### 监控 MinIO（07-sre-install/docker/minio）

MinIO 本身支持 Prometheus metrics，可以直接配置：

```yaml
  - job_name: 'minio'
    static_configs:
      - targets: ['minio:9000']
    metrics_path: /minio/v2/metrics/cluster
```

### 使用示例配置文件

项目提供了两个示例配置文件：
- `prometheus.yml.example`: 包含各种 Exporter 的监控配置示例
- `docker-compose.yaml.example`: 包含各种 Exporter 服务的配置示例

可以根据需要复制这些文件并修改：

```bash
# 复制示例配置文件
cp prometheus/prometheus.yml.example prometheus/prometheus.yml
cp docker-compose.yaml.example docker-compose.yaml

# 根据需要修改配置
vi prometheus/prometheus.yml
vi docker-compose.yaml
```

## 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart

# 查看服务状态
docker-compose ps

# 进入容器
docker exec -it prometheus sh
docker exec -it grafana sh

# 重载 Prometheus 配置
curl -X POST http://localhost:9090/-/reload
```

## 故障排查

### Prometheus 无法启动

1. 检查配置文件语法：
```bash
docker run --rm -v $(pwd)/prometheus:/etc/prometheus prom/prometheus:latest \
  promtool check config /etc/prometheus/prometheus.yml
```

2. 查看日志：
```bash
docker-compose logs prometheus
```

### Grafana 无法连接 Prometheus

1. 确认两个容器在同一个网络（monitoring）
2. 检查 Prometheus 数据源配置
3. 查看 Grafana 日志：
```bash
docker-compose logs grafana
```

### 数据不显示

1. 检查 Prometheus 是否抓取到数据：访问 http://localhost:9090/targets
2. 检查 Grafana 数据源连接状态
3. 确认时间范围设置正确

## 参考资源

- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 官方文档](https://grafana.com/docs/)
- [Prometheus 最佳实践](https://prometheus.io/docs/practices/)
- [Grafana 仪表板库](https://grafana.com/grafana/dashboards/)

## 安全建议

1. **修改默认密码**：首次登录 Grafana 后立即修改管理员密码
2. **限制访问**：使用反向代理（如 Nginx）添加认证和 HTTPS
3. **网络隔离**：将监控服务放在独立的 Docker 网络中
4. **定期备份**：定期备份 Prometheus 和 Grafana 数据
5. **更新镜像**：定期更新 Prometheus 和 Grafana 镜像版本

## 版本信息

- Prometheus: latest (建议固定版本号用于生产环境)
- Grafana: latest (建议固定版本号用于生产环境)
