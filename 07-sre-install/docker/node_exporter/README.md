# Node Exporter 监控服务

Node Exporter 用于收集 Linux 系统硬件和操作系统指标，供 Prometheus 抓取。

## 功能说明

Node Exporter 会收集以下系统指标：
- CPU 使用率
- 内存使用情况
- 磁盘 I/O 和空间使用
- 网络统计信息
- 系统负载
- 文件系统使用情况
- 其他系统级指标

## 快速开始

### 1. 启动服务

```bash
cd node_exporter
docker-compose up -d
```

### 2. 验证服务

访问 `http://localhost:9100/metrics` 查看指标输出。

### 3. 查看日志

```bash
docker-compose logs -f node-exporter
```

## 配置说明

### 网络模式

- **network_mode: host**: 使用宿主机网络模式，容器直接使用宿主机的主机名和网络

### 端口

- **9100**: Node Exporter 指标暴露端口（由于使用 host 网络模式，直接绑定到宿主机）

### 挂载卷

- `/proc:/host/proc:ro`: 只读挂载系统进程信息
- `/sys:/host/sys:ro`: 只读挂载系统信息
- `/:/rootfs:ro`: 只读挂载根文件系统

### 命令参数

- `--path.procfs=/host/proc`: 指定 procfs 路径
- `--path.sysfs=/host/sys`: 指定 sysfs 路径
- `--collector.filesystem.mount-points-exclude`: 排除不需要监控的文件系统挂载点

## 与 Prometheus 集成

### 1. 配置 Prometheus（推荐配置）

由于 Node Exporter 使用 `network_mode: host`，容器会直接使用宿主机的主机名。在 Prometheus 的 `prometheus.yml` 配置文件中添加：

```yaml
scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']  # 如果 Prometheus 也在同一主机
        # 或使用宿主机 IP: ['192.168.1.100:9100']
    relabel_configs:
      # 设置 node_name 标签为宿主机名
      - source_labels: [__address__]
        regex: '([^:]+):.*'
        target_label: node_name
        replacement: '${1}'
      # 或者直接使用宿主机名（需要替换为实际主机名）
      - target_label: node_name
        replacement: 'your-hostname'  # 替换为实际宿主机名
```

### 2. 使用环境变量动态设置主机名

如果需要在多个主机上部署，可以使用环境变量：

```yaml
scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
    relabel_configs:
      - target_label: node_name
        replacement: '${HOSTNAME}'  # 使用环境变量
```

### 3. 自动获取宿主机名（使用 file_sd_configs）

如果需要自动发现多个节点，可以使用文件服务发现：

```yaml
scrape_configs:
  - job_name: 'node-exporter'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/node-exporter.json'
    relabel_configs:
      - source_labels: [__meta_file_name]
        regex: '(.+)'
        target_label: node_name
```

### 4. 多主机部署示例

如果 Prometheus 和 Node Exporter 不在同一主机：

```yaml
scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: 
          - 'node1.example.com:9100'
          - 'node2.example.com:9100'
          - 'node3.example.com:9100'
    relabel_configs:
      - source_labels: [__address__]
        regex: '([^:]+):.*'
        target_label: node_name
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
```

## 故障排查

### 无法访问指标

1. 检查容器是否正常运行：
```bash
docker-compose ps
```

2. 查看容器日志：
```bash
docker-compose logs node-exporter
```

3. 检查端口是否被占用：
```bash
netstat -tlnp | grep 9100
# 或
ss -tlnp | grep 9100
```

### Prometheus 无法抓取指标

1. 确认 Node Exporter 服务正常运行
2. 检查 Prometheus 配置中的 targets 地址是否正确
3. 如果使用 Docker 网络，确认两个容器在同一网络中
4. 检查防火墙设置

## 安全建议

1. **限制访问**：在生产环境中，建议使用防火墙或反向代理限制对 9100 端口的访问
2. **网络隔离**：将 Node Exporter 放在独立的 Docker 网络中
3. **定期更新**：定期更新 Node Exporter 镜像版本

## 参考资源

- [Node Exporter 官方文档](https://github.com/prometheus/node_exporter)
- [Prometheus 官方文档](https://prometheus.io/docs/)
