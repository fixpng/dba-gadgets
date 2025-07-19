#!/bin/bash

# Linux磁盘性能测试脚本
# 功能: 全面测试磁盘的读写性能、IOPS、延迟等指标

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
TEST_DIR="/tmp/disk_test"
LOG_FILE="/tmp/disk_performance_$(date +%Y%m%d_%H%M%S).log"
RESULTS_FILE="/tmp/disk_test_results.txt"

# 默认测试参数
TEST_SIZE="1G"
TEST_DURATION="60"
BLOCK_SIZES=("4k" "8k" "16k" "64k" "1M" "4M")
TEST_TYPES=("read" "write" "randread" "randwrite" "randrw")

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $message${NC}" | tee -a "$LOG_FILE"
}

# 打印分隔线
print_separator() {
    echo "================================================================" | tee -a "$LOG_FILE"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查并安装必要工具
install_tools() {
    print_message $BLUE "检查并安装磁盘测试工具..."
    
    # 检查包管理器
    if command_exists apt; then
        PKG_INSTALL="apt install -y"
        UPDATE_CMD="apt update"
    elif command_exists yum; then
        PKG_INSTALL="yum install -y"
        UPDATE_CMD="yum update"
    elif command_exists dnf; then
        PKG_INSTALL="dnf install -y"
        UPDATE_CMD="dnf update"
    else
        print_message $RED "未找到支持的包管理器"
        return 1
    fi
    
    # 安装必要工具
    tools=("fio" "hdparm" "smartctl" "iostat" "iotop")
    
    for tool in "${tools[@]}"; do
        if ! command_exists $tool; then
            print_message $YELLOW "正在安装 $tool..."
            case $tool in
                "fio")
                    sudo $PKG_INSTALL fio >/dev/null 2>&1
                    ;;
                "hdparm")
                    sudo $PKG_INSTALL hdparm >/dev/null 2>&1
                    ;;
                "smartctl")
                    sudo $PKG_INSTALL smartmontools >/dev/null 2>&1
                    ;;
                "iostat"|"iotop")
                    sudo $PKG_INSTALL sysstat iotop >/dev/null 2>&1
                    ;;
            esac
        fi
    done
    
    # 创建测试目录
    mkdir -p "$TEST_DIR"
    
    print_message $GREEN "工具安装完成"
}

# 获取磁盘信息
get_disk_info() {
    print_message $BLUE "获取磁盘基本信息..."
    print_separator
    
    echo "=== 磁盘列表 ===" | tee -a "$LOG_FILE"
    lsblk -d -o NAME,SIZE,MODEL,SERIAL,TYPE | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    echo "=== 文件系统使用情况 ===" | tee -a "$LOG_FILE"
    df -h | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    echo "=== 挂载点信息 ===" | tee -a "$LOG_FILE"
    mount | grep -E "(ext|xfs|btrfs|ntfs)" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 检测测试目录所在的磁盘
    local test_disk=$(df "$TEST_DIR" | tail -1 | awk '{print $1}')
    local test_fs=$(df -T "$TEST_DIR" | tail -1 | awk '{print $2}')
    
    echo "=== 测试目录信息 ===" | tee -a "$LOG_FILE"
    echo "测试目录: $TEST_DIR" | tee -a "$LOG_FILE"
    echo "所在磁盘: $test_disk" | tee -a "$LOG_FILE"
    echo "文件系统: $test_fs" | tee -a "$LOG_FILE"
    echo "可用空间: $(df -h "$TEST_DIR" | tail -1 | awk '{print $4}')" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
}

# 硬盘SMART信息
get_smart_info() {
    print_message $BLUE "获取磁盘SMART信息..."
    print_separator
    
    if ! command_exists smartctl; then
        print_message $RED "smartctl未安装，跳过SMART检查"
        return 1
    fi
    
    echo "=== 磁盘健康状态 ===" | tee -a "$LOG_FILE"
    for disk in $(lsblk -d -n -o NAME | grep -E '^sd|^nvme|^hd'); do
        echo "检查 /dev/$disk:" | tee -a "$LOG_FILE"
        
        # 基本健康状态
        local health=$(sudo smartctl -H /dev/$disk 2>/dev/null | grep "SMART overall-health" | awk '{print $6}')
        if [ "$health" = "PASSED" ]; then
            print_message $GREEN "  健康状态: 良好"
        elif [ -n "$health" ]; then
            print_message $RED "  健康状态: $health"
        else
            echo "  无法获取SMART信息" | tee -a "$LOG_FILE"
        fi
        
        # 温度信息
        local temp=$(sudo smartctl -A /dev/$disk 2>/dev/null | grep -i temperature | head -1 | awk '{print $10}')
        if [ -n "$temp" ]; then
            echo "  温度: ${temp}°C" | tee -a "$LOG_FILE"
        fi
        
        # 通电时间
        local power_on=$(sudo smartctl -A /dev/$disk 2>/dev/null | grep "Power_On_Hours" | awk '{print $10}')
        if [ -n "$power_on" ]; then
            echo "  通电时间: $power_on 小时" | tee -a "$LOG_FILE"
        fi
        
        echo | tee -a "$LOG_FILE"
    done
}

