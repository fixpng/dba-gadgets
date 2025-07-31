# 数据血缘摄取脚本

本目录下的脚本用于自动化提取和录入数据血缘信息，支持多种数据平台和ETL工具，包括 DolphinScheduler、StreamPark、Canal、FlinkSQL、DataX 等。血缘信息将自动同步到 OpenMetadata 元数据平台，便于数据治理和溯源。

- 同步 ETL平台 数据血缘至 元数据平台 的脚本程序还在优化中，当前支持类型如下：

| 序号 | 血缘来源                            | 已支持                                                  | 规划中                       |
| ---- | ------------------------------------ | -------------------------------------------------------- | ---------------------------- |
| 0    | 元数据同步（平台自带） |  视图血缘                      | 无                  |
| 1    | 离线ETL平台 DoplhinScheduler（海豚） | SQL、DATAX                                               | shell、其他                  |
| 2    | 实时ETL平台 StreamPark               | FlinkSQL（starrocks、mongo-cdc、mysql-cdc、jdbc、kafka） | FlinkSQL(elasticsearch)、jar |
| 3    | Canal                                | mysql --> canal --> kafka                                | 无                           |

依赖环境
- Python 3.7+
- 依赖包安装：
  ```bash
  pip install sqllineage openmetadata-ingestion pymysql requests django mirage-crypto
  ```

主要脚本说明
- `open_metadata_lineage.py`  
  核心血缘提取与写入 OpenMetadata 的实现，支持 SQL、DataX、FlinkSQL、Canal 等多种方式。
- `get_etl_add_lineage.py`  
  各平台（DolphinScheduler、StreamPark、Canal）血缘提取入口，调用 `open_metadata_lineage.py`。
- `execute_demo.py`  
  脚本入口，定时任务可直接调用，自动批量提取并写入血缘信息。
- `open_metadata_db_info.py`  
  数据库服务、域、标签等元数据的批量注册与同步脚本。

使用方法
1. 配置数据库连接、OpenMetadata 地址和 Token（详见各脚本开头的配置）。
2. 执行 `execute_demo.py`，即可自动批量提取并写入血缘信息。
   ```bash
   python execute_demo.py
   ```
3. 可根据需要单独调用 `get_etl_add_lineage.py` 中的各类 Demo 或平台方法。

注意事项
- 需提前在 OpenMetadata 平台配置好服务、域、标签等基础元数据。
- 数据库连接、平台 API Token 等敏感信息请妥善保管。
- 如需扩展支持新的数据源或血缘类型，可在 `open_metadata_lineage.py` 中补充相应方法。

