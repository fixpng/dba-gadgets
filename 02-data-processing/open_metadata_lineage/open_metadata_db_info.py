# -*- coding: utf-8 -*-
import requests
import json
import random
import pymysql
from datetime import datetime, timedelta, timezone
from django.conf import settings
from mirage.crypto import Crypto
""" 
脚本功能：获取数据库元数据信息，目前支持：mysql、mongo，依赖archery的 sql_instance 表获取登录配置
```sql
CREATE TABLE open_metadata_url_service (
    id INT AUTO_INCREMENT PRIMARY KEY,
    url_pattern VARCHAR(255) NOT NULL,
    service_name VARCHAR(255) NOT NULL,
    UNIQUE INDEX idx_url_pattern (url_pattern)
);
	 
INSERT INTO open_metadata_url_service (url_pattern, service_name)
select concat(host,':',port) as address,instance_name 
from sql_instance
WHERE  host is not null  and replace(host,' ','') <> '' and instance_name not like '%下线%' and environment in ('uat','prod')
and instance_name not in ('xxxxxxxxxxx')
union
select real_address as address,instance_name 
from sql_instance
 WHERE  real_address is not null and replace(real_address,' ','') <> '' and instance_name not like '%下线%' and environment in ('uat','prod')
 and instance_name not in ('xxxxxxxxxx');
```
"""

# 加密
if not settings.configured:
    settings.configure(
        SECRET_KEY="xxxxxxxxxxxxxxxxxxxx",
    )
C = Crypto()


# Archery库连接信息
arch_config = {
    'host': '192.168.31.130',
    'port': 3306,
    'database': 'archery',
    'user': 'archery',
    'password': 'xxxxxxxxxxxxxxx'
}

# 数据库连接函数-mysql
def create_mysql_connection(host, port, database, user, password):
    return pymysql.connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
        connect_timeout=1
    )
    
# 基础配置
base_url = "http://meta.fixpng.com/api/v1/"
headers = {
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9",
    "Authorization": "Bearer xxxxxxxxxxxxxxxxxxx",
    "Connection": "keep-alive",
    "Content-Type": "application/json",
    "Cookie": "session=a82333bc-ccb2-42df-b7e8-fc818f5c69ed.1LEbd-CMsD7kjxJDTnxJQf_HhOY; STAR_OMD_USER_897491068=true; VERSION_1_5_2=true; STAR_OMD_USER_admin=true; STAR_OMD_USER_888=true; i18next=zh-CN; __session=%7B%22id%22%3A%22e35adeb1-7454-4134-b4bf-d1299e436c3c%22%2C%22created%22%3A1732182352792%2C%22createdAt%22%3A%222024-11-21T09%3A45%3A52.792Z%22%2C%22expires%22%3A1732184156484%2C%22expiresAt%22%3A%222024-11-21T10%3A15%3A56.484Z%22%2C%22modified%22%3A1732182356484%2C%22modifiedAt%22%3A%222024-11-21T09%3A45%3A56.484Z%22%7D",
    "Origin": "http://meta.fixpng.com",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.88 Safari/537.36"
}