# hdparm硬盘测试
hdparm_test() {
    print_message $BLUE "HDParm硬盘速度测试..."
    print_separator
    
    if ! command_exists hdparm; then
        print_message $RED "hdparm未安装，跳过此测试"
        return 1
    fi
    
    echo "=== HDParm测试结果 ===" | tee -a "$LOG_FILE"
    
    for disk in $(lsblk -d -n -o NAME | grep -E '^sd|^hd' | head -3); do
        echo "测试磁盘: /dev/$disk" | tee -a "$LOG_FILE"
        
        # 缓存读取速度
        echo "缓存读取速度:" | tee -a "$LOG_FILE"
        sudo hdparm -T /dev/$disk | grep "Timing" | tee -a "$LOG_FILE"
        
        # 硬盘读取速度
        echo "硬盘读取速度:" | tee -a "$LOG_FILE"
        sudo hdparm -t /dev/$disk | grep "Timing" | tee -a "$LOG_FILE"
        
        echo | tee -a "$LOG_FILE"
    done
}

# DD测试
dd_test() {
    print_message $BLUE "DD读写速度测试..."
    print_separator
    
    local test_file="$TEST_DIR/dd_test_file"
    
    echo "=== DD测试结果 ===" | tee -a "$LOG_FILE"
    echo "测试文件: $test_file" | tee -a "$LOG_FILE"
    echo "测试大小: $TEST_SIZE" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 写入测试
    echo "顺序写入测试:" | tee -a "$LOG_FILE"
    local write_result=$(dd if=/dev/zero of="$test_file" bs=1M count=1024 oflag=direct 2>&1 | tail -1)
    local write_result=$(dd if=/dev/zero of="$test_file" bs=1M count=1024  2>&1 | tail -1)
    echo "$write_result" | tee -a "$LOG_FILE"
    
    # 清除缓存
    sudo sync && sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
    
    # 读取测试
    echo "顺序读取测试:" | tee -a "$LOG_FILE"
    #local read_result=$(dd if="$test_file" of=/dev/null bs=1M iflag=direct 2>&1 | tail -1)
    local read_result=$(dd if="$test_file" of=/dev/null bs=1M  2>&1 | tail -1)
    echo "$read_result" | tee -a "$LOG_FILE"
    
    # 随机写入测试
    echo "随机写入测试:" | tee -a "$LOG_FILE"
    #local random_write=$(dd if=/dev/urandom of="$test_file" bs=1M count=1024 oflag=direct 2>&1 | tail -1)
    local random_write=$(dd if=/dev/urandom of="$test_file" bs=1M count=1024  2>&1 | tail -1)
    echo "$random_write" | tee -a "$LOG_FILE"
    
    # 清理测试文件
    rm -f "$test_file"
    echo | tee -a "$LOG_FILE"
}

