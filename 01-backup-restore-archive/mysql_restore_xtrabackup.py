import os
import sys
import subprocess
import configparser
import logging
import socket
import re
import pymysql
import time
import base64

"""
docker-compose 快速恢复 xtrabackup 物理备份的 mysql 数据库
1. 恢复成功后使用docker来启动数据库，使用 docker ps即可看到恢复的数据库。
2. 可以恢复多个实例，要求备份的文件名不能重复。
3. 恢复的端口号不会冲突，会判断是否存在，如果存在会自动增加，例如恢复了一个文件名为 prod-20240107172119408 的端口号为6033 ，继续恢复文件名为 prod-20240208172119408 的端口号就会为6034。
4. 恢复成功后，会修改root密码，密码在脚本开头定义。
"""

MYSQL_VERSION = None
BACKUP_FILE = None

# 检查目录是否挂载
CHECK_DIR = r"/dbbackup"
# 定义恢复目录
RESTORE_DIR_ROOT = r"/dbbackup/restore/restore_db"
# 所在服务器IP
host = "127.0.0.1"
# MySQL 用户
user = "root"
# 旧密码
old_password = base64.b64decode("dGVzdHBhc3N3b3Jk").decode("utf-8")
# 恢复完毕，修改后的密码，最后可以用这个密码登录
new_password = "root.COM2025"

# 如果恢复的是MySQL 8.0 版本，需要用-xtrabackup-8.0版本
xbstream_cmd_8_0 = f"/usr/local/percona-xtrabackup-8.0.34-29-Linux-x86_64.glibc2.17/bin/xbstream"
xtrabackup_cmd_8_0 = f"/usr/local/percona-xtrabackup-8.0.34-29-Linux-x86_64.glibc2.17/bin/xtrabackup"
# 如果恢复的是MySQL 5.6/5.7 版本，需要用-xtrabackup-2.4版本
xbstream_cmd_2_4 = f"/usr/local/percona-xtrabackup-2.4.28-Linux-x86_64.glibc2.17/bin/xbstream"
xtrabackup_cmd_2_4 = f"/usr/local/percona-xtrabackup-2.4.28-Linux-x86_64.glibc2.17/bin/innobackupex"

def mkdir_if_not_exists(backup_dir):
    """
    如果不存在文件夹，就会递归创建新建文件夹
    """
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)

def check_directory_existence(directory_path):
    """
    如果不存在文件夹，就会退出脚本执行
    """
    if os.path.exists(directory_path) and os.path.isdir(directory_path):
        print(f"{directory_path} Directory exists")
        sys.exit(1)

