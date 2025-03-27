#!/bin/bash
# rsync同步备份文件脚本（挂载目录）

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <days> <source_root> <target_root>"
    echo "备份<days>天内<source_root>目录数据至<target_root>目录，删除<target_root>目录<days>天前数据"
    exit 1
fi

readonly DAYS_BACK="$1"
readonly SOURCE_ROOT=$(echo "$2" | sed 's:/\+$::')
readonly TARGET_ROOT=$(echo "$3" | sed 's:/\+$::')
START_TIME=$(date +%Y-%m-%d_%H:%M:%S)
START_TIME_S=`date +%s`

echo "============================="
echo "$START_TIME 备份过去 $DAYS_BACK 天内修改过的数据，源根目录为 '$SOURCE_ROOT',目标根目录为 '$TARGET_ROOT'"
echo "============================="

# 使用find查找过去DAYS_BACK天内修改过的文件，并通过循环处理
find "$SOURCE_ROOT" -type f -mtime -"$DAYS_BACK" -print0 | while IFS= read -r -d '' src_file; do
    relative_path="${src_file#$SOURCE_ROOT/}"
    target_dir="$TARGET_ROOT/$relative_path"
    mkdir -p "$(dirname "$target_dir")"
    rsync -av --progress "$src_file" "$target_dir"
    echo "$END_TIME rsync备份至 $target_dir 完成"
done

echo "开始清理目标目录中超过 $DAYS_BACK 天未修改的文件和文件夹..."
find "$TARGET_ROOT" -type f -mtime "+$DAYS_BACK" -print -delete
find "$TARGET_ROOT" -type d -mtime "+$DAYS_BACK" -empty -print -delete
echo "清理完成。"

END_TIME=$(date +%Y-%m-%d_%H:%M:%S)
END_TIME_S=`date +%s`
SUM_TIME=$(($END_TIME_S - $START_TIME_S))
echo "============================="
echo "$END_TIME 备份及清理完成，耗时 $SUM_TIME 秒 "
echo "============================="