# FIO测试
fio_test() {
    print_message $BLUE "FIO综合性能测试..."
    print_separator
    
    if ! command_exists fio; then
        print_message $RED "fio未安装，跳过此测试"
        return 1
    fi
    
    echo "=== FIO测试结果 ===" | tee -a "$LOG_FILE"
    echo "测试目录: $TEST_DIR" | tee -a "$LOG_FILE"
    echo "测试时间: ${TEST_DURATION}秒" | tee -a "$LOG_FILE"
    echo "测试大小: $TEST_SIZE" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 创建FIO测试配置
    local fio_config="$TEST_DIR/fio_test.conf"
    
    # 顺序读写测试
    echo "1. 顺序读写测试" | tee -a "$LOG_FILE"
    cat > "$fio_config" << EOF
[global]
directory=$TEST_DIR
size=$TEST_SIZE
runtime=$TEST_DURATION
time_based=1
group_reporting=1
ioengine=libaio
iodepth=32


[seq-read]
rw=read
bs=1M
numjobs=1

[seq-write]
rw=write
bs=1M
numjobs=1
EOF
    
    fio "$fio_config" --output-format=normal 2>/dev/null | grep -E "(read|write|IOPS|BW)" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 随机读写测试
    echo "2. 随机读写测试 (4K)" | tee -a "$LOG_FILE"
    cat > "$fio_config" << EOF
[global]
directory=$TEST_DIR
size=$TEST_SIZE
runtime=$TEST_DURATION
time_based=1
group_reporting=1
ioengine=libaio
iodepth=32


[random-read]
rw=randread
bs=4k
numjobs=1

[random-write]
rw=randwrite
bs=4k
numjobs=1
EOF
    
    fio "$fio_config" --output-format=normal 2>/dev/null | grep -E "(read|write|IOPS|BW)" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 混合读写测试
    echo "3. 混合读写测试 (70%读/30%写)" | tee -a "$LOG_FILE"
    cat > "$fio_config" << EOF
[global]
directory=$TEST_DIR
size=$TEST_SIZE
runtime=$TEST_DURATION
time_based=1
group_reporting=1
ioengine=libaio
iodepth=32


[mixed-rw]
rw=randrw
rwmixread=70
bs=4k
numjobs=1
EOF
    
    fio "$fio_config" --output-format=normal 2>/dev/null | grep -E "(read|write|IOPS|BW)" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 不同块大小测试
    echo "4. 不同块大小性能测试" | tee -a "$LOG_FILE"
    for bs in "${BLOCK_SIZES[@]}"; do
        echo "块大小: $bs" | tee -a "$LOG_FILE"
        cat > "$fio_config" << EOF
[global]
directory=$TEST_DIR
size=512M
runtime=30
time_based=1
group_reporting=1
ioengine=libaio
iodepth=16


[test-$bs]
rw=randread
bs=$bs
numjobs=1
EOF
        
        fio "$fio_config" --output-format=normal 2>/dev/null | grep -E "(IOPS|BW)" | head -2 | tee -a "$LOG_FILE"
        echo | tee -a "$LOG_FILE"
    done
    
    # 延迟测试
    echo "5. 延迟测试" | tee -a "$LOG_FILE"
    cat > "$fio_config" << EOF
[global]
directory=$TEST_DIR
size=512M
runtime=30
time_based=1
group_reporting=1
ioengine=libaio
iodepth=1


[latency-test]
rw=randread
bs=4k
numjobs=1
EOF
    
    fio "$fio_config" --output-format=normal 2>/dev/null | grep -E "(lat|clat)" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 清理配置文件
    rm -f "$fio_config"
}

# 实时IO监控
io_monitor() {
    print_message $BLUE "实时IO监控测试..."
    print_separator
    
    if ! command_exists iostat; then
        print_message $RED "iostat未安装，跳过此测试"
        return 1
    fi
    
    echo "=== 当前IO状态 ===" | tee -a "$LOG_FILE"
    iostat -x 1 3 | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 在后台运行IO压力测试并监控
    echo "=== IO压力测试监控 ===" | tee -a "$LOG_FILE"
    echo "启动后台IO压力测试..." | tee -a "$LOG_FILE"
    
    # 启动后台IO任务
    #dd if=/dev/zero of="$TEST_DIR/io_stress_test" bs=1M count=2048 oflag=direct >/dev/null 2>&1 &
    dd if=/dev/zero of="$TEST_DIR/io_stress_test" bs=1M count=2048  >/dev/null 2>&1 &
    local dd_pid=$!
    
    # 监控IO状态
    iostat -x 2 5 | tee -a "$LOG_FILE"
    
    # 等待后台任务完成
    wait $dd_pid 2>/dev/null
    rm -f "$TEST_DIR/io_stress_test"
    
    echo "IO压力测试完成" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
}

# 文件系统性能测试
filesystem_test() {
    print_message $BLUE "文件系统性能测试..."
    print_separator
    
    echo "=== 文件系统性能测试 ===" | tee -a "$LOG_FILE"
    
    # 创建大量小文件测试
    echo "1. 小文件创建测试 (1000个4KB文件)" | tee -a "$LOG_FILE"
    local small_files_dir="$TEST_DIR/small_files"
    mkdir -p "$small_files_dir"
    
    local start_time=$(date +%s.%N)
    for i in {1..1000}; do
        dd if=/dev/zero of="$small_files_dir/file_$i" bs=4k count=1 >/dev/null 2>&1
    done
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "创建1000个文件用时: ${duration}秒" | tee -a "$LOG_FILE"
    
    # 删除小文件测试
    start_time=$(date +%s.%N)
    rm -rf "$small_files_dir"
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc)
    echo "删除1000个文件用时: ${duration}秒" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
    
    # 目录操作测试
    echo "2. 目录操作测试" | tee -a "$LOG_FILE"
    local dir_test="$TEST_DIR/dir_test"
    
    start_time=$(date +%s.%N)
    for i in {1..100}; do
        mkdir -p "$dir_test/dir_$i"
    done
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc)
    echo "创建100个目录用时: ${duration}秒" | tee -a "$LOG_FILE"
    
    rm -rf "$dir_test"
    echo | tee -a "$LOG_FILE"
}

