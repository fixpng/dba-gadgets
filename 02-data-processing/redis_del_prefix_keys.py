#!/usr/bin/env python3
"""
Redis 安全非阻塞前缀键删除工具（中文说明）。

使用示例：
    - 预览（模拟删除，不会真正删除）：
            python redis_del_prefix_keys.py --prefix TOUCH_ANNOTATION_OPT_yg000 --prefix TOUCH_ANNOTATION_OPT_00000 --dry-run

    - 真正删除（必须同时加上 --confirm）：
            python redis_del_prefix_keys.py --prefix TOUCH_ANNOTATION_OPT_yg000 --confirm

主要特性：
    - 使用 SCAN 遍历，避免使用 KEYS 导致阻塞。
    - 使用 UNLINK 批量删除以实现非阻塞删除（当可用时），否则回退到 DEL。
    - 支持分批删除、dry-run 预览以及显式确认参数以保证安全。
"""
from __future__ import annotations

import argparse
import logging
import sys
from typing import Iterable, List

import redis


def delete_prefixes(
    client: redis.Redis,
    prefixes: Iterable[str],
    batch_size: int = 500,
    scan_count: int = 1000,
    use_unlink: bool = True,
    dry_run: bool = True,
) -> int:
    """扫描并删除匹配任一前缀的 key。

    返回删除的键数量（或 dry-run 时将会删除的数量）。
    """
    total = 0

    # 选择删除方式：优先使用 UNLINK（非阻塞），如果不可用则回退到 DEL
    has_unlink = use_unlink and hasattr(client, "unlink")
    delete_name = "UNLINK" if has_unlink else "DEL"

    for prefix in prefixes:
        pattern = f"{prefix}*"
        logging.info("扫描模式 %s", pattern)
        batch: List[bytes] = []
        for key in client.scan_iter(match=pattern, count=scan_count):
            batch.append(key)
            if len(batch) >= batch_size:
                if dry_run:
                    logging.info("dry-run：将 %s %d 个键（前缀=%s)", delete_name, len(batch), prefix)
                else:
                    try:
                        if has_unlink:
                            client.unlink(*batch)
                        else:
                            client.delete(*batch)
                        logging.info("已 %s %d 个键（前缀=%s)", delete_name, len(batch), prefix)
                    except Exception:
                        logging.exception("删除批次失败（前缀=%s)", prefix)
                total += len(batch)
                batch = []

        # 最后剩余的小批次
        if batch:
            if dry_run:
                logging.info("dry-run：将 %s %d 个键（前缀=%s)", delete_name, len(batch), prefix)
            else:
                try:
                    if has_unlink:
                        client.unlink(*batch)
                    else:
                        client.delete(*batch)
                    logging.info("已 %s %d 个键（前缀=%s)", delete_name, len(batch), prefix)
                except Exception:
                    logging.exception("删除最后一批失败（前缀=%s)", prefix)
            total += len(batch)

    return total


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Redis 安全非阻塞前缀键删除工具（支持 dry-run 与批量删除）")
    p.add_argument("--host", default="localhost", help="Redis 主机，默认 localhost")
    p.add_argument("--port", type=int, default=6379, help="Redis 端口，默认 6379")
    p.add_argument("--db", type=int, default=0, help="Redis 数据库编号，默认 0")
    p.add_argument("--password", default=None, help="Redis 密码（如需）")
    p.add_argument("--prefix", action="append", required=True, help="要删除的键前缀，可重复指定多个")
    p.add_argument("--batch-size", type=int, default=500, help="每个批次删除的键数量，默认 500")
    p.add_argument("--scan-count", type=int, default=1000, help="SCAN 的 COUNT 提示，默认 1000（不是严格保证）")
    p.add_argument("--no-unlink", dest="use_unlink", action="store_false", help="即使 Redis 支持也不要使用 UNLINK（强制使用 DEL）")
    p.add_argument("--dry-run", dest="dry_run", action="store_true", default=False, help="模拟执行，显示将被删除的键数量但不实际删除")
    p.add_argument("--confirm", action="store_true", help="确认并执行删除（必须指定以实际删除）")
    p.add_argument("--log-level", default="INFO", help="日志级别，默认 INFO")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level.upper(), logging.INFO), format="%(asctime)s %(levelname)s: %(message)s")

    if not args.dry_run and not args.confirm:
        logging.error("除非使用 --dry-run，否则必须指定 --confirm 才会实际删除。可先使用 --dry-run 预览要删除的键。")
        return 2

    try:
        client = redis.Redis(host=args.host, port=args.port, db=args.db, password=args.password)
        # quick ping to verify connection
        client.ping()
    except Exception:
        logging.exception("无法连接到 Redis：%s:%s db=%s", args.host, args.port, args.db)
        return 3

    deleted = delete_prefixes(
        client,
        prefixes=args.prefix,
        batch_size=args.batch_size,
        scan_count=args.scan_count,
        use_unlink=args.use_unlink,
        dry_run=args.dry_run,
    )

    if args.dry_run:
        logging.info("模拟运行完成。匹配到的键总数：%d", deleted)
    else:
        logging.info("删除完成。请求删除的键总数：%d", deleted)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
