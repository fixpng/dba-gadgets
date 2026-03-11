---
title: "Docker Compose"
description: "使用 Docker Compose 方式部署夜莺监控项目，快速启动进程做测试。"
lead: ""
date: 2020-11-12T13:26:54+01:00
lastmod: 2025-05-31T10:50:43.970+08:00
draft: false
images: []
menu:
  docs:
    parent: "install"
weight: 300
toc: true
---

## 下载

参考[二进制安装](https://n9e.github.io/zh/docs/install/binary/)章节，下载夜莺监控的发布包，里面会有 Docker compose 相关的配置文件，也可以直接下载夜莺的源码仓库，里面也可以找到 Docker compose 的配置文件。

## 启动

不管是下载发布包还是源码仓库，解压缩之后都会有一个 `docker/compose-bridge` 目录，进入这个目录执行 `docker-compose up -d` 命令即可（国内网络，镜像下载可能会失败，您需要自行解决科学上网的问题）。

```bash
root@ubuntu-linux-22-04-desktop:/opt/n9e/docker/compose-bridge# docker compose up -d
[+] Running 5/5
 ✔ Container victoriametrics  Started                                                                                                                                                                            0.6s
 ✔ Container redis            Started                                                                                                                                                                            0.6s
 ✔ Container mysql            Started                                                                                                                                                                            0.6s
 ✔ Container nightingale      Started                                                                                                                                                                            0.2s
 ✔ Container categraf         Started                                                                                                                                                                            0.2s
root@ubuntu-linux-22-04-desktop:/opt/n9e/docker/compose-bridge# docker compose ps
NAME              IMAGE                                                      COMMAND                  SERVICE           CREATED         STATUS         PORTS
categraf          m.daocloud.io/docker.io/flashcatcloud/categraf:latest      "/entrypoint.sh"         categraf          2 minutes ago   Up 3 seconds
mysql             mysql:8                                                    "docker-entrypoint.s…"   mysql             2 minutes ago   Up 4 seconds   0.0.0.0:3306->3306/tcp, :::3306->3306/tcp, 33060/tcp
nightingale       m.daocloud.io/docker.io/flashcatcloud/nightingale:latest   "sh -c /app/n9e"         nightingale       2 minutes ago   Up 3 seconds   0.0.0.0:17000->17000/tcp, :::17000->17000/tcp, 0.0.0.0:20090->20090/tcp, :::20090->20090/tcp
redis             redis:6.2                                                  "docker-entrypoint.s…"   redis             2 minutes ago   Up 4 seconds   0.0.0.0:6379->6379/tcp, :::6379->6379/tcp
victoriametrics   victoriametrics/victoria-metrics:v1.79.12                  "/victoria-metrics-p…"   victoriametrics   2 minutes ago   Up 4 seconds   0.0.0.0:8428->8428/tcp, :::8428->8428/tcp
```

Docker compose 启动了多个容器，分别是：

- `victoriametrics`：时序数据库，和 Prometheus 兼容，性能更好
- `redis`：缓存数据库，夜莺使用 Redis 来存储 jwt token 和机器的心跳元信息
- `mysql`：关系型数据库，夜莺使用 MySQL 来存储用户信息、告警规则、仪表盘等配置类数据
- `nightingale`：夜莺监控的核心服务
- `categraf`：监控数据采集器，负责采集主机的 CPU、内存、磁盘等指标数据

## 登录

使用浏览器访问 [http://localhost:17000](http://localhost:17000) 打开夜莺监控的页面，默认用户名是 `root`，默认密码是 `root.2020`。

> 请把 localhost 替换成你的服务器 IP 地址。

## 集群模式

集群模式下，多个 `n9e` 要共享同一套 MySQL 和 Redis，所以就不能简单的使用默认的 Docker compose 了，您需要修改 `etc-nightingale` 目录下的 `config.toml` 配置文件，配置统一的 MySQL 和 Redis 的连接信息。

## 边缘模式

边缘模式需要用到 `n9e-edge` 进程，不过社区并未提供 `n9e-edge` 的 Docker 镜像，所以边缘模式下还是需要使用[二进制方式](https://n9e.github.io/zh/docs/prologue/architecture/#%E8%BE%B9%E7%BC%98%E6%A8%A1%E5%BC%8F)部署 n9e-edge 进程。边缘模式的详细说明请参考：[夜莺监控 - 边缘告警引擎架构详解](/zh/docs/prologue/architecture/#边缘模式)。
