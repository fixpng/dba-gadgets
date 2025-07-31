import requests
import json
import re
import base64
import open_metadata_lineage
"""  
被execute_demo.py调用的脚本，主要用于数据血缘提取
脚本功能：
- 离线ETL平台 dolphinscheduler 血缘提取
- 实时ETL平台 streampark 血缘提取
- 各方法血缘提取 demo
pip install sqllineage
pip install openmetadata-ingestion
"""


class GetCanalData:
    def __init__(self):
        
        self.username = "admin"
        self.password = "123456"
        self.url = "https://uatcanal.fixpng.com"
        # self.url = "http://192.168.31.130:8089"
        
        self.token = None
        self.get_token()

    def get_token(self):
        """接口1，获取令牌"""
        url = f"{self.url}/api/v1/user/login"
        res = requests.post(url, json={"username": self.username, "password": self.password}).json()
        self.token = res['data']['token']

    def get_data_add_lineage(self):
        """获取页面列表页内容"""
        url = f"{self.url}/api/v1/canal/instances?name=&clusterServerId=&page=1&size=1"
        headers = {
            'x-token': self.token
        }
        res = requests.get(url, headers=headers).json()
        print(res)
        for page in range(int(res['data']['count']/200) + 1):
            url = f"{self.url}/api/v1/canal/instances?name=&clusterServerId=&page={page + 1}&size=200"
            res = requests.get(url, headers=headers).json()
            for data in res['data']['items']:
                print (f"==========={data}============")
                content = self.get_data_detail(num=data['id'])
                description = f'''Canal\nInstance 名称：{data['name']}\n链接地址：{self.url}/#/canalServer/canalInstances'''
                # print(content)
                open_metadata_lineage.add_lineage_by_canal_propertios(content,description_=description)

    def get_data_detail(self, num):
        # 获取详细修改数据内容
        url = f"{self.url}/api/v1/canal/instance/{num}"
        headers = {
            'x-token': self.token
        }
        res = requests.get(url, headers=headers).json()
        content = res['data']['content']  # 这个即是修改页面里面内容
        return content


class GetDolphinSchedulerData:
    def __init__(self):
        self.url = 'https://uatds.fixpng.com/dolphinscheduler'
        
        self.userName = 'admin'
        self.userPassword = '123456'
        self.sessionId = None
        self.get_session_id()
        self.headers = {
            'Cookie': f'sessionId={self.sessionId};sessionId={self.sessionId}',
            'User-Agent': 'Apifox/1.0.0 (https://apifox.com)'
        }
        self.data_sources = {}
        self.get_data_sources()
        
    def get_session_id(self):
        login_url = f'{self.url}/login'
        payload = {
            'userName': self.userName,
            'userPassword': self.userPassword
        }
        response = requests.post(login_url, data=payload)
        if response.status_code == 200:
            self.sessionId = response.json().get('data', {}).get('sessionId')
            print("Login successful")
        else:
            print(f"Login failed: {response.text}")

    # 获取所有数据源
    def get_data_sources(self):
        url = f"{self.url}/datasources?pageNo=1&pageSize=1000&searchVal="
        response = requests.get(url, headers=self.headers)

        data = response.json().get('data', {}).get('totalList', [])
        for item in data:
            source_id = item.get('id')
            connection_params = json.loads(item.get('connectionParams', '{}'))
            jdbc_url = connection_params.get('jdbcUrl')
            if jdbc_url:
                self.data_sources[source_id] = jdbc_url
        print(self.data_sources)
        
    def get_data_add_lineage(self):
        projects = self.get_projects_list()
        for project in projects:
            project_code = project.get('code')
            project_name = project.get('name')
            user_name = project.get('userName')
            print(f"正在处理项目: {project_name} (Code: {project_code})")
            
            tasks = self.get_app_list(project_code = project_code)
            for task in tasks:
                process_definition_name = task.get('processDefinitionName')
                task_name = task.get('taskName')
                task_code = task.get('taskCode')
                task_type = task.get('taskType')
                task_url = f'{self.url}/ui/projects/{project_code}/task/definitions'
                
                description = f'''DolphinScheduler-{task_type}
项目名称：{project_name}
工作流名称：{process_definition_name}
任务名称：{task_name}
所属用户：{user_name}
链接地址：{task_url}'''
                print(description)
                
                # 获取任务详情
                self.get_task(project_code=project_code,task_code=task_code,description=description)
                print('-------------')
                
    # 获取所有项目列表
    def get_projects_list(self):
        url = f"{self.url}/projects?pageSize=2000&pageNo=1&searchVal="
        response = requests.get(url, headers=self.headers)
        if response.status_code == 200:
            data = response.json().get('data', {}).get('totalList', [])
            return data
        else:
            print(f"获取项目列表失败，状态码：{response.status_code}")
            return []

    # 获取指定项目的任务列表
    def get_app_list(self,project_code):
        url = f"{self.url}/projects/{project_code}/task-definition?pageSize=9999999&pageNo=1&searchTaskName=&taskType="
        response = requests.get(url, headers=self.headers)
        if response.status_code == 200:
            data = response.json().get('data', {}).get('totalList', [])
            return data
        else:
            print(f"获取任务列表失败，状态码：{response.status_code}")
            return []
        
    # 获取指定任务的详情，包括SQL或DataX JSON
    def get_task(self,project_code,task_code,description):
        url = f"{self.url}/projects/{project_code}/task-definition/{task_code}"
        response = requests.get(url, headers=self.headers)

        # 定义正则表达式模式，忽略大小写
        pattern = re.compile(r'(insert\s+into.*\s+select)', re.IGNORECASE)
        try:
            if response.status_code == 200:
                task_data = response.json().get('data', {})
                task_params = task_data.get('taskParams', {})
                if task_data['taskType'] == 'SQL':
                    # 检查 SQL 查询中是否包含 'INSERT ... SELECT'，忽略大小写
                    if pattern.search(task_params['sql']):
                        raw_service = self.data_sources[task_params['datasource']]
                        service = open_metadata_lineage.get_service_by_url(raw_service)
                        
                        if raw_service.split('/')[-1] == service or raw_service.split('/')[-1] == '':
                            db_name = None
                        else:
                            db_name = raw_service.split('/')[-1]
                                      
                        dolphinscheduler_sql = task_params['sql'].replace('`','')
                        open_metadata_lineage.add_lineage_by_sql(service,db_name,dolphinscheduler_sql,description_=description)
                    else:
                        print(f"任务 {task_code} 的SQL不为insert ... select, 跳过")
                        
                elif task_data['taskType'] == 'DATAX':
                    preprocessed_json_str = task_params['json'].replace('\n', '').replace('\t',' ').replace('`','')
                    datax_json = json.loads(preprocessed_json_str)
                    open_metadata_lineage.add_lineage_by_datax_json(datax_json,description_=description)
                else:
                    print(f"任务 {task_code} 不为SQL或DATAX 类型 {task_data['taskType']}")
            else:
                print(f"获取任务详情失败，状态码：{response.status_code}")
        
        except Exception as exc:
            print(f"执行失败,异常:{exc}")
            print('-----------------------')
 
 