class MetaService:
    def __init__(self, base_url, headers):
        self.base_url = base_url
        self.headers = headers

    def create_tag(self, classifications_name, tag_name, description):
        url = f"{self.base_url}tags"
        data = {
            "name": tag_name,
            "displayName": "",
            "description": description,
            "classification": classifications_name,
            "style": {}
        }
        response = requests.post(url, headers=self.headers, data=json.dumps(data))
        print(f"Create Tag Response Status Code: {response.status_code}")
        print(f"Create Tag Response Content: {response.content}")
        return response.json()
    def create_domain(self, name, description):
        url = f"{self.base_url}domains"
        data = {
            "name": name,
            "displayName": "",
            "description": description,
            "domainType": "Aggregate",
            "owners": [],
            "experts": [],
            "style": {}
        }
        response = requests.post(url, headers=self.headers, data=json.dumps(data))
        print(f"Create Domain Response Status Code: {response.status_code}")
        print(f"Create Domain Response Content: {response.content}")
        return response.json()

    def create_database_service(self, name, description, domain, db_type, username, password, hostPort, env, resourceGroups):
        url = f"{self.base_url}services/databaseServices"
        # 分割 resourceGroups 字符串
        if env == "prod":
            tier = "Tier1"
        elif env == "uat":
            tier = "Tier2"
        elif env == "fat":
            tier = "Tier3"
        elif env == "dev":
            tier = "Tier4"
        else:
            tier = "Tier5"
        # 生成标签列表
        tags = [{
            "labelType": "Automated",
            "source": "Classification",
            "state": "Confirmed",
            "tagFQN": f"Tier.{tier}"
        }]
        
        # resourceGroups = "resource_group1::resource_group2::resource_group3"
        resource_group_list = [group.strip() for group in resourceGroups.split('::') if group.strip()]
        # 动态生成资源组标签
        for group in resource_group_list:
            tags.append({
                "labelType": "Automated",
                "source": "Classification",
                "state": "Confirmed",
                "tagFQN": f"ResourceGroup.{group}"
            })
            
            
        if db_type=='mysql':
            serviceType = "Mysql"
            scheme = "mysql+pymysql"
            databaseName = "information_schema"
            connection = {
                "config": {
                    "type": serviceType,
                    "scheme": scheme,
                    "username": username,
                    "authType": {
                        "password": password
                    },
                    "hostPort": hostPort,
                    "databaseName" : databaseName,
                    "supportsMetadataExtraction": True,
                    "supportsDBTExtraction": True,
                    "supportsProfiler": True,
                    "supportsQueryComment": True
                }
            }
        elif db_type == 'mongo':
            serviceType = "MongoDB"
            scheme = "mongodb"
            databaseName = "admin"
            connection = {
                "config": {
                    "type": serviceType,
                    "scheme": scheme,
                    "username": username,
                    "password": password,
                    "hostPort": hostPort,
                    "databaseName" : databaseName,
                    "supportsMetadataExtraction": True,
                    "supportsProfiler": True
                }
            }
        
        data = {
            "name": name,
            "serviceType": serviceType,
            "domain": domain,
            "description": description,
            "owners": [
                {
                    "id": "dc732f45-ee37-4775-9859-3dbc292eb624",
                    "type": "user"
                }
            ],
            "connection": connection,
            "tags": tags
        }
        response = requests.post(url, headers=self.headers, data=json.dumps(data))
        # print(f"Create Database Service Response Status Code: {response.status_code}")
        print(f"Create Database Service Response Content: {response.content}")
        return response.json()

    def create_ingestion_pipeline(self, service_id, service_name):
        current_time = datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
        random_hour = random.randint(20, 23) if random.randint(0, 1) == 0 else random.randint(0, 6)
        random_minute = random.randint(0, 59)
        schedule_interval = f"{random_minute} {random_hour} * * *"

        url = f"{self.base_url}services/ingestionPipelines"
        data = {
            "airflowConfig": {
                "scheduleInterval": schedule_interval,
                "startDate": current_time
            },
            "loggerLevel": "INFO",
            "name": f"{service_name}_metadata_000000",
            "displayName": f"{service_name}_metadata_000000",
            "owners": [
                {
                    "id": "dc732f45-ee37-4775-9859-3dbc292eb624",
                    "type": "user"
                }
            ],
            "pipelineType": "metadata",
            "service": {
                "id": service_id,
                "type": "databaseService"
            },
            "sourceConfig": {
                "config": {
                    "type": "DatabaseMetadata",
                    "markDeletedTables": True,
                    "markDeletedStoredProcedures": True,
                    "includeTables": True,
                    "includeViews": True,
                    "includeTags": True,
                    "includeOwners": False,
                    "includeStoredProcedures": True,
                    "includeDDL": True,
                    "overrideMetadata": False,
                    "overrideViewLineage": False,
                    "queryLogDuration": 1,
                    "queryParsingTimeoutLimit": 300,
                    "useFqnForFiltering": False,
                    "threads": 1,
                    "incremental": {
                        "enabled": False,
                        "lookbackDays": 7,
                        "safetyMarginDays": 1
                    }
                }
            }
        }
        
        response = requests.post(url, headers=self.headers, data=json.dumps(data))
        print(f"Create Ingestion Pipeline Response Status Code: {response.status_code}")
        # print(f"Create Ingestion Pipeline Response Content: {response.content}")
        return response.json()

    def deploy_ingestion_pipeline(self, pipeline_id):
        url = f"{self.base_url}services/ingestionPipelines/deploy/{pipeline_id}"
        response = requests.post(url, headers=self.headers)
        print(f"Deploy Ingestion Pipeline Response Status Code: {response.status_code}")
        print(f"Deploy Ingestion Pipeline Response Content: {response.content}")