# 生成性能报告
generate_report() {
    print_message $BLUE "生成磁盘性能报告..."
    print_separator
    
    echo "=== 磁盘性能测试报告 ===" | tee -a "$RESULTS_FILE"
    echo "测试时间: $(date)" | tee -a "$RESULTS_FILE"
    echo "测试主机: $(hostname)" | tee -a "$RESULTS_FILE"
    echo "测试目录: $TEST_DIR" | tee -a "$RESULTS_FILE"
    echo | tee -a "$RESULTS_FILE"
    
    # 从日志中提取关键性能指标
    echo "=== 关键性能指标 ===" | tee -a "$RESULTS_FILE"
    
    # DD测试结果
    echo "DD测试结果:" | tee -a "$RESULTS_FILE"
    grep -A 1 "顺序写入测试:" "$LOG_FILE" | grep -E "(MB/s|GB/s)" | tee -a "$RESULTS_FILE"
    grep -A 1 "顺序读取测试:" "$LOG_FILE" | grep -E "(MB/s|GB/s)" | tee -a "$RESULTS_FILE"
    echo | tee -a "$RESULTS_FILE"
    
    # FIO测试结果摘要
    echo "FIO测试结果摘要:" | tee -a "$RESULTS_FILE"
    grep -E "(read|write).*BW=" "$LOG_FILE" | head -10 | tee -a "$RESULTS_FILE"
    echo | tee -a "$RESULTS_FILE"
    
    # 函数用于提取速度并转换为 MB/s
    # 参数1: 包含速度信息的字符串，例如 "1.2 GB/s" 或 "500 MB/s"
    # 返回值: 转换为 MB/s 的浮点数
    convert_to_mbps() {
        local speed_str="$1"
        local value=$(echo "$speed_str" | awk '{print $1}')
        local unit=$(echo "$speed_str" | awk '{print $2}')
        local mbps_value=""

        case "$unit" in
            "KB/s")
                mbps_value=$(echo "scale=2; $value / 1024" | bc -l)
                ;;
            "MB/s")
                mbps_value="$value"
                ;;
            "GB/s")
                mbps_value=$(echo "scale=2; $value * 1024" | bc -l)
                ;;
            *)
                echo "0" # 无法识别的单位，返回0
                ;;
        esac
        echo "$mbps_value"
    }

    # 简单的性能评估逻辑
    # 提取原始速度字符串（包含数值和单位）
    local raw_seq_read_speed_str=$(grep "顺序读取测试:" -A 1 "$LOG_FILE" | grep -oE "[0-9.]+\s*(MB/s|GB/s|KB/s)" | head -1)
    local raw_seq_write_speed_str=$(grep "顺序写入测试:" -A 1 "$LOG_FILE" | grep -oE "[0-9.]+\s*(MB/s|GB/s|KB/s)" | head -1)

    # 将提取到的原始速度字符串转换为 MB/s 进行比较
    local seq_read_speed_mbps=$(convert_to_mbps "$raw_seq_read_speed_str")
    local seq_write_speed_mbps=$(convert_to_mbps "$raw_seq_write_speed_str")

    echo "=== 性能评估 ===" | tee -a "$RESULTS_FILE"

    if [ -n "$raw_seq_read_speed_str" ]; then
        if (( $(echo "$seq_read_speed_mbps > 100" | bc -l) )); then
            echo "顺序读取性能: 优秀 (${raw_seq_read_speed_str})" | tee -a "$RESULTS_FILE"
        elif (( $(echo "$seq_read_speed_mbps > 50" | bc -l) )); then
            echo "顺序读取性能: 良好 (${raw_seq_read_speed_str})" | tee -a "$RESULTS_FILE"
        else
            echo "顺序读取性能: 一般 (${raw_seq_read_speed_str})" | tee -a "$RESULTS_FILE"
        fi
    fi

    if [ -n "$raw_seq_write_speed_str" ]; then
        if (( $(echo "$seq_write_speed_mbps > 100" | bc -l) )); then
            echo "顺序写入性能: 优秀 (${raw_seq_write_speed_str})" | tee -a "$RESULTS_FILE"
        elif (( $(echo "$seq_write_speed_mbps > 50" | bc -l) )); then
            echo "顺序写入性能: 良好 (${raw_seq_write_speed_str})" | tee -a "$RESULTS_FILE"
        else
            echo "顺序写入性能: 一般 (${raw_seq_write_speed_str})" | tee -a "$RESULTS_FILE"
        fi
    fi

    echo | tee -a "$RESULTS_FILE"
    
    # 文件位置
    echo "=== 测试文件位置 ===" | tee -a "$RESULTS_FILE"
    echo "详细日志: $LOG_FILE" | tee -a "$RESULTS_FILE"
    echo "测试报告: $RESULTS_FILE" | tee -a "$RESULTS_FILE"
    echo | tee -a "$RESULTS_FILE"
    
    print_message $GREEN "性能报告生成完成!"
    echo "详细报告查看: cat $RESULTS_FILE"


}

