# 📚 dba-gadgets
- 自己在DBA工作中编写与搜集的通用工具脚本整合整理，用法已在各脚本内注明。
- Tools and scripts developed and collected by the DBA in their work, with usage instructions included in each script.
- mysql、oracle、mongo、redis、postgresql、starrocks...


> 以下目录树，使用脚本 `python .\03-files-processing\files_tree.py --markdown` 生成

dba-gadgets
- [01-backup-restore-archive](./01-backup-restore-archive) | 备份、恢复、归档
  - [mongo_backup_mongodump.sh](./01-backup-restore-archive/mongo_backup_mongodump.sh)
  - [mongo_restore_mongodump.sh](./01-backup-restore-archive/mongo_restore_mongodump.sh)
  - [mysql_backup_mysqldump.sh](./01-backup-restore-archive/mysql_backup_mysqldump.sh)
  - [mysql_restore_mysqldump.sh](./01-backup-restore-archive/mysql_restore_mysqldump.sh)
  - [mysql_restore_xtrabackup.py](./01-backup-restore-archive/mysql_restore_xtrabackup.py)
  - [oracle_rman_backup.sh](./01-backup-restore-archive/oracle_rman_backup.sh)
  - [sr_backup_snapshot.py](./01-backup-restore-archive/sr_backup_snapshot.py)
  - [sr_restore_snapshot.py](./01-backup-restore-archive/sr_restore_snapshot.py)
- [02-data-processing](./02-data-processing) | 数据处理
  - [__pycache__](./02-data-processing/__pycache__)
  - [data_duplicate](./02-data-processing/data_duplicate)
  - [mysql_concurrency_test.py](./02-data-processing/mysql_concurrency_test.py)
  - [mysql_csv_to_table.py](./02-data-processing/mysql_csv_to_table.py)
  - [open_metadata_lineage](./02-data-processing/open_metadata_lineage)
    - [execute_demo.py](./02-data-processing/open_metadata_lineage/execute_demo.py)
    - [get_etl_add_lineage.py](./02-data-processing/open_metadata_lineage/get_etl_add_lineage.py)
    - [open_metadata_db_info.py](./02-data-processing/open_metadata_lineage/open_metadata_db_info.py)
    - [open_metadata_lineage.py](./02-data-processing/open_metadata_lineage/open_metadata_lineage.py)
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
  - [oracle_tbs_autoext.sh](./02-data-processing/oracle_tbs_autoext.sh)
  - [redis_del_big_list.py](./02-data-processing/redis_del_big_list.py)
  - [redis_del_idle_key.py](./02-data-processing/redis_del_idle_key.py)
  - [redis_del_prefix_keys.py](./02-data-processing/redis_del_prefix_keys.py)
  - [sr_alter_table_rn.py](./02-data-processing/sr_alter_table_rn.py)
  - [sr_alter_view_rn.py](./02-data-processing/sr_alter_view_rn.py)
- [03-files-processing](./03-files-processing) | 文件处理
  - [delete_files.sh](./03-files-processing/delete_files.sh)
  - [files_backup.sh](./03-files-processing/files_backup.sh)
  - [files_rsync_migration.sh](./03-files-processing/files_rsync_migration.sh)
  - [files_tree.py](./03-files-processing/files_tree.py)
  - [generate_test_files.sh](./03-files-processing/generate_test_files.sh)
  - [hw_rds_download_audit_logs.py](./03-files-processing/hw_rds_download_audit_logs.py)
  - [sql_to_excel](./03-files-processing/sql_to_excel)
    - [sql.xlsx](./03-files-processing/sql_to_excel/sql.xlsx)
    - [sql_to_excel.py](./03-files-processing/sql_to_excel/sql_to_excel.py)
- [04-db-check](./04-db-check) | 数据库检查
  - [app_batch_management.sh](./04-db-check/app_batch_management.sh)
  - [disk_performance_test.sh](./04-db-check/disk_performance_test.sh)
  - [hardware_info.sh](./04-db-check/hardware_info.sh)
  - [mysql_bussine_test.py](./04-db-check/mysql_bussine_test.py)
  - [mysql_f_rollback_time_calc.sql](./04-db-check/mysql_f_rollback_time_calc.sql)
  - [mysql_pt_slave_repair.py](./04-db-check/mysql_pt_slave_repair.py)
  - [mysql_reverse_sql.py](./04-db-check/mysql_reverse_sql.py)
  - [mysql_state_dump.sh](./04-db-check/mysql_state_dump.sh)
  - [oracle_generating_focused_AWR_reports.sql](./04-db-check/oracle_generating_focused_AWR_reports.sql)
  - [zabbix](./04-db-check/zabbix)
    - [mysql_zabbix_monitor.sh](./04-db-check/zabbix/mysql_zabbix_monitor.sh)
    - [sr_zabbix_check.py](./04-db-check/zabbix/sr_zabbix_check.py)
- [05-db-install](./05-db-install) | 数据库安装
  - [Oracle一键安装命令生成工具v2.0.html](./05-db-install/Oracle一键安装命令生成工具v2.0.html)
  - [docker](./05-db-install/docker)
    - [mongodb](./05-db-install/docker/mongodb)
      - [docker-compose.yaml](./05-db-install/docker/mongodb/docker-compose.yaml)
    - [mssql](./05-db-install/docker/mssql)
      - [docker-compose.yaml](./05-db-install/docker/mssql/docker-compose.yaml)
    - [mysql](./05-db-install/docker/mysql)
      - [docker-compose.yaml](./05-db-install/docker/mysql/docker-compose.yaml)
      - [slave](./05-db-install/docker/mysql/slave)
        - [docker-compose.yaml](./05-db-install/docker/mysql/slave/docker-compose.yaml)
        - [setup_replication.sh](./05-db-install/docker/mysql/slave/setup_replication.sh)
    - [oracle](./05-db-install/docker/oracle)
      - [docker-compose.yaml](./05-db-install/docker/oracle/docker-compose.yaml)
    - [otter](./05-db-install/docker/otter)
      - [docker-compose.yaml](./05-db-install/docker/otter/docker-compose.yaml)
    - [postgresql](./05-db-install/docker/postgresql)
      - [docker-compose.yaml](./05-db-install/docker/postgresql/docker-compose.yaml)
    - [proxysql](./05-db-install/docker/proxysql)
      - [docker-compose.yaml](./05-db-install/docker/proxysql/docker-compose.yaml)
      - [proxysql.cnf](./05-db-install/docker/proxysql/proxysql.cnf)
    - [redis](./05-db-install/docker/redis)
      - [docker-compose.yaml](./05-db-install/docker/redis/docker-compose.yaml)
  - [mssql_offline_install.sh](./05-db-install/mssql_offline_install.sh)
  - [mysql_generic_install.sh](./05-db-install/mysql_generic_install.sh)
  - [oracle_shell_install.sh](./05-db-install/oracle_shell_install.sh)
  - [pg_install.sh](./05-db-install/pg_install.sh)
  - [pg_souece_install.sh](./05-db-install/pg_souece_install.sh)
  - [vastbase_g100_install_v17.sh](./05-db-install/vastbase_g100_install_v17.sh)
