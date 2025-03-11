import os
import sys

"""
files_tree 生成当前目录的树状结构及markdown格式链接。

用法:
    python files_tree.py [--dirs] [--files] [--markdown]

选项:
    --dirs      仅在输出中包含目录。
    --files     仅在输出中包含文件。
    --markdown  以markdown格式输出，目录和文件使用'-'表示。
"""

# 定义文件/目录与描述的映射
description_map = {
    "01-backup-and-archive": "备份和归档",
    "02-data-processing": "数据处理",
    "03-files-processing": "文件处理",
    "04-db-check": "数据库检查",
    "05-db-install": "数据库安装",
}

def tree(directory, padding, only_dirs=False, only_files=False, markdown=False):
    items = os.listdir(directory)
    items.sort()
    
    # 过滤掉指定的文件和目录，并添加描述
    items = [item for item in items if item not in ['.git', 'README.md', 'aaa.md', 'LICENSE']]
    
    for index, item in enumerate(items):
        path = os.path.join(directory, item)
        is_last_item = index == len(items) - 1

        if only_files and os.path.isdir(path):
            continue
        if only_dirs and not os.path.isdir(path):
            continue

        description = description_map.get(item, "")
        if markdown:
            link = f"[{item}]({path.replace(os.sep, '/')})"
            print(padding + ("- " if is_last_item else "- ") + f"{link}{(' | ' + description) if description else ''}")
        else:
            print(padding + ("└── " if is_last_item else "├── ") + f"{item}{(' | ' + description) if description else ''}")

        if os.path.isdir(path):
            if is_last_item:
                tree(path, padding + "    " if not markdown else padding + "  ", only_dirs, only_files, markdown)
            else:
                tree(path, padding + "│   " if not markdown else padding + "  ", only_dirs, only_files, markdown)

# 入口函数
if __name__ == "__main__":
    root_dir = '.'
    only_dirs = '--dirs' in sys.argv
    only_files = '--files' in sys.argv
    markdown = '--markdown' in sys.argv

    print(os.path.basename(os.path.abspath(root_dir)))
    tree(root_dir, '', only_dirs, only_files, markdown)