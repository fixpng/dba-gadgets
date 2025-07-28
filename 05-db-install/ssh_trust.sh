#!/bin/bash
# SSH 一键互信配置脚本
# Author: LuciferLiu
# Description: 自动配置 SSH 互信，支持多主机批量配置，增强错误报告和调试功能
# https://www.modb.pro/db/1943277099851198464

set -e

# 全局调试开关
DEBUG_MODE=false

# 调试输出函数
function debug_log() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "DEBUG: $*" >&2
    fi
}

# 日志级别颜色
INFO_COLOR='\E[1;34m'    # 蓝色
SUCCESS_COLOR='\E[1;32m' # 绿色
WARNING_COLOR='\E[1;33m' # 黄色
ERROR_COLOR='\E[1;31m'   # 红色
RESET='\E[0m'

# 统一日志输出函数
function log() {
    local level=$1
    shift
    local message="$*"
    local color=""

    case "$level" in
    "info") color="$INFO_COLOR" ;;
    "success") color="$SUCCESS_COLOR" ;;
    "warning") color="$WARNING_COLOR" ;;
    "error") color="$ERROR_COLOR" ;;
    *) color="$RESET" ;;
    esac

    # 转换为大写（兼容老版本bash）
    local upper_level=$(echo "$level" | tr '[:lower:]' '[:upper:]')
    printf "${color}[%s] %s${RESET}\n" "$upper_level" "$message"
}

function check_ssh_connection() {
    local target_user=$1
    local target_ip=$2
    local current_user=$3
    local port=${4:-22}
    local timeout_seconds=10

    debug_log "开始检查连接 $target_user@$target_ip:$port"

    # 首先检查端口是否可达
    debug_log "检查端口连通性..."
    if ! nc -z -w 3 "$target_ip" "$port" 2>/dev/null; then
        debug_log "端口不可达"
        echo "port_unreachable"
        return 1
    fi
    debug_log "端口可达"

    # 根据当前用户和目标用户决定执行方式
    local ssh_result
    local ssh_exit_code
    
    if [[ "$current_user" == "$target_user" ]]; then
        debug_log "当前用户就是目标用户，直接执行SSH检查"
        # 当前用户就是目标用户，直接执行
        set +e  # 临时关闭错误退出
        ssh_result=$(timeout 15 ssh -q -o BatchMode=yes -o ConnectTimeout=$timeout_seconds \
            -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey \
            -p "$port" "$target_ip" echo "connected" 2>&1)
        ssh_exit_code=$?
        set -e  # 重新启用错误退出
        debug_log "SSH命令执行完成，退出码: $ssh_exit_code"
    else
        debug_log "需要切换到用户 $target_user"
        # 检查目标用户是否存在
        if ! id "$target_user" &>/dev/null; then
            debug_log "用户 $target_user 不存在"
            echo "user_not_exist"
            return 1
        fi
        debug_log "用户 $target_user 存在，开始切换用户执行SSH检查"
        
        # 使用 su 切换用户执行，添加超时控制
        set +e  # 临时关闭错误退出
        ssh_result=$(timeout 15 su -s /bin/bash "$target_user" -c \
            "ssh -q -o BatchMode=yes -o ConnectTimeout=$timeout_seconds \
             -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey \
             -p $port $target_ip echo connected" 2>&1)
        ssh_exit_code=$?
        set -e  # 重新启用错误退出
        debug_log "su+SSH命令执行完成，退出码: $ssh_exit_code"
        
        # 检查是否因为超时而失败
        if [ $ssh_exit_code -eq 124 ]; then
            debug_log "命令超时"
            echo "timeout"
            return 1
        fi
    fi

    debug_log "SSH结果: '$ssh_result'"
    
    # 分析SSH连接结果
    if [[ $ssh_exit_code -eq 0 && "$ssh_result" == "connected" ]]; then
        debug_log "SSH连接成功"
        echo "success"
        return 0
    else
        debug_log "SSH连接失败，分析错误信息"
        # 根据错误信息提供具体的失败原因
        if echo "$ssh_result" | grep -q "Permission denied"; then
            debug_log "权限拒绝"
            echo "permission_denied"
        elif echo "$ssh_result" | grep -q "Connection refused"; then
            debug_log "连接被拒绝"
            echo "connection_refused"
        elif echo "$ssh_result" | grep -q "Connection timed out"; then
            debug_log "连接超时"
            echo "connection_timeout"
        elif echo "$ssh_result" | grep -q "Host key verification failed"; then
            debug_log "主机密钥验证失败"
            echo "host_key_failed"
        elif echo "$ssh_result" | grep -q "No route to host"; then
            debug_log "无路由到主机"
            echo "no_route"
        else
            debug_log "其他错误，归类为需要配置"
            echo "need_configuration"
        fi
        return 1
    fi
}