- [06-auxiliary-tools](./06-auxiliary-tools) | 辅助工具
  - [MobaXterm-Keygen.py](./06-auxiliary-tools/MobaXterm-Keygen.py)
  - [dango_scripts.py](./06-auxiliary-tools/dango_scripts.py)
  - [ssh_setup_keyless.sh](./06-auxiliary-tools/ssh_setup_keyless.sh)
  - [ssh_trust.sh](./06-auxiliary-tools/ssh_trust.sh)
- [07-sre-install](./07-sre-install) | 运维安装
  - [FTPServerAutoCreate.py](./07-sre-install/FTPServerAutoCreate.py)
  - [docker](./07-sre-install/docker)
    - [SQLBot](./07-sre-install/docker/SQLBot)
      - [docker-compose.yaml](./07-sre-install/docker/SQLBot/docker-compose.yaml)
    - [frpc](./07-sre-install/docker/frpc)
      - [data](./07-sre-install/docker/frpc/data)
        - [frpc.toml](./07-sre-install/docker/frpc/data/frpc.toml)
        - [frpc_full.toml](./07-sre-install/docker/frpc/data/frpc_full.toml)
        - [ssl](./07-sre-install/docker/frpc/data/ssl)
      - [data.yml](./07-sre-install/docker/frpc/data.yml)
      - [docker-compose.yml](./07-sre-install/docker/frpc/docker-compose.yml)
      - [scripts](./07-sre-install/docker/frpc/scripts)
        - [init.sh](./07-sre-install/docker/frpc/scripts/init.sh)
    - [frps](./07-sre-install/docker/frps)
      - [data](./07-sre-install/docker/frps/data)
        - [frps.toml](./07-sre-install/docker/frps/data/frps.toml)
        - [frps_full.toml](./07-sre-install/docker/frps/data/frps_full.toml)
        - [ssl](./07-sre-install/docker/frps/data/ssl)
      - [data.yml](./07-sre-install/docker/frps/data.yml)
      - [docker-compose.yml](./07-sre-install/docker/frps/docker-compose.yml)
      - [scripts](./07-sre-install/docker/frps/scripts)
        - [init.sh](./07-sre-install/docker/frps/scripts/init.sh)
    - [minio](./07-sre-install/docker/minio)
      - [docker-compose.yaml](./07-sre-install/docker/minio/docker-compose.yaml)
    - [n9e](./07-sre-install/docker/n9e)
      - [docker-compose.yaml](./07-sre-install/docker/n9e/docker-compose.yaml)
    - [node_exporter](./07-sre-install/docker/node_exporter)
      - [docker-compose.yml](./07-sre-install/docker/node_exporter/docker-compose.yml)
      - [prometheus-config-example.yml](./07-sre-install/docker/node_exporter/prometheus-config-example.yml)
    - [prometheus-grafana](./07-sre-install/docker/prometheus-grafana)
      - [docker-compose.yaml](./07-sre-install/docker/prometheus-grafana/docker-compose.yaml)
      - [grafana](./07-sre-install/docker/prometheus-grafana/grafana)
        - [dashboards](./07-sre-install/docker/prometheus-grafana/grafana/dashboards)
        - [provisioning](./07-sre-install/docker/prometheus-grafana/grafana/provisioning)
          - [dashboards](./07-sre-install/docker/prometheus-grafana/grafana/provisioning/dashboards)
            - [default.yml](./07-sre-install/docker/prometheus-grafana/grafana/provisioning/dashboards/default.yml)
          - [datasources](./07-sre-install/docker/prometheus-grafana/grafana/provisioning/datasources)
            - [prometheus.yml](./07-sre-install/docker/prometheus-grafana/grafana/provisioning/datasources/prometheus.yml)
      - [prometheus](./07-sre-install/docker/prometheus-grafana/prometheus)
        - [prometheus.yml](./07-sre-install/docker/prometheus-grafana/prometheus/prometheus.yml)
        - [prometheus.yml.example](./07-sre-install/docker/prometheus-grafana/prometheus/prometheus.yml.example)
        - [rules](./07-sre-install/docker/prometheus-grafana/prometheus/rules)
          - [example.yml](./07-sre-install/docker/prometheus-grafana/prometheus/rules/example.yml)
  - [openssh-update.sh](./07-sre-install/openssh-update.sh)
  - [zabbix](./07-sre-install/zabbix)
    - [install_zabbix_server5.0.sh](./07-sre-install/zabbix/install_zabbix_server5.0.sh)
    - [install_zabbix_server6.0.sh](./07-sre-install/zabbix/install_zabbix_server6.0.sh)
    - [install_zabbix_server7.sh](./07-sre-install/zabbix/install_zabbix_server7.sh)


-----------

# DBA & 数据工程常用工具目录

> 覆盖通用管理、MySQL、PostgreSQL、Oracle、SQL Server、Redis、MongoDB、Neo4j、Milvus/向量数据库、Elasticsearch、ClickHouse、Cassandra、ETL/CDC、数据仓库/数据湖、数据治理（元数据、质量、血缘、合规、MDM）、任务调度、BI 可视化等完整数据技术栈。

## 一、通用工具（跨数据库）

### 1.1 通用客户端与管理

| 工具 | 简介 | 链接 |
|------|------|------|
| **DBeaver** | 开源跨平台数据库管理工具，支持几乎所有主流数据库 | https://dbeaver.io |
| **DataGrip** | JetBrains 出品的专业数据库 IDE，智能补全和重构能力强 | https://www.jetbrains.com/datagrip |
| **Navicat** | 商业级多数据库图形化管理工具，功能全面 | https://navicat.com |
| **Azure Data Studio** | 微软出品的跨平台数据库管理工具，插件生态丰富 | https://learn.microsoft.com/en-us/azure-data-studio |
| **DbVisualizer** | 跨平台通用数据库客户端，支持 50+ 数据库 | https://www.dbvis.com |
| **Beekeeper Studio** | 开源现代化数据库管理工具，界面简洁美观 | https://www.beekeeperstudio.io |
| **Chat2DB** | AI 驱动的数据库管理工具，支持自然语言生成 SQL | https://github.com/chat2db/Chat2DB |
| **usql** | 通用命令行数据库客户端，统一接口访问多种数据库 | https://github.com/xo/usql |
| **Adminer** | 单文件 PHP 数据库管理工具，极其轻量 | https://www.adminer.org |

### 1.2 通用监控与告警

| 工具 | 简介 | 链接 |
|------|------|------|
| **Prometheus + Grafana** | 开源监控告警 + 可视化仪表盘，DBA 监控标配组合 | https://prometheus.io / https://grafana.com |
| **Zabbix** | 企业级开源监控方案，支持数据库模板化深度监控 | https://www.zabbix.com |
| **Datadog** | 商业 SaaS 监控平台，200+ 数据库集成 | https://www.datadoghq.com |
| **Nightingale (夜莺)** | 开源企业级监控告警平台，滴滴开源 | https://github.com/ccfos/nightingale |
| **Telegraf + InfluxDB + Grafana (TIG)** | 指标采集 + 时序存储 + 可视化的监控栈 | https://www.influxdata.com/time-series-platform/telegraf |

### 1.3 通用数据库迁移与版本管理

