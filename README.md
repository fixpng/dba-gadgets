# 📚 dba-gadgets
DBA工作中个人编写与搜集的工具脚本整理整合
> A collection of many scripts for database administrator (DBA)
```powershell
dba-gadgets
├── 01-backup-and-archive | 备份和归档
│   ├── mongo_backup_mongodump.sh
│   ├── mysql_backup_mysqldump.sh
│   └── mysql_restore_xtrabackup.py
├── 02-data-processing | 数据处理
│   ├── oracle_clear_tabhwm
│   │   ├── oracle_f_get_part.sql
│   │   ├── oracle_proc_clear_tabhwm.sql
│   │   └── oracle_tb_clear_hwm.sql
│   ├── oracle_job_log
│   │   ├── oracle_proc_job_log.sql
│   │   └── oracle_tb_job_log.sql
│   ├── oracle_proc_Increment_seq.sql
│   ├── oracle_table_tool
│   │   ├── oracle_f_str_split.sql
│   │   ├── oracle_pkg_tab_tool.sql
│   │   └── oracle_tb_tab_tool.sql
│   ├── redis_del_big_list.py
│   └── redis_del_idle_key.py
├── 03-files-processing | 文件处理
│   ├── delete_files.sh
│   ├── files_tree.py
│   ├── generate_test_files.sh
│   ├── hw_rds_download_audit_logs.py
│   └── mysql_to_excel
│       ├── mysql_to_excel.py
│       └── sql.xlsx
└── 04-db-check
    ├── mysql_f_rollback_time_calc.sql
    ├── mysql_pt_slave_repair.py
    └── mysql_reverse_sql.py
```