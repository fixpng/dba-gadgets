#!/bin/bash
# app_batch_management 批量启停状态查看 docker/systemctl 管理的应用，个人用于 ansible 分发执行
# ```
# chmod +x /data/scripts/app_batch_management.sh
# /data/scripts/app_batch_management.sh  "ps8|ps57|redis|mysql|mongo|nebula|starrocks|postgresql|apollo-db" status
# ```

# 获取匹配关键词和操作类型
keywords=$1
action=$2

# 检查关键词和操作类型是否为空
if [ -z "$keywords" ] || [ -z "$action" ]; then
    echo "用法: $0 <keywords> {stop|status|start|restart}"
    echo "示例: $0 \"ps8|ps57|redis|mysql|mongo|nebula|starrocks|postgresql|apollo-db\" status"
    exit 1
fi

# 打印匹配关键词
echo "匹配的关键词: $keywords"

# Docker部分
case $action in
  stop)
    echo "正在停止 Docker 容器..."
    containers=$(docker ps --format '{{.Names}}' | grep -Ei "$keywords")
    if [ -n "$containers" ]; then
        echo "$containers" | xargs -I {} sh -c 'echo "正在停止容器: {}"; docker stop {}'
    else
        echo "未找到匹配的 Docker 容器。"
    fi
    ;;
  status)
    echo "检查 Docker 容器状态..."
    all_containers=$(docker ps -a --format '{{.Names}}: {{.Status}}' | grep -Ei "$keywords")
    if [ -n "$all_containers" ]; then
        echo "$all_containers"
    else
        echo "未找到匹配的 Docker 容器。"
    fi
    ;;
  start)
    echo "正在启动 Docker 容器..."
    containers=$(docker ps -a --format '{{.Names}}' | grep -Ei "$keywords")
    if [ -n "$containers" ]; then
        for container in $containers; do
            if docker ps --format '{{.Names}}' | grep -Ewi "$container"; then
                echo "容器 $container 已在运行中。"
            else
                echo "正在启动容器: $container"
                docker start "$container"
            fi
        done
    else
        echo "未找到匹配的 Docker 容器。"
    fi
    ;;
  restart)
    echo "正在重启 Docker 容器..."
    containers=$(docker ps -a --format '{{.Names}}' | grep -Ei "$keywords")
    if [ -n "$containers" ]; then
        echo "$containers" | xargs -I {} sh -c 'echo "正在重启容器: {}"; docker restart {}'
    else
        echo "未找到匹配的 Docker 容器。"
    fi
    ;;
  *)
    echo "无效的操作。用法: $0 <keywords> {stop|status|start|restart}"
    exit 1
    ;;
esac

# Systemd部分
case $action in
  stop)
    echo "正在停止 Systemd 服务..."
    services=$(systemctl list-units --type service --state=active | grep -oEi "$keywords")
    if [ -n "$services" ]; then
        echo "$services" | xargs -I {} sh -c 'echo "正在停止服务: {}"; systemctl stop {}'
    else
        echo "未找到匹配的正在运行的 Systemd 服务。"
    fi
    ;;
  status)
    echo "检查 Systemd 服务状态..."
    active_services=$(systemctl list-units --type service --state=active | grep -Ei "$keywords")
    inactive_services=$(systemctl list-units --type service --state=inactive | grep -Ei "$keywords")
    dead_services=$(systemctl list-units --type service --state=failed | grep -Ei "$keywords")
    
    if [ -n "$active_services" ]; then
        echo "运行中的服务:"
        echo "$active_services"
    else
        echo "未找到运行中的 Systemd 服务。"
    fi
    
    if [ -n "$inactive_services" ]; then
        echo "未激活的服务:"
        echo "$inactive_services"
    else
        echo "未找到未激活的 Systemd 服务。"
    fi
    
    if [ -n "$dead_services" ]; then
        echo "已停止的服务:"
        echo "$dead_services"
    else
        echo "未找到已停止的 Systemd 服务。"
    fi
    ;;
  start)
    echo "正在启动 Systemd 服务..."
    inactive_services=$(systemctl list-units --type service --state=inactive | grep -oEi "$keywords")
    dead_services=$(systemctl list-units --type service --state=failed | grep -oEi "$keywords")
    
    if [ -n "$inactive_services" ]; then
        for service in $inactive_services; do
            if systemctl is-active --quiet "$service"; then
                echo "服务 $service 已在运行中。"
            else
                echo "正在启动服务: $service"
                systemctl start "$service"
            fi
        done
    fi
    
    if [ -n "$dead_services" ]; then
        for service in $dead_services; do
            echo "正在启动已停止的服务: $service"
            systemctl start "$service"
        done
    fi
    
    if [ -z "$inactive_services" ] && [ -z "$dead_services" ]; then
        echo "未找到匹配的 Systemd 服务。"
    fi
    ;;
  restart)
    echo "正在重启 Systemd 服务..."
    active_services=$(systemctl list-units --type service --state=active | grep -oEi "$keywords")
    inactive_services=$(systemctl list-units --type service --state=inactive | grep -oEi "$keywords")
    dead_services=$(systemctl list-units --type service --state=failed | grep -oEi "$keywords")
    
    if [ -n "$active_services" ]; then
        echo "$active_services" | xargs -I {} sh -c 'echo "正在重启服务: {}"; systemctl restart {}'
    fi
    
    if [ -n "$inactive_services" ]; then
        for service in $inactive_services; do
            echo "正在重启未激活的服务: $service"
            systemctl restart "$service"
        done
    fi
    
    if [ -n "$dead_services" ]; then
        for service in $dead_services; do
            echo "正在重启已停止的服务: $service"
            systemctl restart "$service"
        done
    fi
    
    if [ -z "$active_services" ] && [ -z "$inactive_services" ] && [ -z "$dead_services" ]; then
        echo "未找到匹配的 Systemd 服务。"
    fi
    ;;
  *)
    echo "无效的操作。用法: $0 <keywords> {stop|status|start|restart}"
    exit 1
    ;;
esac