| 工具 | 简介 | 链接 |
|------|------|------|
| **Flyway** | 数据库版本管理和迁移工具，SQL/Java 双模式 | https://flywaydb.org |
| **Liquibase** | 数据库变更管理工具，支持 XML/YAML/JSON/SQL 格式 | https://www.liquibase.com |
| **Bytebase** | 开源数据库 DevOps 和 CI/CD 平台，Web 界面协作 | https://www.bytebase.com |
| **Atlas** | 声明式数据库 Schema 管理工具，支持 HCL/SQL | https://atlasgo.io |
| **golang-migrate** | Go 编写的轻量级数据库迁移工具 | https://github.com/golang-migrate/migrate |
| **Alembic** | SQLAlchemy 配套的 Python 数据库迁移工具 | https://alembic.sqlalchemy.org |
| **sqitch** | 无框架依赖的数据库变更管理工具 | https://sqitch.org |

### 1.4 通用 SQL 审核与安全

| 工具 | 简介 | 链接 |
|------|------|------|
| **Archery** | 开源 SQL 审核平台，集成工单审批和执行全流程 | https://github.com/hhyo/Archery |
| **Yearning** | 开源 MySQL SQL 审核平台，轻量易用 | https://github.com/cookieY/Yearning |
| **SQLE** | 爱可生开源的多数据库 SQL 审核工具 | https://github.com/actiontech/sqle |
| **SQLFluff** | SQL 代码风格检查和自动格式化工具 | https://sqlfluff.com |
| **SonarQube** | 代码质量管理平台，支持 PL/SQL 和 T-SQL 扫描 | https://www.sonarsource.com/products/sonarqube |
| **Vault** | HashiCorp 密钥管理工具，支持数据库动态凭证 | https://www.vaultproject.io |

### 1.5 通用数据建模与设计

| 工具 | 简介 | 链接 |
|------|------|------|
| **ERwin** | 企业级数据建模工具，行业标准 | https://www.erwin.com/products/erwin-data-modeler |
| **PowerDesigner** | SAP 出品的数据架构和建模工具 | https://www.sap.com/products/powerdesigner-data-modeling-tools.html |
| **dbdiagram.io** | 在线数据库 ER 图设计工具，代码驱动 | https://dbdiagram.io |
| **DrawDB** | 开源在线数据库 ER 图设计和 SQL 生成工具 | https://drawdb.vercel.app |
| **SchemaSpy** | 数据库文档自动生成工具，生成 ER 图和 HTML 文档 | https://schemaspy.org |
| **tbls** | CI 友好的数据库文档生成工具 | https://github.com/k1LoW/tbls |

### 1.6 通用 CDC（变更数据捕获）

| 工具 | 简介 | 链接 |
|------|------|------|
| **Debezium** | 基于日志的分布式 CDC 平台，支持 MySQL/PG/Mongo/Oracle 等 | https://debezium.io |
| **Flink CDC** | Apache Flink 生态的 CDC 连接器，流式数据集成 | https://github.com/apache/flink-cdc |
| **AWS DMS** | AWS 数据库迁移服务，支持异构迁移和持续 CDC 复制 | https://aws.amazon.com/dms |
| **AWS SCT** | AWS 异构数据库 Schema 转换工具 | https://aws.amazon.com/dms/schema-conversion-tool |

### 1.7 Kubernetes / 云原生数据库运维

| 工具 | 简介 | 链接 |
|------|------|------|
| **KubeDB** | Kubernetes 上运行和管理数据库的 Operator | https://kubedb.com |
| **CloudNativePG** | Kubernetes 原生 PostgreSQL Operator | https://cloudnative-pg.io |
| **Percona Operators** | Percona 出品的 MySQL/PG/MongoDB Kubernetes Operator | https://www.percona.com/software/percona-kubernetes-operators |
| **Vitess** | 云原生 MySQL 水平扩展方案，原生支持 Kubernetes | https://vitess.io |

---

## 二、MySQL 生态

### 2.1 客户端与管理

| 工具 | 简介 | 链接 |
|------|------|------|
| **MySQL Workbench** | MySQL 官方图形化管理、建模和迁移工具 | https://www.mysql.com/products/workbench |
| **phpMyAdmin** | 基于 Web 的 MySQL/MariaDB 管理工具，部署简单 | https://www.phpmyadmin.net |
| **HeidiSQL** | 轻量级 Windows 平台 MySQL/MariaDB 管理工具 | https://www.heidisql.com |
| **mycli** | 带语法高亮和自动补全的 MySQL 命令行客户端 | https://www.mycli.net |

### 2.2 备份与恢复

| 工具 | 简介 | 链接 |
|------|------|------|
| **mysqldump** | MySQL 官方逻辑备份工具，简单通用 | https://dev.mysql.com/doc/refman/en/mysqldump.html |
| **mysqlpump** | MySQL 官方多线程逻辑备份工具，mysqldump 改进版 | https://dev.mysql.com/doc/refman/en/mysqlpump.html |
| **Percona XtraBackup** | MySQL 热备份工具，支持不停机增量物理备份 | https://www.percona.com/software/mysql-database/percona-xtrabackup |
| **mydumper / myloader** | 多线程 MySQL 备份恢复工具，速度远超 mysqldump | https://github.com/mydumper/mydumper |
| **MySQL Enterprise Backup** | MySQL 官方企业版物理备份工具 | https://www.mysql.com/products/enterprise/backup.html |

### 2.3 高可用与代理

| 工具 | 简介 | 链接 |
|------|------|------|
| **MySQL InnoDB Cluster** | MySQL 官方高可用方案，Group Replication + Router + Shell | https://dev.mysql.com/doc/refman/en/mysql-innodb-cluster-introduction.html |
| **MySQL Router** | MySQL 官方中间件代理，透明路由到后端实例 | https://dev.mysql.com/doc/mysql-router/en |
| **Orchestrator** | MySQL 高可用拓扑管理和故障自动切换工具 | https://github.com/openark/orchestrator |
| **ProxySQL** | 高性能 MySQL 代理，支持读写分离、查询路由和缓存 | https://proxysql.com |
| **MaxScale** | MariaDB 出品的数据库代理，支持读写分离和故障切换 | https://mariadb.com/kb/en/maxscale |
| **MHA** | MySQL 主从高可用故障自动切换方案 | https://github.com/yoshinorim/mha4mysql-manager |
| **Vitess** | YouTube 开源的 MySQL 水平分片中间件，云原生架构 | https://vitess.io |
| **ShardingSphere** | Apache 分布式数据库中间件，支持分库分表和读写分离 | https://shardingsphere.apache.org |

### 2.4 性能分析与优化