class GetStreamParkData:
    def __init__(self):
        # 定义公共的请求头和API地址
        self.url = 'https://uatstreampark.fixpng.com'
        
        self.username='admin'
        self.password='123456'
        self.token = None
        self.get_token()
        self.headers = {
            'Authorization': self.token,
            'User-Agent': 'Apifox/1.0.0 (https://apifox.com)'
        }
        
    def get_token(self):
        login_url = f'{self.url}/passport/signin'
        payload = {
            'username': self.username,
            'password': self.password,
            'loginType': 'PASSWORD'
        }
        response = requests.post(login_url, data=payload)
        if response.status_code == 200:
            self.token = response.json().get('data', {}).get('token')
            print(response.text)
            print(self.token)
            print("Login successful")
        else:
            print(f"Login failed: {response.text}")

    def get_data_add_lineage(self):
        # 获取作业列表
        jobs = self.get_job_list()
        
        # 遍历作业列表中的每个作业ID，获取对应的Flink SQL
        for job in jobs:
            nick_name = job.get('nickName')
            job_name = job.get('jobName')
            task_type = job.get('k8sNamespace')
            task_id = job.get('id')
            team_id = job.get('teamId')
            
            description = f'''StreamPark-{task_type}
任务名称：{job_name}
所属用户：{nick_name}
链接地址：{self.url}/#/flink/app/detail?appId={task_id}'''
            print(description)
            self.get_flink_sql(task_id,team_id,description)

    
    # 1. 获取StreamPark作业管理列表
    def get_job_list(self, page_num=1, page_size=9999999, team_id='100000'):
        url = f'{self.url}/flink/app/list'
        data = {
            'pageNum': str(page_num),
            'pageSize': str(page_size),
            'teamId': team_id
        }

        response = requests.post(url, headers=self.headers, data=data)
        
        if response.status_code == 200:
            # print(response.json())
            job_list = response.json().get('data', {}).get('records', [])
            flink_sql_jobs = [job for job in job_list if job.get('appType') == 1]
            print(f"获取到的作业ID列表: {[job['id'] for job in flink_sql_jobs]}")
            return flink_sql_jobs
        else:
            print(f"获取作业列表失败，状态码: {response.status_code},{response.text}")
            return []

    # 2. 根据作业ID获取Flink SQL
    def get_flink_sql(self, app_id, team_id, description):
        url = f'{self.url}/flink/app/get'
        
        # 请求参数,只取最新的一个
        data = {
            "id": app_id,
            "teamId": team_id
        }

        response = requests.post(url, headers=self.headers, data=data)
        # print(response.json())

        if response.status_code == 200:
            row_filnk_sql = response.json().get('data', {}).get('flinkSql')
            # 解码为字符串
            flink_sql = base64.b64decode(row_filnk_sql).decode('utf-8')
            open_metadata_lineage.add_lineage_by_flink_sql(flink_sql, description_=description)
            
        else:
            print(f"获取appId {app_id} 的Flink SQL失败, 状态码: {response.status_code}")
            print(response.json())
            

