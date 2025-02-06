#!/bin/bash

# 生成指定天数内的文件的方法
generate_files() {
    local TARGET_DIR="$1"        # 指定目录
    local GENERATE_DAYS="$2"     # 生成的天数

    # 如果目录不存在，创建该目录
    mkdir -p "$TARGET_DIR"

    # 生成最近 xx 天的文件
    for i in $(seq 0 $GENERATE_DAYS); do
        # 计算日期
        MOD_DATE=$(date -d "-$i days" '+%Y-%m-%d')

        # 生成文件名
        FILE_NAME="test_file_$MOD_DATE.txt"

        # 创建空文件
        touch "$TARGET_DIR/$FILE_NAME"

        # 修改文件的修改时间
        touch -d "$MOD_DATE" "$TARGET_DIR/$FILE_NAME"
    done

    echo "Files generated in $TARGET_DIR with modification dates for the last $GENERATE_DAYS days."
}

# 调用
generate_files "/data/scripts/test2/t3" 180
generate_files "/data/scripts/test2/t4" 90