| 工具 | 简介 | 链接 |
|------|------|------|
| **Percona Toolkit** | MySQL DBA 瑞士军刀，包含 30+ 实用工具集 | https://www.percona.com/software/database-tools/percona-toolkit |
| **pt-query-digest** | Percona Toolkit 中的慢查询分析工具 | https://docs.percona.com/percona-toolkit/pt-query-digest.html |
| **pt-online-schema-change** | Percona 出品的 MySQL 在线无锁 DDL 变更工具 | https://docs.percona.com/percona-toolkit/pt-online-schema-change.html |
| **gh-ost** | GitHub 出品的 MySQL 在线表结构变更工具，基于 binlog 无触发器 | https://github.com/github/gh-ost |
| **MySQL Tuner** | MySQL 配置和性能自动诊断调优脚本 | https://github.com/major/MySQLTuner-perl |
| **sys schema** | MySQL 内置性能诊断视图集合，简化 performance_schema 使用 | https://dev.mysql.com/doc/refman/en/sys-schema.html |
| **SQLAdvisor** | 美团开源的 SQL 索引优化建议工具 | https://github.com/Meituan-Dianping/SQLAdvisor |
| **SOAR** | 小米开源的 SQL 优化与改写建议工具 | https://github.com/XiaoMi/soar |
| **PMM** | Percona 出品的数据库专用监控平台 | https://www.percona.com/software/database-tools/percona-monitoring-and-management |
| **mysqld_exporter** | Prometheus 的 MySQL 指标采集器 | https://github.com/prometheus/mysqld_exporter |

### 2.5 数据同步与复制

| 工具 | 简介 | 链接 |
|------|------|------|
| **Canal** | 阿里开源的 MySQL binlog 增量订阅和消费组件 | https://github.com/alibaba/canal |
| **Maxwell** | Zendesk 开源的 MySQL binlog 实时解析工具，输出 JSON | https://github.com/zendesk/maxwell |
| **mysql-binlog-connector** | Java 版 MySQL binlog 解析库 | https://github.com/shyiko/mysql-binlog-connector-java |

---

## 三、PostgreSQL 生态

### 3.1 客户端与管理

| 工具 | 简介 | 链接 |
|------|------|------|
| **pgAdmin** | PostgreSQL 官方推荐的图形化管理工具 | https://www.pgadmin.org |
| **pgcli** | 带语法高亮和自动补全的 PostgreSQL 命令行客户端 | https://www.pgcli.com |
| **Postico** | macOS 平台简洁优雅的 PostgreSQL 客户端 | https://eggerapps.at/postico2 |
| **pgModeler** | PostgreSQL 数据库建模和逆向工程工具 | https://pgmodeler.io |

### 3.2 备份与恢复

| 工具 | 简介 | 链接 |
|------|------|------|
| **pg_dump / pg_dumpall** | PostgreSQL 官方逻辑备份工具 | https://www.postgresql.org/docs/current/app-pgdump.html |
| **pg_basebackup** | PostgreSQL 官方物理备份工具，支持流式基础备份 | https://www.postgresql.org/docs/current/app-pgbasebackup.html |
| **Barman** | PostgreSQL 企业级备份管理工具，支持增量备份和 PITR | https://pgbarman.org |
| **pgBackRest** | 高性能 PostgreSQL 备份恢复方案，支持并行、加密和增量 | https://pgbackrest.org |
| **WAL-G** | 基于 WAL 的 PostgreSQL 云备份工具，支持 S3/GCS/Azure | https://github.com/wal-g/wal-g |

### 3.3 高可用与连接池

| 工具 | 简介 | 链接 |
|------|------|------|
| **Patroni** | PostgreSQL 高可用集群管理方案，基于 etcd/ZooKeeper/Consul | https://github.com/patroni/patroni |
| **PgBouncer** | 轻量级 PostgreSQL 连接池，降低连接开销 | https://www.pgbouncer.org |
| **Pgpool-II** | PostgreSQL 连接池 + 负载均衡 + 复制管理中间件 | https://www.pgpool.net |
| **repmgr** | PostgreSQL 复制管理和故障自动切换工具 | https://repmgr.org |
| **Citus** | PostgreSQL 分布式水平扩展插件，透明分片 | https://www.citusdata.com |
| **Stolon** | 云原生 PostgreSQL 高可用管理器，支持 Kubernetes | https://github.com/sorintlab/stolon |

### 3.4 性能分析与优化

| 工具 | 简介 | 链接 |
|------|------|------|
| **pg_stat_statements** | PostgreSQL 内置扩展，统计 SQL 执行性能 | https://www.postgresql.org/docs/current/pgstatstatements.html |
| **pgBadger** | PostgreSQL 日志分析器，生成详细的 HTML 性能报告 | https://pgbadger.darold.net |
| **pg_stat_monitor** | Percona 出品的 pg_stat_statements 增强版 | https://github.com/percona/pg_stat_monitor |
| **explain.dalibo.com** | PostgreSQL 执行计划在线可视化分析工具 | https://explain.dalibo.com |
| **pgHero** | PostgreSQL 性能仪表盘，一目了然发现性能瓶颈 | https://github.com/ankane/pghero |
| **HypoPG** | PostgreSQL 虚拟索引插件，不实际创建索引即可评估效果 | https://hypopg.readthedocs.io |
| **Dexter** | PostgreSQL 自动索引推荐工具 | https://github.com/ankane/dexter |
| **postgres_exporter** | Prometheus 的 PostgreSQL 指标采集器 | https://github.com/prometheus-community/postgres_exporter |

### 3.5 迁移工具

| 工具 | 简介 | 链接 |
|------|------|------|
| **pgLoader** | 高速数据迁移工具，支持 MySQL/SQLite 等迁移到 PostgreSQL | https://pgloader.io |
| **ora2pg** | Oracle 迁移到 PostgreSQL 的专用工具 | https://ora2pg.darold.net |
| **pglogical** | PostgreSQL 逻辑复制扩展，支持选择性表复制 | https://github.com/2ndQuadrant/pglogical |

---

## 四、Oracle 生态

### 4.1 客户端与管理

| 工具 | 简介 | 链接 |
|------|------|------|
| **SQL*Plus** | Oracle 官方命令行管理工具，DBA 操作基础 | https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug |
| **Oracle SQL Developer** | Oracle 官方免费图形化开发和管理工具 | https://www.oracle.com/database/sqldeveloper |
| **Oracle Enterprise Manager (OEM)** | Oracle 企业级数据库监控和管理平台 | https://www.oracle.com/enterprise-manager |
| **TOAD for Oracle** | 老牌商业 Oracle 开发和管理工具 | https://www.quest.com/products/toad-for-oracle |
| **PL/SQL Developer** | 专业的 Oracle PL/SQL 开发 IDE | https://www.allroundautomations.com/products/pl-sql-developer |
| **oracledb_exporter** | Prometheus 的 Oracle 数据库指标采集器 | https://github.com/iamseth/oracledb_exporter |

### 4.2 备份与恢复

| 工具 | 简介 | 链接 |
|------|------|------|
| **RMAN** | Oracle 官方备份恢复工具，支持增量、压缩和加密 | https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv |
| **Data Pump (expdp/impdp)** | Oracle 高速逻辑导入导出工具，替代 exp/imp | https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil |
| **Oracle Flashback** | Oracle 数据闪回技术，支持表级和数据库级时间点恢复 | https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/flashback.html |

### 4.3 高可用与容灾

| 工具 | 简介 | 链接 |
|------|------|------|
| **Oracle Data Guard** | Oracle 官方主备容灾方案，支持物理/逻辑 Standby | https://www.oracle.com/database/data-guard |
| **Oracle RAC** | Oracle 多节点集群数据库方案，共享存储架构 | https://www.oracle.com/database/real-application-clusters |
| **Oracle GoldenGate** | Oracle 实时数据复制和同步工具，支持异构数据库 | https://www.oracle.com/middleware/technologies/goldengate.html |