class AllDemo:
    '''
    demo1: 单列血源添加
    '''
    @staticmethod
    def demo1():
        result = open_metadata_lineage.add_lineage("bigdata1.ods_acct_accounts-test0827_acct_dsf_txn_detail_test", "*",
                            "fat-starrocks.default.dsj_dwd.dwd_public_md_user_log_d", "*", 'demo1','select 1 ',fromType_='kafka')
        print(result)

    '''
    demo2: SQL血源添加, 使用第三方包 sqllineage, 因为 OpenMetadata 原生sql添加方法没有返回信息和中间过程, 成功失败无法追踪、高级功能也无法使用
    '''
    @staticmethod
    def demo2():
        database_service = 'Test-MySQL'

        # Original SQL query
        sql = """
        insert
        into
        my_test.fee_info (creator, tenant_id, updator) 
        select
            A.creator,
            B.tenant_id,
            B.office_name
        from
            my_test.archive_ledger_relationship A
        left join my_test.task_archive_borrowing B on
            B.mid = A.archive_ledger_id
        where
            A.state_id = 1
        """

        open_metadata_lineage.add_lineage_by_sql(database_service, 'default', sql)

    '''
    demo3: 解析 DATAX 的 JSON 血源添加,
    '''
    @staticmethod
    def demo3():
        data = """{
  "job": {
    "setting": {
      "speed": {
        "channel": 3
      },
      "errorLimit": {
        "record": 50,
        "percentage": 0.02
      }
    },
    "content": [
      {
        "reader": {
          "name": "mysqlreader",
          "parameter": {
            "username": "bigdata",
            "password": "123456",
            "connection": [
              {
                "querySql": [
                  "select 
`id`                 ,
`time_id`            ,
`time_code`          ,
`time_name`          ,
`year_id`            ,
`year_code`          ,
`year_name`          ,
`scene_id`           ,
`scene_code`         ,
`scene_name`         ,
`org_view_id`        ,
`org_view_code`      ,
`org_view_name`      ,
`org_id`             ,
`org_code`           ,
`org_name`           ,
`entry_code`         ,
`entry_name`         ,
`entry_key`          ,
`is_status`          ,
`entry_source`       ,
`business_type`      ,
`submit_user_id`     ,
`submit_user_name`   ,
`submit_time`        ,
`reject_user_id`     ,
`reject_user_name`   ,
`reject_time`        ,
`is_link`            ,
`tenant_id`          ,
`remark`             ,
`deleted`            ,
`create_user`        ,
`create_user_open_id`,
`create_time`        ,
`update_user`        ,
`update_user_open_id`,
`update_time`        ,
`book_type_id`       ,
`currency_code`      ,
`currency_name`      ,
                    now() as etl_time
                  from saas_fixpng_consolidated_statement.accounting_entry ;
                  "],
                  "jdbcUrl": [
                    "jdbc:mysql://lanuatsaasfixpng.internal.cn-south-1.mysql.rds.myfixpngcloud.com:6033"
                  ]
                  }
                ]
              }
            },
              "writer": {
                "name": "starrockswriter",
                "parameter": {
                  "username": "bigdata",
                  "password": "123456",
                  "database": "dsj_ods",
                  "table": "to_fixpng_saas_accounting_entry",
                  "column": ["*"],
                  "preSql": ["truncate table dsj_ods.to_fixpng_saas_accounting_entry"],
                  "postSql": [],
                  "jdbcUrl": "jdbc:mysql://uatstarrocks.fixpng.com:9030/dsj_ods",
                  "loadUrl": ["uatstarrocks.fixpng.com:8030"],
                  "loadProps": {
                    "format": "json",
                    "strip_outer_array": true
                  }
                }

              }
              }
            ]
          }
        }
        """
        description = '''DolphinScheduler-DATAX
项目名称：【体验环境】ODS_FIXPNG_电子档案、合并报表宽表
工作流名称：【uat】ods
任务名称：导入数据to_fixpng_saas_accounting_entry
所属用户：fixpng
链接地址：https://uatds.fixpng.com/dolphinscheduler/ui/projects/14016424928512/task/definitions'''
        datax_json = json.loads(data.replace('\n', '').replace('\t',' ').replace('`',''))
        print(datax_json)
        open_metadata_lineage.add_lineage_by_datax_json(datax_json,description_= description)


    '''
    demo4: 解析 FlinkSQL 血源添加,
    '''
    @staticmethod
    def demo4():
        """kafka jdbc"""
        flink_sql = """
CREATE TABLE `to_xxj_saas_pay_org_trade_flow_detail_receipt_binlog` (
  `id` bigint NOT NULL COMMENT '主键ID',
  `trade_flow_detail_id` bigint NULL COMMENT '交易明细流水id',
  `request_no` varchar(240) NULL COMMENT '业务交易流水号',
  `batch_no` varchar(240) NULL COMMENT '业务批次号',
  `channel_info_code` varchar(120) NULL COMMENT '渠道code',
  `receipt_type` int NULL COMMENT '回单类型 1：付款单  2：回款单',
  `channel_account_code` varchar(120) NULL COMMENT '渠道账号代码',
  `channel_account_id` bigint NULL COMMENT '渠道账户id',
  `is_status` int NULL COMMENT '0：未处理  1：成功  2：处理中  3：失败',
  `trade_type` int NULL COMMENT '交易类型',
  `url` varchar(2000) NULL COMMENT '存储url 路径',
  `file_name` varchar(400) NULL COMMENT '文件名',
  `bank_side_status` int NULL COMMENT '银行处理状态 ：-1：未知，0：未发起 1：已受理 2：受理中 3：处理失败 4：处理成功',
  `trade_time` timestamp NULL COMMENT '交易时间',
  `app_id` varchar(80) NULL COMMENT 'appid',
  `trade_message` varchar(400) NULL COMMENT '请求消息',
  `trade_request_no` varchar(240) NULL COMMENT '请求流水',
  `trade_order_no` varchar(1024) NULL COMMENT '请求返回订单号',
  `create_time` timestamp NULL COMMENT '请求时间',
  `update_time` timestamp NULL COMMENT '更新时间',
  `extend_1` varchar(320) NULL COMMENT '扩展字段1',
  `extend_2` varchar(320) NULL COMMENT '扩展字段2',
  `search_count` int NULL COMMENT '查询',
  PRIMARY KEY (`id`) NOT ENFORCED
--)WITH ( 'connector' = 'mysql-cdc',
--       'hostname' = '192.168.31.133',
--       'port' = '6033',
--       'username' = 'bigdata',
--       'password' = '123456',
--       'database-name' = 'saas_cash_pay_trade',
--       'table-name' = 'pay_org_trade_flow_detail_receipt',
--     'scan.startup.mode' = 'initial' 
--      -- 'scan.startup.mode' = 'timestamp',
--      -- 'scan.startup.timestamp-millis' = '1720144311000'
--	    ,'debezium.snapshot.mode' = 'when_needed','server-id'='7003');
)WITH ( 'connector' = 'kafka',
    'topic' = 'ods_xxj_saas_cash_pay_trade-saas_pay_org_trade_flow_detail_receipt-uat',
    'properties.bootstrap.servers' = 'hwuat-kafka03.fixpng.com:9092,hwuat-kafka02.fixpng.com:9092,hwuat-kafka01.fixpng.com:9092',
       'properties.group.id' = 'kafka_group_saas_xxj_20240709_saas_prod_ods',
       'format' = 'canal-json',
       'scan.startup.mode' = 'earliest-offset',
       'canal-json.ignore-parse-errors' = 'true');			
		
CREATE TABLE `to_xxj_saas_pay_org_trade_flow_detail_receipt` (
  `id` bigint NOT NULL COMMENT '主键ID',
  `trade_flow_detail_id` bigint NULL COMMENT '交易明细流水id',
  `request_no` varchar(240) NULL COMMENT '业务交易流水号',
  `batch_no` varchar(240) NULL COMMENT '业务批次号',
  `channel_info_code` varchar(120) NULL COMMENT '渠道code',
  `receipt_type` int NULL COMMENT '回单类型 1：付款单  2：回款单',
  `channel_account_code` varchar(120) NULL COMMENT '渠道账号代码',
  `channel_account_id` bigint NULL COMMENT '渠道账户id',
  `is_status` int NULL COMMENT '0：未处理  1：成功  2：处理中  3：失败',
  `trade_type` int NULL COMMENT '交易类型',
  `url` varchar(2000) NULL COMMENT '存储url 路径',
  `file_name` varchar(400) NULL COMMENT '文件名',
  `bank_side_status` int NULL COMMENT '银行处理状态 ：-1：未知，0：未发起 1：已受理 2：受理中 3：处理失败 4：处理成功',
  `trade_time` timestamp NULL COMMENT '交易时间',
  `app_id` varchar(80) NULL COMMENT 'appid',
  `trade_message` varchar(400) NULL COMMENT '请求消息',
  `trade_request_no` varchar(240) NULL COMMENT '请求流水',
  `trade_order_no` varchar(1024) NULL COMMENT '请求返回订单号',
  `create_time` timestamp NULL COMMENT '请求时间',
  `update_time` timestamp NULL COMMENT '更新时间',
  `extend_1` varchar(320) NULL COMMENT '扩展字段1',
  `extend_2` varchar(320) NULL COMMENT '扩展字段2',
  `search_count` int NULL COMMENT '查询',
  `etl_time` timestamp NULL COMMENT 'etl时间',
 PRIMARY KEY (`id`) NOT ENFORCED		
 )WITH( 'connector' = 'starrocks',
       'jdbc-url'='jdbc:mysql://uatstarrocks.fixpng.com:9030',
       'load-url'='uatstarrocks.fixpng.com:8030',
       'database-name' = 'dsj_ods',
       'table-name' = 'to_xxj_saas_pay_org_trade_flow_detail_receipt',
       'username'='bigdata',
       'password'= '123456',
       'sink.buffer-flush.max-rows' = '64000',
       'sink.buffer-flush.max-bytes' = '300000000',
       'sink.buffer-flush.interval-ms' = '5000',
       'sink.max-retries' = '3',
       'sink.parallelism' = '1',
       'sink.buffer-flush.enqueue-timeout-ms' = '3600000',
       'sink.properties.format'='json',
       'sink.version'='V1',
       'sink.properties.strip_outer_array' ='true');
	   
insert into to_xxj_saas_pay_org_trade_flow_detail_receipt select *,LOCALTIMESTAMP as etl_time from to_xxj_saas_pay_org_trade_flow_detail_receipt_binlog;

CREATE TABLE `to_xxj_saas_pay_org_trade_flow_receipt_binlog` (
  `id` bigint NOT NULL COMMENT '主键ID',
  `channel_info_code` varchar(120) NOT NULL COMMENT '渠道code',
  `trade_flow_id` bigint NULL COMMENT '交易流水id',
  `request_no` varchar(240) NULL COMMENT '请求流水号',
  `receipt_type` int NULL COMMENT '回单类型 1：付款单  2：回款单',
  `channel_account_code` varchar(120) NULL COMMENT '渠道账号代码',
  `channel_account_id` bigint NULL COMMENT '渠道账户id',
  `is_status` int NULL COMMENT '0：未处理  1：成功  2：处理中  3：失败',
  `trade_type` int NULL COMMENT '交易类型',
  `url` varchar(2000) NULL COMMENT '存储url 路径',
  `file_name` varchar(800) NULL COMMENT '文件名',
  `bank_side_status` int NULL COMMENT '银行处理状态 ：-1：未知，0：未发起 1：已受理 2：受理中 3：处理失败 4：处理成功',
  `trade_time` timestamp NULL COMMENT '交易时间',
  `app_id` varchar(80) NULL COMMENT 'appid',
  `trade_message` varchar(400) NULL COMMENT '请求消息',
  `trade_request_no` varchar(480) NULL COMMENT '请求流水',
  `trade_order_no` varchar(320) NULL COMMENT '请求返回订单号',
  `create_time` timestamp NULL COMMENT '请求时间',
  `update_time` timestamp NULL COMMENT '更新时间',
  `extend_1` varchar(320) NULL COMMENT '扩展字段1',
  `extend_2` varchar(320) NULL COMMENT '扩展字段2',
  `search_count` int NULL COMMENT '查询次数',
  `trans_type` int NULL COMMENT '交易业务类型:1-单笔交易;2-批量交易;3-提现;4-退票;5-充值0-其他',
  `extend_3` varchar(512) NULL COMMENT '扩展字段3 浦发申请编号',
  `tenant_id` varchar(256) NULL COMMENT '租户ID',
 PRIMARY KEY (`id`) NOT ENFORCED
--  )
--  WITH ( 'connector' = 'mysql-cdc',
--       'hostname' = '192.168.31.133',
--       'port' = '6033',
--       'username' = 'bigdata',
--       'password' = '123456',
--       'database-name' = 'saas_cash_pay_trade',
--       'table-name' = 'pay_org_trade_flow_receipt',
--     'scan.startup.mode' = 'initial' 
--      -- 'scan.startup.mode' = 'timestamp',
--      -- 'scan.startup.timestamp-millis' = '1720144311000'
--	    ,'debezium.snapshot.mode' = 'when_needed','server-id'='7033');
)WITH ( 'connector' = 'kafka',
    'topic' = 'ods_xxj_saas_cash_pay_trade-saas_pay_org_trade_flow_receipt-uat',
    'properties.bootstrap.servers' = 'hwuat-kafka03.fixpng.com:9092,hwuat-kafka02.fixpng.com:9092,hwuat-kafka01.fixpng.com:9092',
       'properties.group.id' = 'kafka_group_saas_xxj_20240709_saas_prod_ods',
       'format' = 'canal-json',
       'scan.startup.mode' = 'earliest-offset',
       'canal-json.ignore-parse-errors' = 'true');		
	   
CREATE TABLE `to_xxj_saas_pay_org_trade_flow_receipt` (
  `id` bigint NOT NULL COMMENT '主键ID',
  `channel_info_code` varchar(120) NOT NULL COMMENT '渠道code',
  `trade_flow_id` bigint NULL COMMENT '交易流水id',
  `request_no` varchar(240) NULL COMMENT '请求流水号',
  `receipt_type` int NULL COMMENT '回单类型 1：付款单  2：回款单',
  `channel_account_code` varchar(120) NULL COMMENT '渠道账号代码',
  `channel_account_id` bigint NULL COMMENT '渠道账户id',
  `is_status` int NULL COMMENT '0：未处理  1：成功  2：处理中  3：失败',
  `trade_type` int NULL COMMENT '交易类型',
  `url` varchar(2000) NULL COMMENT '存储url 路径',
  `file_name` varchar(800) NULL COMMENT '文件名',
  `bank_side_status` int NULL COMMENT '银行处理状态 ：-1：未知，0：未发起 1：已受理 2：受理中 3：处理失败 4：处理成功',
  `trade_time` timestamp NULL COMMENT '交易时间',
  `app_id` varchar(80) NULL COMMENT 'appid',
  `trade_message` varchar(400) NULL COMMENT '请求消息',
  `trade_request_no` varchar(480) NULL COMMENT '请求流水',
  `trade_order_no` varchar(320) NULL COMMENT '请求返回订单号',
  `create_time` timestamp NULL COMMENT '请求时间',
  `update_time` timestamp NULL COMMENT '更新时间',
  `extend_1` varchar(320) NULL COMMENT '扩展字段1',
  `extend_2` varchar(320) NULL COMMENT '扩展字段2',
  `search_count` int NULL COMMENT '查询次数',
  `trans_type` int NULL COMMENT '交易业务类型:1-单笔交易;2-批量交易;3-提现;4-退票;5-充值0-其他',
  `extend_3` varchar(512) NULL COMMENT '扩展字段3 浦发申请编号',
  `tenant_id` varchar(256) NULL COMMENT '租户ID',
  `etl_time` timestamp NULL COMMENT 'etl时间',
   PRIMARY KEY (`id`,`channel_info_code`) NOT ENFORCED
 )WITH( 'connector' = 'starrocks',
       'jdbc-url'='jdbc:mysql://uatstarrocks.fixpng.com:9030',
       'load-url'='uatstarrocks.fixpng.com:8030',
       'database-name' = 'dsj_ods',
       'table-name' = 'to_xxj_saas_pay_org_trade_flow_receipt',
       'username'='bigdata',
       'password'= '123456',
       'sink.buffer-flush.max-rows' = '64000',
       'sink.buffer-flush.max-bytes' = '300000000',
       'sink.buffer-flush.interval-ms' = '5000',
       'sink.max-retries' = '3',
       'sink.parallelism' = '1',
       'sink.buffer-flush.enqueue-timeout-ms' = '3600000',
       'sink.properties.format'='json',
       'sink.version'='V1',
       'sink.properties.strip_outer_array' ='true');
	   
insert into to_xxj_saas_pay_org_trade_flow_receipt select *,LOCALTIMESTAMP as etl_time from to_xxj_saas_pay_org_trade_flow_receipt_binlog;
	   
	   
CREATE TABLE to_saas_pay_org_trade_flow_person_receipt_binlog(
`id`  bigint not  null   comment  '主键ID',
`trade_flow_detail_id`  bigint  comment  '交易明细流水id',
`request_no`  varchar(240)  comment  '业务交易流水号',
`batch_no`  varchar(240)  comment  '业务批次号',
`channel_info_code`  varchar(120)  comment  '渠道code',
`receipt_type`  int  comment  '回单类型 1：付款单  2：回款单',
`channel_account_code`  varchar(120)  comment  '渠道账号代码',
`channel_account_id`  bigint  comment  '渠道账户id',
`is_status`  int  comment  '0：未处理  1：成功  2：处理中  3：失败',
`trade_type`  int  comment  '交易类型',
`url`  varchar(2000)  comment  '存储url 路径',
`file_name`  varchar(400)  comment  '文件名',
`bank_side_status`  int  comment  '银行处理状态 ：-1：未知，0：未发起 1：已受理 2：受理中 3：处理失败 4：处理成功',
`trade_time`  timestamp  comment  '交易时间',
`app_id`  varchar(80)  comment  'appid',
`trade_message`  varchar(8000)  comment  '请求消息',
`trade_request_no`  varchar(240)  comment  '请求流水',
`trade_order_no`  varchar(1024)  comment  '请求返回订单号',
`create_time`  timestamp  comment  '请求时间',
`update_time`  timestamp  comment  '更新时间',
`extend_1`  varchar(320)  comment  '扩展字段1',
`extend_2`  varchar(320)  comment  '扩展字段2',
`search_count`  int  comment  '查询',
`extend_3`  varchar(128)  comment  '扩展字段3',
`is_delete`  int  comment  '逻辑删除:0-否;1-是',
 PRIMARY KEY (`id`) NOT ENFORCED
-- )
-- WITH ( 'connector' = 'mysql-cdc',
--      'hostname' = '192.168.31.133',
--      'port' = '6033',
--      'username' = 'bigdata',
--      'password' = '123456',
--      'database-name' = 'saas_cash_pay_trade',
--      'table-name' = 'pay_org_trade_flow_person_receipt',
--   -- 'scan.startup.mode' = 'initial' 
--      'scan.startup.mode' = 'timestamp',
--      'scan.startup.timestamp-millis' = '1720144311000');
)WITH ( 'connector' = 'kafka',
    'topic' = 'ods_xxj_saas_cash_pay_trade-pay_org_trade_flow_person_receipt-uat',
    'properties.bootstrap.servers' = 'hwuat-kafka03.fixpng.com:9092,hwuat-kafka02.fixpng.com:9092,hwuat-kafka01.fixpng.com:9092',
       'properties.group.id' = 'kafka_group_saas_xxj_20240709_saas_prod_ods',
       'format' = 'canal-json',
       'scan.startup.mode' = 'earliest-offset',
       'canal-json.ignore-parse-errors' = 'true');	
       
CREATE TABLE to_saas_pay_org_trade_flow_person_receipt
 ( 
`id`  bigint not  null   comment  '主键ID',
`trade_flow_detail_id`  bigint  comment  '交易明细流水id',
`request_no`  varchar(240)  comment  '业务交易流水号',
`batch_no`  varchar(240)  comment  '业务批次号',
`channel_info_code`  varchar(120)  comment  '渠道code',
`receipt_type`  int  comment  '回单类型 1：付款单  2：回款单',
`channel_account_code`  varchar(120)  comment  '渠道账号代码',
`channel_account_id`  bigint  comment  '渠道账户id',
`is_status`  int  comment  '0：未处理  1：成功  2：处理中  3：失败',
`trade_type`  int  comment  '交易类型',
`url`  varchar(2000)  comment  '存储url 路径',
`file_name`  varchar(400)  comment  '文件名',
`bank_side_status`  int  comment  '银行处理状态 ：-1：未知，0：未发起 1：已受理 2：受理中 3：处理失败 4：处理成功',
`trade_time`  timestamp  comment  '交易时间',
`app_id`  varchar(80)  comment  'appid',
`trade_message`  varchar(8000)  comment  '请求消息',
`trade_request_no`  varchar(240)  comment  '请求流水',
`trade_order_no`  varchar(1024)  comment  '请求返回订单号',
`create_time`  timestamp  comment  '请求时间',
`update_time`  timestamp  comment  '更新时间',
`extend_1`  varchar(320)  comment  '扩展字段1',
`extend_2`  varchar(320)  comment  '扩展字段2',
`search_count`  int  comment  '查询',
`extend_3`  varchar(128)  comment  '扩展字段3',
`is_delete`  int  comment  '逻辑删除:0-否;1-是',
`etl_time`       timestamp COMMENT 'etl 时间',
 PRIMARY KEY (`id`) NOT ENFORCED
 )
 WITH( 'connector' = 'starrocks',
       'jdbc-url'='jdbc:mysql://uatstarrocks.fixpng.com:9030',
       'load-url'='uatstarrocks.fixpng.com:8030',
       'database-name' = 'dsj_ods',
       'table-name' = 'to_saas_pay_org_trade_flow_person_receipt',
       'username'='bigdata',
       'password'= '123456',
       'sink.buffer-flush.max-rows' = '64000',
       'sink.buffer-flush.max-bytes' = '300000000',
       'sink.buffer-flush.interval-ms' = '5000',
       'sink.max-retries' = '3',
       'sink.parallelism' = '1',
       'sink.buffer-flush.enqueue-timeout-ms' = '3600000',
       'sink.properties.format'='json',
       'sink.version'='V1',
       'sink.properties.strip_outer_array' ='true');
insert into to_saas_pay_org_trade_flow_person_receipt select id,trade_flow_detail_id,request_no,batch_no,channel_info_code,receipt_type,channel_account_code,channel_account_id,is_status,trade_type,url,file_name,bank_side_status,trade_time,app_id,trade_message,trade_request_no,trade_order_no,create_time,update_time,extend_1,extend_2,search_count,extend_3,is_delete,LOCALTIMESTAMP as etl_time from to_saas_pay_org_trade_flow_person_receipt_binlog a;
    """
        open_metadata_lineage.add_lineage_by_flink_sql(flink_sql)


    '''
    demo5: 解析 CANAL 的 instance.propertios 血源添加,
    '''
    @staticmethod
    def demo5():
        instance_propertios ="""
#################################################
## mysql serverId , v1.0.26+ will autoGen
# canal.instance.mysql.slaveId=0

# enable gtid use true/false
canal.instance.gtidon=false

#孵化体验和测试库
# position info
#地址
canal.instance.master.address=fatswb-mysql.fixpng.com:3306
canal.instance.master.journal.name=
canal.instance.master.position=
canal.instance.master.timestamp=
canal.instance.master.gtid=

# rds oss binlog
canal.instance.rds.accesskey=
canal.instance.rds.secretkey=
canal.instance.rds.instanceId=

# table meta tsdb info
canal.instance.tsdb.enable=true
#canal.instance.tsdb.url=jdbc:mysql://127.0.0.1:3306/canal_tsdb
#canal.instance.tsdb.dbUsername=canal
#canal.instance.tsdb.dbPassword=canal

#canal.instance.standby.address =
#canal.instance.standby.journal.name =
#canal.instance.standby.position =
#canal.instance.standby.timestamp =
#canal.instance.standby.gtid=

# username/password
#用户名/密码
canal.instance.dbUsername=bigdata
canal.instance.dbPassword=123456
canal.instance.connectionCharset = UTF-8
# enable druid Decrypt database password
canal.instance.enableDruid=false

# table regex
#要采集的库表，fixpng_hatch_xfh 是体验库，fixpng_hatch_feature是测试库，此时采集的是体验的
canal.instance.filter.regex=\
fixpng_hatch_xfh.incubate_cooperation_provider,\
fixpng_hatch_xfh.hatch_company_info,\
fixpng_hatch_xfh.hatch_business_scope_change,\
fixpng_hatch_xfh.hatch_cooperation_contract,\
fixpng_hatch_xfh.hatch_person_info,\
fixpng_hatch_xfh.hatch_bearing_contract,\
fixpng_hatch_xfh.hatch_natural_person_info,\
fixpng_hatch_xfh.hatch_register_info,\
fixpng_hatch_xfh.incubate_subject_cooperation,\
fixpng_hatch_xfh.hatch_crm_order,\

# table black regex
canal.instance.filter.black.regex=




# table field filter(format: schema1.tableName1:field1/field2,schema2.tableName2:field1/field2)
#canal.instance.filter.field=test1.t_product:id/subject/keywords,test2.t_company:id/name/contact/ch
# table field black filter(format: schema1.tableName1:field1/field2,schema2.tableName2:field1/field2)
#canal.instance.filter.black.field=test1.t_product:subject/product_image,test2.t_company:id/name/contact/ch

# mq config
canal.mq.topic=test_hatch
# dynamic topic route by schema or table regex
#配置表的topic
canal.mq.dynamicTopic=\
ods-hatch-fixpng_hatch_xfh-incubate_cooperation_provider-test:fixpng_hatch_xfh\\.incubate_cooperation_provider,\
ods-hatch-fixpng_hatch_xfh-hatch_company_info-test:fixpng_hatch_xfh\\.hatch_company_info,\
ods-hatch-fixpng_hatch_xfh-hatch_business_scope_change-test:fixpng_hatch_xfh\\.hatch_business_scope_change,\
ods-hatch-fixpng_hatch_xfh-hatch_cooperation_contract-test:fixpng_hatch_xfh\\.hatch_cooperation_contract,\
ods_hatch_fixpng_hatch_xfh_hatch_person_info_test:fixpng_hatch_xfh\\.hatch_person_info,\
ods-hatch-fixpng_hatch_xfh-hatch_bearing_contract-test:fixpng_hatch_xfh\\.hatch_bearing_contract,\
ods-hatch-fixpng_hatch_xfh-hatch_natural_person_info-test:fixpng_hatch_xfh\\.hatch_natural_person_info,\
ods-hatch-fixpng_hatch_xfh-hatch_register_info-test:fixpng_hatch_xfh\\.hatch_register_info,\
ods-hatch-fixpng_hatch_xfh-incubate_subject_cooperation-test:fixpng_hatch_xfh\\.incubate_subject_cooperation,\
ods-hatch-fixpng_hatch_xfh-hatch_crm_order-test:fixpng_hatch_xfh\\.hatch_crm_order,\

canal.mq.partition=0
# hash partition config
#canal.mq.partitionsNum=3
#canal.mq.partitionHash=test.table:id^name,.*\\..*
#################################################

    """
        open_metadata_lineage.add_lineage_by_canal_propertios(instance_propertios)