# 清理测试文件
cleanup() {
    print_message $BLUE "清理测试文件..."
    
    # 删除测试目录中的文件
    find "$TEST_DIR" -type f -name "*test*" -delete 2>/dev/null
    
    # 如果目录为空则删除
    if [ -d "$TEST_DIR" ] && [ -z "$(ls -A "$TEST_DIR")" ]; then
        rmdir "$TEST_DIR"
    fi
    
    print_message $GREEN "清理完成"
}

# 显示帮助信息
show_help() {
    echo "Linux磁盘性能测试脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -d, --directory DIR    指定测试目录 (默认: /tmp/disk_test)"
    echo "  -s, --size SIZE        指定测试文件大小 (默认: 1G)"
    echo "  -t, --time TIME        指定测试时间 (默认: 60秒)"
    echo "  -q, --quick            快速测试模式 (减少测试时间)"
    echo "  -h, --help             显示帮助信息"
    echo
    echo "示例:"
    echo "  $0                     # 使用默认参数测试"
    echo "  $0 -d /home/test       # 指定测试目录"
    echo "  $0 -s 2G -t 30         # 指定文件大小和测试时间"
    echo "  $0 -q                  # 快速测试"
}

# 参数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--directory)
                TEST_DIR="$2"
                shift 2
                ;;
            -s|--size)
                TEST_SIZE="$2"
                shift 2
                ;;
            -t|--time)
                TEST_DURATION="$2"
                shift 2
                ;;
            -q|--quick)
                TEST_SIZE="512M"
                TEST_DURATION="30"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_message $RED "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 解析参数
    parse_args "$@"
    
    # 开始测试
    print_message $GREEN "开始磁盘性能测试..."
    echo "测试开始时间: $(date)" | tee -a "$LOG_FILE"
    echo "测试参数: 目录=$TEST_DIR, 大小=$TEST_SIZE, 时间=${TEST_DURATION}秒" | tee -a "$LOG_FILE"
    print_separator
    
    # 检查权限
    if [ "$EUID" -ne 0 ]; then
        print_message $YELLOW "建议使用root权限运行以获得更准确的结果"
    fi
    
    # 创建测试目录
    mkdir -p "$TEST_DIR"
    
    # 检查磁盘空间
    local available_space=$(df "$TEST_DIR" | tail -1 | awk '{print $4}')
    local test_size_kb=$(echo "$TEST_SIZE" | sed 's/G/*1024*1024/g; s/M/*1024/g; s/K//g' | bc)
    
    if [ "$available_space" -lt "$test_size_kb" ]; then
        print_message $RED "磁盘空间不足，需要至少 $TEST_SIZE 空间"
        exit 1
    fi
    
    # 安装工具
    install_tools
    
    # 执行测试
    get_disk_info
    get_smart_info
    hdparm_test
    dd_test
    fio_test
    io_monitor
    filesystem_test
    
    # 生成报告
    generate_report
    
    # 清理
    cleanup
    
    print_message $GREEN "磁盘性能测试完成!"
    echo "查看详细结果: cat $RESULTS_FILE"
}

# 信号处理
trap 'print_message $RED "测试被中断，正在清理..."; cleanup; exit 1' INT TERM

# 检查bc命令
if ! command_exists bc; then
    echo "警告: bc命令未找到，部分计算功能可能不可用"
fi

# 执行主函数
main "$@"