### 4.4 性能分析与优化

| 工具 | 简介 | 链接 |
|------|------|------|
| **AWR** | Oracle 自动负载快照和性能报告工具 | https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/automatic-performance-diagnostics.html |
| **ASH** | Oracle 实时会话采样和活动分析 | https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/active-session-history.html |
| **ADDM** | Oracle 自动诊断和调优建议引擎 | https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/automatic-database-diagnostic-monitor.html |
| **SQL Tuning Advisor** | Oracle 内置 SQL 调优顾问 | https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/sql-tuning-advisor.html |
| **Oratop** | 类似 top 的 Oracle 实时数据库监控命令行工具 | https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs |

---

## 五、SQL Server 生态

### 5.1 客户端与管理

| 工具 | 简介 | 链接 |
|------|------|------|
| **SQL Server Management Studio (SSMS)** | SQL Server 官方图形化管理和开发工具，Windows 平台标配 | https://learn.microsoft.com/en-us/sql/ssms |
| **Azure Data Studio** | 微软跨平台数据库管理工具，支持 SQL Server 和 PostgreSQL | https://learn.microsoft.com/en-us/azure-data-studio |
| **sqlcmd** | SQL Server 官方命令行客户端工具 | https://learn.microsoft.com/en-us/sql/tools/sqlcmd/sqlcmd-utility |
| **mssql-cli** | 带语法高亮和自动补全的 SQL Server 命令行客户端 | https://github.com/dbcli/mssql-cli |
| **TOAD for SQL Server** | Quest 出品的商业级 SQL Server 管理和开发工具 | https://www.quest.com/products/toad-for-sql-server |
| **dbForge Studio for SQL Server** | Devart 出品的专业 SQL Server IDE | https://www.devart.com/dbforge/sql/studio |
| **SQL Server Configuration Manager** | SQL Server 服务和网络协议配置管理工具 | https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-configuration-manager |

### 5.2 备份与恢复

| 工具 | 简介 | 链接 |
|------|------|------|
| **BACKUP / RESTORE** | SQL Server 内置备份恢复命令，支持完整/差异/日志备份 | https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore |
| **Ola Hallengren 维护方案** | 社区最流行的 SQL Server 备份和维护存储过程集 | https://ola.hallengren.com |
| **dbatools** | PowerShell 模块，500+ 命令覆盖 SQL Server DBA 日常工作 | https://dbatools.io |
| **Redgate SQL Backup Pro** | Redgate 出品的 SQL Server 备份增强工具，支持压缩和加密 | https://www.red-gate.com/products/sql-backup |
| **Litespeed for SQL Server** | Quest 出品的 SQL Server 高速备份压缩工具 | https://www.quest.com/products/litespeed-for-sql-server |

### 5.3 高可用与容灾

| 工具 | 简介 | 链接 |
|------|------|------|
| **Always On Availability Groups** | SQL Server 企业级高可用和读副本方案 | https://learn.microsoft.com/en-us/sql/database-engine/availability-groups |
| **Always On Failover Cluster** | SQL Server 基于 Windows 故障转移集群的高可用方案 | https://learn.microsoft.com/en-us/sql/sql-server/failover-clusters |
| **Log Shipping** | SQL Server 内置日志传送灾备方案，简单可靠 | https://learn.microsoft.com/en-us/sql/database-engine/log-shipping |
| **Database Mirroring** | SQL Server 数据库镜像，实时同步到镜像实例（已弃用，推荐 AG） | https://learn.microsoft.com/en-us/sql/database-engine/database-mirroring |
| **Distributed Availability Groups** | 跨集群/跨地域的 AG 级联复制方案 | https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/distributed-availability-groups |

### 5.4 性能分析与优化

| 工具 | 简介 | 链接 |
|------|------|------|
| **Query Store** | SQL Server 内置查询性能历史记录和回归检测功能 | https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store |
| **Dynamic Management Views (DMVs)** | SQL Server 内置的性能诊断系统视图集合 | https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views |
| **SQL Server Profiler** | SQL Server 跟踪和重放查询的图形化工具（逐步被 XEvents 替代） | https://learn.microsoft.com/en-us/sql/tools/sql-server-profiler |
| **Extended Events (XEvents)** | SQL Server 轻量级事件跟踪框架，替代 Profiler | https://learn.microsoft.com/en-us/sql/relational-databases/extended-events |
| **Database Engine Tuning Advisor (DTA)** | SQL Server 内置索引和分区调优建议工具 | https://learn.microsoft.com/en-us/sql/relational-databases/performance/database-engine-tuning-advisor |
| **sp_Blitz / sp_BlitzFirst** | Brent Ozar 开源的 SQL Server 健康检查和性能诊断脚本 | https://www.brentozar.com/blitz |
| **SolarWinds DPA** | 商业数据库性能分析工具，支持 SQL Server 等多数据库 | https://www.solarwinds.com/database-performance-analyzer |
| **SentryOne (now SQL Sentry)** | 商业 SQL Server 性能监控和调优平台 | https://www.sentryone.com |
| **mssql_exporter** | Prometheus 的 SQL Server 指标采集器 | https://github.com/awarber/mssql_exporter |

### 5.5 数据迁移与同步

| 工具 | 简介 | 链接 |
|------|------|------|
| **SQL Server Integration Services (SSIS)** | SQL Server 内置的 ETL 和数据集成平台 | https://learn.microsoft.com/en-us/sql/integration-services |
| **SQL Server Replication** | SQL Server 内置数据复制方案，支持事务/合并/快照复制 | https://learn.microsoft.com/en-us/sql/relational-databases/replication |
| **BCP (Bulk Copy Program)** | SQL Server 大批量数据导入导出命令行工具 | https://learn.microsoft.com/en-us/sql/tools/bcp-utility |
| **Redgate SQL Compare** | Redgate 出品的 SQL Server 数据库 Schema 比较和同步工具 | https://www.red-gate.com/products/sql-compare |
| **Redgate SQL Data Compare** | Redgate 出品的 SQL Server 数据比较和同步工具 | https://www.red-gate.com/products/sql-data-compare |
| **Azure SQL Migration** | 微软官方数据库迁移到 Azure SQL 的评估和迁移工具 | https://learn.microsoft.com/en-us/azure/dms |

### 5.6 报表与审计

| 工具 | 简介 | 链接 |
|------|------|------|
| **SQL Server Reporting Services (SSRS)** | SQL Server 内置的企业报表服务 | https://learn.microsoft.com/en-us/sql/reporting-services |
| **SQL Server Audit** | SQL Server 内置审计功能，记录数据库级和服务器级事件 | https://learn.microsoft.com/en-us/sql/relational-databases/security/auditing |
| **Redgate SQL Monitor** | Redgate 出品的 SQL Server 监控和告警工具 | https://www.red-gate.com/products/sql-monitor |
| **dbWatch** | 跨平台数据库监控工具，支持 SQL Server 和其他数据库 | https://www.dbwatch.com |

---

## 六、Redis 生态