def execute_command(command):
    result = subprocess.run(command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("正在执行命令>>> ",command)
    return result.returncode

def check_filesystem(directory_path):
    """
    检查是否存在挂载目录，如果需要恢复的数据库很大，并且又没有挂载目录，则会把恢复的数据放在 根目录，会可能把根目录空间撑满
    """
    expected_filesystem = "obsfs"
    df_output = os.popen("df -h " + directory_path).read()
    relevant_line = [line for line in df_output.split('\n') if directory_path in line]
    if len(relevant_line) > 0:
        filesystem = relevant_line[0].split()[0]
        if filesystem != expected_filesystem:
            print(f"Unable to find information about {directory_path}")
            sys.exit(1)
        else:
            print(f"The filesystem of {directory_path} is {expected_filesystem}")
    else:
        print(f"Unable to find information about {directory_path}")

def logging_file(file_name, content):
    """
    记录日志内容到指定的文件中
    Args:
    file_name (str): 日志文件名
    content (str): 要记录的日志内容
    """
    logger = logging.getLogger('my_logger')
    logger.setLevel(logging.INFO)
    fh = logging.FileHandler(file_name, mode='a', encoding='utf-8')  # 使用追加模式
    formatter = logging.Formatter(fmt="%(asctime)s %(filename)s %(lineno)d行 | %(message)s",datefmt="%Y/%m/%d %H:%M:%S")
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    logger.info(content)
    logger.removeHandler(fh)
    fh.close()

cnf_content = """[mysql]  
port=3306  
prompt="\\u@\\h [\\d]>"  

[mysqld]
default_authentication_plugin=mysql_native_password
port=3306 
datadir=/var/lib/mysql
log-error=/var/lib/mysql/mysql-error.log
socket=/var/run/mysqld/mysql.sock  
#max_allowed_packet= 2G  
skip-name-resolve=1 
character_set_server=utf8mb4
collation_server=utf8mb4_general_ci
user=mysql
sql_mode=""
lower_case_table_names = 1 
#performance setting
lock_wait_timeout = 3600
open_files_limit = 65535
interactive_timeout = 600
wait_timeout = 600
connect_timeout=600
net_read_timeout=600

#innodb 
innodb_buffer_pool_size=2G
innodb_buffer_pool_instances = 8
innodb_data_file_path = ibdata1:12M:autoextend
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 32M
innodb_log_file_size = 2G
innodb_log_files_in_group = 3
#innodb_max_undo_log_size = 2G

#binlog  
server-id=10086
log-bin = mysql 
binlog_format=row

#gtid 
gtid_mode=on
enforce_gtid_consistency=on  
log-slave-updates=1  
#log_replica_updates=1
"""

docker_compose_yml = """version: '2.1'
services:
    mysql:
        environment:
            TZ: "Asia/Shanghai"
            MYSQL_ROOT_PASSWORD: "root.COM2020" 
        user: "1001:1001"
        image: mysql:8.0.28
        container_name: "ps6033"
        security_opt:
            - seccomp:unconfined
        restart: always
        volumes:  
            - "/dbbackup/data/dbdata:/var/lib/mysql"
            - "/dbbackup/data/run_mysqld:/var/run/mysqld"            
            - "/dbbackup/data/cnf/my.cnf:/etc/my.cnf"  
        ports:  
            - "6033:3306"
        command: ["--lower-case-table-names=1"]            
"""

def write_to_file(file_path, file_name, content):
    """
    写入内容到配置文件 my.cnf
    """
    file_dir = f"%s/%s" %(file_path, file_name)
    with open(file_dir, 'w') as file:
        file.write(content)

def set_cnf_value(cnf_file,key, value):
    """
    修改配置文件 my.cnf
    """
    config = configparser.ConfigParser()
    config.read(cnf_file)
    if 'mysqld' in config and key in config['mysqld']:
        config.set('mysqld', key, value)
        with open(cnf_file, mode='w', encoding='utf-8') as configfile:
            config.write(configfile)
    else:
        print(f"错误：键 {key} 不存在于配置文件中")

def check_mysql_version(mysql_version):
    """
    判断MySQL的版本
    """
    if "5.6" in mysql_version:
        return "5.6"
    if "5.7" in mysql_version:
        return "5.7"
    if "8.0" in mysql_version:
        return "8.0"
    
def docker_image_mysql_version(mysql_version):
    """
    判断MySQL的版本
    """
    if "5.6" in mysql_version:
        return "5.6.51"
    if "5.7" in mysql_version:
        return "5.7.43"
    if "8.0" in mysql_version:
        return "8.0.25"

def extract_mysql_instance_name(path):
    """
    获取文件名，并把包含除字母数字以外的字符，全都转换成下划线 "_"
    此文件名的作用：用于创建恢复时的目录名称
    """
    instance_name = path.split('/')[-1]
    cleaned_instance_name = re.sub(r'[-]', '_', instance_name)
    return cleaned_instance_name

def unzip_mysqlbak_file(bak_file,unzip_dir,log_file,version):
    """
    解压备份文件
    """
    mysql_version = check_mysql_version(version)
    if mysql_version == '5.6':
        xbstream_cmd = f"%s  -x --parallel=4 <  %s -C %s" %(xbstream_cmd_2_4,bak_file,unzip_dir)
        xtrabackup_cmd = f"%s --parallel=4 --decompress  %s" %(xtrabackup_cmd_2_4,unzip_dir)
    elif mysql_version == '5.7':
        xbstream_cmd = f"%s  -x --parallel=4 <  %s -C %s" %(xbstream_cmd_2_4,bak_file,unzip_dir)
        xtrabackup_cmd = f"%s --parallel=4 --decompress  %s" %(xtrabackup_cmd_2_4,unzip_dir)
    elif mysql_version == '8.0':
        xbstream_cmd = f"%s  -x --parallel=4 <  %s -C %s" %(xbstream_cmd_8_0,bak_file,unzip_dir)
        xtrabackup_cmd = f"%s --parallel=4 --decompress  --target-dir=%s" %(xtrabackup_cmd_8_0,unzip_dir)
    else:
        print("unzip错误：无效的版本号")
    logging_file(log_file,xbstream_cmd)
    logging_file(log_file,xtrabackup_cmd)
    execute_command(xbstream_cmd)
    execute_command(xtrabackup_cmd)

def del_qp_file(path):
    """
    删除临时备份文件中的qp后缀名文件
    """
    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith(".qp"):
                os.remove(os.path.join(root, file))

def prepare_mysqlbak_file(unzip_dir,log_file,version):
    """
    prepare恢复备份文件
    """
    mysql_version = check_mysql_version(version)
    if mysql_version == '5.6':
        xtrabackup_cmd = f"%s --apply-log  %s" %(xtrabackup_cmd_2_4,unzip_dir)
    elif mysql_version == '5.7':
        xtrabackup_cmd = f"%s --apply-log  %s" %(xtrabackup_cmd_2_4,unzip_dir)
    elif mysql_version == '8.0':
        xtrabackup_cmd = f"%s --prepare --target-dir=%s" %(xtrabackup_cmd_8_0,unzip_dir)
    else:
        print("prepare错误：无效的版本号")
    logging_file(log_file,xtrabackup_cmd)
    execute_command(xtrabackup_cmd)

def restore_mysqlbak_file(cnf_file,unzip_dir,log_file,version):
    """
    copy-back恢复备份文件
    """
    mysql_version = check_mysql_version(version)
    if mysql_version == '5.6':
        xtrabackup_cmd = f"%s --defaults-file=%s --copy-back  %s" %(xtrabackup_cmd_2_4,cnf_file,unzip_dir)
    elif mysql_version == '5.7':
        xtrabackup_cmd = f"%s --defaults-file=%s --copy-back  %s" %(xtrabackup_cmd_2_4,cnf_file,unzip_dir)
    elif mysql_version == '8.0':
        xtrabackup_cmd = f"%s --defaults-file=%s --copy-back --target-dir=%s" %(xtrabackup_cmd_8_0,cnf_file,unzip_dir)
    else:
        print("restore错误：无效的版本号")
    logging_file(log_file,xtrabackup_cmd)
    execute_command(xtrabackup_cmd)

def update_chown(dir_or_file):
    """
    修改目录权限
    """
    chown_dir = f"chown -R 1001:1001 {dir_or_file}"
    execute_command(chown_dir)

def update_innodb_data_file_path(RESTORE_DIR_DB,cnf_file):
    """
    修改 my.cnf  innodb_data_file_path 参数
    """
    file_name = f"{RESTORE_DIR_DB}/ibdata1"
    file_size_bytes = os.path.getsize(file_name)
    file_size_MB = int(file_size_bytes / (1024 * 1024))
    innodb_data_file_path_value = f"ibdata1:{file_size_MB}M:autoextend"
    set_cnf_value(cnf_file,'innodb_data_file_path', innodb_data_file_path_value)

def update_file_content(file_path, file_name, old_content, new_content):
    """
    修改文件内容
    file_path：文件路径
    file_name： 文件名
    old_content： 需要替换的内容
    new_content：修改的内容
    """
    file_path = f"{file_path}/{file_name}"
    old_content_escaped = old_content.replace('/', r'\/')
    new_content_escaped = new_content.replace('/', r'\/')
    sed_cmd = f"sed -i 's/{old_content_escaped}/{new_content_escaped}/g' {file_path}"
    execute_command(sed_cmd)

def check_port_existence(port_number):
    """
    检查端口是否存在，如果不存在，返回port_number；如果存在，则port_number+1
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        result = s.connect_ex(('127.0.0.1', port_number))
        if result == 0:
            # 端口已被占用，尝试检查 port_number + 1 是否被占用
            while True:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s2:
                    result_2 = s2.connect_ex(('127.0.0.1', port_number + 1))
                    if result_2 != 0:
                        return str(port_number + 1)
                    else:
                        port_number += 1
        else:
            return str(port_number)

def get_next_container_name():
    """
    获取容器名，用于创建容器名
    """
    try:
        output = subprocess.check_output(["docker", "ps", "-a"])
        output_str = output.decode("utf-8")
        container_names = re.findall(r'ps\d+', output_str)
        if not container_names:
            return "ps6033"
        else:
            max_number = max([int(name[2:]) for name in container_names])
            next_number = max_number + 1
            return "ps" + str(next_number)
    except subprocess.CalledProcessError:
        return "Error occurred while trying to fetch container names"

def change_mysql_root_password(port,mysql_version):
    """
    修改MySQL 用户密码
    """
    max_retries = 6
    retry_interval = 30
    print("正在执行命令>>>  正在修改 MySQL root 用户密码")
    def connect_mysql_with_retry():
        for _ in range(max_retries):
            try:
                connection = pymysql.connect(host=host, user=user, port=int(port), password=old_password, database='mysql')
                return connection
            except pymysql.MySQLError as e:
                print(f"Failed to connect to MySQL. Retrying in {retry_interval} seconds.")
                time.sleep(retry_interval)
        raise ConnectionError("Unable to connect to MySQL after multiple retries.")

    connection = connect_mysql_with_retry()
    cursor = connection.cursor()
    if "5.6" in mysql_version:
        sql = f"""SET PASSWORD FOR 'root'@'%' = PASSWORD('{new_password}');"""
    if "5.7" in mysql_version or "8.0" in mysql_version:
        sql = f"""ALTER USER 'root'@'%' IDENTIFIED BY '{new_password}'; """
    cursor.execute(sql)
    connection.commit()
    cursor.close()
    connection.close()
    port = int(port)
    login_cmd = f'''mysql -h{host} -P{port} -u{user} -p"{new_password}"'''
    print("登录命令>>> ",login_cmd)

def restore_mysql(_mysql_version=MYSQL_VERSION,_backup_file=BACKUP_FILE):
    # Start time for duration calculation
    start_time = time.time()

    # 检查需要恢复的目录是否挂载上，如果没挂载上，直接退出
    check_filesystem(CHECK_DIR)
    # 定义目录
    instance_name = extract_mysql_instance_name(_backup_file)
    RESTORE_DIR_BASE = f"%s/%s" % (RESTORE_DIR_ROOT,instance_name)
    # 目录：数据文件目录
    RESTORE_DIR_DB = f"%s/dbdata" % (RESTORE_DIR_BASE)
    # 目录：配置文件目录
    RESTORE_DIR_CNF = f"%s/cnf" % (RESTORE_DIR_BASE)
    # 日志文件
    log_file = f"%s/restore.log" % (RESTORE_DIR_BASE)
    # MySQL配置文件 my.cnf
    cnf_file = f"{RESTORE_DIR_CNF}/my.cnf"
    docker_compose_file = "docker-compose.yml"
    # 检查目录是否存在，如果存在，说明此备份文件已经恢复，则直接退出
    check_directory_existence(RESTORE_DIR_BASE)
    # 创建目录
    mkdir_if_not_exists(RESTORE_DIR_DB)
    mkdir_if_not_exists(RESTORE_DIR_CNF)
    # 目录：sock文件目录
    run_mysqld_tmp_dir = f"{RESTORE_DIR_BASE}/run_mysqld"
    mkdir_if_not_exists(run_mysqld_tmp_dir)
    # 创建配置文件 my.cnf
    write_to_file(RESTORE_DIR_CNF, "my.cnf", cnf_content)
    # 创建配置文件 docker-compose.yml
    write_to_file(RESTORE_DIR_BASE, "docker-compose.yml", docker_compose_yml)
    # 解压全备文件
    unzip_mysqlbak_file(_backup_file,RESTORE_DIR_DB,log_file,_mysql_version)
    # 删除qp文件
    del_qp_file(RESTORE_DIR_DB)
    # 准备备份文件,恢复数据到自建库
    prepare_mysqlbak_file(RESTORE_DIR_DB,log_file,_mysql_version)
    # 修改目录权限
    update_chown(RESTORE_DIR_DB)
    update_chown(cnf_file)
    update_chown(run_mysqld_tmp_dir)
    # 修改 innodb_data_file_path 参数
    update_innodb_data_file_path(RESTORE_DIR_DB,cnf_file)
    # 获取端口号
    new_port = check_port_existence(6033)
    # 获取MySQL版本号对应镜像
    docker_image = docker_image_mysql_version(_mysql_version)
    # 修改 docker-compose.yml 文件
    update_file_content(RESTORE_DIR_BASE, docker_compose_file,"/dbbackup/data/dbdata", RESTORE_DIR_DB)
    update_file_content(RESTORE_DIR_BASE, docker_compose_file,"/dbbackup/data/run_mysqld",run_mysqld_tmp_dir)
    update_file_content(RESTORE_DIR_BASE, docker_compose_file,"/dbbackup/data/cnf",RESTORE_DIR_CNF)
    update_file_content(RESTORE_DIR_BASE, docker_compose_file,"8.0.28",docker_image)
    update_file_content(RESTORE_DIR_BASE, docker_compose_file,"6033",new_port)
    # 获取docker容器名
    container_name = get_next_container_name()
    # 修改 docker-compose.yml 文件
    update_file_content(RESTORE_DIR_BASE, docker_compose_file,"ps6033",container_name)
    # 使用docker-compose启动docker
    docker_compose_name = f"{RESTORE_DIR_BASE}/{docker_compose_file}"
    docker_compose_up = f"docker-compose -f {docker_compose_name} up -d"
    # 启动docker
    execute_command(docker_compose_up)
    # 修改 MySQL root 用户密码
    change_mysql_root_password(new_port,_mysql_version)

    # End time for duration calculation
    end_time = time.time()
    duration_seconds = int(end_time - start_time)

    return RESTORE_DIR_BASE, duration_seconds, host, new_port, user, new_password 

if __name__ == "__main__":
    # 执行脚本后面接两个参数，第一个参数是版本号，必须要精确到小版本号；第二个参数是备份文件的路径
    if len(sys.argv) != 3:
        print("Usage: python3 restore_mysql.py <mysql_version> <backup_file>")
        print('eg: python3 restore_mysql.py "8.0.28" "/hwdbbackup/mysql/prod_aigc/mysql-rds-prod-aigc-20240107172119408"')
        sys.exit(1)

    MYSQL_VERSION = sys.argv[1]
    BACKUP_FILE = sys.argv[2]

    # Call the restore_mysql function with the provided arguments
    restore_dir, port, duration_seconds = restore_mysql(_mysql_version=MYSQL_VERSION, _backup_file=BACKUP_FILE)

    print(f"Restore completed in {duration_seconds} seconds.")
    print(f"Restore directory: {restore_dir}")
    print(f"MySQL is running on port: {port}")

