# coding: utf-8
"""
华为云 rds api 批量拉取审计日志
"""

import os
import requests
from huaweicloudsdkcore.auth.credentials import BasicCredentials
from huaweicloudsdkrds.v3.region.rds_region import RdsRegion
from huaweicloudsdkcore.exceptions import exceptions
from huaweicloudsdkrds.v3 import *

# 实例id，日志开始结束时间，下载目录
instance_id = "aaaaaaaaaaaaaaaaaaaaaaaaa"
start_time = "2024-12-24T00:00:00+0800"
end_time = "2024-12-24T11:05:00+0800"
download_directory = "d:/tmp/tmp_downloaded_logs"

ak = "xxxxxxxxxxxxxxxx"
sk = "xxxxxxxxxxxxxxxxxxxxxxxxxxx"

def get_client():
    # 从环境变量中读取 AK 和 SK
    # ak = os.environ["CLOUD_SDK_AK"]
    # sk = os.environ["CLOUD_SDK_SK"]

    credentials = BasicCredentials(ak, sk)
    client = RdsClient.new_builder() \
        .with_credentials(credentials) \
        .with_region(RdsRegion.value_of("cn-south-1")) \
        .build()
    return client

def list_auditlogs(client, instance_id, start_time, end_time, limit=5):
    auditlogs = []
    offset = 0

    while True:
        request = ListAuditlogsRequest()
        request.instance_id = instance_id
        request.start_time = start_time
        request.end_time = end_time
        request.offset = offset
        request.limit = limit

        response = client.list_auditlogs(request)
        auditlogs.extend(response.auditlogs)

        if len(auditlogs) >= response.total_record:
            break

        offset += limit

    return auditlogs

def generate_download_link(client, instance_id, auditlog_id):
    request = ShowAuditlogDownloadLinkRequest()
    request.instance_id = instance_id
    request.body = GenerateAuditlogDownloadLinkRequest(ids=[auditlog_id])
    response = client.show_auditlog_download_link(request)
    return response.links[0] if response.links else None

def download_log(download_link, log_name, download_directory):
    file_path = os.path.join(download_directory, log_name.split('/')[-1])
    response = requests.get(download_link)
    with open(file_path, 'wb') as f:
        f.write(response.content)
    print(f"Downloaded: {file_path}")

# 多线程下载时部分文件会有问题，因此单线程慢慢下
def download_logs_sequentially(client, instance_id, auditlogs, download_directory):
    for log in auditlogs:
        download_link = generate_download_link(client, instance_id, log.id)
        if download_link:
            download_log(download_link, log.name, download_directory)
            #time.sleep(0.75)  # 增加延时，确保每分钟不超过80个请求
        else:
            print(f"Failed to get download link for: {log.name}")

def main():
    os.makedirs(download_directory, exist_ok=True)

    client = get_client()

    print('-----------')
    try:
        auditlogs = list_auditlogs(client, instance_id, start_time, end_time)
        print(f"Total audit logs fetched: {len(auditlogs)}")
        print('-----------')
        print(auditlogs)
        print('-----------')

        download_logs_sequentially(client, instance_id, auditlogs, download_directory)

    except exceptions.ClientRequestException as e:
        print(e.status_code)
        print(e.request_id)
        print(e.error_code)
        print(e.error_msg)

if __name__ == "__main__":
    main()