| 工具 | 简介 | 链接 |
|------|------|------|
| **redis-cli** | Redis 官方命令行客户端 | https://redis.io/docs/connect/cli |
| **RedisInsight** | Redis 官方图形化管理工具，支持数据浏览和性能分析 | https://redis.io/insight |
| **Another Redis Desktop Manager** | 开源跨平台 Redis 桌面管理工具，界面美观 | https://github.com/qishibo/AnotherRedisDesktopManager |
| **Tiny RDM** | 轻量美观的现代 Redis 桌面客户端 | https://github.com/tiny-craft/tiny-rdm |
| **redis-benchmark** | Redis 官方基准测试工具，评估实例性能 | https://redis.io/docs/management/optimization/benchmarks |
| **redis-rdb-tools** | Redis RDB 文件解析和内存分析工具 | https://github.com/sripathikrishnan/redis-rdb-tools |
| **Redis Sentinel** | Redis 官方高可用监控和自动故障切换方案 | https://redis.io/docs/management/sentinel |
| **Redis Cluster** | Redis 官方分布式集群方案，自动分片 | https://redis.io/docs/management/scaling |
| **Twemproxy** | Twitter 开源的 Redis/Memcached 代理，支持自动分片 | https://github.com/twitter/twemproxy |
| **Codis** | 豌豆荚开源的 Redis 集群代理方案 | https://github.com/CodisLabs/codis |
| **KeyDB** | Redis 多线程高性能分支，兼容 Redis 协议 | https://docs.keydb.dev |
| **Dragonfly** | 现代高性能内存数据库，兼容 Redis/Memcached 协议 | https://www.dragonflydb.io |
| **redis_exporter** | Prometheus 的 Redis 指标采集器 | https://github.com/oliver006/redis_exporter |

---

## 七、MongoDB 生态

| 工具 | 简介 | 链接 |
|------|------|------|
| **mongosh** | MongoDB 官方现代交互式命令行 Shell | https://www.mongodb.com/docs/mongodb-shell |
| **MongoDB Compass** | MongoDB 官方图形化管理工具，支持可视化查询和聚合 | https://www.mongodb.com/products/compass |
| **Studio 3T** | 商业级 MongoDB IDE，支持 SQL 查询和数据迁移 | https://studio3t.com |
| **Robo 3T** | 轻量级开源 MongoDB 管理工具 | https://robomongo.org |
| **mongodump / mongorestore** | MongoDB 官方逻辑备份和恢复工具 | https://www.mongodb.com/docs/database-tools/mongodump |
| **MongoDB Atlas** | MongoDB 官方全托管云数据库服务 | https://www.mongodb.com/atlas |
| **MongoDB Ops Manager** | MongoDB 企业级运维管理平台，自动化部署和监控 | https://www.mongodb.com/products/ops-manager |
| **Percona Backup for MongoDB** | Percona 出品的 MongoDB 分布式一致性备份工具 | https://www.percona.com/software/mongodb/percona-backup-for-mongodb |
| **mtools** | MongoDB 日志分析和性能可视化工具集 | https://github.com/rueckstiess/mtools |
| **mongotop / mongostat** | MongoDB 官方实时性能监控命令行工具 | https://www.mongodb.com/docs/database-tools/mongotop |
| **mongodb_exporter** | Prometheus 的 MongoDB 指标采集器 | https://github.com/percona/mongodb_exporter |

---

## 八、Neo4j 生态（图数据库）

| 工具 | 简介 | 链接 |
|------|------|------|
| **Neo4j Browser** | Neo4j 内置 Web 交互式查询和可视化界面 | https://neo4j.com/docs/browser-manual/current |
| **Neo4j Desktop** | Neo4j 官方桌面管理工具，集成开发环境 | https://neo4j.com/download |
| **Neo4j Bloom** | Neo4j 图数据可视化探索工具，无需写 Cypher | https://neo4j.com/product/bloom |
| **neo4j-admin** | Neo4j 官方命令行管理工具，备份/恢复/导入 | https://neo4j.com/docs/operations-manual/current/tools/neo4j-admin |
| **APOC** | Neo4j 社区最大的存储过程和函数扩展库 | https://neo4j.com/labs/apoc |
| **Graph Data Science Library** | Neo4j 图算法库，支持 PageRank、社区检测等 | https://neo4j.com/docs/graph-data-science/current |
| **Cypher Shell** | Neo4j 官方 Cypher 命令行客户端 | https://neo4j.com/docs/operations-manual/current/tools/cypher-shell |
| **Arrows.app** | Neo4j 图模型在线设计工具 | https://arrows.app |
| **Neodash** | 开源 Neo4j 仪表盘构建工具 | https://neo4j.com/labs/neodash |

---

## 九、Milvus 生态（向量数据库）

### 9.1 Milvus 工具

| 工具 | 简介 | 链接 |
|------|------|------|
| **Attu** | Milvus 官方图形化管理工具，支持集合管理和向量搜索 | https://github.com/zilliztech/attu |
| **Milvus CLI** | Milvus 官方命令行管理工具 | https://milvus.io/docs/cli_overview.md |
| **Milvus Backup** | Milvus 官方数据备份恢复工具 | https://github.com/zilliztech/milvus-backup |
| **Birdwatcher** | Milvus 调试和诊断工具，检查 etcd 元数据 | https://github.com/milvus-io/birdwatcher |
| **PyMilvus** | Milvus Python SDK，DBA 脚本化管理首选 | https://github.com/milvus-io/pymilvus |
| **Milvus Sizing Tool** | Milvus 官方容量规划计算器 | https://milvus.io/tools/sizing |
| **Zilliz Cloud** | Milvus 全托管云服务 | https://zilliz.com |

### 9.2 其他向量数据库

| 工具 | 简介 | 链接 |
|------|------|------|
| **Qdrant** | Rust 编写的高性能向量数据库，支持过滤搜索 | https://qdrant.tech |
| **Weaviate** | 开源向量数据库，内置向量化模块 | https://weaviate.io |
| **Chroma** | 轻量级嵌入式向量数据库，适合 AI 应用原型 | https://www.trychroma.com |
| **Pinecone** | 全托管向量数据库云服务 | https://www.pinecone.io |
| **pgvector** | PostgreSQL 向量搜索扩展，复用 PG 生态 | https://github.com/pgvector/pgvector |

---

## 十、Elasticsearch 生态

| 工具 | 简介 | 链接 |
|------|------|------|
| **Kibana** | Elasticsearch 官方可视化和管理平台 | https://www.elastic.co/kibana |
| **Cerebro** | Elasticsearch 集群管理和监控 Web 工具 | https://github.com/lmenezes/cerebro |
| **ElasticHQ** | Elasticsearch 集群管理和监控工具 | https://www.elastichq.org |
| **elasticsearch-head** | Elasticsearch 集群信息查看 Web 前端 | https://github.com/mobz/elasticsearch-head |
| **elasticsearch_exporter** | Prometheus 的 Elasticsearch 指标采集器 | https://github.com/prometheus-community/elasticsearch_exporter |

---

## 十一、ClickHouse 生态