# 配置 SSH 互信 - 增强错误报告
function setup_ssh_trust() {
    local target_user=$1
    local target_group=$(id -gn $target_user)
    local password="$2"
    local current_user=$3
    local port=$4
    shift 4
    local ips=("$@")
    local failed_ips=()

    # 设置 SSH 目录路径
    local ssh_dir
    [[ "$target_user" == "root" ]] && ssh_dir="/root/.ssh" || ssh_dir="/home/$target_user/.ssh"

    log info "准备用户 $target_user 的 SSH 配置"

    # 清理并重建 SSH 目录
    if [[ "$current_user" == "root" ]]; then
        rm -rf "$ssh_dir" >/dev/null 2>&1 || true
        mkdir -p "$ssh_dir"
        chown "$target_user":"$target_group" "$ssh_dir"
        chmod 755 "$ssh_dir"
    else
        # 普通用户操作自己的目录
        rm -rf "$ssh_dir" >/dev/null 2>&1 || true
        mkdir -p "$ssh_dir"
        chmod 755 "$ssh_dir"
    fi

    # 生成 SSH 密钥 - 根据用户类型选择不同方式
    log info "生成 SSH 密钥对"
    if [[ "$current_user" == "$target_user" ]]; then
        # 当前用户就是目标用户
        ssh-keygen -t rsa -f "$ssh_dir/id_rsa" -N '' >/dev/null 2>&1
        cat "$ssh_dir/id_rsa.pub" >>"$ssh_dir/authorized_keys"
        chmod 644 "$ssh_dir/authorized_keys"
    elif [[ "$current_user" == "root" ]]; then
        # root 用户为目标用户生成密钥
        su -s /bin/bash "$target_user" -c "ssh-keygen -t rsa -f '$ssh_dir/id_rsa' -N ''" >/dev/null 2>&1
        su -s /bin/bash "$target_user" -c "cat '$ssh_dir/id_rsa.pub' >> '$ssh_dir/authorized_keys'"
        su -s /bin/bash "$target_user" -c "chmod 644 '$ssh_dir/authorized_keys'"
    else
        log error "无法为用户 $target_user 生成密钥"
        return 1
    fi

    # 收集所有目标主机公钥到 known_hosts
    log info "收集所有目标主机的公钥到 known_hosts"
    if [[ "$current_user" == "$target_user" || "$current_user" == "root" ]]; then
        # 确保 known_hosts 文件存在
        touch "$ssh_dir/known_hosts"

        # 收集所有主机的公钥（带哈希格式）
        for target_ip in "${ips[@]}"; do
            log info "  收集 $target_ip:$port 的公钥"
            if ! ssh-keyscan -p "$port" -H "$target_ip" 2>/dev/null >>"$ssh_dir/known_hosts"; then
                log warning "  ⚠ 无法收集 $target_ip:$port 的公钥，主机可能不可达"
            fi
        done

        # 设置权限
        if [[ "$current_user" == "root" ]]; then
            chown "$target_user":"$target_group" "$ssh_dir/known_hosts"
        fi

        # 设置权限
        chmod 644 "$ssh_dir/known_hosts"
    else
        log warning "跳过 known_hosts 配置（需要 root 或目标用户权限）"
    fi

    # 逐个主机配置SSH互信
    for target_ip in "${ips[@]}"; do
        log info "➔ 正在配置主机: $target_ip:$port"

        # 首先检查网络连通性
        if ! nc -z -w 3 "$target_ip" "$port" 2>/dev/null; then
            log error "  ✗ $target_ip:$port - 网络不可达，跳过配置"
            failed_ips+=("$target_ip")
            continue
        fi

        # 使用 expect 自动处理密码输入
        local expect_result
        expect_result=$(
            expect <<EOF 2>&1
set timeout 30
spawn scp -o StrictHostKeyChecking=no -P "$port" -r "$ssh_dir" $target_user@$target_ip:~
expect {
    "Are you sure you want to continue connecting*" { 
        send "yes\r"
        exp_continue 
    }
    "*password:" { 
        send -- "$password\r"
        exp_continue 
    }
    "Password:" { 
        send -- "$password\r"
        exp_continue 
    }
    "password for*" { 
        send -- "$password\r"
        exp_continue 
    }
    "Permission denied*" {
        puts "ERROR_PERMISSION_DENIED"
        exit 1
    }
    "Connection refused*" {
        puts "ERROR_CONNECTION_REFUSED"
        exit 1
    }
    "Connection timed out*" {
        puts "ERROR_CONNECTION_TIMEOUT"
        exit 1
    }
    "No route to host*" {
        puts "ERROR_NO_ROUTE"
        exit 1
    }
    eof { 
        exit 0 
    }
    timeout { 
        puts "ERROR_TIMEOUT"
        exit 1 
    }
}
EOF
        )
        local expect_exit_code=$?

        # 根据expect的执行结果提供详细的错误信息
        if [[ $expect_exit_code -eq 0 ]]; then
            log success "  ✓ 主机 $target_ip:$port 配置成功"
        else
            case "$expect_result" in
            *"ERROR_PERMISSION_DENIED"*)
                log error "  ✗ $target_ip:$port - 权限拒绝，请检查用户名和密码"
                ;;
            *"ERROR_CONNECTION_REFUSED"*)
                log error "  ✗ $target_ip:$port - 连接被拒绝，SSH服务可能未运行"
                ;;
            *"ERROR_CONNECTION_TIMEOUT"*)
                log error "  ✗ $target_ip:$port - 连接超时，网络不可达或防火墙阻止"
                ;;
            *"ERROR_NO_ROUTE"*)
                log error "  ✗ $target_ip:$port - 无路由到主机，网络配置问题"
                ;;
            *"ERROR_TIMEOUT"*)
                log error "  ✗ $target_ip:$port - 操作超时，主机响应慢或网络不稳定"
                ;;
            *)
                log error "  ✗ $target_ip:$port - 配置失败: $expect_result"
                ;;
            esac
            failed_ips+=("$target_ip")
        fi
    done

    # 返回失败主机列表
    if [ ${#failed_ips[@]} -gt 0 ]; then
        echo "${failed_ips[*]}"
    fi
}

# 验证IP地址格式函数
function validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # 验证每个数字段是否在0-255之间
        IFS='.' read -ra ADDR <<<"$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -lt 0 || $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 读取配置文件函数
function read_config_file() {
    local config_file="$1"
    local ips=()

    if [[ ! -f "$config_file" ]]; then
        log error "配置文件不存在: $config_file"
        exit 1
    fi

    log info "从配置文件读取IP地址: $config_file" >&2

    while IFS= read -r line; do
        # 跳过空行和注释行
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # 去除前后空格
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # 验证IP格式
        if validate_ip "$line"; then
            ips+=("$line")
        else
            log warning "跳过无效IP格式: $line" >&2
        fi
    done <"$config_file"

    if [[ ${#ips[@]} -eq 0 ]]; then
        log error "配置文件中未找到有效的IP地址" >&2
        exit 1
    fi

    log info "从配置文件读取到 ${#ips[@]} 个IP地址" >&2
    echo "${ips[@]}"
}

# 主函数
function main() {
    # 获取当前执行用户
    local current_user=$(whoami)
    local user=""
    local password=""
    local port=22
    local ips=()
    local config_file=""

    # 参数检查
    if [[ $# -lt 1 ]]; then
        echo "用法: $0 [-u 用户名] [-P 端口号] -p 密码 [-i \"IP1,IP2,...\" | -c 配置文件] [-d]"
        echo "参数说明:"
        echo "  -u 用户名    : SSH 连接的用户名（默认为当前用户）"
        echo "  -P 端口号    : SSH 连接的端口号（默认为22）"
        echo "  -p 密码      : SSH 连接的密码"
        echo "  -i IP列表    : 目标主机IP地址，用逗号分隔"
        echo "  -c 配置文件  : 包含IP地址的配置文件路径（每行一个IP）"
        echo "  -d          : 开启调试模式"
        echo ""
        echo "配置文件格式:"
        echo "  # 这是注释行"
        echo "  10.168.1.110"
        echo "  10.168.1.111"
        echo "  10.168.1.112"
        echo ""
        echo "示例1 (命令行IP): $0 -p 'password' -i \"10.168.1.110,10.168.1.111,10.168.1.112\""
        echo "示例2 (配置文件): $0 -p 'password' -c /path/to/hosts.conf"
        echo "示例3 (指定用户): $0 -u root -p 'password' -c /path/to/hosts.conf"
        echo "示例4 (自定义端口): $0 -P 2222 -p 'password' -c /path/to/hosts.conf"
        echo "示例5 (调试模式): $0 -d -p 'password' -c /path/to/hosts.conf"
        exit 1
    fi

    # 解析参数
    while getopts ":u:p:i:P:c:d" opt; do
        case $opt in
        u) user="$OPTARG" ;;
        p) password="$OPTARG" ;;
        i) IFS=',' read -ra ips <<<"$OPTARG" ;;
        P) port="$OPTARG" ;;
        c) config_file="$OPTARG" ;;
        d) DEBUG_MODE=true ;;
        \?)
            echo "无效选项: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "选项 -$OPTARG 需要参数" >&2
            exit 1
            ;;
        esac
    done

    # 如果未指定用户，则使用当前用户
    if [[ -z "$user" ]]; then
        user="$current_user"
        log info "未指定用户，将配置当前用户: $user"
    fi

    # 处理IP地址输入 - 支持配置文件和命令行参数
    if [[ -n "$config_file" && ${#ips[@]} -gt 0 ]]; then
        log error "不能同时使用 -i 和 -c 参数"
        exit 1
    elif [[ -n "$config_file" ]]; then
        # 从配置文件读取IP地址
        local config_ips
        config_ips=$(read_config_file "$config_file")
        read -ra ips <<<"$config_ips"
    elif [[ ${#ips[@]} -eq 0 ]]; then
        log error "必须指定IP地址（使用 -i 或 -c 参数）"
        exit 1
    fi

    # 验证参数
    if [[ -z "$password" || ${#ips[@]} -eq 0 ]]; then
        log error "缺少必要参数: 密码或IP列表"
        exit 1
    fi

    # 检查用户是否存在
    if ! id "$user" &>/dev/null; then
        log error "用户 $user 不存在"
        exit 1
    fi

    # 权限检查
    if [[ "$current_user" != "root" && "$current_user" != "$user" ]]; then
        log error "权限错误:"
        log error "  当前用户: $current_user"
        log error "  目标用户: $user"
        log error "只有 root 用户或目标用户本身才能配置该用户的 SSH 互信"
        exit 1
    fi

    log info "============ SSH 互信配置开始 ============"
    log info "执行用户: $current_user"
    log info "目标用户: $user"
    log info "SSH端口: $port"
    log info "目标主机: ${ips[*]}"

    # 安装依赖
    if ! command -v expect &>/dev/null; then
        log info "安装 expect 工具..."
        if [[ "$current_user" = "root" ]]; then
            yum install -y expect >/dev/null 2>&1 || {
                log error "expect 安装失败"
                exit 1
            }
            log success "expect 安装完成"
        else
            log error "需要 root 权限安装 expect，请使用 sudo 运行脚本"
            exit 1
        fi
    fi


    # 检查互信状态，过滤已配置的主机
    log info "检查现有互信配置..."
    local unconfigured_ips=()
    local configured_count=0
    
    for target_ip in "${ips[@]}"; do
        log info "正在检查 $target_ip..."
        
        # 使用 set +e 确保函数调用不会导致脚本退出
        set +e
        status=$(check_ssh_connection "$user" "$target_ip" "$current_user" "$port")
        check_result=$?
        set -e
        
        debug_log "检查结果: $status (返回码: $check_result)"
        
        if [ "$status" = "success" ]; then
            log success "$target_ip: 已配置互信"
            configured_count=$((configured_count + 1))
        elif [ "$status" = "port_unreachable" ]; then
            log error "$target_ip: 端口不可达或主机无响应"
        elif [ "$status" = "connection_refused" ]; then
            log error "$target_ip: 连接被拒绝，SSH服务可能未运行"
        elif [ "$status" = "connection_timeout" ]; then
            log error "$target_ip: 连接超时，网络不可达或防火墙阻止"
        elif [ "$status" = "user_not_exist" ]; then
            log error "$target_ip: 用户 $user 不存在"
        elif [ "$status" = "timeout" ]; then
            log error "$target_ip: 检查超时"
        elif [ "$status" = "host_key_failed" ]; then
            log error "$target_ip: 主机密钥验证失败"
        elif [ "$status" = "no_route" ]; then
            log error "$target_ip: 无路由到主机，网络配置问题"
        else
            log info "$target_ip: 需要配置互信"
            unconfigured_ips+=("$target_ip")
        fi
    done

    # 如果所有主机都已配置互信，直接显示结果
    if [ ${#unconfigured_ips[@]} -eq 0 ]; then
        log success "所有主机已配置互信，无需操作"
        log info "============ 配置已完成 ============"
        exit 0
    fi

    log info "需要配置互信的主机: ${unconfigured_ips[*]}"

    # 配置互信 - 只配置未成功的主机
    log info "开始配置 SSH 互信..."
    setup_ssh_trust "$user" "$password" "$current_user" "$port" "${unconfigured_ips[@]}"

    # 等待配置完成
    sleep 2

    # ���终互信验证
    log info "----------- 互信验证结果 -----------"
    local success_count=0
    local failed_hosts_list=()

    for target_ip in "${ips[@]}"; do
        status=$(check_ssh_connection "$user" "$target_ip" "$current_user" "$port")
        if [ "$status" = "success" ]; then
            log success "✓ $target_ip 验证通过"
            # 安全的计数器递增
            success_count=$((success_count + 1))
        else
            log error "✗ $target_ip 验证失败"
            failed_hosts_list+=("$target_ip")
        fi
    done

    # 输出最终统计
    log info "-----------------------------------"
    log info "主机总数:   ${#ips[@]}"
    log success "成功数量:   $success_count"
    if [ ${#failed_hosts_list[@]} -gt 0 ]; then
        log error "失败数量:   ${#failed_hosts_list[@]}"
        log warning "失败主机:   ${failed_hosts_list[*]}"
    fi
    log info "==================================="

    if [ $success_count -eq ${#ips[@]} ]; then
        log success "所有主机互信配置成功!"
    else
        log error "部分主机配置失败，请检查!"
        exit 1
    fi
}

main "$@"
