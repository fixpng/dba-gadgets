# 📚 dba-gadgets
> 自己在DBA工作中编写与搜集的工具脚本整合整理，用法已在各脚本内注明。<br>
> Tools and scripts developed and collected by the DBA in their work, with usage instructions included in each script.<br>
> mysql、oracle、mongo、redis、postgresql、starrocks...

dba-gadgets
- [01-backup-and-archive](./01-backup-and-archive) | 备份和归档
  - [mongo_backup_mongodump.sh](./01-backup-and-archive/mongo_backup_mongodump.sh)
  - [mysql_backup_mysqldump.sh](./01-backup-and-archive/mysql_backup_mysqldump.sh)
  - [mysql_restore_xtrabackup.py](./01-backup-and-archive/mysql_restore_xtrabackup.py)
- [02-data-processing](./02-data-processing) | 数据处理
  - [oracle_clear_tabhwm](./02-data-processing/oracle_clear_tabhwm)
    - [oracle_f_get_part.sql](./02-data-processing/oracle_clear_tabhwm/oracle_f_get_part.sql)
    - [oracle_proc_clear_tabhwm.sql](./02-data-processing/oracle_clear_tabhwm/oracle_proc_clear_tabhwm.sql)
    - [oracle_tb_clear_hwm.sql](./02-data-processing/oracle_clear_tabhwm/oracle_tb_clear_hwm.sql)
  - [oracle_job_log](./02-data-processing/oracle_job_log)
    - [oracle_proc_job_log.sql](./02-data-processing/oracle_job_log/oracle_proc_job_log.sql)
    - [oracle_tb_job_log.sql](./02-data-processing/oracle_job_log/oracle_tb_job_log.sql)
  - [oracle_proc_Increment_seq.sql](./02-data-processing/oracle_proc_Increment_seq.sql)
  - [oracle_table_tool](./02-data-processing/oracle_table_tool)
    - [oracle_f_str_split.sql](./02-data-processing/oracle_table_tool/oracle_f_str_split.sql)
    - [oracle_pkg_tab_tool.sql](./02-data-processing/oracle_table_tool/oracle_pkg_tab_tool.sql)
    - [oracle_tb_tab_tool.sql](./02-data-processing/oracle_table_tool/oracle_tb_tab_tool.sql)
  - [redis_del_big_list.py](./02-data-processing/redis_del_big_list.py)
  - [redis_del_idle_key.py](./02-data-processing/redis_del_idle_key.py)
- [03-files-processing](./03-files-processing) | 文件处理
  - [delete_files.sh](./03-files-processing/delete_files.sh)
  - [files_tree.py](./03-files-processing/files_tree.py)
  - [generate_test_files.sh](./03-files-processing/generate_test_files.sh)
  - [hw_rds_download_audit_logs.py](./03-files-processing/hw_rds_download_audit_logs.py)
  - [mysql_to_excel](./03-files-processing/mysql_to_excel)
    - [mysql_to_excel.py](./03-files-processing/mysql_to_excel/mysql_to_excel.py)
    - [sql.xlsx](./03-files-processing/mysql_to_excel/sql.xlsx)
- [04-db-check](./04-db-check) | 数据库检查
  - [app_batch_management.sh](./04-db-check/app_batch_management.sh)
  - [mysql_f_rollback_time_calc.sql](./04-db-check/mysql_f_rollback_time_calc.sql)
  - [mysql_pt_slave_repair.py](./04-db-check/mysql_pt_slave_repair.py)
  - [mysql_reverse_sql.py](./04-db-check/mysql_reverse_sql.py)
- [05-db-install](./05-db-install) | 数据库安装
  - [mssql_offline_install.sh](./05-db-install/mssql_offline_install.sh)
  - [mysql_generic_install.sh](./05-db-install/mysql_generic_install.sh)
  - [oracle_shell_install.sh](./05-db-install/oracle_shell_install.sh)
  - [pg_souece_install.sh](./05-db-install/pg_souece_install.sh)