| 工具 | 简介 | 链接 |
|------|------|------|
| **clickhouse-client** | ClickHouse 官方命令行客户端 | https://clickhouse.com/docs/en/interfaces/cli |
| **Tabix** | ClickHouse Web 图形化管理界面 | https://tabix.io |
| **clickhouse-backup** | ClickHouse 备份恢复工具，支持 S3/GCS | https://github.com/Altinity/clickhouse-backup |
| **chproxy** | ClickHouse HTTP 代理和负载均衡器 | https://github.com/ContentSquare/chproxy |
| **ClickHouse Keeper** | ClickHouse 内置的 ZooKeeper 替代组件 | https://clickhouse.com/docs/en/guides/sre/keeper |

---

## 十二、Cassandra 生态

| 工具 | 简介 | 链接 |
|------|------|------|
| **cqlsh** | Cassandra 官方 CQL 命令行客户端 | https://cassandra.apache.org/doc/latest/cassandra/tools/cqlsh.html |
| **nodetool** | Cassandra 集群管理和诊断命令行工具 | https://cassandra.apache.org/doc/latest/cassandra/tools/nodetool/nodetool.html |
| **DataStax** | Cassandra 企业版和托管云服务 | https://www.datastax.com |
| **Medusa** | Spotify 开源的 Cassandra 备份恢复工具 | https://github.com/thelastpickle/cassandra-medusa |
| **Reaper** | Cassandra 反熵修复调度和管理工具 | https://cassandra-reaper.io |

---

## 十三、ETL / 数据集成

### 13.1 综合 ETL / ELT 平台

| 工具 | 简介 | 链接 |
|------|------|------|
| **Apache NiFi** | 可视化数据流管理和 ETL 平台，拖拽式操作 | https://nifi.apache.org |
| **Kettle (Pentaho Data Integration)** | 开源图形化 ETL 工具，拖拽构建数据管道 | https://www.hitachivantara.com/en-us/products/pentaho-plus-platform/data-integration-analytics.html |
| **DataX** | 阿里开源的离线异构数据源同步框架 | https://github.com/alibaba/DataX |
| **SeaTunnel** | Apache 高性能分布式数据集成平台，支持实时和离线 | https://seatunnel.apache.org |
| **Talend Open Studio** | 开源 ETL 工具，图形化设计数据转换流程 | https://www.talend.com/products/talend-open-studio |
| **Informatica** | 企业级商业数据集成和 ETL 领导者 | https://www.informatica.com |
| **dbt** | 以 SQL 为核心的数据转换和建模工具，ELT 首选 | https://www.getdbt.com |
| **Airbyte** | 开源 ELT 数据集成平台，300+ 数据连接器 | https://airbyte.com |
| **Fivetran** | 全托管 ELT 管道服务，自动化 schema 变更同步 | https://www.fivetran.com |
| **Stitch** | Talend 旗下云端 ETL 服务，简单易用 | https://www.stitchdata.com |
| **StreamSets** | 实时数据集成平台，支持流式和批处理 | https://streamsets.com |
| **SQLMesh** | dbt 替代方案，内置增量模型和虚拟数据环境 | https://sqlmesh.com |

### 13.2 CDC（变更数据捕获）

| 工具 | 简介 | 链接 |
|------|------|------|
| **Debezium** | 基于日志的分布式 CDC 平台，支持多种数据库 | https://debezium.io |
| **Canal** | 阿里开源的 MySQL binlog 增量同步组件 | https://github.com/alibaba/canal |
| **Maxwell** | MySQL binlog 实时解析，输出 JSON 到 Kafka 等 | https://github.com/zendesk/maxwell |
| **Flink CDC** | Apache Flink 生态的 CDC 连接器，流式数据集成 | https://github.com/apache/flink-cdc |
| **Oracle GoldenGate** | Oracle 官方实时数据复制和 CDC 工具 | https://www.oracle.com/middleware/technologies/goldengate.html |

---

## 十四、数据仓库

### 14.1 OLAP 引擎与数仓产品

| 工具 | 简介 | 链接 |
|------|------|------|
| **ClickHouse** | Yandex 开源的列式 OLAP 数据库，极致查询性能 | https://clickhouse.com |
| **Apache Doris** | MPP 分析型数据库，兼容 MySQL 协议，实时分析能力强 | https://doris.apache.org |
| **StarRocks** | 新一代极速全场景 MPP 数据库，Doris 增强分支 | https://www.starrocks.io |
| **Apache Hive** | Hadoop 生态 SQL 数据仓库，离线批处理场景标配 | https://hive.apache.org |
| **Apache Impala** | Hadoop 上的低延迟交互式 SQL 查询引擎 | https://impala.apache.org |
| **Presto / Trino** | 分布式 SQL 查询引擎，支持跨数据源联邦查询 | https://trino.io |
| **Apache Druid** | 实时 OLAP 数据库，适合高并发低延迟切片分析 | https://druid.apache.org |
| **Apache Kylin** | 基于预计算的超大规模 OLAP 引擎，亚秒级查询 | https://kylin.apache.org |
| **Apache Pinot** | LinkedIn 开源的实时分布式 OLAP 数据库 | https://pinot.apache.org |
| **Greenplum** | 基于 PostgreSQL 的大规模并行处理(MPP)数仓 | https://greenplum.org |
| **Amazon Redshift** | AWS 全托管云数据仓库，按需扩展 | https://aws.amazon.com/redshift |
| **Google BigQuery** | Google 全托管 Serverless 数据仓库，按查询计费 | https://cloud.google.com/bigquery |
| **Snowflake** | 云原生数据仓库，存算分离架构，多云支持 | https://www.snowflake.com |
| **Azure Synapse** | 微软云端统一分析平台，集数仓与大数据于一体 | https://azure.microsoft.com/en-us/products/synapse-analytics |
| **Databricks** | 统一数据湖仓平台，基于 Spark 和 Delta Lake | https://www.databricks.com |
| **DuckDB** | 嵌入式分析型数据库，单机 OLAP 场景的 SQLite | https://duckdb.org |
| **SelectDB** | Apache Doris 商业发行版，提供云原生托管服务 | https://www.selectdb.com |
| **ByteHouse** | 字节跳动基于 ClickHouse 增强的云原生数仓 | https://www.volcengine.com/product/bytehouse |
| **MatrixOne** | 超融合异构数据库，一套系统覆盖 TP/AP/Streaming | https://www.matrixorigin.cn |
| **TiDB** | PingCAP 开源的分布式 HTAP 数据库，兼容 MySQL 协议 | https://www.pingcap.com |
| **CockroachDB** | 分布式 SQL 数据库，兼容 PostgreSQL 协议 | https://www.cockroachlabs.com |
| **YugabyteDB** | 分布式 SQL 数据库，兼容 PostgreSQL 和 Cassandra | https://www.yugabyte.com |

### 14.2 数据湖 & 湖仓一体

| 工具 | 简介 | 链接 |
|------|------|------|
| **Apache Iceberg** | 开放表格式，支持 ACID 事务和 Schema 演进 | https://iceberg.apache.org |
| **Apache Hudi** | 数据湖增量处理框架，支持 Upsert 和增量查询 | https://hudi.apache.org |
| **Delta Lake** | Databricks 开源的数据湖 ACID 事务层 | https://delta.io |
| **Apache Paimon** | 流式数据湖仓平台，原生支持 Flink 实时入湖 | https://paimon.apache.org |
| **Apache Ozone** | Hadoop 生态分布式对象存储，适合数据湖底座 | https://ozone.apache.org |