# 主函数
def main():
    meta_service = MetaService(base_url, headers)
    
    # domains = ["数据中台", "业务中台", "HRM"]
    
    # # 创建域
    # for domain in domains:
    #     domain_response = meta_service.create_domain(domain, f"{domain}")
    #     if domain_response.get("id"):
    #         domain_id = domain_response["id"]
    #         print(f"Domain {domain} created successfully with ID: {domain_id}")
    #     else:
    #         print(f"Failed to create Domain {domain}.")
            
    
    # 创建Tags
    # tags = [("HRM考勤","group_id=10"),("HRM绩效","group_id=100"),("HRM宿舍","group_id=102")]
    # classifications_name = "ResourceGroup"
    # for tag_name,desc in tags:
    #     tag_response = meta_service.create_tag(classifications_name,tag_name, desc)
    #     if tag_response.get("id"):
    #         tag_id = tag_response["id"]
    #         print(f"Tag {tag_name} created successfully with ID: {tag_id}")
    #     else:
    #         print(f"Failed to create Tag {tag_name}.")
            


   # 连接到日志数据库 archery
    try:
        LOGS_CONNECTION = create_mysql_connection(**arch_config)
        LOGS_CURSOR = LOGS_CONNECTION.cursor()
    except Exception as e:
        print(f"连接Archery数据库出错:{e}")
        exit

    query = """
    with rg as 
    (select a.instance_id,a.resourcegroup_id,b.group_name
    from  sql_instance_resource_group a
    inner join resource_group b on (a.resourcegroup_id=b.group_id))
    SELECT id, project_name,environment, db_type, instance_name,host, port,GROUP_CONCAT(rg.group_name SEPARATOR '::') AS group_name
    FROM sql_instance a left join rg on (a.id=rg.instance_id)
    WHERE db_type in ('mongo') AND environment='uat' and instance_name not like '%下线%' 
    GROUP BY id, project_name, db_type, instance_name, host, port;
    """
    LOGS_CURSOR.execute(query)
    archive_list = LOGS_CURSOR.fetchall()
    LOGS_CURSOR.close() 

    # 加载映射关系到内存
    # url_service_mapping = load_url_service_mapping(LOGS_CONNECTION)
    LOGS_CONNECTION.close()
    
    # 创建数据库服务(测试用)
    # database_services = [
    #     ("uat-zt(中台)-02用户", "uat-zt(中台)-02用户", "168.192.31.135:8124","uat"),
    #     ("uat-zt(中台)-09共用", "uat-zt(中台)-09共用", "168.192.31.135:8125","uat")
    # ]
    username, password = "open_metadata", "openMetadata"
    # for service_name, description, hostPort,env,resourceGroups in database_services:

    for item in archive_list:
        id, project_name,environment, db_type, instance_name,host, port,group_name = item
        db_service_response = meta_service.create_database_service(instance_name, f"archery_instance_id={id}", project_name, db_type, username, password, f"{host}:{port}", environment, group_name)
        if db_service_response.get("id"):
            service_id = db_service_response["id"]
            print(f"Database Service {instance_name} created successfully with ID: {service_id}")
            
            # 创建摄入管道
            ingestion_pipeline_response = meta_service.create_ingestion_pipeline(service_id, instance_name)
            if ingestion_pipeline_response.get("id"):
                pipeline_id = ingestion_pipeline_response["id"]
                print(f"Ingestion Pipeline {instance_name}_metadata_000000 created successfully with ID: {pipeline_id}")
                
                # 部署摄入管道
                meta_service.deploy_ingestion_pipeline(pipeline_id)
            else:
                print(f"Failed to create Ingestion Pipeline for {instance_name}.")
        else:
            print(f"Failed to create Database Service for {instance_name}.")

if __name__ == "__main__":
    main()