### 14.3 实时计算引擎

| 工具 | 简介 | 链接 |
|------|------|------|
| **Apache Flink** | 流批一体计算引擎，实时数仓核心组件 | https://flink.apache.org |
| **Apache Spark** | 统一大数据计算引擎，批处理/SQL/ML/图计算 | https://spark.apache.org |
| **Apache Kafka** | 分布式消息和事件流平台，实时数据管道基础 | https://kafka.apache.org |
| **Apache Pulsar** | 云原生分布式消息流平台，多租户和分层存储 | https://pulsar.apache.org |
| **RisingWave** | 云原生流数据库，以 SQL 构建实时物化视图 | https://www.risingwave.com |
| **Materialize** | 流式 SQL 物化视图引擎，兼容 PostgreSQL | https://materialize.com |
| **ksqlDB** | Confluent 基于 Kafka 的流处理 SQL 引擎 | https://ksqldb.io |

---

## 十五、数据治理

### 15.1 元数据管理与数据发现

| 工具 | 简介 | 链接 |
|------|------|------|
| **Apache Atlas** | Hadoop 生态的数据治理和元数据管理框架，支持血缘追踪 | https://atlas.apache.org |
| **DataHub** | LinkedIn 开源的元数据管理和数据发现平台 | https://datahubproject.io |
| **OpenMetadata** | 开源统一元数据平台，数据发现、血缘、质量一站式 | https://open-metadata.org |
| **Amundsen** | Lyft 开源的数据发现和元数据管理平台 | https://www.amundsen.io |
| **Marquez** | WeWork 开源的元数据和数据血缘追踪服务 | https://marquezproject.ai |
| **Apache Gravitino** | 统一元数据湖，管理跨平台数据资产和 AI 资产 | https://gravitino.apache.org |
| **Metacat** | Netflix 开源的统一元数据管理服务 | https://github.com/Netflix/metacat |
| **Dataplex** | Google Cloud 数据治理和管理服务 | https://cloud.google.com/dataplex |
| **AWS Glue Data Catalog** | AWS 托管元数据目录，与 Glue ETL 深度集成 | https://aws.amazon.com/glue |
| **Unity Catalog** | Databricks 开源的统一数据和 AI 治理目录 | https://www.unitycatalog.io |

### 15.2 数据质量

| 工具 | 简介 | 链接 |
|------|------|------|
| **Great Expectations** | Python 数据质量验证和文档化框架，最流行的开源方案 | https://greatexpectations.io |
| **Apache Griffin** | 大数据质量监控解决方案，支持批处理和流式 | https://griffin.apache.org |
| **Deequ** | AWS 开源的数据质量验证库，基于 Spark | https://github.com/awslabs/deequ |
| **Soda** | 数据质量检查工具，以 YAML 定义检查规则 | https://www.soda.io |
| **Datafold** | 数据回归测试和质量监控平台 | https://www.datafold.com |
| **Elementary** | dbt 原生数据可观测性工具，自动异常检测 | https://www.elementary-data.com |
| **Monte Carlo** | 商业数据可观测性平台，自动检测数据异常 | https://www.montecarlodata.com |

### 15.3 数据血缘与沿袭

| 工具 | 简介 | 链接 |
|------|------|------|
| **OpenLineage** | 开放数据血缘标准和采集框架 | https://openlineage.io |
| **Marquez** | 基于 OpenLineage 的数据血缘追踪服务 | https://marquezproject.ai |
| **SQLLineage** | 基于 SQL 解析的自动血缘分析工具 | https://github.com/reata/sqllineage |
| **DataHub** | 内置数据血缘可视化能力 | https://datahubproject.io |

### 15.4 数据分类与隐私合规

| 工具 | 简介 | 链接 |
|------|------|------|
| **Apache Ranger** | Hadoop 生态统一安全授权和审计框架 | https://ranger.apache.org |
| **Apache Sentry** | Hadoop 生态细粒度权限管理（已停维，功能并入 Ranger） | https://sentry.apache.org |
| **Collibra** | 企业级数据治理和数据目录商业平台 | https://www.collibra.com |
| **Alation** | 企业级数据目录和数据治理商业平台 | https://www.alation.com |
| **Privacera** | 统一数据访问治理和隐私合规平台 | https://privacera.com |
| **AWS Lake Formation** | AWS 数据湖权限管理和治理服务 | https://aws.amazon.com/lake-formation |
| **Immuta** | 数据访问控制和隐私保护平台 | https://www.immuta.com |

### 15.5 数据标准与主数据管理 (MDM)

| 工具 | 简介 | 链接 |
|------|------|------|
| **Informatica MDM** | 企业级主数据管理商业平台 | https://www.informatica.com/products/master-data-management.html |
| **Talend MDM** | 开源主数据管理方案 | https://www.talend.com/products/mdm |
| **Reltio** | 云原生主数据管理平台 | https://www.reltio.com |
| **Ataccama ONE** | 数据质量 + 数据目录 + 主数据管理一体化平台 | https://www.ataccama.com |

---

## 十六、任务调度与编排

| 工具 | 简介 | 链接 |
|------|------|------|
| **Apache Airflow** | 最流行的工作流编排平台，Python DAG 定义 | https://airflow.apache.org |
| **DolphinScheduler** | Apache 可视化分布式任务调度平台，国产开源 | https://dolphinscheduler.apache.org |
| **XXL-JOB** | 轻量级分布式任务调度平台，开箱即用 | https://github.com/xuxueli/xxl-job |
| **Azkaban** | LinkedIn 开源的批量工作流调度器 | https://azkaban.github.io |
| **Oozie** | Hadoop 生态工作流调度系统 | https://oozie.apache.org |
| **Dagster** | 现代数据编排平台，资产感知型调度 | https://dagster.io |
| **Prefect** | 新一代 Python 工作流编排工具，Airflow 替代 | https://www.prefect.io |
| **Temporal** | 微服务编排引擎，支持长时间运行工作流 | https://temporal.io |

---

## 十七、数据可视化 / BI

| 工具 | 简介 | 链接 |
|------|------|------|
| **Apache Superset** | Apache 开源 BI 平台，支持丰富的可视化图表 | https://superset.apache.org |
| **Metabase** | 开源 BI 工具，零代码即可生成图表和仪表盘 | https://www.metabase.com |
| **Grafana** | 开源可视化平台，支持时序和关系型数据源 | https://grafana.com |
| **Redash** | 开源查询和可视化工具，支持多种数据源 | https://redash.io |
| **Tableau** | 商业 BI 领导者，拖拽式数据可视化分析 | https://www.tableau.com |
| **Power BI** | 微软商业 BI 工具，深度集成 Office 生态 | https://powerbi.microsoft.com |
| **FineBI / 帆软** | 国产商业 BI 工具，企业报表和自助分析 | https://www.finebi.com |
| **QuickSight** | AWS 全托管 BI 服务 | https://aws.amazon.com/quicksight |
| **Looker** | Google 云 BI 平台，LookML 建模驱动 | https://cloud.google.com/looker |
